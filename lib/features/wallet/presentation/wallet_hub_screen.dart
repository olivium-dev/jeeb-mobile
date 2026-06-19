import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../offline_mode/application/offline_cubit.dart';
import '../application/wallet_hub_cubit.dart';
import '../application/wallet_hub_state.dart';
import '../domain/wallet_repository.dart';
import 'wallet_hub_l10n.dart';

/// wallet-hub (JM-053). REPLACES the `/wallet` "coming soon" stub
/// (21_NAV_PLAN §A: exists-stub → REPLACE). The Jeeber's money home.
///
/// AC surface (30_BACKLOG JM-053 / 65_W2_TEST_PLAN §2):
///   * `wallet_available_balance` — the available balance amount (D1/D41).
///   * `wallet_gift_badge` — post-KYC starter credit badge (D42).
///   * `wallet_affordability_card` — STATE copy ("enough to bid" / "top up to
///     bid"), NOT a derived capacity number (D43 — fixes S-10 false-green).
///   * `wallet_reserved_now` — sum of live 10% reserves (D1).
///   * `wallet_topup_cta` → `wallet-charge-info` (D92/D93) — the one OWNED
///     money edge; guarded offline (D35).
///   * `wallet_how_fees_work` → `wallet_how_fees_explainer` (bottom sheet) —
///     the fee-only economics explainer (D41/D44).
///   * `wallet_earnings_row` → earnings-fees-dashboard (JM-052, W3).
///   * `wallet_see_all_activity` → wallet-activity-list (JM-055, W3).
///   * `wallet_kyc_pending_banner` — shown while KYC is pending (D38/D39): the
///     Jeeber may top up but cannot yet bid.
///   * State variants healthy / low / empty / all-reserved (D30) — driven off
///     [WalletBalance.affordabilityState], copy-only (D43).
///
/// Cross-wave honesty (R-4, jm-053): `wallet_earnings_row` (earnings-fees-
///   dashboard, JM-052) and `wallet_see_all_activity` (wallet-activity-list,
///   JM-055) now `goNamed('earnings')` / `goNamed('wallet-activity')` — both
///   routes are registered (app_router.dart), so these are HONEST edges. They
///   were GUARDED coming-soon during W3 (the W3-era `_comingSoon` notice) until
///   the JM-052/055 routes landed; this swap closes that residual.
///
/// Data: reads the Jeeber wallet snapshot via `sl<WalletRepository>()` — the
/// INTEGRATOR-STUB until W1m (`GET /v1/jeeb/wallet`) lands + DI repoints to
/// `DioWalletRepository` (CTO-D2). The screen renders whatever snapshot the repo
/// returns; the `jeeb.seam.wallet_state` Maestro states surface once DI is on
/// the live endpoint.
class WalletHubScreen extends StatelessWidget {
  const WalletHubScreen({super.key, this.repository, this.kycStatusGate});

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletRepository? repository;

  /// KYC-status source for the pending banner (AC7). Defaults to the shared
  /// `sl<JeeberKycStatusGate>()` the integrator landed (JM-036) — the same gate
  /// the DELIVERY tab + offer gate read, so the banner is honest end-to-end and
  /// the `jeeb.seam.kyc_status=pending` Maestro state drives it. Test seam.
  final JeeberKycStatusGate? kycStatusGate;

  @override
  Widget build(BuildContext context) {
    final gate = kycStatusGate ?? sl<JeeberKycStatusGate>();
    return BlocProvider<WalletHubCubit>(
      create: (_) => WalletHubCubit(
        repository: repository ?? sl<WalletRepository>(),
      )..load(),
      child: _WalletHubView(kycPending: gate.status == JeeberKycStatus.pending),
    );
  }
}

class _WalletHubView extends StatelessWidget {
  const _WalletHubView({required this.kycPending});

  final bool kycPending;

