import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/countdown_format.dart';
import '../../../core/lifecycle/route_resume_refetch.dart';
import '../../../core/network/single_flight_get.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../cancel_request/presentation/cancel_request_sheet.dart';
import '../application/waiting_cubit.dart';
import '../application/waiting_state.dart';
import '../data/dio_waiting_repository.dart';
import '../data/fake_waiting_repository.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

/// Signature for the optional cubit factory the screen exposes for tests.
/// Production wiring leaves it `null` so the default ticker-driven cubit is
/// used; tests pass a factory that injects an empty `refreshSignals` /
/// `clockTicks` so the test binding doesn't complain about pending timers.
typedef WaitingCubitFactory =
    WaitingCubit Function(WaitingRepository repository, String requestId);

/// JM-026 — Waiting / No-Coverage state [D48, D69].
///
/// Route: `/requests/:id/waiting` (name `waiting-no-coverage`, registered by the
/// W1 integrator). This REWRITES the orphaned tier-upgrade placeholder into the
/// real pre-accept waiting surface:
///
///  - **Broadcast state:** `waiting_notified_count` + `waiting_countdown` render
///    while the matching service fans the request out (AC1). `waiting_notified_count`
///    shows neutral reassurance copy when the gateway never populated the
///    counter (notifiedCount <= 0) rather than a false "No Jeebers nearby".
///    `waiting_countdown` is driven by the snapshot's ANCHOR PAIR
///    (`receivedAt` + `remainingAtReceipt`, P7): a server-relative remaining
///    value pinned to the device instant it arrived, so handset clock skew
///    cannot shift it. When the server says no countdown applies the label says
///    so — the client never fabricates a window.
///  - **No-offers-yet variant:** ONLY once the broadcast window has elapsed with
///    zero offers in, the `waiting_no_coverage_state` container shows instead
///    (clock-driven, never gated on notifiedCount — BUG-4 / JM-026).
///  - **Offers arrived:** the cubit polls; once an offer lands the screen flips
///    live to `waiting_review_offers_cta` → `offer-review` (AC2, JM-028).
///  - **Terminal server status:** the countdown and polling stop, and
///    `waiting_terminal_state` offers a role-aware Home exit.
///  - `waiting_retarget_cta` → `request-type` (re-target, D48; AC3).
///  - `waiting_cancel_cta` → `CancelRequestSheet` (free pre-accept, D69; AC4).
///
/// The screen self-provides its cubit and resolves [WaitingRepository] from the
/// GetIt container (DioWaitingRepository in release builds). When DI has not yet
/// registered the type it constructs `DioWaitingRepository(sl<Dio>())` directly
/// (real `:4010` Dio) so the screen is still data-bound; a [FakeWaitingRepository]
/// is the last-resort fallback only when even `Dio` is unavailable (mirrors
/// `ClientOffersScreen._resolveRepository`).
///
/// MIDNIGHT (M3-03) — this screen has no tile of its own; its nearest is **E2
/// (empty — waiting for offers)**, whose subject is literally this one, and
/// which the offer-review list already adopted. Carried over from E2:
/// [JeebEmptyStateVariant.radar] in every state, the board's own
/// `520×460 at 50% 42%` orange glow on a `content` field, the glass pill
/// countdown capsule, the glass secondary pill over a periwinkle text link in
/// the docked footer, and E2's headline/body/action ink hierarchy. Same states,
/// same order, same edges, every identifier still resolvable.
///
/// Semantics identifiers (EXACT, per 63_W1_TEST_PLAN §2.6):
///   waiting_notified_count     — number of Jeebers notified (broadcast signature)
///   waiting_countdown          — broadcast countdown timer
///   waiting_no_coverage_state  — no-coverage variant root (0 notified)
///   waiting_review_offers_cta  — appears when offers arrive → offer-review-list
///   waiting_retarget_cta       — re-target → request-type-selection (D48)
///   waiting_cancel_cta         — cancel → cancel-request-confirm sheet (D69)
///   waiting_terminal_state     — matched/cancelled/expired/closed request
///   waiting_terminal_home_cta  — terminal exit → role-aware Home
class NoOfferTimeoutScreen extends StatelessWidget {
  const NoOfferTimeoutScreen({
    super.key,
    required this.requestId,
    this.repository,
    this.cubitFactory,
  });

