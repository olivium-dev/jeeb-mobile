import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
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
/// Redesign-24 (`docs/redesign-2026-08/per-screen-revised/23-wallet.md`): a
/// restyle, not a rewrite — same data, same route, same block order, all 11
/// identifiers unmoved. Five bands over a deliberately empty lower third:
/// navy balance hero → affordability note → outlined reserve note → inline CTA
/// + orange fee link → grouped exits card, with the trust line docked at the
/// bottom of the viewport.
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
        // The board's header is an in-body row, not a Material app bar, so it
        // renders in EVERY state (loading / failed / loaded) instead of only
        // where a Scaffold would have hung one.
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar(
                identifier: 'wallet_back',
                title: copy.title,
                leadingTooltip: copy.back,
                // The wallet chip reaches this hub via stack-REPLACING `goNamed(
                // 'wallet')`, so there is usually nothing to pop. Pop when we can
                // (pushed entry), else return to the shell — never pop the last
                // page (which would leave an empty Navigator → black surface).
                onLeadingPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(
                child: BlocBuilder<WalletHubCubit, WalletHubState>(
                  builder: (context, state) {
                    switch (state.status) {
                      case WalletHubStatus.initial:
                      case WalletHubStatus.loading:
                        return const OmdsLoadingState();
                      case WalletHubStatus.failed:
                        return OmdsErrorState(
                          message: copy.loadError,
                          retryLabel: copy.retry,
                          onRetry: () =>
                              context.read<WalletHubCubit>().refresh(),
                        );
                      case WalletHubStatus.loaded:
                        return OmdsPullToRefresh(
                          onRefresh: () =>
                              context.read<WalletHubCubit>().refresh(),
                          child: _LoadedBody(
                            balance: state.balance,
                            copy: copy,
                          ),
                        );
                    }
                  },
                ),
              ),
            ],
          ),
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
    final b = balance;
    final currency = b?.currency ?? '';
    final affordability = b?.affordabilityState ?? WalletAffordability.empty;
    final hasGift = (b?.giftCredit ?? 0) > 0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          // Gutter 24, first block 16 below the top bar; the trust line owns
          // the bottom inset, so this sliver ends flush.
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.medium,
            Spacing.xLarge,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── KYC-pending banner (D38/D39): top-up allowed, bidding not
              // yet. Gated on the shared JeeberKycStatusGate (JM-036) — the
              // same source the DELIVERY tab + offer gate read, so the banner
              // is honest end-to-end. `jeeb.seam.kyc_status=pending` drives it
              // in Maestro (AC7).
              if (copy.kycPending)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: Spacing.small,
                  ),
                  child: JeebInfoNote.muted(
                    identifier: 'wallet_kyc_pending_banner',
                    icon: Icons.hourglass_top,
                    title: copy.kycPendingTitle,
                    text: copy.kycPendingBody,
                  ),
                ),

              // ── Available balance (the screen's signature element). ────────
              _BalanceHero(
                copy: copy,
                availableBalance: b?.availableBalance ?? 0,
                giftCredit: b?.giftCredit ?? 0,
                currency: currency,
                hasGift: hasGift,
              ),

              const SizedBox(height: Spacing.small),

              // ── Affordability state note (D43 — STATE copy, NOT a number).
              JeebInfoNote(
                identifier: 'wallet_affordability_card',
                tone: _affordabilityTone(affordability),
                icon: _affordabilityIcon(affordability),
                title: copy.affordabilityTitle(affordability),
                text: copy.affordabilityBody(affordability),
              ),

              const SizedBox(height: Spacing.small),

              // ── Reserved-now (sum of live 10% reserves, D1). ──────────────
              // TODO(redesign-24): the board's "1 live offer ·" half needs a
              // live-reserve COUNT; WalletBalance carries the amount only
              // (wallet_repository.dart). Omitted, not faked.
              JeebInfoNote.outlined(
                identifier: 'wallet_reserved_now',
                icon: Icons.lock,
                title: copy.reservedNowLabel,
                text: copy.reservedNowHint,
                trailing: Text(
                  MoneyFormat.format(b?.reservedNow ?? 0, currency: currency),
                  style: context.jeebText.cardTitle
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),

              // ── Top up → wallet-charge-info (the one OWNED edge; D35
              // offline) with the fee explainer link beneath it. The footer
              // keeps its 16px top inset but drops the 24 gutter: this block
              // sits INSIDE the padded sliver, so the gutter would double.
              JeebCtaFooter.single(
                padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
                below: JeebCtaButton.accentText(
                  identifier: 'wallet_how_fees_work',
                  label: copy.howFeesWork,
                  onTap: () => _showHowFees(context),
                ),
                child: JeebCtaButton(
                  identifier: 'wallet_topup_cta',
                  label: copy.topUpCta,
                  leadingIcon: Icons.add,
                  onTap: () => _onTopUp(context),
                ),
              ),

              const SizedBox(height: Spacing.medium),

              JeebOutlinedCard.grouped(
                children: [
                  // ── Earnings row → earnings-fees-dashboard (JM-052, W3). ──
                  // R-4 (jm-053): an HONEST `goNamed('earnings')` — the
                  // standalone `earnings` route is registered (app_router.dart)
                  // hosting the same EarningsDashboardScreen (+ EarningsCubit)
                  // the Earnings tab renders. Replaces the W3-era guarded
                  // `_comingSoon` once JM-052 shipped.
                  JeebListRow(
                    identifier: 'wallet_earnings_row',
                    icon: Icons.show_chart,
                    title: copy.earningsRow,
                    subtitle: copy.earningsRowSubtitle,
                    onTap: () => context.goNamed('earnings'),
                  ),
                  // ── See all activity → wallet-activity-list (JM-055, W3). ──
                  // R-4 (jm-053): an HONEST `goNamed('wallet-activity')` — the
                  // `wallet-activity` route is registered (app_router.dart)
                  // hosting WalletActivityListScreen. Replaces the W3-era
                  // guarded `_comingSoon` once JM-055 shipped.
                  JeebListRow(
                    identifier: 'wallet_see_all_activity',
                    icon: Icons.article,
                    title: copy.seeAllActivity,
                    subtitle: copy.seeAllActivitySubtitle,
                    onTap: () => context.goNamed('wallet-activity'),
                  ),
                ],
              ),
            ]),
          ),
        ),

        // ── The empty lower third is the design (R1): fill the viewport, dock
        // the trust line at its foot, and scroll only once the content
        // genuinely overflows (200% text scale, KYC banner, long AR copy).
        SliverFillRemaining(
          hasScrollBody: false,
          child: _CashDisclaimer(text: copy.cashDisclaimer),
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

  /// Filled glyphs only (R10 — no `_outlined` variants on this board).
  IconData _affordabilityIcon(WalletAffordability a) {
    switch (a) {
      case WalletAffordability.enough:
        return Icons.check_circle;
      case WalletAffordability.low:
        return Icons.warning;
      case WalletAffordability.empty:
        return Icons.account_balance_wallet;
      case WalletAffordability.allReserved:
        return Icons.lock_clock;
    }
  }

  /// Non-healthy affordability is an attention state ("top up to bid") ->
  /// the kit's warning tone, not its error tone (UX-AUDIT T1 dark-red banner).
  /// All four branches stay: the board only draws `enough`, but D43, the widget
  /// tests and Maestro AC6 (`wallet_state=insufficient`) need the other three.
  JeebInfoNoteTone _affordabilityTone(WalletAffordability a) {
    switch (a) {
      case WalletAffordability.enough:
        return JeebInfoNoteTone.success;
      case WalletAffordability.low:
      case WalletAffordability.empty:
      case WalletAffordability.allReserved:
        return JeebInfoNoteTone.warning;
    }
  }
}

