import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_cubit.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';
import '../data/request_feed_repository.dart';
import 'request_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/request_feed_screen_fixtures.dart';

/// Jeeber-mode realtime delivery request feed (JEEB-66 / T-mobile-013).
///
/// Hosts the [RequestFeedCubit], drives a 1Hz UI ticker so each card with a
/// server deadline can update its countdown badge without re-emitting cubit
/// state, and surfaces accept/decline outcomes via OMDS snackbars. The cubit
/// also retires requests with real deadlines on the same cadence.
// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live feed UI is jeeber_home/jeeber_feed_tab_view.dart (its repository stays live via DI) — see docs/project-understanding/reconciliation/orphans.md
class RequestFeedScreen extends StatelessWidget {
  const RequestFeedScreen({super.key, this.cubit});

  /// Optional pre-wired cubit. Production callers pass `null` and let the
  /// screen wire up the [FakeRequestFeedRepository] until the real gateway
  /// client lands; tests pass a configured one.
  final RequestFeedCubit? cubit;

  @override
  Widget build(BuildContext context) {
    const view = _RequestFeedView();
    if (cubit != null) {
      return BlocProvider<RequestFeedCubit>.value(
        value: cubit!,
        child: view,
      );
    }
    return BlocProvider<RequestFeedCubit>(
      create: (_) => RequestFeedCubit(
        repository: FakeRequestFeedRepository(),
        // JEBV4-342 (b02): wired through the SAME shared resolver the live
        // dashboard host uses, so if this screen is ever un-orphaned it is
        // already push-driven rather than quietly poll-only. Returns `null`
        // when DI has not run, which is this screen's normal (test) case.
        // b02 wave D: same topics as the live dashboard host, so the orphaned
        // construction cannot drift from the one that ships.
        refreshSignals: resolvePushRefreshStream(
          topics: const {RefreshTopic.feed, RefreshTopic.offers},
        ),
      )..start(),
      child: view,
    );
  }
}

class _RequestFeedView extends StatefulWidget {
  const _RequestFeedView();

  @override
  State<_RequestFeedView> createState() => _RequestFeedViewState();
}

class _RequestFeedViewState extends State<_RequestFeedView> {
  Timer? _uiTicker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'request_feed_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: l10n.requestFeedTitle, centerTitle: false),
        body: SafeArea(
          child: BlocConsumer<RequestFeedCubit, RequestFeedState>(
            listenWhen: (prev, curr) => prev.lastEffect != curr.lastEffect,
            listener: _onEffect,
            builder: (context, state) => _FeedColumn(state: state, now: _now),
          ),
        ),
      ),
    );
  }

  void _onEffect(BuildContext context, RequestFeedState state) {
    final effect = state.lastEffect;
    if (effect == null) return;
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: _effectMessage(effect, l10n));
    context.read<RequestFeedCubit>().clearEffect();
  }

  String _effectMessage(RequestActionEffect effect, AppLocalizations l10n) {
    return switch (effect.outcome) {
      RequestActionOutcome.accepted => l10n.requestFeedActionAcceptedSnack,
      RequestActionOutcome.declined => l10n.requestFeedActionDeclinedSnack,
      RequestActionOutcome.alreadyTaken => l10n.requestFeedActionTakenSnack,
      RequestActionOutcome.expired => l10n.requestFeedActionExpiredSnack,
      RequestActionOutcome.networkError =>
        l10n.requestFeedActionNetworkSnack,
    };
  }
}

class _FeedColumn extends StatelessWidget {
  const _FeedColumn({required this.state, required this.now});

  final RequestFeedState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        if (state.transport == FeedTransport.polling)
          _ReconnectingBanner(message: l10n.requestFeedReconnecting),
        Expanded(child: _FeedBody(state: state, now: now, l10n: l10n)),
      ],
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody({
    required this.state,
    required this.now,
    required this.l10n,
  });

  final RequestFeedState state;
  final DateTime now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (state.status == RequestFeedStatus.loading && state.requests.isEmpty) {
      return const Center(child: OmdsLoadingState());
    }
    if (state.status == RequestFeedStatus.error && state.requests.isEmpty) {
      return OmdsErrorState(
        title: l10n.requestFeedErrorTitle,
        message: l10n.requestFeedErrorLoad,
        retryLabel: l10n.requestFeedErrorRetry,
        onRetry: () => context.read<RequestFeedCubit>().refresh(),
      );
    }
    return _FeedListOrEmpty(state: state, now: now, l10n: l10n);
  }
}

class _FeedListOrEmpty extends StatelessWidget {
  const _FeedListOrEmpty({
    required this.state,
    required this.now,
    required this.l10n,
  });

