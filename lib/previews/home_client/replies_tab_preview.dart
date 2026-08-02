/// Widget previews for [RepliesTab] — run with `flutter widget-preview start`.
///
/// [RepliesTab] is a pure projection of [ClientHomeState]: it branches on
/// `status` (failed → error, loading → spinner) and then on `replies.isEmpty`,
/// so all four of its visual branches are reachable by seeding the cubit and
/// nothing else. There is no seam to seed the cubit directly — [ClientHomeCubit]
/// takes a repository, not a state — so each preview builds the cubit over a
/// LOCAL fake repository declared below and calls `load()`. The three fakes
/// (`_SeededHomeRepository`, `_FailingHomeRepository`, `_StalledHomeRepository`)
/// return canned data, throw, or never complete respectively; none of them can
/// reach the network, which is the rule in `lib/previews/README.md` rather than
/// something [jeebPreviewHost]'s guard should have to catch.
///
/// Two deliberate deviations from how production drives this tab, both so the
/// canvas stays honest:
///
///  * **Explicit no-op callbacks.** `const RepliesTab()` in
///    `client_home_screen.dart` passes none, so both CTAs fall through to the
///    widget's own defaults — `GoRouter.of(context)` and
///    `GetIt.instance<OffersRepository>()`. Neither exists under the preview
///    host, so a tap in the canvas would throw instead of showing a state. The
///    previews inject empty handlers; what they review is the CTA ROW's layout,
///    not its navigation (that is `test/features/home_client/replies_tab_test.dart`'s job).
///  * **Empty avatar URLs.** [RepliesCard] renders offerer avatars through
///    `OmdsProfileAvatar` → `CachedNetworkImage`. With a URL, every preview
///    would try to fetch from a CDN the canvas cannot reach and settle on the
///    error glyph; with an empty one the avatar falls back to its initials
///    placeholder, which is both network-free and the same geometry — the
///    overlap ramp and the "+N" cluster are what this card's layout risk lives
///    in, not the image bytes.
///
/// Fixture values (`ORD-234xx`, `Hamra, Beirut`, five/nine offers, three
/// avatars) are lifted from `test/features/home_client/replies_tab_test.dart`
/// so the canvas and the widget test describe the same rows.
///
/// One state is deliberately absent: `ClientHomeStatus.initial`. Before
/// `load()` runs, `_RepliesContent` falls through to `replies.isEmpty` and
/// paints the SAME empty state as a finished load that found nothing — so
/// "we have not asked yet" and "there are no replies" are pixel-identical.
/// That is a widget-level finding, not a missing preview: `Empty` below already
/// shows exactly what the pre-load frame looks like.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/home_client/application/client_home_cubit.dart';
import '../../features/home_client/domain/client_home_repository.dart';
import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/tabs/replies_tab.dart';
import '../harness/jeeb_preview.dart';

/// One reply row: header + two-line summary + the CTA row + divider. Phone
/// width, because the CTA row is `MainAxisAlignment.end` and only overflows
/// when the box is as narrow as a real phone.
const Size repliesTabCardBox = Size(390, 200);

/// The full-tab states (empty / error / loading) centre an icon + copy block,
/// so they need the height a tab body actually gets.
const Size repliesTabStateBox = Size(390, 340);

/// Three stacked rows. `_RepliesList` is a bare [Column] with no scrollable of
/// its own — in production it is a child of the home `ListView`, so it may be
/// any height. The canvas has to supply that height itself.
const Size repliesTabListBox = Size(390, 620);

/// Canned snapshot, delivered on the next microtask. The cubit's `load()`
/// therefore passes through `loading` and lands on `ready`.
class _SeededHomeRepository implements ClientHomeRepository {
  const _SeededHomeRepository(this.replies);

  final List<ClientHomeRequest> replies;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(replies: replies);
}

/// A cold load that throws. `ClientHomeCubit._fetch` swallows the error and
/// emits `failed` only because nothing is cached yet — which is precisely the
/// condition this tab's error state is for.
class _FailingHomeRepository implements ClientHomeRepository {
  const _FailingHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw Exception('preview: home snapshot unreachable');
}

