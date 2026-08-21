import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection_container.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/onboarding/onboarding_cubit.dart';
import '../gateway/dev_gateway_client.dart';

class ScenarioUsersPage extends StatefulWidget {
  const ScenarioUsersPage({super.key});

  @override
  State<ScenarioUsersPage> createState() => _ScenarioUsersPageState();
}

class _UserScenario {
  const _UserScenario(this.label, this.role, this.scenario);

  final String label;
  final String role;
  final String scenario;
}

const List<_UserScenario> _scenarios = [
  _UserScenario('Regular customer', 'client', 'regular'),
  _UserScenario('Jeeber', 'jeeber', 'regular'),
  _UserScenario('Suspended', 'client', 'suspended'),
  _UserScenario('KYC pending', 'client', 'kyc-pending'),
  _UserScenario('Funded wallet', 'client', 'funded-wallet'),
  _UserScenario('Admin', 'admin', 'regular'),
];

class _ScenarioUsersPageState extends State<ScenarioUsersPage> {
  final DevGatewayClient _client = DevGatewayClient();
  final AuthTokenStore _tokenStore = sl<AuthTokenStore>();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${_selectedScenario.label}: ${user.username} '
            '(${user.id})',
          ),
        ),
      );
      if (isJeeber && _approveKyc) {
        final status = await _runOnlineReady(user.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${user.id} — $status')));
      }
      _loadRoster();
    } on DevGatewayException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _makeOnlineReady(String userId) async {
    setState(() => _seeding = true);
    try {
      final status = await _runOnlineReady(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$userId — $status')));
    } on DevGatewayException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Scenario Users')),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadRoster();
          await _rosterFuture;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Create user', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<_UserScenario>(
              initialValue: _selectedScenario,
              decoration: const InputDecoration(
                labelText: 'Scenario',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final scenario in _scenarios)
                  DropdownMenuItem(
                    value: scenario,
                    child: Text(scenario.label),
                  ),
              ],
              onChanged: _seeding
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _selectedScenario = value;
                          if (!_usernameEdited) {
                            _usernameController.text =
                                DevGatewayClient.suggestedUsername(value.role);
                          }
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              enabled: !_seeding,
              decoration: const InputDecoration(
                labelText: 'Username',
                helperText:
                    'Sent as displayName; blank falls back to the auto value.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _usernameEdited = true,
            ),
            if (_selectedScenario.role == 'jeeber') ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _approveKyc,
                onChanged: _seeding
                    ? null
                    : (value) => setState(() => _approveKyc = value ?? false),
                title: const Text('Approve KYC (make online-ready)'),
                subtitle: const Text(
                  'Approves KYC server-side, then signs in. Falls back to a '
                  'temporary forced-role session that reverts on token refresh.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _seeding ? null : _createUser,
              icon: _seeding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add),
              label: const Text('Create user'),
            ),
            if (_lastSeeded != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last created',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      SelectableText('id: ${_lastSeeded!.id}'),
                      SelectableText('username: ${_lastSeeded!.username}'),
                      if (_lastSeeded!.role != null)
                        SelectableText('role: ${_lastSeeded!.role}'),
                      SelectableText('status: ${_lastSeeded!.status}'),
                      if (_lastSeededWasJeeber) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _seeding
                              ? null
                              : () => _makeOnlineReady(_lastSeeded!.id),
                          icon: const Icon(Icons.verified_user),
                          label: const Text('Make online-ready'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Roster', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            _buildRoster(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoster() {
    return FutureBuilder<List<DevUser>>(
      future: _rosterFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          final message = error is DevGatewayException
              ? error.message
              : error.toString();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loadRoster,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final users = snapshot.data ?? const <DevUser>[];
        if (users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No users seeded yet.'),
          );
        }
        return Column(
          children: [
            for (final user in users)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(user.username.isEmpty ? user.id : user.username),
                  subtitle: Text(
                    'id: ${user.id}'
                    '${user.role != null ? ' • role: ${user.role}' : ''}'
                    ' • status: ${user.status}',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
