/// Widget previews for [RepliesCard] — run with `flutter widget-preview start`.
///
/// The card is a pure function of one [ClientHomeRequest] plus two
/// [VoidCallback]s: no cubit, no repository, no clock. Every state below is a
/// plain value object and two empty closures, which makes these previews
/// network-free by construction rather than by the guard in [jeebPreviewHost].
///
/// Two deliberate fixture choices:
///
///  * **Empty avatar URLs.** `_OfferAvatar` renders through
///    `OmdsProfileAvatar`, which short-circuits to its initials placeholder when
///    `profilePicUrl` is null or empty and only constructs a network image
///    otherwise. An empty string keeps the canvas off the CDN and — because the
///    placeholder is laid out at the same `Sizes.large` box — preserves the
///    exact geometry this card's layout risk lives in: the overlap ramp and the
///    "+N" cluster, not the image bytes.
///  * **No-op callbacks.** The tab supplies the real navigation
///    (`replies_check_offers_cta` → JM-028, `replies_accept_cta` → JM-029);
///    under the preview host there is no `GoRouter` and no `GetIt`, so a tap
///    must do nothing rather than throw. What these previews review is the CTA
///    ROW's layout — the navigation contract is
///    `test/features/home_client/replies_tab_test.dart`'s job.
///
/// Fixture values (`ORD-234xx`, `Hamra, Beirut`, five/nine offers, three
/// avatars) are lifted from `test/features/home_client/replies_tab_test.dart`
/// so the canvas and the widget test describe the same rows.
///
/// The states that matter are the ones where a *derived* value moves: the
/// header is `displayId ?? title`, the subtitle is
/// [ClientHomeRequest.summaryLine] (which suppresses an echo of the header),
/// and the offer cluster is three different shapes depending on how
/// `offerCount` compares to the number of avatar URLs — including two shapes
/// that render nothing at all.
library;

import 'package:flutter/material.dart';

import '../../features/home_client/domain/client_home_request.dart';
import '../../features/home_client/presentation/widgets/replies_card.dart';
import '../harness/jeeb_preview.dart';

/// One reply row: header + one-line summary + the CTA row + divider. Phone
/// width, because `_RepliesActions` is `MainAxisAlignment.end` with no wrap —
/// it only overflows when the box is as narrow as a real phone.
const Size repliesCardBox = Size(390, 200);

/// The same box with headroom for the `maxLines: 2` summary the long-content
/// state actually fills.
const Size repliesCardTallBox = Size(390, 230);

/// A Replies row in the shape `GET /v1/requests?status=offers-received`
/// delivers it: offers are in, no jeeber assigned yet, no ETA, no progress.
///
/// [avatarCount] drives how many overlapping circles render; the "+N" cluster
/// shows `offerCount - avatarCount` (clamped by `_maxInline` = 3).
ClientHomeRequest _reply({
  required String id,
  String? displayId,
  String? title,
  required int offerCount,
  int avatarCount = 3,
  String destinationLabel = 'Hamra, Beirut',
  String? itemsSummary,
  ClientRequestTier tier = ClientRequestTier.express,
}) =>
    ClientHomeRequest(
      id: id,
      displayId: displayId,
      title: title ?? displayId ?? id,
      status: ClientRequestStatus.offersReceived,
      destinationLabel: destinationLabel,
      itemsSummary: itemsSummary,
      tier: tier,
      offerCount: offerCount,
      // Empty strings on purpose — see the library doc: the avatar resolves to
      // its initials placeholder instead of reaching for a CDN.
      offerAvatarUrls: List<String>.filled(avatarCount, ''),
      conversationId: 'conv-$id',
    );

Widget _hosted(ClientHomeRequest request) => RepliesCard(
      request: request,
      onCheckOffers: () {},
      onAccept: () {},
    );

/// The Figma reference row (`+6 offers`): nine offers, three inline avatars.
///
/// Three things have to survive together on one line — an ellipsizing order id
/// in an [Expanded], the overlap ramp, and the `+6` counter at its intrinsic
/// width. This is the state to read the AR RTL rendering of: the stack is built
/// from `PositionedDirectional`, so if the overlap ever stops mirroring, it
/// stops here first.
///
/// Note what is NOT on this row. The fixture is `ClientRequestTier.flash`, and
/// the card's own class doc promises "title + tier badge" — but
/// `_RepliesHeader` renders no badge of any kind, so Flash, Express and
/// Standard replies are pixel-identical here while the sibling
/// `PendingRequestCard` distinguishes them.
@JeebPreview(group: 'home_client', name: 'Nine offers · +6', size: repliesCardBox)
Widget repliesCardWithOverflowCount() => _hosted(
      _reply(
        id: 'rep-1',
        displayId: 'ORD-23470',
        offerCount: 9,
        tier: ClientRequestTier.flash,
      ),
    );