  final RequestFeedState state;
  final DateTime now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return OmdsPullToRefresh(
      onRefresh: () => context.read<RequestFeedCubit>().refresh(),
      child: state.requests.isEmpty
          ? _EmptyFeed(l10n: l10n)
          : _FeedList(state: state, now: now),
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({required this.state, required this.now});

  final RequestFeedState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RequestFeedCubit>();
    return ListView.builder(
      key: const Key('requestFeed.list'),
      padding: const EdgeInsets.symmetric(vertical: Spacing.small),
      itemCount: state.requests.length,
      itemBuilder: (_, index) => _FeedListRow(
        request: state.requests[index],
        actionStatus: state.actionStatusFor(state.requests[index].id),
        now: now,
        onAccept: () => cubit.accept(state.requests[index].id),
        onDecline: () => cubit.decline(state.requests[index].id),
      ),
    );
  }
}

class _FeedListRow extends StatelessWidget {
  const _FeedListRow({
    required this.request,
    required this.actionStatus,
    required this.now,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final DateTime now;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return RequestCard(
      request: request,
      actionStatus: actionStatus,
      secondsRemaining: _secondsLeft(),
      onAccept: onAccept,
      onDecline: onDecline,
    );
  }

  int? _secondsLeft() {
    final expiresAt = request.expiresAt;
    if (expiresAt == null) return null;
    final diff = expiresAt.difference(now).inSeconds;
    return diff.clamp(0, 1 << 31);
  }
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('requestFeed.reconnectingBanner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      // Reconnecting is a transient attention state -> semantic warning role.
      color: context.jeebRoles.warningContainer,
      child: _ReconnectingRow(message: message),
    );
  }
}

class _ReconnectingRow extends StatelessWidget {
  const _ReconnectingRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.wifi_off_outlined,
          size: Sizes.medium,
          color: context.jeebRoles.onWarningContainer,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.jeebRoles.onWarningContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // OmdsPullToRefresh's child must be scrollable for the gesture to fire,
    // so the empty state is wrapped in a single-child scroll view sized to
    // the viewport.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: OmdsEmptyState(
            key: const Key('requestFeed.empty'),
            icon: Icons.inbox_outlined,
            title: l10n.requestFeedEmptyTitle,
            subtitle: l10n.requestFeedEmptySubtitle,
          ),
        ),
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
// Render tests: test/previews/jeeber_request_feed/request_feed_screen_preview_test.dart
// ===========================================================================
//
// [RequestFeedScreen] renders no content of its own. It is a chain of four
// branches over one [RequestFeedState], and every branch is a different body:
//
//     transport == polling                    → a banner ABOVE whatever follows
//     status == loading && requests.isEmpty   → OmdsLoadingState (a bare spinner)
//     status == error   && requests.isEmpty   → OmdsErrorState (title + Retry)
//     requests.isEmpty                        → OmdsEmptyState
//     otherwise                               → ListView of RequestCard
//
// [RequestCard] itself is previewed in `request_card.dart`, where the card's own
// gates (tier chip, countdown, `_actionsLocked`) are the subject. What is on
// review HERE is the branch — which body a given state produces, and what the
// two axes that are NOT part of that chain (`transport`, `errorMessageKey`) do
// to it. Both of those are where this screen's real gaps are, and neither is
// visible from the card.
//
// The fakes and their canned data are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/request_feed_screen_fixtures.dart`, shared with
// the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_05_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states".
//
// Three things about this harness are worth knowing before editing it:
//
//  * **Every preview passes a cubit.** With `cubit: null` the screen builds its
//    own [FakeRequestFeedRepository] — which arms a `Timer.periodic` that
//    synthesises a new request every 12 s — and calls `resolvePushRefreshStream`
//    against the DI container. Neither belongs in a canvas, so the constructor's
//    `cubit` seam is the ONLY way these previews mount the screen.
//  * **The cubits are frozen, not started.** [SeededRequestFeedScreenCubit]
//    emits one designed state in its constructor and never calls `start()`, so
//    none of the cubit's three subscriptions and neither of its timers exist.
//    The screen's OWN 1 Hz ticker still runs — it is unconditional (see below)
//    — but it only re-reads the device clock.
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.** They
//    nest: the host's `Scaffold + SafeArea` frames the card and this screen's
//    `Scaffold + OMDSAppBar` paints inside it. Same nesting the Screen Catalog
//    produces. The frame is pinned in the TREE by [_requestFeedScreenFramed],
//    not just in `size:`, so the render tests measure a phone rather than the
//    800 pt test surface.
//
// The states are the six the Screen Catalog names, plus three it cannot reach.
// What opening them together shows:
//
//   * **The lifecycle buckets do not exist on this screen.** The catalog names
//     "Incoming — Ignore / Offer card", "Pending response" and "Accepted —
//     delivery-action cards" as three states, after Figma screens 24/25/26. This
//     screen renders all three IDENTICALLY: `_FeedListRow` reads `id`,
//     `expiresAt` and the action status and nothing else, so `feedStatus` and
//     `nextDeliveryAction` are dropped on the floor and every row gets the same
//     Decline/Accept pair. [requestFeedScreenLifecycleRows] puts one row of each
//     bucket on the board at once; the three cards are indistinguishable. (The
//     screen-25/26 affordances live on `JeeberFeedCard` in
//     `jeeber_home/presentation/widgets/`, which is what actually ships — this
//     screen is the ORPHAN noted at the top of the file.)
//   * **A refresh that fails over a populated feed is silent.**
//     `RequestFeedCubit._refresh` catches, keeps `status: ready` because the
//     feed is non-empty, and records the failure in `errorMessageKey` — a field
//     NOTHING in this file reads. [requestFeedScreenRefreshFailedOverRows] is
//     that state: stale rows, no banner, no toast, no retry, nothing.
//   * **The cold read has no surface of its own beyond a bare spinner.**
//     [requestFeedScreenColdRead] is the only body with zero text in it, in
//     either locale — which is why the render test pins it structurally rather
//     than by a string.
//   * **The countdown badge is raw seconds.** `requestFeedExpiresIn` is
//     `"Expires in {seconds}s"` with no mm:ss formatting, so the production
//     5-minute offer window reads "Expires in 287s" and the dev fixture's
//     far-future deadline in [requestFeedScreenLiveRequest] reads eight digits.
//     That preview is the catalog's screen-24 row verbatim, so the number is
//     the fixture's fault and the formatting is the screen's.
//
// Everything else here is the ordinary set: empty, error, degraded transport and
// the layout ceiling on the narrowest phone the app supports.

