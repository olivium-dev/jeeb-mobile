import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/single_flight_get.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../../cancel_request/presentation/cancel_request_sheet.dart';
import '../application/waiting_cubit.dart';
import '../application/waiting_state.dart';
import '../data/dio_waiting_repository.dart';
import '../data/fake_waiting_repository.dart';
import '../domain/waiting_repository.dart';

/// Signature for the optional cubit factory the screen exposes for tests.
/// Production wiring leaves it `null` so the default ticker-driven cubit is
/// used; tests pass a factory that injects empty `pollTicks` / `clockTicks` so
/// the test binding doesn't complain about pending timers.
typedef WaitingCubitFactory = WaitingCubit Function(
  WaitingRepository repository,
  String requestId,
);

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
///  - **No-offers-yet variant:** ONLY once the broadcast window has elapsed with
///    zero offers in, the `waiting_no_coverage_state` container shows instead
///    (clock-driven, never gated on notifiedCount — BUG-4 / JM-026).
///  - **Offers arrived:** the cubit polls; once an offer lands the screen flips
///    live to `waiting_review_offers_cta` → `offer-review` (AC2, JM-028).
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
/// Semantics identifiers (EXACT, per 63_W1_TEST_PLAN §2.6):
///   waiting_notified_count     — number of Jeebers notified (broadcast signature)
///   waiting_countdown          — broadcast countdown timer
///   waiting_no_coverage_state  — no-coverage variant root (0 notified)
///   waiting_review_offers_cta  — appears when offers arrive → offer-review-list
///   waiting_retarget_cta       — re-target → request-type-selection (D48)
///   waiting_cancel_cta         — cancel → cancel-request-confirm sheet (D69)
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
        coalescer:
            sl.isRegistered<SingleFlightGet>() ? sl<SingleFlightGet>() : null,
      );
    }
    return FakeWaitingRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<WaitingCubit>(
      create: (_) {
        final cubit = cubitFactory?.call(repo, requestId) ??
            WaitingCubit(repository: repo, requestId: requestId);
        cubit.load();
        return cubit;
      },
      child: _WaitingView(requestId: requestId),
    );
  }
}

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.waitingTitle),
      body: SafeArea(
        child: BlocBuilder<WaitingCubit, WaitingState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const _WaitingLoading();
            }
            if (state.status == WaitingScreenStatus.failed) {
              return _WaitingError(
                onRetry: () => context.read<WaitingCubit>().retry(),
              );
            }
            return _WaitingLoaded(requestId: requestId, state: state);
          },
        ),
      ),
    );
  }
}

class _WaitingLoading extends StatelessWidget {
  const _WaitingLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(Spacing.large),
        child: OmdsShimmer(width: 220, height: 120),
      ),
    );
  }
}

class _WaitingError extends StatelessWidget {
  const _WaitingError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: Semantics(
        identifier: 'waiting_error_state',
        container: true,
        child: OmdsErrorState(
          message: l10n.waitingErrorBody,
          onRetry: onRetry,
        ),
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
    context.pushNamed(
      'offer-review',
      pathParameters: {'id': requestId},
    );
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
    final theme = Theme.of(context);
    final request = state.request;
    final notifiedCount = request?.notifiedCount ?? 0;
    final showReviewOffers = state.hasOffers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Spacing.large),
          // Header is re-driven off REAL signals — offers, phase, and the
          // broadcast countdown — never off notifiedCount (BUG-4 / JM-026
          // false-no-coverage). The softened "No offers yet" state appears ONLY
          // once the broadcast window has fully elapsed with zero offers in;
          // while offers exist or the clock is still running we stay optimistic.
          if (state.isNoOffersYet)
            const _NoOffersYetHeader()
          else
            _BroadcastHeader(
              notifiedCount: notifiedCount,
              remaining: state.remaining,
            ),
          // G1 (sprint-009 P0): echo the customer's own request content while
          // they wait — the same text the jeeber feed is showing right now.
          if (request?.title != null && request!.title!.trim().isNotEmpty) ...[
            const SizedBox(height: Spacing.xLarge),
            _RequestSummaryCard(text: request.title!.trim()),
          ],
          const SizedBox(height: Spacing.twoXLarge),

          // ── Offers-arrived: live transition to the review CTA (AC2) ───────
          if (showReviewOffers) ...[
            Semantics(
              identifier: 'waiting_review_offers_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.waitingReviewOffersCta,
                onTap: () => _openReviewOffers(context),
              ),
            ),
            const SizedBox(height: Spacing.small),
          ],

          // ── Re-target (D48; AC3) ──────────────────────────────────────────
          Semantics(
            identifier: 'waiting_retarget_cta',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.waitingRetargetCta,
              variant: OmdsButtonVariant.outlined,
              onTap: () => _retarget(context),
            ),
          ),
          const SizedBox(height: Spacing.small),

          // ── Cancel (free pre-accept, D69; AC4) ────────────────────────────
          Semantics(
            identifier: 'waiting_cancel_cta',
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.waitingCancelCta,
              variant: OmdsButtonVariant.text,
              textColor: theme.colorScheme.error,
              onTap: () => _cancel(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Broadcast (coverage) header — notified count + live countdown (AC1).
class _BroadcastHeader extends StatelessWidget {
  const _BroadcastHeader({
    required this.notifiedCount,
    required this.remaining,
  });

  final int notifiedCount;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.podcasts,
          size: Sizes.eightXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.large),
        Text(
          l10n.requestSummaryFindingTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.medium),
        // waiting_notified_count — broadcast-state signature id (63 §2.6). The
        // node is ALWAYS present (Maestro flows resolve it), but its text is
        // re-driven: with a real count we show "Notified N nearby Jeebers";
        // when the gateway never populated the counter (notifiedCount <= 0) we
        // show neutral reassurance copy instead of "No Jeebers nearby yet"
        // (BUG-4 / JM-026 false-no-coverage).
        Semantics(
          identifier: 'waiting_notified_count',
          child: Text(
            notifiedCount > 0
                ? l10n.requestSummaryFindingNotifiedCount(notifiedCount)
                : l10n.waitingReachingOutLabel,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: Spacing.small),
        // waiting_countdown — broadcast countdown timer (AC1).
        Semantics(
          identifier: 'waiting_countdown',
          child: Text(
            l10n.waitingCountdownLabel(_format(remaining)),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  static String _format(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    final mm = minutes.toString();
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
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
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'waiting_request_description',
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: OmdsBorderRadius.uiLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.waitingRequestSummaryLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
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
/// `waiting_no_coverage_state` so existing Maestro flows still resolve it.
class _NoOffersYetHeader extends StatelessWidget {
  const _NoOffersYetHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // waiting_no_coverage_state — variant root (63 §2.6, coined). Container so a
    // Maestro flow can assert the whole no-offers-yet block is present. Id kept
    // unchanged on purpose so existing flows keep resolving it.
    return Semantics(
      identifier: 'waiting_no_coverage_state',
      container: true,
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: Sizes.eightXLarge,
            // No-coverage is an attention state → semantic warning role, not
            // the brand tertiary orange.
            color: context.jeebRoles.warning,
          ),
          const SizedBox(height: Spacing.large),
          Text(
            l10n.waitingNoCoverageTitle,
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.small),
          Text(
            l10n.waitingNoCoverageBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
