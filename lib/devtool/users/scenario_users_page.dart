import 'package:flutter/material.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection_container.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/onboarding/onboarding_cubit.dart';
import '../../l10n/app_localizations.dart';
import '../gateway/dev_gateway_client.dart';
import 'fund_jeeber_wallet_page.dart';

class ScenarioUsersPage extends StatefulWidget {
  const ScenarioUsersPage({super.key, this.client});

  final DevGatewayClient? client;

  @override
  State<ScenarioUsersPage> createState() => _ScenarioUsersPageState();
}

class _UserScenario {
  const _UserScenario(this.labelKey, this.role, this.scenario);

  final String labelKey;
  final String role;
  final String scenario;
}

const List<_UserScenario> _scenarios = [
  _UserScenario('regular', 'client', 'regular'),
  _UserScenario('jeeber', 'jeeber', 'regular'),
  _UserScenario('suspended', 'client', 'suspended'),
  _UserScenario('kycPending', 'client', 'kyc-pending'),
  _UserScenario('admin', 'admin', 'regular'),
];

class _ScenarioUsersPageState extends State<ScenarioUsersPage> {
  late final DevGatewayClient _client = widget.client ?? DevGatewayClient();
  AuthTokenStore get _tokenStore => sl<AuthTokenStore>();
  final TextEditingController _usernameController = TextEditingController();

  _UserScenario _selectedScenario = _scenarios.first;
  bool _seeding = false;
  bool _usernameEdited = false;
  bool _approveKyc = false;
  DevUser? _lastSeeded;
  bool _lastSeededWasJeeber = false;

  Future<List<DevUser>>? _rosterFuture;

