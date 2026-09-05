import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/notifications/application/push_refresh_signals.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
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
///   JM-055) `goNamed('earnings')` / `goNamed('wallet-activity')` — both routes
///   are registered (app_router.dart), so these are HONEST edges.
///
/// MIDNIGHT R4 (`Jeeb Rich UI.dc.html` L258-322): the balance becomes a frosted
/// bank-card — hero glass over a Ø150 orange corner glow, with the wordmark
/// opposite the eyebrow and the reserve/live-offer stats folded in under a
/// hairline. The affordability state is a green-tinted note, and the Top up
/// pill is the screen's ONLY solid orange element (caption). R4 draws **zero**
/// animated elements (03-MOTION-NOTES §R4), including the field ring and the
/// balance glow, so the field mounts with `animateDecor: false` and no landed
/// top-up mark plays over it (M5, audit B2).
///
/// Data: reads the Jeeber wallet snapshot via `sl<WalletRepository>()` — the
/// INTEGRATOR-STUB until W1m (`GET /v1/jeeb/wallet`) lands + DI repoints to
/// `DioWalletRepository` (CTO-D2). The screen renders whatever snapshot the repo
/// returns; the `jeeb.seam.wallet_state` Maestro states surface once DI is on
/// the live endpoint.
class WalletHubScreen extends StatefulWidget {
  const WalletHubScreen({
    super.key,
    this.repository,
    this.kycStatusGate,
    this.walletRefreshSignals,
  });

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletRepository? repository;

  /// KYC-status source for the pending banner (AC7). Defaults to the shared
  /// `sl<JeeberKycStatusGate>()` the integrator landed (JM-036) — the same gate
  /// the DELIVERY tab + offer gate read, so the banner is honest end-to-end and
  /// the `jeeb.seam.kyc_status=pending` Maestro state drives it. Test seam.
  final JeeberKycStatusGate? kycStatusGate;

  /// F1 — the push→refetch bus, filtered to `RefreshTopic.wallet`. Injectable
  /// for tests; defaults to the DI-registered [PushRefreshSignals] stream.
  final Stream<void>? walletRefreshSignals;

  @override
  State<WalletHubScreen> createState() => _WalletHubScreenState();
}

