import 'package:flutter/material.dart';
import 'package:omds/omds.dart';
import '../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';

import '../../l10n/app_localizations.dart';
import '../gateway/dev_gateway_client.dart';
import '../gateway/dev_gateway_failure.dart';
import 'fund_jeeber_wallet_page.dart';

class FundJeeberWalletPickerPage extends StatefulWidget {
  const FundJeeberWalletPickerPage({super.key, this.client});

  final DevGatewayClient? client;

  @override
  State<FundJeeberWalletPickerPage> createState() =>
      _FundJeeberWalletPickerPageState();
}

class _FundJeeberWalletPickerPageState
    extends State<FundJeeberWalletPickerPage> {
  late final DevGatewayClient _client = widget.client ?? DevGatewayClient();
  late Future<List<DevUser>> _jeebersFuture = _fetchJeebers();

  Future<List<DevUser>> _fetchJeebers() async {
    final users = await _client.listUsers();
    final jeebers = users.where((user) => user.isJeeber).toList()
      ..sort((left, right) => _label(left).compareTo(_label(right)));
    return List<DevUser>.unmodifiable(jeebers);
  }

  void _retry() {
    final retry = _fetchJeebers();
    setState(() {
      _jeebersFuture = retry;
    });
  }

  Future<void> _refresh() async {
    final refresh = _fetchJeebers();
    setState(() {
      _jeebersFuture = refresh;
    });
    try {
      await refresh;
    } on Object {
      // The FutureBuilder renders the localized error and retry action.
    }
  }

  void _openFunding(DevUser jeeber) {
    Navigator.of(context).push(
      OmdsSlideRoute<void>(
        page: FundJeeberWalletPage(jeeber: jeeber, client: _client),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.walletFundingTitle,
        showBackButton: true,
        centerTitle: false,
      ),
      body: JeebPullToRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Spacing.medium),
          children: [
            Text(
              l10n.walletFundingPickerDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.medium),
            FutureBuilder<List<DevUser>>(
              future: _jeebersFuture,
              builder: (context, snapshot) => _JeeberPickerSnapshot(
                snapshot: snapshot,
                onRetry: _retry,
                onSelected: _openFunding,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JeeberPickerSnapshot extends StatelessWidget {
  const _JeeberPickerSnapshot({
    required this.snapshot,
    required this.onRetry,
    required this.onSelected,
  });

  final AsyncSnapshot<List<DevUser>> snapshot;
  final VoidCallback onRetry;
  final ValueChanged<DevUser> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (snapshot.connectionState == ConnectionState.waiting) {
      return JeebEmptyState.compact(
        identifier: 'devtool_wallet_funding_picker_loading',
        status: JeebEmptyStateStatus.loading,
        reason: JeebEmptyStateReason.loading,
        variant: JeebEmptyStateVariant.pocket,
        headline: l10n.walletFundingPickerLoading,
      );
    }
    if (snapshot.error case final error?) {
      return JeebFailureBlock.compact(
        failure: devGatewayFailure(error),
        identifier: 'devtool_wallet_funding_picker_error',
        headlineOverride: l10n.walletFundingPickerErrorTitle,
        bodyOverride: devGatewayMessage(error),
        variant: JeebEmptyStateVariant.pocket,
        onRetry: onRetry,
        onExit: () => Navigator.of(context).maybePop(),
      );
    }
    final jeebers = snapshot.data ?? const <DevUser>[];
    if (jeebers.isEmpty) {
      return JeebEmptyState.compact(
        identifier: 'devtool_wallet_funding_picker_empty',
        reason: JeebEmptyStateReason.nothingYet,
        variant: JeebEmptyStateVariant.pocket,
        headline: l10n.walletFundingPickerEmptyTitle,
        body: l10n.walletFundingPickerEmptyBody,
        action: JeebCtaButton.outline(
          label: l10n.actionRetry,
          leadingIcon: Icons.refresh,
          expand: false,
          identifier: 'devtool_wallet_funding_picker_empty_retry_cta',
          onTap: onRetry,
        ),
      );
    }
    return _JeeberPickerList(jeebers: jeebers, onSelected: onSelected);
  }
}

class _JeeberPickerList extends StatelessWidget {
  const _JeeberPickerList({required this.jeebers, required this.onSelected});

  final List<DevUser> jeebers;
  final ValueChanged<DevUser> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final jeeber in jeebers)
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.small),
          child: OmdsSettingsRow(
            identifier: 'devtool.walletFunding.jeeber.${jeeber.id}',
            title: _label(jeeber),
            subtitle: _metadata(context, jeeber),
            leadingIcon: Icons.account_balance_wallet_outlined,
            onTap: () => onSelected(jeeber),
          ),
        ),
    ],
  );
}

String _label(DevUser user) {
  final displayName = user.displayName?.trim() ?? '';
  if (displayName.isNotEmpty) return displayName;
  final username = user.username.trim();
  return username.isNotEmpty ? username : _bidi(user.id);
}

String _metadata(BuildContext context, DevUser user) {
  final l10n = AppLocalizations.of(context);
  return <String>[
    l10n.walletFundingPickerTapToFund,
    l10n.scenarioUsersId(_bidi(user.id)),
    l10n.scenarioUsersStatus(_localizedStatus(l10n, user.status)),
  ].join('\n');
}

String _localizedStatus(AppLocalizations l10n, String value) =>
    switch (value.trim().toLowerCase()) {
      'active' => l10n.scenarioUsersStatusActive,
      'suspended' => l10n.scenarioUsersStatusSuspended,
      'pending' || 'kyc-pending' => l10n.scenarioUsersStatusPending,
      _ => value,
    };

String _bidi(String value) => '\u2068$value\u2069';