  @override
  void initState() {
    super.initState();
    _usernameController.text = DevGatewayClient.suggestedUsername(
      _selectedScenario.role,
    );
    _loadRoster();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _loadRoster() {
    setState(() {
      _rosterFuture = _client.listUsers();
    });
  }

  Future<void> _createUser() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _seeding = true);
    try {
      final username = _usernameController.text.trim();
      final user = await _client.seedUser(
        role: _selectedScenario.role,
        scenario: _selectedScenario.scenario,
        displayName: username.isEmpty ? null : username,
      );
      if (!mounted) return;
      final isJeeber = _selectedScenario.role == 'jeeber';
      setState(() {
        _lastSeeded = user;
        _lastSeededWasJeeber = isJeeber;
      });
      if (!_usernameEdited) {
        _usernameController.text = DevGatewayClient.suggestedUsername(
          _selectedScenario.role,
        );
      }
      showOmdsSuccessSnackbar(
        context,
        message: l10n.scenarioUsersCreated(
          _scenarioLabel(l10n, _selectedScenario),
          user.username,
          _bidiScenario(user.id),
        ),
      );
      if (isJeeber && _approveKyc) {
        final status = await _runOnlineReady(user.id);
        if (!mounted) return;
        showOmdsSuccessSnackbar(context, message: '${user.id} — $status');
      }
      _loadRoster();
    } on DevGatewayException catch (e) {
      if (!mounted) return;
      showOmdsErrorSnackbar(context, message: e.message);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _makeOnlineReady(String userId) async {
    setState(() => _seeding = true);
    try {
      final status = await _runOnlineReady(userId);
      if (!mounted) return;
      showOmdsSuccessSnackbar(context, message: '$userId — $status');
    } on DevGatewayException catch (e) {
      if (!mounted) return;
      showOmdsErrorSnackbar(context, message: e.message);
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  void _openWalletFunding(DevUser jeeber) {
    Navigator.of(context).push(
      OmdsSlideRoute<void>(
        page: FundJeeberWalletPage(jeeber: jeeber, client: _client),
      ),
    );
  }

  // Approves the jeeber's KYC server-side (sanctioned admin review route),
  // then signs in and verifies availability; _saveSession notes the caveat.
  Future<String> _runOnlineReady(String userId) async {
    final adminToken = await _client.mintTokenForUser(
      userId,
      roles: const ['admin'],
    );
    final kycId = await _client.findKycSubmissionId(userId, adminToken);
    final String approveNote;
    if (kycId != null) {
      final roleGranted = await _client.approveKyc(kycId, adminToken);
      approveNote = roleGranted
          ? 'KYC approved (driver role granted)'
          : 'KYC approved';
    } else {
      approveNote = 'no KYC submission in the review queue to approve';
    }

    final normal = await _client.mintSession(userId);
    final normalReady = await _client.availabilityLoads(normal.accessToken);
    if (normalReady) {
      await _saveSession(userId, normal);
      return '$approveNote; signed in, availability loads';
    }

    final forced = await _client.mintSession(
      userId,
      roles: const ['customer', 'driver'],
    );
    await _saveSession(userId, forced);
    return '$approveNote; a normal session still 403s — signed in with a '
        'temporary forced-role session (reverts on token refresh)';
  }

  Future<void> _saveSession(
    String userId,
    ({String accessToken, String refreshToken}) session,
  ) async {
    await _tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      userId: userId,
    );
    await sl<SharedPreferences>().setBool(OnboardingCubit.completedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.scenarioUsersTitle,
        showBackButton: true,
        centerTitle: false,
      ),
      body: OmdsPullToRefresh(
        onRefresh: () async {
          _loadRoster();
          await _rosterFuture;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.scenarioUsersCreate,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            OMDSBottomSheetSelectField(
              title: l10n.scenarioUsersScenario,
              label: l10n.scenarioUsersScenario,
              value: _selectedScenario.labelKey,
              showSearch: false,
              enabled: !_seeding,
              identifier: 'devtool.scenarioUsers.scenario',
              options: [
                for (final scenario in _scenarios)
                  OMDSSelectOption(
                    value: scenario.labelKey,
                    label: _scenarioLabel(l10n, scenario),
                  ),
              ],
              onChanged: (option) {
                if (option == null) return;
                final value = _scenarios.firstWhere(
                  (scenario) => scenario.labelKey == option.value,
                );
                setState(() {
                  _selectedScenario = value;
                  if (!_usernameEdited) {
                    _usernameController.text =
                        DevGatewayClient.suggestedUsername(value.role);
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            OmdsTextField(
              controller: _usernameController,
              enabled: !_seeding,
              labelText: l10n.scenarioUsersUsername,
              hintText: l10n.scenarioUsersUsernameHelp,
              identifier: 'devtool.scenarioUsers.username',
              onChanged: (_) => _usernameEdited = true,
            ),
            if (_selectedScenario.role == 'jeeber') ...[
              const SizedBox(height: 4),
              OmdsCheckboxTile(
                contentPadding: EdgeInsets.zero,
                value: _approveKyc,
                enabled: !_seeding,
                onChanged: _seeding
                    ? null
                    : (value) => setState(() => _approveKyc = value ?? false),
                title: l10n.scenarioUsersApproveKyc,
                subtitle: l10n.scenarioUsersApproveKycHelp,
                identifier: 'devtool.scenarioUsers.approveKyc',
              ),
            ],
            const SizedBox(height: 12),
            OmdsLoadingButton(
              text: l10n.scenarioUsersCreate,
              onTap: _createUser,
              isLoading: _seeding,
              isEnabled: !_seeding,
              identifier: 'devtool.scenarioUsers.create',
            ),
            if (_lastSeeded != null) ...[
              const SizedBox(height: 16),
              OMDSSectionCard(
                title: l10n.scenarioUsersLastCreated,
                showDivider: false,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      l10n.scenarioUsersId(_bidiScenario(_lastSeeded!.id)),
                    ),
                    SelectableText(
                      l10n.scenarioUsersUsernameValue(_lastSeeded!.username),
                    ),
                    if (_lastSeeded!.role != null)
                      SelectableText(
                        l10n.scenarioUsersRole(
                          _localizedRole(l10n, _lastSeeded!.role!),
                        ),
                      ),
                    SelectableText(
                      l10n.scenarioUsersStatus(
                        _localizedStatus(l10n, _lastSeeded!.status),
                      ),
                    ),
                    if (_lastSeededWasJeeber) ...[
                      const SizedBox(height: 8),
                      OMDSOutlinedButton(
                        enabled: !_seeding,
                        onTap: () => _makeOnlineReady(_lastSeeded!.id),
                        icon: const Icon(Icons.verified_user),
                        text: l10n.scenarioUsersMakeOnlineReady,
                        identifier: 'devtool.scenarioUsers.makeOnlineReady',
                      ),
                      const SizedBox(height: 8),
                      OmdsPrimaryButton(
                        identifier: 'devtool.walletFunding.lastCreated',
                        text: l10n.walletFundingAddMoney,
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        onTap: () => _openWalletFunding(_lastSeeded!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              l10n.scenarioUsersRoster,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            _ScenarioUsersRoster(
              future: _rosterFuture,
              onRetry: _loadRoster,
              onAddMoney: _openWalletFunding,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScenarioUsersRoster extends StatelessWidget {
  const _ScenarioUsersRoster({
    required this.future,
    required this.onRetry,
    required this.onAddMoney,
  });

  final Future<List<DevUser>>? future;
  final VoidCallback onRetry;
  final ValueChanged<DevUser> onAddMoney;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<DevUser>>(
    future: future,
    builder: (context, snapshot) => _ScenarioRosterSnapshot(
      snapshot: snapshot,
      onRetry: onRetry,
      onAddMoney: onAddMoney,
    ),
  );
}

class _ScenarioRosterSnapshot extends StatelessWidget {
  const _ScenarioRosterSnapshot({
    required this.snapshot,
    required this.onRetry,
    required this.onAddMoney,
  });

  final AsyncSnapshot<List<DevUser>> snapshot;
  final VoidCallback onRetry;
  final ValueChanged<DevUser> onAddMoney;

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: OmdsLoadingState()),
      );
    }
    final error = snapshot.error;
    if (error != null) {
      return _ScenarioRosterError(error: error, onRetry: onRetry);
    }
    final users = snapshot.data ?? const <DevUser>[];
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(AppLocalizations.of(context).scenarioUsersEmpty),
      );
    }
    return _ScenarioRosterList(users: users, onAddMoney: onAddMoney);
  }
}

class _ScenarioRosterError extends StatelessWidget {
  const _ScenarioRosterError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is DevGatewayException
        ? (error as DevGatewayException).message
        : error.toString();
    return OMDSSectionCard(
      title: AppLocalizations.of(context).scenarioUsersRoster,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          OMDSOutlinedButton(
            text: AppLocalizations.of(context).scenarioUsersRetry,
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ScenarioRosterList extends StatelessWidget {
  const _ScenarioRosterList({required this.users, required this.onAddMoney});

  final List<DevUser> users;
  final ValueChanged<DevUser> onAddMoney;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final user in users)
        _ScenarioUserRosterCard(user: user, onAddMoney: () => onAddMoney(user)),
    ],
  );
}

class _ScenarioUserRosterCard extends StatelessWidget {
  const _ScenarioUserRosterCard({required this.user, required this.onAddMoney});

  final DevUser user;
  final VoidCallback onAddMoney;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final metadata = <String>[
      l10n.scenarioUsersId(_bidiScenario(user.id)),
      if (user.role != null)
        l10n.scenarioUsersRole(_localizedRole(l10n, user.role!)),
      l10n.scenarioUsersStatus(_localizedStatus(l10n, user.status)),
    ].join('\n');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OmdsSettingsRow(
        title: user.username.isEmpty ? _bidiScenario(user.id) : user.username,
        subtitle: metadata,
        trailing: user.isJeeber
            ? _RosterWalletAction(userId: user.id, onTap: onAddMoney)
            : null,
      ),
    );
  }
}

class _RosterWalletAction extends StatelessWidget {
  const _RosterWalletAction({required this.userId, required this.onTap});

  final String userId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    child: OmdsPrimaryButton(
      text: AppLocalizations.of(context).walletFundingAddMoney,
      identifier: 'devtool.walletFunding.roster.$userId',
      onTap: onTap,
    ),
  );
}

String _scenarioLabel(AppLocalizations l10n, _UserScenario scenario) =>
    switch (scenario.labelKey) {
      'regular' => l10n.scenarioUsersRegular,
      'jeeber' => l10n.scenarioUsersJeeber,
      'suspended' => l10n.scenarioUsersSuspended,
      'kycPending' => l10n.scenarioUsersKycPending,
      'admin' => l10n.scenarioUsersAdmin,
      _ => scenario.labelKey,
    };

String _bidiScenario(String value) => '\u2068$value\u2069';

String _localizedRole(AppLocalizations l10n, String value) =>
    switch (value.trim().toLowerCase()) {
      'client' || 'customer' => l10n.scenarioUsersRoleCustomer,
      'driver' || 'jeeber' => l10n.scenarioUsersRoleJeeber,
      'partner' => l10n.scenarioUsersRolePartner,
      'admin' => l10n.scenarioUsersRoleAdmin,
      _ => value,
    };

String _localizedStatus(AppLocalizations l10n, String value) =>
    switch (value.trim().toLowerCase()) {
      'active' => l10n.scenarioUsersStatusActive,
      'suspended' => l10n.scenarioUsersStatusSuspended,
      'pending' || 'kyc-pending' => l10n.scenarioUsersStatusPending,
      _ => value,
    };