class _WalletHubScreenState extends State<WalletHubScreen>
    with ResumeRefetchMixin {
  late final WalletHubCubit _cubit = WalletHubCubit(
    repository: widget.repository ?? sl<WalletRepository>(),
  )..load();
  StreamSubscription<void>? _walletRefreshSub;

  @override
  void initState() {
    super.initState();
    // F1 — no top-up event exists server-side; only guard-2's auto-withdraw
    // fires this bus (a top-up is caught by the resume catch-up below).
    _walletRefreshSub =
        (widget.walletRefreshSignals ??
                resolvePushRefreshStream(topics: const {RefreshTopic.wallet}))
            ?.listen((_) => unawaited(_cubit.refresh()));
  }

  @override
  void onAppResumed() => unawaited(_cubit.refresh());

  @override
  void dispose() {
    unawaited(_walletRefreshSub?.cancel());
    _walletRefreshSub = null;
    unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gate = widget.kycStatusGate ?? sl<JeeberKycStatusGate>();
    return BlocProvider<WalletHubCubit>.value(
      value: _cubit,
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
        backgroundColor: Colors.transparent,
        // R4's field: base wash + orange glow + periwinkle wash + one quiet
        // orbit ring, and no twinkles — the hero layer set minus its stars.
        body: JeebMidnightField(
          variant: JeebFieldVariant.hero,
          glowPlacement: JeebFieldGlowPlacement.topStart,
          washPlacement: JeebFieldWashPlacement.endMid,
          showTwinkles: false,
          animateDecor: false,
          // The board's header is an in-body row, not a Material app bar, so it
          // renders in EVERY state (loading / failed / loaded) instead of only
          // where a Scaffold would have hung one.
          child: SafeArea(
            child: Column(
              children: [
                JeebTopBar(
                  identifier: 'wallet_back',
                  title: copy.title,
                  leadingTooltip: copy.back,
                  // The wallet chip reaches this hub via stack-REPLACING
                  // `goNamed('wallet')`, so there is usually nothing to pop.
                  // Pop when we can, else return to the shell — never pop the
                  // last page (which would leave an empty Navigator).
                  onLeadingPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
                Expanded(
                  child: BlocBuilder<WalletHubCubit, WalletHubState>(
                    builder: (context, state) {
                      final cubit = context.read<WalletHubCubit>();
                      switch (state.status) {
                        case WalletHubStatus.initial:
                        case WalletHubStatus.loading:
                          return JeebStateHost(
                            child: JeebEmptyState(
                              status: JeebEmptyStateStatus.loading,
                              reason: JeebEmptyStateReason.loading,
                              variant: JeebEmptyStateVariant.pocket,
                              headline: copy.loadingHeadline,
                              identifier: 'wallet_loading',
                            ),
                          );
                        case WalletHubStatus.failed:
                          return JeebStateHost(
                            child: JeebFailureBlock(
                              failure: state.failure ?? const UnknownFailure(),
                              identifier: 'wallet_load_error',
                              retryIdentifier: 'wallet_retry_cta',
                              exitIdentifier: 'wallet_exit_cta',
                              variant: JeebEmptyStateVariant.pocket,
                              onRetry: cubit.load,
                              onExit: _walletExit(context, state.failure),
                            ),
                          );
                        case WalletHubStatus.loaded:
                          final balance = state.balance;
                          if (balance == null) {
                            return JeebStateHost(
                              child: JeebFailureBlock(
                                failure:
                                    state.failure ??
                                    const UnknownFailure(parse: true),
                                identifier: 'wallet_load_error',
                                retryIdentifier: 'wallet_retry_cta',
                                exitIdentifier: 'wallet_exit_cta',
                                variant: JeebEmptyStateVariant.pocket,
                                onRetry: cubit.load,
                                onExit: _walletExit(context, state.failure),
                              ),
                            );
                          }
                          return JeebPullToRefresh(
                            onRefresh: cubit.refresh,
                            child: _LoadedBody(
                              balance: balance,
                              copy: copy,
                              refreshError: state.refreshError,
                              onRetryRefresh: cubit.refresh,
                              onDismissRefreshError: cubit.clearRefreshError,
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
      ),
    );
  }
}

/// R6: an unrecoverable kind gets a way out, never a headline with no act. An
/// expired session leaves to the root, where the redirect lands on sign-in.
VoidCallback _walletExit(BuildContext context, AppFailure? failure) =>
    failure is UnauthorizedFailure
    ? () => context.go('/')
    : () => context.canPop() ? context.pop() : context.go('/');

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({
    required this.balance,
    required this.copy,
    this.refreshError,
    this.onRetryRefresh,
    this.onDismissRefreshError,
  });

  final WalletBalance balance;
  final WalletHubL10n copy;

  /// A refresh that failed over a balance the Jeeber is still reading.
  final AppFailure? refreshError;
  final VoidCallback? onRetryRefresh;
  final VoidCallback? onDismissRefreshError;

  /// R4's link rows measure `15/16`, two steps looser than the kit default.
  static const EdgeInsetsGeometry _linkRowPadding =
      EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 15);

  @override
  Widget build(BuildContext context) {
    final b = balance;
    final currency = b.currency;
    final affordability = b.affordabilityState;
    final hasGift = b.giftCredit > 0;
    final warm = refreshError;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          // Gutter 24, balance card 20 below the top bar; the trust line owns
          // the bottom inset, so this sliver ends flush.
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.xLarge,
            Spacing.large,
            Spacing.xLarge,
            0,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (warm != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: Spacing.small,
                  ),
                  child: JeebRefreshFailedNote(
                    failure: warm,
                    identifier: 'wallet_refresh_failed_note',
                    onRetry: onRetryRefresh,
                    onDismiss: onDismissRefreshError ?? () {},
                  ),
                ),
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

              // ── The frosted bank-card (the screen's signature element). ────
              _BalanceCard(
                copy: copy,
                availableBalance: b.availableBalance,
                reservedNow: b.reservedNow,
                giftCredit: b.giftCredit,
                currency: currency,
                hasGift: hasGift,
              ),

              const SizedBox(height: Spacing.small + 2),

              // ── Affordability state note (D43 — STATE copy, NOT a number).
              JeebInfoNote(
                identifier: 'wallet_affordability_card',
                tone: _affordabilityTone(affordability),
                icon: _affordabilityIcon(affordability),
                title: copy.affordabilityTitle(affordability),
                text: copy.affordabilityBody(affordability),
              ),

              // ── Top up → wallet-charge-info (the one OWNED edge; D35
              // offline) over the fee explainer link. The footer keeps its top
              // inset but drops the 24 gutter: this block sits INSIDE the
              // padded sliver, so the gutter would double.
              JeebCtaFooter.single(
                padding: const EdgeInsetsDirectional.only(top: Spacing.medium),
                // The link's own 48dp tap target already supplies the board's
                // 12px optical gap, so the footer adds none.
                spacing: 0,
                below: JeebCtaButton.text(
                  identifier: 'wallet_how_fees_work',
                  label: copy.howFeesWork,
                  labelStyle: context.jeebText.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  onTap: () => _showHowFees(context),
                ),
                child: JeebCtaButton.accent(
                  identifier: 'wallet_topup_cta',
                  label: copy.topUpCta,
                  leadingIcon: Icons.add,
                  onTap: () => _onTopUp(context),
                ),
              ),

              const SizedBox(height: Spacing.large),

              JeebOutlinedCard.grouped(
                children: [
                  // ── Earnings row → earnings-fees-dashboard (JM-052, W3). ──
                  // TODO(midnight): omitted, not faked — the board's
                  // "$127.50 cash this week" needs a weekly-cash figure
                  // `WalletBalance` does not carry (wallet_repository.dart).
                  JeebListRow(
                    identifier: 'wallet_earnings_row',
                    icon: Icons.show_chart,
                    title: copy.earningsRow,
                    subtitle: copy.earningsRowSubtitle,
                    padding: _linkRowPadding,
                    onTap: () => context.goNamed('earnings'),
                  ),
                  // ── See all activity → wallet-activity-list (JM-055, W3). ──
                  JeebListRow(
                    identifier: 'wallet_see_all_activity',
                    icon: Icons.article,
                    title: copy.seeAllActivity,
                    subtitle: copy.seeAllActivitySubtitle,
                    padding: _linkRowPadding,
                    onTap: () => context.goNamed('wallet-activity'),
                  ),
                ],
              ),
            ]),
          ),
        ),

        // ── The empty lower third is the design: fill the viewport, dock the
        // trust line at its foot, and scroll only once the content genuinely
        // overflows (200% text scale, KYC banner, long AR copy).
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
      showJeebErrorSnack(
        context,
        message: copy.offlineMoneyBlocked,
        identifier: 'wallet_topup_offline_snack',
      );
      return;
    }
    context.goNamed('wallet-charge-info');
  }

  bool _isOffline(BuildContext context) {
    try {
      return context.read<OfflineCubit>().state.status ==
          ConnectivityStatus.offline;
    } on ProviderNotFoundException {
      // Genuinely absent (production default) — treat as online.
      return false;
    } catch (_) {
      Diag.event('wallet_hub.offline_probe_failed');
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

/// The frosted bank-card (R4 caption): hero glass at `xl`, a real blur, the
/// board's `floatNav` lift, one off-canvas orange glow at the top-END corner,
/// the wordmark opposite the eyebrow, and the reserve stats under a hairline.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.copy,
    required this.availableBalance,
    required this.reservedNow,
    required this.giftCredit,
    required this.currency,
    required this.hasGift,
  });

  /// Board `padding: 22px` (`tpl 268`).
  static const double _cardPadding = 22;

  /// The corner glow: Ø150 pushed 40 off both edges (`tpl 269`).
  static const double _glowDiameter = 150;
  static const double _glowOffset = -40;

  /// Board `height:15px` on the wordmark lockup.
  static const double _wordmarkHeight = 15;
  static const double _wordmarkOpacity = 0.85;

  final WalletHubL10n copy;
  final double availableBalance;
  final double reservedNow;
  final double giftCredit;
  final String currency;
  final bool hasGift;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    // `MoneyFormat` prints the ISO code inline for anything but USD, so the
    // board's standalone `USD` suffix would double it there.
    final code = currency.trim().toUpperCase();
    final showCurrencySuffix = code.isEmpty || code == 'USD';

    return JeebGlassCapsule(
      radius: JeebRadii.xl,
      blurSigma: JeebGlassCapsule.heroBlur,
      shadow: JeebShadows.floatNav,
      padding: EdgeInsetsDirectional.zero,
      child: Stack(
        // The capsule's own ClipRRect turns the overhanging glow into the arc
        // the board renders; without this the Stack would crop it square.
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            top: _glowOffset,
            end: _glowOffset,
            child: IgnorePointer(
              child: Container(
                width: _glowDiameter,
                height: _glowDiameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      semantic.accentRing,
                      semantic.accentRing.withValues(alpha: 0),
                    ],
                    stops: const <double>[0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(_cardPadding),
            // The id belongs to the CONTENT, not the card: wrapping the card
            // would pull the decorative glow into the node. Both flags are
            // load-bearing — without them the nested gift-badge id is swallowed.
            child: Semantics(
              identifier: 'wallet_available_balance',
              container: true,
              explicitChildNodes: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Natural casing in, uppercase out: the kit owns the
                      // transform so no lane calls `toUpperCase()` on a
                      // caseless script.
                      Expanded(
                        child: JeebSectionLabel(copy.availableBalanceLabel),
                      ),
                      const SizedBox(width: Spacing.small),
                      ExcludeSemantics(
                        child: Opacity(
                          opacity: _wordmarkOpacity,
                          child: SvgPicture.asset(
                            'assets/brand/jeeb_wordmark.svg',
                            height: _wordmarkHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.small - 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        // The hero is the one place a 200% text scale can push
                        // a number off the card, so it scales down rather than
                        // wraps.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            MoneyFormat.format(
                              availableBalance,
                              currency: currency,
                            ),
                            style: context.jeebText.statHero.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (showCurrencySuffix) ...[
                        const SizedBox(width: Spacing.xSmall),
                        Text(
                          'USD',
                          style: context.jeebText.body.copyWith(
                            fontWeight: FontWeight.w700,
                            color: semantic.mutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // ── Gift / starter-credit badge (D42, post-KYC). ──────────
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
                  const SizedBox(height: Spacing.medium),
                  ColoredBox(
                    color: semantic.glassBorder,
                    child: const SizedBox(height: 1, width: double.infinity),
                  ),
                  const SizedBox(height: Spacing.small + 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Semantics(
                          identifier: 'wallet_reserved_now',
                          container: true,
                          // The board drops the "released if you're not picked"
                          // line; the fact survives as the node's hint.
                          hint: copy.reservedNowHint,
                          child: _BalanceStat(
                            label: copy.reservedNowLabel,
                            value: MoneyFormat.format(
                              reservedNow,
                              currency: currency,
                            ),
                          ),
                        ),
                      ),
                      // TODO(midnight): omitted, not faked — the board's
                      // "Live offers · 1" needs a live-reserve COUNT that
                      // `WalletBalance` does not carry (wallet_repository.dart).
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One column of the bank-card's footer: an 11/w600 periwinkle label over a
/// w800 money figure — the money emphasis of doc-13 Pattern C.
class _BalanceStat extends StatelessWidget {
  const _BalanceStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final text = context.jeebText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.caption.copyWith(color: semantic.mutedText)),
        const SizedBox(height: Sizes.threeXSmall),
        Text(
          value,
          style: text.cardTitle.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// The starter-credit pill (D42) — screen-local by design: the kit ships no
/// unselected chip that reads on glass, because R4 is the only screen that
/// wants one.
class _GiftPill extends StatelessWidget {
  const _GiftPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
        // 6px on the board; there is no token between 4 and 8.
        vertical: Spacing.xSmall - 2,
      ),
      decoration: BoxDecoration(
        // Sanctioned tokens: orange @12% fill / @30% stroke, against the
        // board's 25/45 — the token layer wins over a two-off literal.
        color: semantic.accentTint,
        border: Border.all(color: semantic.accentRing),
        borderRadius: BorderRadius.circular(JeebRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎁', style: context.jeebText.body),
          const SizedBox(width: Spacing.xSmall - 1),
          Flexible(
            child: Text(
              label,
              style: context.jeebText.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
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
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();

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
            style: context.jeebText.caption.copyWith(
              fontWeight: FontWeight.w500,
              color: semantic.mutedText,
            ),
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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'wallet_how_fees_explainer',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.xSmall,
          Spacing.xLarge,
          Spacing.xLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              copy.feesExplainerTitle,
              style: context.jeebText.h2.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: Spacing.small),
            _FeeBullet(text: copy.feesExplainerLine1),
            _FeeBullet(text: copy.feesExplainerLine2),
            _FeeBullet(text: copy.feesExplainerLine3),
            const SizedBox(height: Spacing.large),
            JeebCtaButton.primary(
              label: copy.feesExplainerGotIt,
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
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            // A reassurance list, not an action: success ink, no orange spend.
            child: Icon(
              Icons.check,
              size: 18,
              color: context.jeebRoles.success,
            ),
          ),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              text,
              style: context.jeebText.body.copyWith(color: semantic.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
