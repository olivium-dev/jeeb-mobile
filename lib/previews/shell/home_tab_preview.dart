/// Widget previews for [HomeTab] — run with `flutter widget-preview start`.
///
/// [HomeTab] is the shell's client-role Requests tab: it owns the
/// [ClientHomeCubit] + [GreetingProfileCubit] and hands [ClientHomeScreen] the
/// four navigation callbacks. What these previews review is therefore the WHOLE
/// tab composition — greeting header, filter chips and list body together — not
/// any one of its parts. The sub-tabs already have their own previews
/// (`pending_requests_tab_preview.dart`, `replies_tab_preview.dart`); the states
/// below are the ones only the composed tab can show:
///
///  * the screen-level `loading` and `failed` layouts, which REPLACE the chip
///    row entirely (you cannot switch tabs while the cold load is failing) —
///    a different shape from the per-tab spinner/error the sub-tab previews show
///    inside a chip row that is still there;
///  * the one-shot "land where the content is" affordance, which is a property
///    of `ClientHomeScreen._resolveInitialTab` driven by the `initialTab` HomeTab
///    chooses, so it is unreachable from a sub-tab preview.
///
/// **Seeding.** [HomeTab] exposes exactly the two seams these need —
/// `repository` and `greetingNameProvider` — so no production edit was required.
/// Each preview builds the real tab over a LOCAL fake [ClientHomeRepository]
/// that answers from canned data, throws, or never answers. The tab's other two
/// dependency lookups are already fail-safe and resolve to `null` with no DI
/// graph mounted: `resolvePushRefreshStream` (no [PushRefreshSignals] registered)
/// and `_resolveGreetingRepository` (no `CustomerProfileRepository`, no `Dio`).
/// Nothing here can reach the network, which is the rule in
/// `lib/previews/README.md` rather than something [jeebPreviewHost]'s guard
/// should have to catch.
///
/// **One canvas caveat.** The tab's own callbacks are wired (so the header "+"
/// renders ENABLED navy rather than disabled-gray — the defect
/// `test/features/shell/home_tab_create_request_fab_test.dart` locks), but the
/// destinations underneath are `GoRouter.of(context)` calls made from inside
/// `PendingRequestsTab` / `RepliesTab`. There is no router in a preview, so
/// TAPPING a row or a CTA in the canvas throws. These previews are for reading
/// states, not for driving navigation — that is
/// `test/client_home_screen_test.dart`'s job.
///
/// Fixture values (`ORD-234xx`, `1 kilo potato, water gallon, coffee blend`,
/// `Hello, Layla`, the nine-offer reply row) are lifted from
/// `test/client_home_screen_test.dart` and `DevClientHomeFixtures` so the canvas
/// and the assertions describe the same rows.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/home_client/domain/client_home_repository.dart';
import '../../features/home_client/domain/client_home_request.dart';
import '../../features/shell/tabs/home_tab.dart';
import '../harness/jeeb_preview.dart';

/// A whole shell tab, so the canvas box is a phone body: 390 dp wide and tall
/// enough that the greeting, the chip row and the first cards are all visible
/// without scrolling. The ready layout is a `ListView`, so a shorter box would
/// scroll rather than overflow — it would hide states, not break them.
const Size _tabBox = Size(390, 780);

/// The two screen-level layouts that replace the body with a single centred
/// block. Shorter on purpose: at [_tabBox] height they are mostly empty space,
/// which makes the greeting-to-spinner relationship harder to read, not easier.
const Size _stateBox = Size(390, 420);

/// The longest free-text title the gateway can hand this tab: a request with no
/// `displayId` falls back to the customer's own typed description, which is
/// unbounded. Duplicated verbatim in the render test so a preview quietly
/// rewired to a short title fails instead of silently losing the one state that
/// exercises the header's non-flexible tier badge.
const String kHomeTabLongTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
    'drop everything at the clinic on Independence Street before it closes';

/// Answers one canned snapshot on the next microtask, so `load()` passes through
/// `loading` and lands on `ready`. No latency, no second read, no socket.
class _SeededHomeRepository implements ClientHomeRepository {
  const _SeededHomeRepository({
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
class _FailingHomeRepository implements ClientHomeRepository {
  const _FailingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw Exception('preview: home summary unreachable');
}

/// Never answers, so the tab stays in `ClientHomeStatus.loading` for as long as
/// the canvas is open. A [Completer] that is never completed holds no timer and
/// no subscription — it simply never settles.
class _StalledHomeRepository implements ClientHomeRepository {
  const _StalledHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// The real tab over a fake repository. [greetingName] feeds the same
/// `greetingNameProvider` seam DI uses; `null` is the honest default (the live
/// `GET /users/me` has not resolved, or the account has no name on file).
Widget _hosted(ClientHomeRepository repository, {String? greetingName}) {
  return HomeTab(
    repository: repository,
    greetingNameProvider: () => greetingName,
  );
}

/// A pending row exactly as the gateway returns one: searching, no offers.
ClientHomeRequest _pending({
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
ClientHomeRequest _reply({required String orderId, required int offerCount}) =>
    ClientHomeRequest(
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
@JeebPreview(group: 'shell', name: 'Pending · two requests', size: _tabBox)
Widget homeTabPending() => _hosted(
  _SeededHomeRepository(
    pending: <ClientHomeRequest>[
      _pending(orderId: 'ORD-23470'),
      _pending(orderId: 'ORD-23471', tier: ClientRequestTier.flash),
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
@JeebPreview(group: 'shell', name: 'Empty · new account', size: _tabBox)
Widget homeTabEmpty() => _hosted(const _SeededHomeRepository());

/// Pending is empty but Replies is not, so the tab MOVES the selection.
///
/// `ClientHomeScreen._resolveInitialTab` is a one-shot "land where the content
/// is" affordance: it fires only because [HomeTab] hands it the DEFAULT
/// `initialTab` (pendingRequests), so it is unreachable from a sub-tab preview
/// and invisible in a static mock. The regression it guards is in
/// `test/client_home_screen_test.dart` — it must advance to Replies and never to
/// the relocated In-Progress surface. Read the chip row here: the selected chip
/// is `Replies`, not the one the tab was built with.
@JeebPreview(group: 'shell', name: 'Auto-advance to Replies', size: _tabBox)
Widget homeTabAdvancesToReplies() => _hosted(
  _SeededHomeRepository(
    replies: <ClientHomeRequest>[_reply(orderId: 'ORD-23480', offerCount: 9)],
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
@JeebPreview(group: 'shell', name: 'Loading · cold', size: _stateBox)
Widget homeTabLoading() =>
    _hosted(const _StalledHomeRepository(), greetingName: 'Layla');

/// Cold load failed: the full-tab connection error and its Retry CTA.
///
/// Only a COLD failure reaches here — a failed background refresh keeps the
/// previous rows painted, and a 429 is not an error at all (it backs the surface
/// off and keeps the data). Retry calls `ClientHomeCubit.load()`, so in the
/// canvas it puts the tab into the loading state above and stays there; the fake
/// has nothing else to say. Unlike the loading layout, this one DOES carry the
/// greeting name through.
@JeebPreview(group: 'shell', name: 'Failed · cold load', size: _stateBox)
Widget homeTabFailed() =>
    _hosted(const _FailingHomeRepository(), greetingName: 'Layla');

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
@JeebPreview(group: 'shell', name: 'Longest content', size: _tabBox)
Widget homeTabLongContent() => _hosted(
  const _SeededHomeRepository(
    pending: <ClientHomeRequest>[
      ClientHomeRequest(
        id: 'pen-long',
        title: kHomeTabLongTitle,
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