  @override
  Widget build(BuildContext context) {
    final copy = WalletHubL10n.of(context, kycPending: kycPending);
    return Semantics(
      identifier: 'wallet_hub_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: copy.title, showBackButton: true),
        body: BlocBuilder<WalletHubCubit, WalletHubState>(
          builder: (context, state) {
            switch (state.status) {
              case WalletHubStatus.initial:
              case WalletHubStatus.loading:
                return const OmdsLoadingState();
              case WalletHubStatus.failed:
                return OmdsErrorState(
                  message: copy.loadError,
                  retryLabel: copy.retry,
                  onRetry: () => context.read<WalletHubCubit>().refresh(),
                );
              case WalletHubStatus.loaded:
                return RefreshIndicator(
                  onRefresh: () => context.read<WalletHubCubit>().refresh(),
                  child: _LoadedBody(balance: state.balance, copy: copy),
                );
            }
          },
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.balance, required this.copy});

  final WalletBalance? balance;
  final WalletHubL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = balance;
    final currency = b?.currency ?? '';
    final affordability = b?.affordabilityState ?? WalletAffordability.empty;
    final hasGift = (b?.giftCredit ?? 0) > 0;

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        // ── KYC-pending banner (D38/D39): top-up allowed, bidding not yet. ──
        // Gated on the shared JeeberKycStatusGate (JM-036) — the same source the
        // DELIVERY tab + offer gate read, so the banner is honest end-to-end.
        // `jeeb.seam.kyc_status=pending` drives it in Maestro (AC7).
        if (copy.kycPending)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.large),
            child: Semantics(
              identifier: 'wallet_kyc_pending_banner',
              container: true,
              child: _Banner(
                icon: Icons.hourglass_top_outlined,
                title: copy.kycPendingTitle,
                body: copy.kycPendingBody,
              ),
            ),
          ),

        // ── Available balance (the screen's signature element). ──────────────
        Semantics(
          identifier: 'wallet_available_balance',
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.availableBalanceLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              const SizedBox(height: Spacing.twoXSmall),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _fmt(b?.availableBalance ?? 0),
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (currency.isNotEmpty) ...[
                    const SizedBox(width: Spacing.xSmall),
                    Text(
                      currency,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
              // ── Gift / starter-credit badge (D42, post-KYC). ──────────────
              if (hasGift) ...[
                const SizedBox(height: Spacing.small),
                Semantics(
                  identifier: 'wallet_gift_badge',
                  container: true,
                  child: OmdsChip(
                    label: copy.giftBadge(_fmt(b?.giftCredit ?? 0), currency),
                    icon: const Icon(Icons.card_giftcard_outlined, size: 16),
                    enabled: false,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: Spacing.large),

        // ── Affordability state card (D43 — STATE copy, NOT a number). ───────
        Semantics(
          identifier: 'wallet_affordability_card',
          container: true,
          child: _Banner(
            icon: _affordabilityIcon(affordability),
            title: copy.affordabilityTitle(affordability),
            body: copy.affordabilityBody(affordability),
            tone: _affordabilityTone(affordability, theme),
          ),
        ),

        const SizedBox(height: Spacing.medium),

        // ── Reserved-now (sum of live 10% reserves, D1). ─────────────────────
        Semantics(
          identifier: 'wallet_reserved_now',
          container: true,
          child: _StatRow(
            icon: Icons.lock_clock_outlined,
            label: copy.reservedNowLabel,
            value: '${_fmt(b?.reservedNow ?? 0)} $currency'.trim(),
            hint: copy.reservedNowHint,
          ),
        ),

        const SizedBox(height: Spacing.large),

        // ── Top up → wallet-charge-info (the one OWNED edge; D35 offline). ───
        Semantics(
          identifier: 'wallet_topup_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: copy.topUpCta,
            onTap: () => _onTopUp(context),
          ),
        ),

        const SizedBox(height: Spacing.small),

        // ── How fees work → explainer sheet (D41/D44). ───────────────────────
        Semantics(
          identifier: 'wallet_how_fees_work',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: copy.howFeesWork,
            variant: OmdsButtonVariant.text,
            onTap: () => _showHowFees(context),
          ),
        ),

        const SizedBox(height: Spacing.large),

        // ── Earnings row → earnings-fees-dashboard (JM-052, W3). ─────────────
        // R-4 (jm-053): now an HONEST `goNamed('earnings')` — the standalone
        // `earnings` route is registered (app_router.dart) hosting the same
        // EarningsDashboardScreen (+ EarningsCubit) the Earnings tab renders.
        // Replaces the W3-era guarded `_comingSoon` once JM-052 shipped.
        Semantics(
          identifier: 'wallet_earnings_row',
          button: true,
          container: true,
          child: OmdsSettingsRow(
            title: copy.earningsRow,
            subtitle: copy.earningsRowSubtitle,
            leadingIcon: Icons.insights_outlined,
            onTap: () => context.goNamed('earnings'),
          ),
        ),

        // ── See all activity → wallet-activity-list (JM-055, W3). ────────────
        // R-4 (jm-053): now an HONEST `goNamed('wallet-activity')` — the
        // `wallet-activity` route is registered (app_router.dart) hosting
        // WalletActivityListScreen. Replaces the W3-era guarded `_comingSoon`
        // once JM-055 shipped.
        Semantics(
          identifier: 'wallet_see_all_activity',
          button: true,
          container: true,
          child: OmdsSettingsRow(
            title: copy.seeAllActivity,
            subtitle: copy.seeAllActivitySubtitle,
            leadingIcon: Icons.receipt_long_outlined,
            onTap: () => context.goNamed('wallet-activity'),
          ),
        ),
      ],
    );
  }

  // ── Top up: guarded offline (D35). Money actions are blocked while the
  //    device is offline. We read the OfflineCubit only if an ancestor provides
  //    it (it is not in the global tree today); absence ⇒ treat as online so
  //    the screen never throws on a missing provider (40_GUARDRAILS_ARCH §6).
  void _onTopUp(BuildContext context) {
    if (_isOffline(context)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(copy.offlineMoneyBlocked)));
      return;
    }
    context.goNamed('wallet-charge-info');
  }

  bool _isOffline(BuildContext context) {
    try {
      return context.read<OfflineCubit>().state.status ==
          ConnectivityStatus.offline;
    } catch (_) {
      // No OfflineCubit in the tree (production default) — treat as online.
      return false;
    }
  }

  void _showHowFees(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HowFeesSheet(copy: copy),
    );
  }

  IconData _affordabilityIcon(WalletAffordability a) {
    switch (a) {
      case WalletAffordability.enough:
        return Icons.check_circle_outline;
      case WalletAffordability.low:
        return Icons.warning_amber_outlined;
      case WalletAffordability.empty:
        return Icons.account_balance_wallet_outlined;
      case WalletAffordability.allReserved:
        return Icons.lock_clock_outlined;
    }
  }

  Color? _affordabilityTone(WalletAffordability a, ThemeData theme) {
    switch (a) {
      case WalletAffordability.enough:
        return null; // neutral / positive surface
      case WalletAffordability.low:
      case WalletAffordability.empty:
      case WalletAffordability.allReserved:
        return theme.colorScheme.errorContainer;
    }
  }

  String _fmt(double v) => v.toStringAsFixed(2);
}