/// One offer, one avatar: `extra == 0`, so the "+N" counter is hidden entirely
/// and the header is an order id next to a single circle.
///
/// The boundary the counter is gated on — `if (extra > 0)` — is what keeps this
/// row from reading "+0". It is also the first row a sender sees the moment
/// bidding opens, so it is the most common shape of this card, not an edge.
@JeebPreview(group: 'home_client', name: 'Single offer · no counter', size: repliesCardBox)
Widget repliesCardSingleOffer() => _hosted(
      _reply(
        id: 'rep-2',
        displayId: 'ORD-23471',
        offerCount: 1,
        avatarCount: 1,
      ),
    );

/// Offers counted but no avatar URLs — the shape the gateway sends when every
/// offerer is a jeeber with no profile picture on file.
///
/// `inline` is empty, so `_OverlappingAvatars` lays out a zero-width box and
/// the cluster degrades to a bare `+4` floating at the end of the header, with
/// nothing to anchor it. Worth looking at next to `Nine offers · +6`: the same
/// widget, a very different-looking header.
@JeebPreview(group: 'home_client', name: 'Counted, no avatars', size: repliesCardBox)
Widget repliesCardCountWithoutAvatars() => _hosted(
      _reply(
        id: 'rep-3',
        displayId: 'ORD-23472',
        offerCount: 4,
        avatarCount: 0,
      ),
    );

/// Zero offers — the whole cluster collapses to `SizedBox.shrink()`.
///
/// A Replies row can only exist because offers came in, so this should be
/// unreachable; it is reachable anyway whenever the list row omits
/// `offerCount` (the field defaults to `0`) or an offer is withdrawn between
/// the list read and the render. What survives is a card with no offer
/// evidence at all still showing **Accept** and **Check Offers** — two CTAs
/// pointing at an empty offer list. The card has no empty branch of its own,
/// so this is what that looks like.
@JeebPreview(group: 'home_client', name: 'Zero offers · CTAs still shown', size: repliesCardBox)
Widget repliesCardZeroOffers() => _hosted(
      _reply(
        id: 'rep-4',
        displayId: 'ORD-23473',
        offerCount: 0,
        avatarCount: 0,
      ),
    );

/// No `displayId` on the row — the header falls back to [title].
///
/// Also the G1 echo guard, made visible: `itemsSummary` here is byte-identical
/// to the header (the customer's own "What do you need?" text became both), so
/// [ClientHomeRequest.summaryLine] must drop to the destination instead of
/// printing the same sentence twice. If this preview ever shows "Pharmacy run
/// for Mom" on both lines, that guard has regressed.
@JeebPreview(group: 'home_client', name: 'No display id · echo guard', size: repliesCardBox)
Widget repliesCardTitleFallback() => _hosted(
      _reply(
        id: 'rep-5',
        title: 'Pharmacy run for Mom',
        itemsSummary: 'Pharmacy run for Mom',
        destinationLabel: 'Mar Mikhael, Beirut',
        offerCount: 5,
      ),
    );

/// Layout ceiling: the longest row the gateway can actually produce.
///
/// A redelivery order id well past the width of the header, a three-digit
/// counter (`+117`, a broadcast that went wide), and a `summaryLine` built from
/// the customer's own free-text description — that field is `maxLines: 2`, so
/// this is where the two-line clamp is either enough or visibly not.
///
/// The 200% rendering of this preview is the one that matters: `Accept` and
/// `Check Offers` are `IntrinsicWidth` pills inside an end-aligned [Row] with
/// no `Wrap`, `Flexible` or `FittedBox` anywhere, so their combined width
/// scales with the text scale while the 390 dp card does not.
@JeebPreview(group: 'home_client', name: 'Long content · +117', size: repliesCardTallBox)
Widget repliesCardLongContent() => _hosted(
      _reply(
        id: 'rep-6',
        displayId: 'ORD-23474-EXPRESS-REDELIVERY-ATTEMPT-3',
        offerCount: 120,
        itemsSummary: '1 kilo potato, water gallon, coffee blend, two boxes '
            'of paracetamol, a phone charger and whatever else is still open '
            'at this hour near the pharmacy',
        destinationLabel: 'Rue Gouraud, Gemmayzeh, Beirut',
      ),
    );