/// The phone this feed is designed against (iPhone 14 / a tall Android).
const Size _requestFeedScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _requestFeedScreenCompactBox = Size(320, 568);

/// Mounts the screen the way the Dashboard host would, over a frozen cubit and
/// pinned to a device-sized frame inside whatever box the host gives it.
///
/// [BlocProvider.value] inside the screen never closes the cubit it is handed,
/// which is fine here: an un-started [RequestFeedCubit] holds no subscription
/// and no timer, so there is nothing to leak. The Screen Catalog, whose cubits
/// ARE started, owns a stateful host that closes them.
Widget _requestFeedScreenFramed(
  RequestFeedCubit cubit, {
  Size box = _requestFeedScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(
      width: box.width,
      height: box.height,
      child: RequestFeedScreen(cubit: cubit),
    ),
  );
}

/// The catalog's "Incoming — Ignore / Offer card" state, verbatim: one live
/// request on a healthy WebSocket transport.
///
/// The reference rendering every other state is read against. Two things to
/// look for. The countdown badge is unformatted seconds — the dev fixture's
/// 365-day deadline makes that unmissable, but the production value (~300 s
/// from `offerDeadlineInSeconds`) is no better formatted. And the card carries
/// none of the Figma screen-24 identity the fixture actually supplies: this
/// screen's [RequestCard] renders pickup, dropoff, distance and earnings, so
/// `senderName`, `senderAvatarUrl`, `senderRating`, `itemsSummary` and
/// `receivedAt` are all present on the model and invisible on screen.
///
/// The matrix is on because this is the reference: the header row and the
/// metadata row are both flex-less [Row]s that clip in Arabic before they clip
/// in English, and the action pills fix their height at 48 pt.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Live request · countdown',
  size: _requestFeedScreenPhoneBox,
  matrix: true,
)
Widget requestFeedScreenLiveRequest() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.ready(
        RequestFeedScreenPreviewFixtures.incomingFeed(),
      ),
    );

/// The board is empty and the read SUCCEEDED — the catalog's "Empty" state.
///
/// The empty hero sits inside an [OmdsPullToRefresh] over a viewport-height
/// scroll view, which is what makes the "Pull down to refresh" the subtitle
/// promises actually work. Note this is the only body reachable from BOTH
/// `status: initial` and `status: ready`: a cubit that was built and never
/// started renders as a settled empty board, indistinguishable from one that
/// asked the gateway and got nothing.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Empty board',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenEmptyBoard() =>
    _requestFeedScreenFramed(RequestFeedScreenPreviewFixtures.emptyBoard());

/// The cold read FAILED with nothing on the board — the catalog's "Error"
/// state, and the only place this screen ever shows an error at all.
///
/// Title, message and Retry, replacing the whole body. `onRetry` calls the real
/// `refresh()`, which here re-throws from the fixture repository, so the state
/// is stable under tapping — the same loop a jeeber with no connectivity sees.
/// The message is hardcoded to `requestFeedErrorLoad`; the cubit's
/// `errorMessageKey` is never consulted, so a future second failure mode would
/// render as this one.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Load failed · retry',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenLoadFailed() =>
    _requestFeedScreenFramed(RequestFeedScreenPreviewFixtures.loadFailed());

