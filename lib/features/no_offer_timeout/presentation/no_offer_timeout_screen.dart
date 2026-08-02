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
import '../../../l10n/app_localizations.dart';
import '../../cancel_request/presentation/cancel_request_sheet.dart';
import '../application/waiting_cubit.dart';
import '../application/waiting_state.dart';
import '../data/dio_waiting_repository.dart';
import '../data/fake_waiting_repository.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/no_offer_timeout_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

typedef WaitingCubitFactory =
    WaitingCubit Function(WaitingRepository repository, String requestId);

class NoOfferTimeoutScreen extends StatelessWidget {
  const NoOfferTimeoutScreen({
    super.key,
    required this.requestId,
    this.repository,
    this.cubitFactory,
  });

  final String requestId;

  final WaitingRepository? repository;

  final WaitingCubitFactory? cubitFactory;

  WaitingRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<WaitingRepository>()) return sl<WaitingRepository>();
    if (sl.isRegistered<Dio>()) {
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
              refreshSignals: resolvePushRefreshStream(
                topics: const {RefreshTopic.order, RefreshTopic.offers},
              ),
            );
        cubit.load();
        return cubit;
      },
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
      builder: (context, state) => Scaffold(
        appBar: OMDSAppBar(
          title: state.isTerminal
              ? l10n.offersRequestClosedTitle
              : l10n.waitingTitle,
        ),
        body: SafeArea(child: _body(context, state)),
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
  const _WaitingError({required this.onRetry, this.failure});

  final VoidCallback onRetry;

  final WaitingFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = failure == WaitingFailure.contractViolation
        ? l10n.waitingErrorContractBody
        : l10n.waitingErrorBody;
    return Padding(
      padding: const EdgeInsets.all(Spacing.large),
      child: Semantics(
        identifier: 'waiting_error_state',
        container: true,
        child: OmdsErrorState(message: message, onRetry: onRetry),
      ),
    );
  }
}

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
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmdsEmptyState(
                key: const Key('waiting-terminal-empty-state'),
                icon: _icon,
                title: _title(l10n),
                subtitle: _subtitle(l10n),
              ),
              const SizedBox(height: Spacing.large),
              Semantics(
                identifier: 'waiting_terminal_home_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  key: const Key('waiting-terminal-home-cta'),
                  text: l10n.trackingCancelledHomeCta,
                  onTap: () => context.go('/'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (phase) {
    WaitingRequestPhase.matched => Icons.check_circle_outline,
    WaitingRequestPhase.cancelled => Icons.cancel_outlined,
    WaitingRequestPhase.expired => Icons.timer_off_outlined,
    _ => Icons.lock_outline,
  };

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

class _WaitingLoaded extends StatelessWidget {
  const _WaitingLoaded({required this.requestId, required this.state});

  final String requestId;
  final WaitingState state;

  void _openReviewOffers(BuildContext context) {
    context.pushNamed('offer-review', pathParameters: {'id': requestId});
  }

  void _retarget(BuildContext context) {
    context.pushNamed('request-type');
  }

  Future<void> _cancel(BuildContext context) async {
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
          if (state.isNoOffersYet)
            const _NoOffersYetHeader()
          else
            _BroadcastHeader(
              notifiedCount: notifiedCount,
              remaining: state.remaining,
            ),
          if (request?.title != null && request!.title!.trim().isNotEmpty) ...[
            const SizedBox(height: Spacing.xLarge),
            _RequestSummaryCard(text: request.title!.trim()),
          ],
          const SizedBox(height: Spacing.twoXLarge),

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

class _BroadcastHeader extends StatelessWidget {
  const _BroadcastHeader({
    required this.notifiedCount,
    required this.remaining,
  });

  final int notifiedCount;

  final Duration? remaining;

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
        Semantics(
          identifier: 'waiting_countdown',
          child: Text(
            remaining == null
                ? l10n.waitingCountdownPending
                : l10n.waitingCountdownLabel(
                    CountdownFormat.format(remaining!),
                  ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

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

class _NoOffersYetHeader extends StatelessWidget {
  const _NoOffersYetHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'waiting_no_coverage_state',
      container: true,
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: Sizes.eightXLarge,
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/no_offer_timeout/no_offer_timeout_screen_preview_test.dart
// ===========================================================================
//
// [NoOfferTimeoutScreen] is the pre-accept WAITING surface: the customer has
// posted a request, nobody has accepted it yet, and this screen is the only
// thing they look at while that is true. It takes a REPOSITORY, not a state —
// it builds its own [WaitingCubit] and calls `load()` at mount — so every
// preview below hands it a local fake through the same [cubitFactory] seam the
// widget tests use, and the real two-phase cold load runs exactly as it does in
// production.
//
// The fakes, the seeded snapshots and the frozen clock are NOT declared here.
// They live in
// `lib/devtool/catalog/fixtures/no_offer_timeout_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_06_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". None of those repositories can reach the network — they answer from
// a canned snapshot, throw, or never complete — and
// [NoOfferTimeoutScreenPreviewFixtures.inertCubit] replaces BOTH of the cubit's
// live streams with empty ones. The second replacement is load-bearing:
// `clockTicks` defaults to a `Stream.periodic(1s)`, and a subscription to it is
// a pending timer that fails every widget test that mounts this screen.
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and the
//    screen's own `Scaffold + OMDSAppBar` paints inside it. That is the same
//    nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.** The `size:` on
//    [JeebPreview] boxes the canvas; [_noOfferTimeoutScreenFramed] pins the
//    same width in the widget tree so the render tests measure the same phone —
//    otherwise they measure the 800 pt test surface, where none of this layout
//    applies. Height is pinned too, but the render surface is 800x600, so a
//    `SizedBox` asking for 844 is enforced down to what the host has; the
//    COMPACT box (320x568) fits and is therefore exact.
//  * **The clock is frozen, so the countdown is a fixed string.** In the app
//    `WaitingCubit.tick()` advances `now` every second; here `clockTicks` is
//    empty and `now` is pinned to the same instant the snapshot was anchored
//    on, so `4:30 left to find a Jeeber` is exactly that and a render test can
//    pin it. Nothing below animates.
//
// The states are the five the Screen Catalog names plus five it does not, and
// the extra five are the ones that break:
//
//   * **Loading.** The cold read in flight — an [OmdsShimmer] block with no
//     copy and nothing to tap. It is also the only state whose render test
//     cannot use `pumpAndSettle`: the shimmer is an indefinite animation, so
//     the harness's settle would time out.
//   * **Terminal.** The server-owned outcome, which replaces the whole waiting
//     surface with an exit — no countdown, no retry, no re-target, no cancel.
//     The Screen Catalog covers none of the four terminal phases.
//   * **No countdown applies (P7).** `remainingAtReceipt == null` is the server
//     saying this row has no offer-wait window. The countdown node stays
//     mounted and says so in words; a fabricated `0:00` here would be a lie
//     with a clock face on it.
//   * **Zero notified while the window runs (BUG-4).** The regression guard,
//     made visible — see below.
//   * **Longest content at 320 pt.** The layout ceiling on the narrowest phone
//     the app supports, carrying the 24 h window that produced the `1433:18`
//     defect on real hardware.
//
// And one PAIR worth reading together, because the screen splits an authority
// here that a previous version got wrong: [noOfferTimeoutScreenZeroNotified]
// (zero Jeebers notified, window still running → the neutral "we're reaching
// out" line) beside [noOfferTimeoutScreenNoOffersYet] (the window has fully
// elapsed with zero offers → the softened no-coverage block). BUG-4 was the
// first one rendering as the second: `notifiedCount` is informational and is
// effectively ALWAYS zero in production, because jeebers discover requests by
// pulling `GET /v1/jeebers/me/feed` and the gateway populates no push-notify
// counter — so gating on it told every waiting customer "No Jeebers nearby yet"
// while the broadcast was perfectly healthy. Only the CLOCK may raise that
// block.

/// The phone this screen is designed against.
const Size _noOfferTimeoutScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _noOfferTimeoutScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _noOfferTimeoutScreenFramed(
  Widget screen, {
  Size box = _noOfferTimeoutScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

/// Builds the screen the way its route builds it — id + repository — with the
/// one seam a preview needs: an inert, clock-pinned cubit.
Widget _noOfferTimeoutScreenHosted(
  WaitingRepository repository, {
  Size box = _noOfferTimeoutScreenPhoneBox,
}) {
  return _noOfferTimeoutScreenFramed(
    NoOfferTimeoutScreen(
      requestId: NoOfferTimeoutScreenPreviewFixtures.requestId,
      repository: repository,
      cubitFactory: NoOfferTimeoutScreenPreviewFixtures.inertCubit,
    ),
    box: box,
  );
}

/// The reference reading: the request is fanning out, six Jeebers have been
/// notified, and 4:30 is left on the server-anchored window (AC1).
///
/// Everything the waiting customer is offered is on this one card — the
/// broadcast header, the echo of their own request text (G1), the free
/// pre-accept Cancel (D69) and the Re-target CTA (D48) — with no Review-offers
/// CTA, because nobody has bid.
///
/// This is the one the matrix is for. Every string here is a centred, wrapping
/// paragraph inside a 342 pt column: at 200% text the header alone is taller
/// than the viewport, and in AR the whole stack mirrors, including the
/// direction the countdown sentence reads in around its Latin clock field.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Broadcasting · counting down',
  size: _noOfferTimeoutScreenPhoneBox,
  matrix: true,
)
Widget noOfferTimeoutScreenBroadcasting() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.broadcasting(),
);

/// A bid has landed (AC2): the screen flips live to `waiting_review_offers_cta`
/// → `offer-review`, above the same Re-target and Cancel it already offered.
///
/// The countdown keeps running and the header stays optimistic — the customer
/// may still want to wait for a cheaper offer, so nothing here is a deadline
/// they are being pushed through.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Offers arrived',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenOffersArrived() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.offersArrived(),
);

/// The broadcast window has fully elapsed with ZERO offers in.
///
/// This is the ONLY shape entitled to the softened no-coverage block
/// (`waiting_no_coverage_state`): `remaining == Duration.zero`, no offers, not
/// terminal. Read it next to [noOfferTimeoutScreenZeroNotified] — the two are
/// one clock apart and were once the same rendering, which is what BUG-4 was.
///
/// Note what the block replaces: the countdown and the notified line are GONE,
/// so the customer loses their only sense of how long they have been waiting
/// at exactly the moment they most want it.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'No offers yet · window elapsed',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenNoOffersYet() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.noOffersYet(),
);

/// BUG-4 / JM-026 false-no-coverage, made visible: zero notified, window still
/// running.
///
/// `notifiedCount` is informational and is effectively always zero in
/// production, so this is what MOST real waiting customers see. It must render
/// the neutral "We're reaching out to Jeebers near you…" line inside
/// `waiting_notified_count` — never "No Jeebers nearby yet", and never the
/// no-coverage block, both of which are claims about coverage that a zero
/// counter is no evidence for.
///
/// If this preview ever starts looking like [noOfferTimeoutScreenNoOffersYet],
/// the regression is back.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Zero notified · window still running',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenZeroNotified() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.zeroNotifiedStillCounting(),
);

/// P7 — the server says NO countdown applies to this row.
///
/// `remainingAtReceipt: null` is a legitimate server answer (accepted,
/// scheduled), not a missing field: a live row without `offerDeadlineInSeconds`
/// is a contract violation that throws in the repository and lands in
/// [noOfferTimeoutScreenContractViolation] instead. The `waiting_countdown`
/// node stays mounted — Maestro flows resolve it — and reads "Finding a Jeeber
/// for you". There is deliberately no `0:00` anywhere on this card.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'No countdown applies',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenNoCountdown() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.noCountdown(),
);

/// The cold read in flight: a single [OmdsShimmer] block and nothing else.
///
/// Note what is NOT on screen — no countdown, no request echo, and no way out
/// except the app bar's back arrow. Worth looking at because this screen has no
/// timeout of its own: the shimmer stays for as long as
/// `GET /v1/requests/{id}` takes, however long that is.
///
/// It is also the one state whose render test cannot use `pumpAndSettle` — the
/// shimmer animates forever, so the settle would time out. See the dedicated
/// pump-once group in
/// `test/previews/no_offer_timeout/no_offer_timeout_screen_preview_test.dart`.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Loading · cold read',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenLoading() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.stalledLoad(),
);

/// The cold read failed on the transport: the centred [OmdsErrorState] with the
/// connection copy and a Retry that re-enters the whole cold-load path.
///
/// The body replaces everything — countdown, request echo, Cancel — so a
/// customer whose network blipped while waiting loses the free pre-accept
/// cancel until the retry succeeds. Read it beside
/// [noOfferTimeoutScreenContractViolation]: same layout, different claim.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Load failed · network',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenLoadFailed() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.failingLoad(),
);

/// P7 — the gateway answered 200 with a payload that violates the offer-wait
/// contract (a live row carrying no `offerDeadlineInSeconds`).
///
/// It gets its OWN copy, and that is the whole point of previewing it beside
/// the network failure: retrying cannot help, the cubit tears its streams down
/// rather than re-reading, and a QA run must report "backend contract break"
/// instead of "network problem". The Retry button is still offered, which is
/// itself worth looking at — it is the only action on a screen where the action
/// is known to be useless.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Contract violation',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenContractViolation() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.contractViolation(),
);

/// The server-owned terminal outcome: the request expired before anyone bid.
///
/// `WaitingCubit.load` returns early on a terminal phase — no refresh
/// subscription, no clock ticker — and the screen swaps the app-bar title to
/// "Request closed" and the body to `waiting_terminal_state`: an icon, the
/// phase's own title and body, and a single role-aware Home exit. Nothing about
/// waiting survives, which is correct: a dead request under a live countdown is
/// the failure this state exists to prevent.
///
/// The other three terminal phases (matched, cancelled, closed) take the same
/// body with a different icon/title/subtitle triple.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Terminal · expired',
  size: _noOfferTimeoutScreenPhoneBox,
)
Widget noOfferTimeoutScreenTerminalExpired() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.terminalExpired(),
);

/// The layout ceiling, on the narrowest phone the app supports.
///
/// Everything that can be long is long at once: a customer-typed paragraph in
/// the "Your request" echo card, which sets no `maxLines` and renders in full;
/// a three-digit notified count; and the 24 h `SafeExpiryWindow` the gateway
/// falls back to when a request's tier does not resolve — the input that
/// printed `1433:18 left to find a Jeeber` on real hardware before
/// `CountdownFormat` promoted the hours field.
///
/// Read the AR RTL and 200% renderings rather than the English one: the English
/// stays plausible long after the other two have stopped fitting.
@JeebPreview(
  group: 'no_offer_timeout',
  name: 'Longest content · compact 320',
  size: _noOfferTimeoutScreenCompactBox,
  matrix: true,
)
Widget noOfferTimeoutScreenLongestContent() => _noOfferTimeoutScreenHosted(
  NoOfferTimeoutScreenPreviewFixtures.longestContent(),
  box: _noOfferTimeoutScreenCompactBox,
);
