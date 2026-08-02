import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/polling_visibility_gate.dart';
import '../../../core/lifecycle/route_visibility.dart';
import '../../../core/session/greeting_profile_cubit.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../customer_profile/data/dio_customer_profile_repository.dart';
import '../../../core/notifications/application/push_refresh_signals.dart';
import '../../customer_profile/domain/customer_profile_repository.dart';
import '../../home_client/application/client_home_cubit.dart';
import '../../home_client/application/client_home_state.dart';
import '../../home_client/data/dev_client_home_fixtures.dart';
import '../../home_client/data/in_memory_client_home_repository.dart';
import '../../home_client/domain/client_home_repository.dart';
import '../../home_client/domain/client_home_request.dart';
import '../../home_client/presentation/client_home_screen.dart';
import '../tab_visibility.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../core/previews/jeeb_preview.dart';

/// Client-role home tab. Hosts the [ClientHomeCubit] scoped to this tab —
/// rebuilt on role switches (the shell tears down + reinflates), which is
/// the right lifetime for a per-tab view-model.
///
/// The repository defaults to the in-memory fake until the jeeb-gateway
/// `/api/clients/me/home-summary` endpoint exists. Callers can inject a
/// real repository through the constructor (used by widget tests).
class HomeTab extends StatelessWidget {
  const HomeTab({super.key, this.repository, this.greetingNameProvider});

  /// Injection hook so tests + the future DI wiring can swap in a Dio-
  /// backed repository without modifying the tab.
  final ClientHomeRepository? repository;

  /// Returns the first name to greet the user with, or `null` if unknown.
  /// Wired to the profile cubit once that ships.
  final String? Function()? greetingNameProvider;