/// The fee-only economics explainer (D41/D44). A static, no-payment bottom sheet
/// — fees are captured (exactly 10%) from the pre-charged wallet balance, never
/// charged in-app. Hosts the asserted `wallet_how_fees_explainer` root.
class _HowFeesSheet extends StatelessWidget {
  const _HowFeesSheet({required this.copy});

  final WalletHubL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'wallet_how_fees_explainer',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.medium,
          Spacing.xSmall,
          Spacing.medium,
          Spacing.large,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.feesExplainerTitle,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.small),
            _FeeBullet(text: copy.feesExplainerLine1),
            _FeeBullet(text: copy.feesExplainerLine2),
            _FeeBullet(text: copy.feesExplainerLine3),
            const SizedBox(height: Spacing.large),
            OmdsPrimaryButton(
              text: copy.feesExplainerGotIt,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeBullet extends StatelessWidget {
  const _FeeBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// A compact informational card used for the affordability state (D43) and the
/// KYC-pending banner (D38/D39). `tone` tints the surface for non-healthy states.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    this.tone,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = tone ?? theme.colorScheme.surfaceContainerHighest;
    final fg = tone != null
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled value row with a hint — used for reserved-now (D1).
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyLarge),
              if (hint != null) ...[
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: Spacing.small),
        Text(
          value,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