/// The cold read still in flight — `GET /v1/jeebers/me/feed` has been issued
/// and nothing has come back.
///
/// A bare centred spinner: no app-bar progress, no skeleton rows, no copy. It
/// is the only state on this screen with no text of its own in either locale,
/// which is also why the render test identifies it by structure. Worth a design
/// decision: on a slow connection this is a blank screen under a title that
/// says "Incoming requests", and it is indistinguishable from a hang.
///
/// The Screen Catalog cannot show this state at all — every catalog state
/// drives a real `start()` through a synchronous fixture repository, so the
/// loading frame is over before the first paint.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Cold read in flight',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenColdRead() =>
    _requestFeedScreenFramed(RequestFeedScreenPreviewFixtures.coldRead());

/// The catalog's "Reconnecting — degraded polling transport" state: the WS
/// upgrade fell over and the repository is polling.
///
/// The banner is the ONLY thing that changes; the same feed renders under it.
/// Read it for two things. It is a plain [Container] in the warning role with
/// no dismiss and no retry, so it is a statement rather than an affordance. And
/// it sits ABOVE the [OmdsPullToRefresh], so it stays pinned while the list
/// scrolls — which is deliberate, and worth confirming against the design.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Reconnecting · polling transport',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenReconnecting() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.degradedTransport(
        RequestFeedScreenPreviewFixtures.incomingFeed(),
      ),
    );

/// The catalog's "Pending response" and "Accepted" states, merged — because on
/// this screen they are not states.
///
/// One row per [JeeberFeedItemStatus]: incoming, pending-response, accepted
/// (with a `nextDeliveryAction` set). All three render the same Decline/Accept
/// card, because `_FeedListRow` never reads `feedStatus` or
/// `nextDeliveryAction`. Previewing them as three separate cards would have
/// been previewing a fiction, so they are here in one board where the collapse
/// is the point: a jeeber cannot tell an auction they can bid on from one they
/// have already bid on from one they have already won.
///
/// This also means the two Decline/Accept buttons on the accepted row are live
/// affordances for a request whose auction is over.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Incoming · pending · accepted (identical)',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenLifecycleRows() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.ready(
        RequestFeedScreenPreviewFixtures.lifecycleFeed(),
      ),
    );

/// A refresh that failed while rows were already on screen.
///
/// `RequestFeedCubit._refresh` catches, keeps `status: ready` (the feed is
/// non-empty, so the error body would have thrown away good rows) and records
/// `errorMessageKey: 'requestFeedErrorLoad'`. Nothing in this file reads that
/// field, so the state renders EXACTLY like a healthy feed: no banner, no
/// snackbar, no stale-data mark, no retry. The rows on screen are whatever the
/// last successful read returned, presented as current.
///
/// This is the state a jeeber is in after walking into a basement: the board
/// looks live, and tapping Accept on it is the only way to find out it is not.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Refresh failed over rows · silent',
  size: _requestFeedScreenPhoneBox,
)
Widget requestFeedScreenRefreshFailedOverRows() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.refreshFailedOverRows(
        RequestFeedScreenPreviewFixtures.staleFeed(),
      ),
    );

/// The layout ceiling on the narrowest phone the app supports: two addresses
/// long enough to hit the card's `maxLines: 2` and a six-figure Lebanese-pound
/// amount, at 320 pt.
///
/// LBP is the home market, so "≈ 4500000.00 LBP" is the normal case rather than
/// an edge case — and the metadata [Row] holds two `MainAxisSize.min` badges
/// with a fixed gap and no flex on either, so nothing can ellipsize or wrap when
/// it does not fit. The currency is rendered as the raw ISO code the gateway
/// sent, never localized and never mapped to a symbol, so the Arabic rendering
/// splices Latin "LBP" into RTL text.
///
/// The matrix is on for what the render test cannot reach. That test pumps this
/// frame at 320 pt in BOTH locales with the real Inter and Noto faces loaded and
/// finds no overflow in either — so the fit is measured, not assumed — but it
/// only ever pumps at 1.0 text scale. The 200% rendering is the open question,
/// and it is the one the canvas answers.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Longest content · compact 320',
  size: _requestFeedScreenCompactBox,
  matrix: true,
)
Widget requestFeedScreenLongestContent() => _requestFeedScreenFramed(
      RequestFeedScreenPreviewFixtures.ready(
        RequestFeedScreenPreviewFixtures.longestContentFeed(),
      ),
      box: _requestFeedScreenCompactBox,
    );