  @override
  Widget build(BuildContext context) {
    final devTab = _devSeamTab();
    final devSeed = devTab != null;
    return MultiBlocProvider(
      key: const Key('home-tab-cubit'),
      providers: [
        BlocProvider(
          create: (_) => ClientHomeCubit(
            repository: repository ?? _resolveRepository(devSeed),
            greetingNameProvider: greetingNameProvider ?? _resolveGreetingName,
            // Push-triggered refetch (sprint-009): re-pull on a status-change
            // push. Absent under bare tests / dev seams where DI isn't set up.
            //
            // b02 wave D: through the ONE shared resolver now, with topics. The
            // hand-rolled GetIt lookup here was the twelfth copy of that check
            // and the only one the wave-D topic filter would have missed —
            // which is exactly the "one call site silently keeps the old
            // behaviour" failure `resolvePushRefreshStream` exists to prevent.
            //
            // `{order, offers}`: this cubit paints In-Progress (order state),
            // Pending and Replies (the auction). It renders no chat row and no
            // jeeber feed, so a `chat` or `new_request` push no longer wakes it.
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.order, RefreshTopic.offers},
            ),
          ),
        ),
        // P0-X06: the personalized greeting (name + avatar) is sourced from the
        // real `GET /users/me` (the same getMe the Profile tab reads), so the
        // header shows "Hello, {name}" + the real avatar instead of the generic
        // "Welcome back" + "?" placeholder. Under the dev seam it is seeded with
        // the deterministic capture fixture; in release it refreshes from the
        // live profile (or stays generic when getMe is unreachable / nameless).
        BlocProvider(
          create: (_) => GreetingProfileCubit(
            repository: _resolveGreetingRepository(devSeed),
            seed: _greetingSeed(devSeed),
            // Profile-name lane: re-pull getMe when a display-name save
            // broadcasts a profile change (the IndexedStack keeps this tab
            // alive, so without the signal the greeting would stay stale).
            refreshSignals: _profileRefreshStream(),
          )..load(),
        ),
      ],
      child: Builder(
        builder: (innerContext) => PollingVisibilityGate(
          // b02 READ ECONOMICS. `isVisible` must AND every condition that makes
          // this surface watchable, and there are two:
          //
          //   * `TabVisibility` — this is the selected `IndexedStack` child;
          //   * `RouteVisibilityScope` — nothing is pushed on top of the shell.
          //
          // The second is the new one, and it is the expensive one. With
          // `/delivery/:id` on top of the shell this cubit was still answering
          // every `order`/`offers` push with a SEVEN-read snapshot, and still
          // ticking its 10 s poll, for a screen the user could not see. Both are
          // now deferred; the debt is paid once, on the way back.
          //
          // Both sources default to visible when absent (bare test, fixture
          // host), so this is inert outside the shell.
          isVisible:
              (TabVisibility.maybeOf(innerContext)?.isVisible ?? true) &&
              RouteVisibilityScope.isOnTop(innerContext),
          target: innerContext.read<ClientHomeCubit>(),
          child: ClientHomeScreen(
            key: const Key('home-tab-root'),
            // JEBV4-298 (E24/Q-086): the Requests tab is on-hold only, so it
            // opens on Pending Requests. The In-Progress live-tracking surface
            // now lives on the Delivery tab. The dev seam may still pin any tab
            // (including In-Progress) for a debug-only capture of that surface.
            initialTab: devTab ?? ClientHomeTab.pendingRequests,
            onCreateRequest: () => _openRequestType(context),
            onOpenRequest: (request) => _openChat(context, request),
            onTrack: (request) => _openTracking(context, request),
          ),
        ),
      ),
    );
  }

  /// Profile-changed broadcast (display-name saves) off GetIt when registered;
  /// `null` under bare tests / fixture hosts so the cubit simply never
  /// re-pulls. Mirrors the [PushRefreshSignals] wiring above.
  Stream<void>? _profileRefreshStream() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<ProfileRefreshSignals>()) return null;
    return getIt<ProfileRefreshSignals>().stream;
  }

  /// The live profile source for the greeting. In the dev-seam capture path we
  /// skip the network (the seed already carries the Figma name/avatar); in
  /// release we self-provide the Dio-backed getMe repo off GetIt — no DI edit,
  /// mirroring how [CustomerProfileScreen] resolves its repo. A bare test (no
  /// Dio registered) gets `null` → the greeting stays on its seed.
  CustomerProfileRepository? _resolveGreetingRepository(bool devSeed) {
    if (devSeed) return null;
    final getIt = GetIt.instance;
    if (getIt.isRegistered<CustomerProfileRepository>()) {
      return getIt<CustomerProfileRepository>();
    }
    if (getIt.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(getIt<Dio>());
    }
    return null;
  }

  /// Seeds the greeting with the deterministic Figma profile under the dev seam
  /// so a single capture APK renders "Hello, Sami" + the avatar without a live
  /// fetch; empty otherwise (the live getMe populates it in release).
  GreetingProfileState _greetingSeed(bool devSeed) {
    if (!devSeed) return const GreetingProfileState();
    return GreetingProfileState(
      name: DevCustomerProfileFixtures.sample.name,
      avatarUrl: DevCustomerProfileFixtures.sample.avatarUrl,
    );
  }

  /// Pulls the [DioClientHomeRepository] off GetIt when available so the
  /// home tab talks to the mock backend; in the dev-seam capture path it uses
  /// the deterministic fixtures so all three filter tabs render populated.
  ClientHomeRepository _resolveRepository(bool devSeed) {
    if (devSeed) {
      return InMemoryClientHomeRepository.fromSnapshot(
        DevClientHomeFixtures.snapshot(),
      );
    }
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ClientHomeRepository>()) {
      return getIt<ClientHomeRepository>();
    }
    return InMemoryClientHomeRepository();
  }

  /// Greets "Sami" (the Figma mock name) under the dev seam so captures match
  /// the design; `null` otherwise until the profile cubit is wired.
  String? _resolveGreetingName() => _devSeamTab() != null ? 'Sami' : null;

  /// The filter tab requested via the dev seam, or `null` when the seam isn't
  /// driving the home tab. Debug-only — always `null` in release builds.
  ClientHomeTab? _devSeamTab() {
    if (!kDebugMode) return null;
    final raw = DevSeam.current.homeTab;
    switch (raw) {
      case 'in_progress':
        return ClientHomeTab.inProgress;
      case 'pending':
        return ClientHomeTab.pendingRequests;
      case 'replies':
        return ClientHomeTab.replies;
      default:
        return null;
    }
  }

  /// Opens the delivery-create flow from the Requests header top plus
  /// (`orders_create_request_button`). Wiring this non-null
  /// callback is what makes the `IconButton.filled` render ENABLED (navy
  /// `colorScheme.primary` fill) instead of the disabled-gray state a null
  /// `onPressed` produces — see `client_home_greeting.dart` `_AddRequestButton`.
  /// Routes to the `request-type` screen (Figma 56535:2392), matching the
  /// production create-request intent. Identical in debug + release; the seam
  /// flows (13/14/15) only assert this button's visibility, never tap it.
  void _openRequestType(BuildContext context) {
    GoRouter.of(context).pushNamed('request-type');
  }

  /// Routes a card tap to `/chat/:id` (BUG-18 client side). Prefer the request
  /// id (== correlationKey) over [ClientHomeRequest.conversationId]: chat-detail
  /// resolves correlationKey-first, so a conversationId param guarantees one
  /// wasted 404 probe. Fall back to the conversationId only when no request id
  /// is available.
  void _openChat(BuildContext context, ClientHomeRequest request) {
    final target = request.id.isNotEmpty
        ? request.id
        : (request.conversationId ?? '');
    if (target.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('chat-detail', pathParameters: {'id': target});
  }

  /// Routes an in-progress card's "Track my order" CTA to the live-tracking
  /// screen (`/orders/:id/tracking`, route `live-tracking`). Distinct from
  /// [_openChat]: in-progress cards track the delivery, replies/pending cards
  /// open the conversation. The tracking screen defends its own empty/invalid
  /// state, so an empty id is a no-op here.
  void _openTracking(BuildContext context, ClientHomeRequest request) {
    if (request.trackingId.isEmpty) return;
    // S9 live-tracking fix: navigate with the SERVER delivery id
    // (`delivery-<offerId>`) so `GET /v1/delivery/<id>` resolves instead of
    // 404'ing on a request id. The router prefers `?deliveryId=` over `:id`;
    // we still set the path id (delivery id when known, else request id as a
    // best-effort fallback via [ClientHomeRequest.trackingId]).
    GoRouter.of(context).pushNamed(
      'live-tracking',
      pathParameters: {'id': request.trackingId},
      queryParameters: {
        if (request.deliveryId != null && request.deliveryId!.isNotEmpty)
          'deliveryId': request.deliveryId!,
      },
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
// Render tests: test/previews/shell/home_tab_preview_test.dart
// ===========================================================================
//
// [HomeTab] is the shell's client-role Requests tab: it owns the
// [ClientHomeCubit] + [GreetingProfileCubit] and hands [ClientHomeScreen] the
// four navigation callbacks. What these previews review is therefore the WHOLE
// tab composition — greeting header, filter chips and list body together — not
// any one of its parts. The sub-tabs already have their own previews
// (`PendingRequestsTab`, `RepliesTab`); the states below are the ones only the
// composed tab can show:
//
//  * the screen-level `loading` and `failed` layouts, which REPLACE the chip
//    row entirely (you cannot switch tabs while the cold load is failing) —
//    a different shape from the per-tab spinner/error the sub-tab previews show
//    inside a chip row that is still there;
//  * the one-shot "land where the content is" affordance, which is a property
//    of `ClientHomeScreen._resolveInitialTab` driven by the `initialTab` HomeTab
//    chooses, so it is unreachable from a sub-tab preview.
//
// **Seeding.** [HomeTab] exposes exactly the two seams these need —
// `repository` and `greetingNameProvider` — so no production edit was required.
// Each preview builds the real tab over a LOCAL fake [ClientHomeRepository]
// that answers from canned data, throws, or never answers. The tab's other two
// dependency lookups are already fail-safe and resolve to `null` with no DI
// graph mounted: `resolvePushRefreshStream` (no [PushRefreshSignals] registered)
// and `_resolveGreetingRepository` (no `CustomerProfileRepository`, no `Dio`).
// Nothing here can reach the network, which is the rule in
// `lib/core/previews/README.md` rather than something [jeebPreviewHost]'s guard
// should have to catch.
//
// **One canvas caveat.** The tab's own callbacks are wired (so the header "+"
// renders ENABLED navy rather than disabled-gray — the defect
// `test/features/shell/home_tab_create_request_fab_test.dart` locks), but the
// destinations underneath are `GoRouter.of(context)` calls made from inside
// `PendingRequestsTab` / `RepliesTab`. There is no router in a preview, so
// TAPPING a row or a CTA in the canvas throws. These previews are for reading
// states, not for driving navigation — that is
// `test/client_home_screen_test.dart`'s job.
//
// Fixture values (`ORD-234xx`, `1 kilo potato, water gallon, coffee blend`,
// `Hello, Layla`, the nine-offer reply row) are lifted from
// `test/client_home_screen_test.dart` and `DevClientHomeFixtures` so the canvas
// and the assertions describe the same rows.

/// A whole shell tab, so the canvas box is a phone body: 390 dp wide and tall
/// enough that the greeting, the chip row and the first cards are all visible
/// without scrolling. The ready layout is a `ListView`, so a shorter box would
/// scroll rather than overflow — it would hide states, not break them.
const Size _homeTabBox = Size(390, 780);

/// The two screen-level layouts that replace the body with a single centred
/// block. Shorter on purpose: at [_homeTabBox] height they are mostly empty
/// space, which makes the greeting-to-spinner relationship harder to read, not
/// easier.
const Size _homeTabStateBox = Size(390, 420);

/// The longest free-text title the gateway can hand this tab: a request with no
/// `displayId` falls back to the customer's own typed description, which is
/// unbounded. Duplicated verbatim in the render test so a preview quietly
/// rewired to a short title fails instead of silently losing the one state that
/// exercises the header's non-flexible tier badge.
const String _homeTabLongTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
    'drop everything at the clinic on Independence Street before it closes';

/// Answers one canned snapshot on the next microtask, so `load()` passes through
/// `loading` and lands on `ready`. No latency, no second read, no socket.
class _HomeTabSeededRepository implements ClientHomeRepository {
  const _HomeTabSeededRepository({
    this.pending = const <ClientHomeRequest>[],
    this.replies = const <ClientHomeRequest>[],
  });

  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(pending: pending, replies: replies);
}

/// Fails the COLD load — the only way to reach `ClientHomeStatus.failed`, since
/// [ClientHomeCubit] deliberately swallows a failed REFRESH while data is
/// already painted.
class _HomeTabFailingRepository implements ClientHomeRepository {
  const _HomeTabFailingRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw Exception('preview: home summary unreachable');
}

/// Never answers, so the tab stays in `ClientHomeStatus.loading` for as long as
/// the canvas is open. A [Completer] that is never completed holds no timer and
/// no subscription — it simply never settles.
class _HomeTabStalledRepository implements ClientHomeRepository {
  const _HomeTabStalledRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// The real tab over a fake repository. [greetingName] feeds the same
/// `greetingNameProvider` seam DI uses; `null` is the honest default (the live
/// `GET /users/me` has not resolved, or the account has no name on file).
Widget _homeTabHosted(
  ClientHomeRepository repository, {
  String? greetingName,
}) {
  return HomeTab(
    repository: repository,
    greetingNameProvider: () => greetingName,
  );
}

/// A pending row exactly as the gateway returns one: searching, no offers.
ClientHomeRequest _homeTabPendingRow({
  required String orderId,
  ClientRequestTier tier = ClientRequestTier.express,
}) => ClientHomeRequest(
  id: orderId.toLowerCase(),
  displayId: orderId,
  title: orderId,
  status: ClientRequestStatus.searching,
  destinationLabel: '1 kilo potato, water gallon, coffee blend',
  itemsSummary: '1 kilo potato, water gallon, coffee blend',
  tier: tier,
);

/// A replies row. The avatar URLs are EMPTY strings on purpose: [RepliesCard]
/// renders offerers through `OmdsProfileAvatar` → `CachedNetworkImage`, and a
/// real URL would have every preview reach for a CDN the canvas cannot see. An
/// empty one falls back to the initials placeholder, which is network-free and
/// the same geometry.
ClientHomeRequest _homeTabReplyRow({
  required String orderId,
  required int offerCount,
}) => ClientHomeRequest(
  id: orderId.toLowerCase(),
  displayId: orderId,
  title: orderId,
  status: ClientRequestStatus.offersReceived,
  destinationLabel: '1 kilo potato, water gallon, coffee blend',
  itemsSummary: '1 kilo potato, water gallon, coffee blend',
  tier: ClientRequestTier.express,
  offerCount: offerCount,
  offerAvatarUrls: const <String>['', '', ''],
  conversationId: 'conv-${orderId.toLowerCase()}',
);

/// The default landing: a named sender with two requests out for bids.
///
/// The composed shape the sub-tab previews cannot show — personalized greeting,
/// the ENABLED navy "+" (a null `onCreateRequest` renders it disabled-gray; see
/// `home_tab_create_request_fab_test.dart`), the `Pending Requests | Replies`
/// chip row, then the rows. Note what is NOT here: JEBV4-298 removed the
/// In-Progress chip from this tab, so two chips is the whole tab bar.
///
/// **Read the 200% rendering.** `_ClientHomeTabBar` (`client_home_screen.dart`)
/// is a bare `Row` of two `OmdsChip`s inside a 16 dp gutter — no `Wrap`, no
/// `Flexible`, no horizontal scroll — so at `textScaleFactor: 2.0` on a 390 dp
/// screen it overflows by 266 dp (278 dp under AR, whose chip labels are
/// longer). Every READY state below inherits that; only the loading and failed
/// layouts escape it, because they drop the chip row entirely.
@JeebPreview(group: 'shell', name: 'Pending · two requests', size: _homeTabBox)
Widget homeTabPending() => _homeTabHosted(
  _HomeTabSeededRepository(
    pending: <ClientHomeRequest>[
      _homeTabPendingRow(orderId: 'ORD-23470'),
      _homeTabPendingRow(orderId: 'ORD-23471', tier: ClientRequestTier.flash),
    ],
  ),
  greetingName: 'Layla',
);

/// Nothing pending and nothing replied — a brand-new account, and the state a
/// sender returns to after every order closes.
///
/// The tallest branch: a 200 dp illustration, the "What do you need?" prompt and
/// a full-width first-request CTA, all UNDER a greeting and a chip row that are
/// still there. Worth reading next to `Failed · cold load` below, which drops
/// the chip row entirely — the two are the same physical space used two
/// different ways.
@JeebPreview(group: 'shell', name: 'Empty · new account', size: _homeTabBox)
Widget homeTabEmpty() => _homeTabHosted(const _HomeTabSeededRepository());

/// Pending is empty but Replies is not, so the tab MOVES the selection.
///
/// `ClientHomeScreen._resolveInitialTab` is a one-shot "land where the content
/// is" affordance: it fires only because [HomeTab] hands it the DEFAULT
/// `initialTab` (pendingRequests), so it is unreachable from a sub-tab preview
/// and invisible in a static mock. The regression it guards is in
/// `test/client_home_screen_test.dart` — it must advance to Replies and never to
/// the relocated In-Progress surface. Read the chip row here: the selected chip
/// is `Replies`, not the one the tab was built with.
@JeebPreview(group: 'shell', name: 'Auto-advance to Replies', size: _homeTabBox)
Widget homeTabAdvancesToReplies() => _homeTabHosted(
  _HomeTabSeededRepository(
    replies: <ClientHomeRequest>[
      _homeTabReplyRow(orderId: 'ORD-23480', offerCount: 9),
    ],
  ),
  greetingName: 'Layla',
);

/// Cold load in flight: greeting, then a bare spinner.
///
/// The whole chip row is GONE — `_ClientHomeBody` swaps the ready layout out
/// wholesale — so this is not "the tab with a loading list", it is a different
/// screen. It also has no text beyond the greeting, which is the point at 200%:
/// every other state grows and this one does not move.
///
/// One detail this preview exists to make visible: the header says "Welcome
/// back", not "Hello, Layla", even though the name was passed in and the cubit
/// already emitted it. `_LoadingLayout` hardcodes `name: null` while
/// `_FailedLayout` two lines below passes `state.greetingName`.
@JeebPreview(group: 'shell', name: 'Loading · cold', size: _homeTabStateBox)
Widget homeTabLoading() =>
    _homeTabHosted(const _HomeTabStalledRepository(), greetingName: 'Layla');

/// Cold load failed: the full-tab connection error and its Retry CTA.
///
/// Only a COLD failure reaches here — a failed background refresh keeps the
/// previous rows painted, and a 429 is not an error at all (it backs the surface
/// off and keeps the data). Retry calls `ClientHomeCubit.load()`, so in the
/// canvas it puts the tab into the loading state above and stays there; the fake
/// has nothing else to say. Unlike the loading layout, this one DOES carry the
/// greeting name through.
@JeebPreview(group: 'shell', name: 'Failed · cold load', size: _homeTabStateBox)
Widget homeTabFailed() =>
    _homeTabHosted(const _HomeTabFailingRepository(), greetingName: 'Layla');

/// The layout ceiling, everything long at once.
///
/// A full name long enough to test the header's `Expanded` against the "+"
/// button, plus a request with NO order id — so the card header falls back to
/// the customer's own free-text title — and a full items list underneath.
///
/// The header itself survives all three renderings: `Expanded` + `Flexible` +
/// `maxLines: 1` ellipsis keeps the greeting off the "+" button, and the
/// greeting drops to the first name ("Hello, Abdulrahman"). What does NOT
/// survive at 200% is everything below it — the chip row overflows by 266 dp
/// and the card's own `pending-server-status` row by a further 201 dp. Neither
/// is caused by this fixture; a two-word title reproduces both.
@JeebPreview(group: 'shell', name: 'Longest content', size: _homeTabBox)
Widget homeTabLongContent() => _homeTabHosted(
  const _HomeTabSeededRepository(
    pending: <ClientHomeRequest>[
      ClientHomeRequest(
        id: 'pen-long',
        title: _homeTabLongTitle,
        status: ClientRequestStatus.searching,
        destinationLabel: 'Rue Gouraud, Gemmayzeh, Beirut',
        itemsSummary:
            'Two boxes of paracetamol, one bottle of cough syrup, a digital '
            'thermometer, four manoushe zaatar and a bag of vitamin C',
        tier: ClientRequestTier.flash,
      ),
    ],
  ),
  greetingName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
);