/// A read that never resolves, so the cubit stays on `loading` for as long as
/// the canvas is open. A `Completer` that is never completed holds no timer and
/// no subscription — it simply never settles.
class _StalledHomeRepository implements ClientHomeRepository {
  const _StalledHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

Widget _hosted(ClientHomeRepository repository) {
  return BlocProvider<ClientHomeCubit>(
    create: (_) => ClientHomeCubit(
      repository: repository,
      // The Replies tab never reads the greeting; `null` keeps the fake
      // narrower than the state it feeds.
      greetingNameProvider: () => null,
    )..load(),
    child: RepliesTab(onCheckOffers: (_) {}, onAccept: (_) {}),
  );
}

/// A replies row. [avatarCount] drives how many overlapping circles render;
/// `offerCount - avatarCount` is what the "+N" cluster shows.
ClientHomeRequest _reply({
  required String displayId,
  required int offerCount,
  int avatarCount = 3,
  String destination = 'Hamra, Beirut',
  String? itemsSummary,
}) {
  return ClientHomeRequest(
    id: displayId.toLowerCase(),
    displayId: displayId,
    title: displayId,
    status: ClientRequestStatus.offersReceived,
    destinationLabel: destination,
    itemsSummary: itemsSummary,
    tier: ClientRequestTier.express,
    offerCount: offerCount,
    // Empty strings on purpose — see the library doc: the avatar resolves to
    // its initials placeholder instead of reaching for a CDN.
    offerAvatarUrls: List<String>.filled(avatarCount, ''),
    conversationId: 'conv-${displayId.toLowerCase()}',
  );
}

/// The Figma reference row (`+6 offers`): nine offers, three inline avatars.
///
/// Three things have to survive together on one line here — an ellipsizing
/// order id, the overlap ramp, and the `+6` counter — and the header [Row]
/// gives the id an `Expanded` while the stack takes its intrinsic width. This
/// is the state to read the AR RTL rendering of: the stack is built from
/// `PositionedDirectional`, so if the overlap ever stops mirroring, it stops
/// here first.
@JeebPreview(name: 'Nine offers · +6', size: repliesTabCardBox)
Widget repliesTabWithOverflowCount() => _hosted(
      _SeededHomeRepository(<ClientHomeRequest>[
        _reply(displayId: 'ORD-23470', offerCount: 9),
      ]),
    );

/// Layout ceiling: the longest row the gateway can actually produce.
///
/// A redelivery order id long past the width of the header, a three-digit offer
/// count (`+117`, a broadcast that went wide), and a `summaryLine` built from
/// the customer's own free-text description — the field is `maxLines: 2`, so
/// this is where the two-line clamp is either enough or visibly not.
///
/// The 200% rendering of this preview is the one that matters: `Accept` and
/// `Check Offers` are `IntrinsicWidth` pills in an end-aligned [Row] with no
/// `Wrap`, `Flexible` or `FittedBox` anywhere, so their combined width scales
/// with the text scale while the 390 dp box does not.
@JeebPreview(name: 'Long content · +117', size: repliesTabCardBox)
Widget repliesTabLongContent() => _hosted(
      _SeededHomeRepository(<ClientHomeRequest>[
        _reply(
          displayId: 'ORD-23470-EXPRESS-REDELIVERY-ATTEMPT-3',
          offerCount: 120,
          itemsSummary: '1 kilo potato, water gallon, coffee blend, two boxes '
              'of paracetamol, a phone charger and whatever else is still open '
              'at this hour near the pharmacy',
          destination: 'Rue Gouraud, Gemmayzeh, Beirut',
        ),
      ]),
    );

/// Three rows at once, spanning all three shapes of the offer cluster: one
/// offer (no `+N` badge at all — `extra == 0` hides it), five offers (`+2`) and
/// nine (`+6`).
///
/// The list is the state that shows what `_RepliesList` is: a [Column], not a
/// [ListView]. It cannot scroll and it does not lazily build, so its height is
/// entirely the host's problem — fine under the home `ListView`, and the reason
/// this preview needs a 620 dp box while every other one fits in 200.
@JeebPreview(name: 'Three replies', size: repliesTabListBox)
Widget repliesTabMultipleReplies() => _hosted(
      _SeededHomeRepository(<ClientHomeRequest>[
        _reply(displayId: 'ORD-23471', offerCount: 1, avatarCount: 1),
        _reply(displayId: 'ORD-23472', offerCount: 5),
        _reply(displayId: 'ORD-23473', offerCount: 9),
      ]),
    );

/// No replies yet — the state a sender sees between submitting a request and
/// the first Jeeber bidding, which is most of the time they spend on this tab.
///
/// Note the title: the tab reuses `homeEmptyTitle` ("What do you need?"), the
/// NEW-ORDER prompt, over a subtitle that explains there are no replies. It
/// reads as a call to action on a tab that has no action, and it is identical
/// to the frame rendered before `load()` has returned.
@JeebPreview(name: 'Empty', size: repliesTabStateBox)
Widget repliesTabEmpty() =>
    _hosted(const _SeededHomeRepository(<ClientHomeRequest>[]));

/// Cold load failed: no cached snapshot, so the whole tab is replaced by the
/// error block and its Retry button.
///
/// Worth reviewing next to `Empty` — both are icon + title + copy centred in
/// the tab, and at a glance the only difference is the icon and the ink colour,
/// so the error has to carry its meaning in the copy alone.
@JeebPreview(name: 'Load failed', size: repliesTabStateBox)
Widget repliesTabFailed() => _hosted(const _FailingHomeRepository());

/// The read is in flight and nothing is cached.
///
/// This is a spinner with no text of any kind — no skeleton row, no "loading
/// your replies". It is the only state of the four that tells a screen-reader
/// user nothing at all, and on a slow connection it is what fills the tab.
@JeebPreview(name: 'Loading', size: repliesTabStateBox)
Widget repliesTabLoading() => _hosted(const _StalledHomeRepository());