/// The navy balance hero — `AVAILABLE TO BID` over the amount, with the
/// starter-credit pill inside the card and one off-canvas orange ring at the
/// bottom-END corner (23 disagrees with 04/19 about the corner, which is why
/// the kit makes it a preset rather than a constant).
class _BalanceHero extends StatelessWidget {
  const _BalanceHero({
    required this.copy,
    required this.availableBalance,
    required this.giftCredit,
    required this.currency,
    required this.hasGift,
  });

  final WalletHubL10n copy;
  final double availableBalance;
  final double giftCredit;
  final String currency;
  final bool hasGift;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    // `MoneyFormat` prints the ISO code inline for anything but USD, so the
    // board's standalone `USD` suffix would double it there.
    final code = currency.trim().toUpperCase();
    final showCurrencySuffix = code.isEmpty || code == 'USD';

    return JeebNavySurfaceCard(
      radius: Spacing.large,
      padding: const EdgeInsetsDirectional.all(Spacing.large),
      shadow: JeebShadows.heroNavy,
      rings: const [JeebNavyRing.statBottomEnd],
      // The id belongs to the CONTENT, not the card: wrapping the card would
      // pull the decorative ring into the node. Both flags are load-bearing —
      // without them the nested gift-badge id is swallowed.
      child: Semantics(
        identifier: 'wallet_available_balance',
        container: true,
        explicitChildNodes: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Natural casing in, uppercase out: the kit owns the transform so
            // no lane calls `toUpperCase()` on a caseless script.
            JeebSectionLabel(copy.availableBalanceLabel),
            const SizedBox(height: Spacing.twoXSmall),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  // The hero is the one place a 200% text scale can push a
                  // number off the card, so it scales down rather than wraps.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      MoneyFormat.format(availableBalance, currency: currency),
                      style: context.jeebText.statHero.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                if (showCurrencySuffix) ...[
                  const SizedBox(width: Spacing.xSmall),
                  Text(
                    'USD',
                    style: context.jeebText.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: semantic.mutedText,
                    ),
                  ),
                ],
              ],
            ),
            // ── Gift / starter-credit badge (D42, post-KYC). ───────────────
            if (hasGift) ...[
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'wallet_gift_badge',
                container: true,
                child: _GiftPill(
                  label: copy.giftBadge(
                    MoneyFormat.format(giftCredit, currency: currency),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The starter-credit pill (D42) — screen-local by design: the kit ships no
/// unselected chip that reads on navy, because 23 is the only screen that wants
/// one (03-WAVE1-KIT §5).
class _GiftPill extends StatelessWidget {
  const _GiftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
        // 6px on the board; there is no token between 4 and 8.
        vertical: Spacing.xSmall - 2,
      ),
      decoration: BoxDecoration(
        // Sanctioned tokens: orange @12% fill / @30% stroke, against the
        // board's 20/40 — the token layer wins over a two-off literal.
        color: semantic.accentTint,
        border: Border.all(color: semantic.accentRing),
        borderRadius: OmdsBorderRadius.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎁', style: context.jeebText.body),
          const SizedBox(width: Spacing.xSmall - 2),
          Flexible(
            child: Text(
              label,
              style: context.jeebText.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The trust line docked at the foot of the viewport (D41/D44): cash on
/// delivery never routes through the fee-only wallet.
class _CashDisclaimer extends StatelessWidget {
  const _CashDisclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();

    return Align(
      alignment: AlignmentDirectional.bottomCenter,
      child: Padding(
        // Bottom 32 against the board's 30 — no 30 token exists.
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.large,
          Spacing.xLarge,
          Spacing.twoXLarge,
        ),
        child: Semantics(
          identifier: 'wallet_cash_disclaimer',
          container: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.jeebText.caption.copyWith(color: semantic.mutedText),
          ),
        ),
      ),
    );
  }
}

/// The fee-only economics explainer (D41/D44). A static, no-payment bottom sheet
/// — the platform fee is captured from the pre-charged wallet balance, never
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