  final String requestId;

  /// Optional repository override. Production builds leave this null and resolve
  /// DioWaitingRepository from DI. Widget tests inject a scripted instance here.
  final WaitingRepository? repository;

  /// Test seam — see [WaitingCubitFactory].
  final WaitingCubitFactory? cubitFactory;

  WaitingRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<WaitingRepository>()) return sl<WaitingRepository>();
    // DI batch for WaitingRepository not landed yet (50_ROUTE_REQUESTS JM-026):
    // construct the real Dio repo over the registered `sl<Dio>()` so the screen
    // is still bound to `:4010`. Fall back to the fake only if Dio itself is
    // unavailable (e.g. a bare widget test without DI).
    if (sl.isRegistered<Dio>()) {
      // FIX-A: share the app-wide coalescer (when registered) so the waiting
      // screen's `GET /v1/offers?requestId` probe dedupes against the offers /
      // home pollers.
      return DioWaitingRepository(
        sl<Dio>(),
        coalescer: sl.isRegistered<SingleFlightGet>()
            ? sl<SingleFlightGet>()
            : null,
      );
    }
    return FakeWaitingRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<WaitingCubit>(
      create: (_) {
        final cubit =
            cubitFactory?.call(repo, requestId) ??
            WaitingCubit(
              repository: repo,
              requestId: requestId,
              // b02 wave C / N9: the ungated 5s poll is gone. A `type=offer`
              // (bid arrived) or `type=request_expired` / `try_expand_tier`
              // push re-reads it, through the ONE existing resolver.
              //
              // b02 wave D — `{order, offers}`: both of this screen's real
              // triggers publish `offers`, and `order` keeps the accept
              // transition landing. `chat` and `new_request` cannot change a
              // waiting customer's coverage state.
              refreshSignals: resolvePushRefreshStream(
                topics: const {RefreshTopic.order, RefreshTopic.offers},
              ),
            );
        cubit.load();
        return cubit;
      },
      // N9 RESUME BACKSTOP. `cubit.load()` above is the MOUNT one-shot; this is
      // the other half of the owner's 2026-07-28 ruling ("pull it each time you
      // open the screen" — mount AND resume).
      //
      // Without it this screen had NO non-push recovery at all: every widget in
      // this file is stateless, the only retry is on the ERROR state, and a
      // push delivered while the app is backgrounded never reaches the refresh
      // bus. A customer who returned without tapping the notification sat on a
      // frozen "Finding Jeebers" whose countdown kept ticking — the deleted 5 s
      // poll was the self-heal that used to hide this.
      //
      // Event-driven, never timed: see `RouteResumeRefetch` for the visibility
      // gate, the deferral rule and the two coalescing floors.
      child: RouteResumeRefetch(
        onResume: (context) => context.read<WaitingCubit>().refreshOnResume(),
        child: _WaitingView(requestId: requestId),
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<WaitingCubit, WaitingState>(
      builder: (context, state) => JeebMidnightField(
        // E2 declares `radial-gradient(520px 460px at 50% 42%, rgba(215,59,0,
        // .22))` over the §8 base wash, and no periwinkle anywhere: a `content`
        // field (its own alpha is .22) anchored `centerUpper`, behind the radar.
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.centerUpper,
        animateDecor: false,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // No `appBar:` — the header is an in-body JeebTopBar, so the title and
          // the back circle share the body's gutter and render in every state.
          body: SafeArea(
            child: Column(
              children: [
                JeebTopBar.back(
                  title: state.isTerminal
                      ? l10n.offersRequestClosedTitle
                      : l10n.waitingTitle,
                  identifier: 'waiting_back',
                  leadingTooltip: MaterialLocalizations.of(
                    context,
                  ).backButtonTooltip,
                  // Same resolution as the route's registered `backFallbacks`
                  // entry ('waiting-no-coverage' → '/'): this screen is usually
                  // a stack root, where a bare pop would be a dead arrow.
                  onLeadingPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
                Expanded(child: _body(context, state)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WaitingState state) {
    if (state.isLoading) return const _WaitingLoading();
    if (state.status == WaitingScreenStatus.failed) {
      return _WaitingError(
        failure: state.error,
        onRetry: () => context.read<WaitingCubit>().retry(),
      );
    }
    if (state.isTerminal) {
      return _WaitingTerminal(
        requestId: requestId,
        phase: state.request!.phase,
      );
    }
    return _WaitingLoaded(requestId: requestId, state: state);
  }
}

/// The scroll body every state sits in: E2 centres its block vertically
/// (`flex:1; justify-content:center`) but the request echo and the longest
/// countdown must still be reachable on a short viewport.
class _CenteredBlock extends StatelessWidget {
  const _CenteredBlock({required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = maxWidth;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: Spacing.xLarge,
              ),
              child: width == null
                  ? child
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width),
                      child: child,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingLoading extends StatelessWidget {
  const _WaitingLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Loading and waiting are ONE block, as on the neighbouring offer list —
    // the skeleton morphs into the radar rather than swapping surfaces.
    return _CenteredBlock(
      child: JeebEmptyState(
        variant: JeebEmptyStateVariant.radar,
        status: JeebEmptyStateStatus.loading,
        headline: l10n.offersWaitingTitle,
        body: l10n.requestSummaryFindingHint,
      ),
    );
  }
}

class _WaitingError extends StatelessWidget {
  const _WaitingError({required this.onRetry, this.failure});

  final VoidCallback onRetry;

  /// Why the load failed. A backend-contract break gets its OWN copy so a QA
  /// run reports "backend contract break", not "network problem" (P7 T5.5).
  final WaitingFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = failure == WaitingFailure.contractViolation
        ? l10n.waitingErrorContractBody
        : l10n.waitingErrorBody;
    // waiting_error_state re-homed onto the block itself — the Padding+Semantics
    // wrapper existed only to host the id and to gutter an OMDS slab.
    return _CenteredBlock(
      maxWidth: Sizes.threeHundredLarge,
      child: JeebEmptyState(
        identifier: 'waiting_error_state',
        variant: JeebEmptyStateVariant.radar,
        status: JeebEmptyStateStatus.error,
        headline: l10n.waitingErrorTitle,
        body: message,
        center: const _NoSignalCore(),
        action: JeebCtaButton.primary(
          label: l10n.requestSummaryRetry,
          onTap: onRetry,
        ),
      ),
    );
  }
}

/// Ø58 radar core, sized off the kit's own core slot; the glyph matches E2's
/// 26px centre mark.
const double _kCoreGlyph = 26;

/// The failure core: a failed read is not a live broadcast, so the orange core
/// and its bloom are replaced — the same swap the offer-review waiting block
/// makes, so both waiting surfaces fail identically.
class _NoSignalCore extends StatelessWidget {
  const _NoSignalCore();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[scheme.onErrorContainer, scheme.error],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.cloud_off_outlined,
          size: _kCoreGlyph,
          color: scheme.onError,
        ),
      ),
    );
  }
}

/// Server-owned terminal state. There is deliberately no countdown, retry,
/// re-target, or cancel action here: this request has left the waiting flow.
class _WaitingTerminal extends StatelessWidget {
  const _WaitingTerminal({required this.requestId, required this.phase});

  final String requestId;
  final WaitingRequestPhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'waiting_terminal_state',
      container: true,
      explicitChildNodes: true,
      child: Column(
        children: [
          Expanded(
            child: _CenteredBlock(
              child: JeebEmptyState(
                key: const Key('waiting-terminal-empty-state'),
                variant: JeebEmptyStateVariant.radar,
                headline: _title(l10n),
                body: _subtitle(l10n),
                center: _TerminalCore(phase: phase),
                // A closed request reaches nobody: the rings stay, the "jeebers
                // in range" discs go rather than assert stale coverage.
                medallions: const <JeebEmptyMedallion>[],
              ),
            ),
          ),
          // The exit docks where every other state's actions dock, so the four
          // states read as one screen rather than four.
          JeebCtaFooter.single(
            child: Semantics(
              identifier: 'waiting_terminal_home_cta',
              container: true,
              button: true,
              child: JeebCtaButton(
                key: const Key('waiting-terminal-home-cta'),
                label: l10n.trackingCancelledHomeCta,
                onTap: () => context.go('/'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (phase) {
    WaitingRequestPhase.matched => l10n.deliveryStageMatched,
    WaitingRequestPhase.cancelled => l10n.deliveryStageCancelled,
    WaitingRequestPhase.expired => l10n.requestSummaryExpiredTitle,
    _ => l10n.offersRequestClosedTitle,
  };

  String? _subtitle(AppLocalizations l10n) => switch (phase) {
    WaitingRequestPhase.expired => l10n.requestSummaryExpiredBody,
    WaitingRequestPhase.cancelled ||
    WaitingRequestPhase.closed => l10n.requestNoLongerAvailable(requestId),
    _ => null,
  };
}

/// The terminal core. An outcome is not a failure, so it never spends the
/// `error` role: each phase takes its own §2 container/onContainer quartet.
class _TerminalCore extends StatelessWidget {
  const _TerminalCore({required this.phase});

  final WaitingRequestPhase phase;

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final (Color fill, Color ink, IconData glyph) = switch (phase) {
      WaitingRequestPhase.matched => (
        roles.successContainer,
        roles.onSuccessContainer,
        Icons.check_circle_outline,
      ),
      WaitingRequestPhase.expired => (
        roles.warningContainer,
        roles.onWarningContainer,
        Icons.timer_off_outlined,
      ),
      WaitingRequestPhase.cancelled => (
        roles.infoContainer,
        roles.onInfoContainer,
        Icons.cancel_outlined,
      ),
      _ => (roles.infoContainer, roles.onInfoContainer, Icons.lock_outline),
    };
    return DecoratedBox(
      key: const Key('waiting-terminal-core'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.fromBorderSide(BorderSide(color: semantic.glassBorder)),
      ),
      child: Center(
        child: Icon(glyph, size: _kCoreGlyph, color: ink),
      ),
    );
  }
}

class _WaitingLoaded extends StatelessWidget {
  const _WaitingLoaded({required this.requestId, required this.state});

  final String requestId;
  final WaitingState state;

  void _openReviewOffers(BuildContext context) {
    // EDGE: waiting_review_offers_cta → offer-review-list (JM-028). The route
    // `offer-review` (`/requests/:id/offers`) is registered by the W1 integrator.
    context.pushNamed('offer-review', pathParameters: {'id': requestId});
  }

  void _retarget(BuildContext context) {
    // EDGE: waiting_retarget_cta → request-type-selection (D48). The route
    // `request-type` is registered. CONTRACT GAP (50_ROUTE_REQUESTS JM-026):
    // the route takes no request-id seed, so "reuse original content" (D48
    // pre-fill) cannot be forwarded yet — the user re-enters the tier picker
    // fresh. Tracked for a `?from=:requestId` route param.
    context.pushNamed('request-type');
  }

  Future<void> _cancel(BuildContext context) async {
    // EDGE: waiting_cancel_cta → cancel-request-confirm sheet (D69). The sheet
    // (JM-030) is a modal, not a route, and itself routes home on confirm.
    await CancelRequestSheet.show(context, requestId: requestId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final request = state.request;
    final notifiedCount = request?.notifiedCount ?? 0;
    final showReviewOffers = state.hasOffers;
    final echo = request?.title?.trim();

    return Column(
      children: [
        // ── The waiting band: E2's radar, headline, body, countdown capsule,
        //    then the request echo. Centred on the residual space, as the tile
        //    draws it, but scrollable so the longest echo stays reachable.
        Expanded(
          child: _CenteredBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header is re-driven off REAL signals — offers, phase, and the
                // broadcast countdown — never off notifiedCount (BUG-4 /
                // JM-026 false-no-coverage). The softened "No offers yet" state
                // appears ONLY once the broadcast window has fully elapsed with
                // zero offers in; while offers exist or the clock is still
                // running we stay optimistic.
                if (state.isNoOffersYet)
                  const _NoOffersYetBlock()
                else
                  _BroadcastBlock(
                    notifiedCount: notifiedCount,
                    remaining: state.remaining,
                    // Offers-arrived grows the footer by the review pill; the
                    // radar gives that height back so the echo card still fits.
                    illustrationSize: showReviewOffers
                        ? JeebEmptyState.compactIllustrationSize
                        : JeebEmptyState.defaultIllustrationSize,
                  ),
                // G1 (sprint-009 P0): echo the customer's own request content
                // while they wait — the same text the jeeber feed is showing
                // right now.
                if (echo != null && echo.isNotEmpty) ...[
                  const SizedBox(height: Spacing.xLarge),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: Spacing.xLarge,
                    ),
                    child: _RequestSummaryCard(text: echo),
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Docked actions. Same three affordances in the same order; the
        //    board's footer keeps them off the scroll body so the cancel exit
        //    is never scrolled past.
        JeebCtaFooter.single(
          // Top inset so a residual scroll-clip line never kisses the pill.
          padding: const EdgeInsetsDirectional.fromSTEB(
            24,
            Spacing.small,
            24,
            32,
          ),
          // ── Cancel (free pre-accept, D69; AC4) ──────────────────────────
          below: Semantics(
            identifier: 'waiting_cancel_cta',
            button: true,
            child: JeebCtaButton.text(
              label: l10n.waitingCancelCta,
              onTap: () => _cancel(context),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Offers-arrived: live transition to the review CTA (AC2) ──
              if (showReviewOffers) ...[
                Semantics(
                  identifier: 'waiting_review_offers_cta',
                  button: true,
                  child: JeebCtaButton(
                    label: l10n.waitingReviewOffersCta,
                    onTap: () => _openReviewOffers(context),
                  ),
                ),
                const SizedBox(height: Spacing.small),
              ],

              // ── Re-target (D48; AC3) ────────────────────────────────────
              Semantics(
                identifier: 'waiting_retarget_cta',
                button: true,
                child: JeebCtaButton.outline(
                  label: l10n.waitingRetargetCta,
                  onTap: () => _retarget(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Broadcast (coverage) block — E2 itself: the radar, the count-bearing
/// headline, the expectation line and the countdown capsule (AC1).
///
/// The two Lottie marks this screen used to draw are GONE, not stilled: both
/// were authored white-surface-only (measured 0.00–0.59% ink on navy,
/// 09-MOTION-VALIDATION §7) and would be invisible on the Midnight field, and
/// the board draws this subject as a vector radar the kit already ships.
class _BroadcastBlock extends StatelessWidget {
  const _BroadcastBlock({
    required this.notifiedCount,
    required this.remaining,
    this.illustrationSize = JeebEmptyState.defaultIllustrationSize,
  });

  final int notifiedCount;

  /// Radar width. Reduced in the offers-arrived state, where the footer's
  /// review pill takes height off the scroll viewport.
  final double illustrationSize;

  /// Time left on the server-anchored offer-wait window. NULL means the server
  /// says no countdown applies to this row — the capsule then says so honestly
  /// instead of rendering a fabricated `0:00`.
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // waiting_notified_count re-homed onto E2's own count-bearing headline
    // ("Broadcasting to N Jeebers…"), which is where the tile puts the reach.
    // At <= 0 the uncounted form carries the reassurance without asserting a
    // false zero (BUG-4 / JM-026 false-no-coverage).
    return JeebEmptyState(
      variant: JeebEmptyStateVariant.radar,
      headline: notifiedCount > 0
          ? l10n.offersWaitingTitleCount(notifiedCount)
          : l10n.offersWaitingTitle,
      headlineIdentifier: 'waiting_notified_count',
      // E2's own body promises "within 4 minutes"; this screen carries a REAL
      // server window right beneath it (up to 23:59), so the honest hint wins.
      body: l10n.requestSummaryFindingHint,
      action: _CountdownCapsule(remaining: remaining),
      illustrationSize: illustrationSize,
    );
  }
}

/// Ø8 dot at the head of the capsule (board 7) and its 14px hourglass twin.
const double _kCapsuleDot = Sizes.xSmall;
const double _kCapsuleGlyph = 14;

/// waiting_countdown — E2's glass countdown capsule: pill glass, an orange dot
/// with its `glowDot` halo, one w700 tabular line. The node is ALWAYS present
/// (Maestro flows resolve it) but its text is honest: no anchor pair means no
/// number, and the pending form drops the rationed orange for the muted tone
/// because "a countdown may arrive" is not a do-it-now moment.
class _CountdownCapsule extends StatelessWidget {
  const _CountdownCapsule({required this.remaining});

  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final live = remaining;
    return JeebGlassCard(
      identifier: 'waiting_countdown',
      radius: JeebRadii.pill,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live != null)
            _CountdownDot(color: context.jeebRoles.accent)
          else
            Icon(
              Icons.hourglass_top,
              size: _kCapsuleGlyph,
              color: semantic.mutedText,
            ),
          const SizedBox(width: Spacing.xSmall),
          Flexible(
            child: Text(
              live != null
                  ? l10n.waitingCountdownLabel(CountdownFormat.format(live))
                  : l10n.waitingCountdownPending,
              style: context.jeebText.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: live != null ? scheme.onSurface : semantic.mutedText,
                // A countdown that reflows every second is unreadable — fix the
                // digit advance so only the glyphs change.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The lit dot at the head of the capsule — E2 draws it with a
/// `0 0 10px rgba(215,59,0,.8)` halo, which is §7's `glowDot`.
class _CountdownDot extends StatelessWidget {
  const _CountdownDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _kCapsuleDot,
      child: DecoratedBox(
        key: const Key('waiting-countdown-dot'),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: JeebShadows.glowDot,
        ),
      ),
    );
  }
}

/// G1 (sprint-009 P0): "Your request" echo card — the customer's own
/// "What do you need?" text (the request `description`/`title` the create
/// POSTed), rendered in full so the customer can verify what the nearby
/// jeebers are being asked to price.
class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'waiting_request_description',
      container: true,
      // Outline over shadow, r16 — the grey slab was the only card on this
      // screen and read as a different product from 11's outlined offer cards.
      child: JeebOutlinedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JeebSectionLabel(l10n.waitingRequestSummaryLabel),
            const SizedBox(height: Spacing.twoXSmall),
            Text(
              text,
              style: context.jeebText.cardTitle.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Softened "No offers yet" variant — shown ONLY once the broadcast window has
/// fully elapsed with zero offers in (clock-driven via [WaitingState.remaining]
/// == zero). It never renders while offers exist or the countdown is running,
/// and it is no longer gated on `notifiedCount` (BUG-4 / JM-026
/// false-no-coverage). The Semantics id is intentionally kept as
/// `waiting_no_coverage_state` so existing Maestro flows still resolve it —
/// re-homed onto the block itself, which deletes the wrapper that hosted it.
///
/// It keeps E2's LIVE broadcast core: the window elapsed, but the copy this
/// state ships says jeebers are "still reviewing your request", so swapping in
/// the no-signal core (which the failure form earns) would contradict it. No
/// countdown capsule either — there is no window left to count.
class _NoOffersYetBlock extends StatelessWidget {
  const _NoOffersYetBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      identifier: 'waiting_no_coverage_state',
      variant: JeebEmptyStateVariant.radar,
      headline: l10n.waitingNoCoverageTitle,
      body: l10n.waitingNoCoverageBody,
    );
  }
}
