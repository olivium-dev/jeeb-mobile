/// Widget previews for [JeeberFeedCard] — run with
/// `flutter widget-preview start`.
///
/// [JeeberFeedCard] is a pure function of ONE argument — the [DeliveryRequest]
/// it is handed — plus two display flags ([JeeberFeedCard.isExpired],
/// [JeeberFeedCard.exposeMakeOfferId]) and four callbacks. It reads no cubit and
/// owns no state, so every preview below is just a hand-built request record.
/// Nothing here can touch the network: no repository is constructed, and the
/// only URL in the file is an avatar the guard in [jeebPreviewHost] would refuse
/// to mutate anyway.
///
/// What counts as a "state" here is therefore **which fields the gateway
/// actually supplied** (identity, rating, tier and distance are all nullable on
/// the wire) crossed with the card's lifecycle bucket
/// ([DeliveryRequest.feedStatus] + the G3 expiry flag). Those two axes decide
/// the whole layout: the identity block collapses without a rating, the footer
/// changes shape without a tier, and the action area swaps between a two-button
/// row, an italic status word and a single pill.
///
/// The fixture values are the ones `test/jeeber_feed_card_test.dart` already
/// uses (`Sami Fawaz`, the potato/water/coffee summary, 3 km, Flash) so a
/// reviewer comparing the canvas against the test suite sees the same card.
///
/// ## Read the AR RTL rendering first
///
/// This card is **narrower than its own content in Arabic**. `_IncomingActions`
/// is a `Row(mainAxisSize: min)` holding Ignore + Offer, and that Row does not
/// wrap; the Arabic labels ("تجاهل" / "تقديم عرض") are wider than the English
/// ones, so on the 266 pt content column of a 390 pt phone the row overflows by
/// 2 pt — and on a **360 pt phone (the Galaxy S22 this project tests on) by
/// 32 pt, at DEFAULT text size**. English is clean at 360 and 390 and overflows
/// by 31 pt at 320. The `EN 200% text` rendering of the matrix is worse again:
/// 115 pt (EN) / 198 pt (AR) at 390. Every incoming-state preview below shows
/// it; `jeeber_feed_card_preview_test.dart` pins the numbers.
///
/// ## Two more things the canvas shows that the test suite does not
///
/// * **The footer is two stacked rows, not one.** `_CardFooter` is a [Wrap] with
///   `WrapAlignment.spaceBetween`, which reads as "tier chip at the start,
///   action at the end" — but the tier chip child measures the FULL content
///   width (266 of 266 at 390 pt), so it takes a run to itself and the action
///   area always lands on a second run underneath, with the chip's visible pill
///   centred rather than start-aligned. Figma 56560:1523 draws one row.
/// * **The accepted-action pill is not content-hugging on a phone.** The
///   [IntrinsicWidth] in `_AcceptedAction` clamps to the incoming constraint, and
///   "Heading to drop off" has an intrinsic width of ~268 pt — wider than the
///   266 pt column at 390 pt and the 236 pt column at 360 pt. The pill therefore
///   renders gutter-to-gutter, which is exactly what that `IntrinsicWidth` is
///   commented as preventing. It hugs only on the 800 pt surface
///   `test/jeeber_feed_card_test.dart` measures it on, and only with the shorter
///   "Order picked" label.
///
/// Genuinely clean, recorded so nobody re-checks it: directionality. Every inset
/// is symmetric or `EdgeInsetsDirectional`, so AR mirrors the avatar (310→358
/// instead of 32→80) and the whole content column with no hand-written
/// direction logic. The timestamp is also honest — [_receivedAtUtc] is a UTC
/// instant, as the gateway sends, and the card converts to device-local before
/// formatting (SW-03), so the canvas shows your wall clock rather than "09:41".
library;

import 'package:flutter/material.dart';

import '../../features/jeeber_request_feed/data/request_feed_models.dart';
import '../../features/jeeber_request_feed/presentation/jeeber_feed_card.dart';
import '../harness/jeeb_preview.dart';

/// A phone-width feed row.
///
/// 380 pt of height for a card that is 204–280 pt tall at default text size is
/// deliberate: the `EN 200% text` rendering of the same states is 284–360 pt,
/// and the thing worth seeing at 200% is the footer — clipping the box to the
/// default-size card would cut off the exact row that breaks.
const Size _cardBox = Size(390, 380);

/// The Galaxy S22 width — the device this project runs its final on-device
/// check on, and the narrowest mainstream Android. 30 pt narrower than
/// [_cardBox] is the difference between a 2 pt Arabic overflow and a 32 pt one.
const Size _narrowBox = Size(360, 380);

/// The instant the gateway reports, as a UTC instant — see the SW-03 note in
/// the library comment. A constant so the canvas never re-renders on a tick.
final DateTime _receivedAtUtc = DateTime.utc(2026, 6, 11, 9, 41);

/// Far enough out that nothing here expires by accident; the G3 state is driven
/// by the explicit flag, not by the clock.
final DateTime _expiresAt = DateTime.utc(2030);

/// The avatar the dev-seam feed host passes today.
const String _avatarUrl = 'https://i.pravatar.cc/150?img=12';

/// One feed row, framed the way the production list frames it.
///
/// The card's content column is `MainAxisSize.max`, so under the bounded height
/// of a preview box it would stretch and drag its border to the bottom of the
/// canvas. Production mounts it in a `ListView.builder` — an unbounded main-axis
/// constraint — and this shrink-wrapping [Column] reproduces exactly that, so
/// the previewed card is the height a jeeber actually sees.
///
/// All four callbacks are supplied because the real host
/// (`jeeber_feed_tab_view.dart`) supplies all four; a null `onTap` would also
/// silently drop the card's `button: true` semantics.
Widget _hosted(
  DeliveryRequest request, {
  bool isExpired = false,
  bool exposeMakeOfferId = false,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      JeeberFeedCard(
        request: request,
        isExpired: isExpired,
        exposeMakeOfferId: exposeMakeOfferId,
        onTap: () {},
        onIgnore: () {},
        onOffer: () {},
        onAdvanceStatus: () {},
      ),
    ],
  );
}

/// One request record. Defaults match the happy path in
/// `test/jeeber_feed_card_test.dart`; each preview overrides only the fields
/// that define its state.
DeliveryRequest _request({
  required String id,
  JeeberFeedItemStatus status = JeeberFeedItemStatus.incoming,
  JeeberDeliveryAction? action,
  String? senderName = 'Sami Fawaz',
  String? senderAvatarUrl = _avatarUrl,
  double? senderRating = 4,
  JeeberRequestTier? tier = JeeberRequestTier.flash,
  String? itemsSummary = '1 kilo potato, water gallon, coffee blend',
  double? distanceFromYouKm = 3,
}) {
  return DeliveryRequest(
    id: id,
    pickup: const RequestLocation(label: 'Hamra', latitude: 0, longitude: 0),
    dropoff: const RequestLocation(label: 'Verdun', latitude: 0, longitude: 0),
    tier: tier,
    estimatedDistanceKm: 3,
    potentialEarnings: 4,
    currency: 'USD',
    expiresAt: _expiresAt,
    senderName: senderName,
    senderAvatarUrl: senderAvatarUrl,
    senderRating: senderRating,
    itemsSummary: itemsSummary,
    distanceFromYouKm: distanceFromYouKm,
    receivedAt: _receivedAtUtc,
    feedStatus: status,
    nextDeliveryAction: action,
  );
}

/// The happy path: a fresh request carrying everything the gateway can send.
///
/// Screen 24 — name, avatar, star rating, description, distance, tier chip and
/// the Ignore / Offer pair. This is the densest the card ever gets at default
/// text size and the baseline every other state should be read against.
///
/// It is also the state that breaks first. Compare the three renderings: EN
/// light fits, `AR RTL dark` overflows the action row by 2 pt at this width, and
/// `EN 200% text` overflows it by 115 pt.
///
/// `exposeMakeOfferId` is true because the feed sets it on the FIRST incoming
/// card (JM-048); it adds a wrapping Semantics node and no pixels, so this
/// preview doubles as the check that it stays invisible.
@JeebPreview(name: 'Incoming · full metadata', size: _cardBox)
Widget jeeberFeedCardIncoming() =>
    _hosted(_request(id: 'req-1'), exposeMakeOfferId: true);

/// The gateway told us almost nothing: no name, no avatar, no rating, no tier.
///
/// This is the closest thing this card has to an empty state, and every one of
/// those omissions is a supported wire shape. Three fallbacks have to hold at
/// once:
///
/// * the name degrades to the localized "Customer", never a blank line;
/// * the avatar shows that word's initial ("C"), never the "?" glyph;
/// * the rating cluster disappears entirely rather than rendering zero stars —
///   an unrated client must not look like a one-star client.
///
/// A fabricated "Standard" chip would be worse than no chip: the jeeber prices
/// off the tier. Dropping it is also the only configuration in which the footer
/// is a single row, because the tier chip is what forces the second one.
@JeebPreview(name: 'Identity + tier omitted', size: _cardBox)
Widget jeeberFeedCardAnonymous() => _hosted(
      _request(
        id: 'req-anon',
        senderName: null,
        senderAvatarUrl: null,
        senderRating: null,
        tier: null,
        itemsSummary: 'Envelope from the notary on Bliss Street',
        distanceFromYouKm: 0.4,
      ),
    );

/// Screen 25: the jeeber has offered and is waiting on the client.
///
/// The whole action row collapses to one italic word, which makes this the only
/// state that cannot overflow — and the one where the card is doing the least to
/// explain itself. Worth a look in the canvas because "Pending" is a *status*,
/// not a button, and it is painted in `onSecondaryContainer` on a
/// `surfaceContainerLow` card: a foreground/background pair that is not defined
/// against each other in either theme.
@JeebPreview(name: 'Offer pending', size: _cardBox)
Widget jeeberFeedCardPending() => _hosted(
      _request(
        id: 'req-pending',
        status: JeeberFeedItemStatus.pendingResponse,
        senderName: 'Layla Hamdan',
        tier: JeeberRequestTier.standard,
      ),
    );

/// Screen 26: the client accepted, so the card becomes a state-machine control.
///
/// Uses the LONGER of the two action labels ("Heading to drop off", not "Order
/// picked") on purpose. `_AcceptedAction` wraps the button in [IntrinsicWidth]
/// specifically so the pill hugs its label instead of expanding to
/// `double.infinity` — and at this width it does not: the label's intrinsic
/// width (~268 pt) is wider than the 266 pt content column, so `IntrinsicWidth`
/// clamps to the constraint and the pill renders gutter-to-gutter. The
/// content-hugging pill Figma 56560:1523 asks for only survives on a surface
/// wider than any phone.
@JeebPreview(name: 'Accepted · advance action', size: _cardBox)
Widget jeeberFeedCardAccepted() => _hosted(
      _request(
        id: 'req-accepted',
        status: JeeberFeedItemStatus.accepted,
        action: JeeberDeliveryAction.headingToDropOff,
        senderName: 'Rami Haddad',
        tier: JeeberRequestTier.bulk,
      ),
    );

/// G3 graceful exit: the offer window closed while the jeeber was looking at it.
///
/// The card must not vanish mid-glance. It fades to
/// `UIConstants.opacityDisabled`, swaps its action row for an "Expired" status,
/// and goes inert — the tap-through and both buttons are gone, so there is no
/// way to act on a request that no longer exists. The feed removes the row once
/// the linger elapses.
///
/// The fade is the state's whole visual signal, which makes `AR RTL dark` the
/// rendering to check: a dimmed `onSurfaceVariant` label on a dark surface is
/// where this state has the least contrast left to give. At 200% the Arabic
/// "منتهي الصلاحية" plus its hourglass glyph overflows that row too (90 pt),
/// which the English rendering never shows.
@JeebPreview(name: 'Expired · G3 linger', size: _cardBox)
Widget jeeberFeedCardExpired() => _hosted(
      _request(id: 'req-expired', senderName: 'Nadia Chami'),
      isExpired: true,
    );

/// The layout ceiling: the longest plausible content on the narrowest real
/// device.
///
/// A client name that cannot fit on one line, a real-world food order as the
/// description, a two-digit distance and a five-star cluster, still incoming so
/// both buttons compete for the same footer — all on the 360 pt Galaxy S22.
///
/// Two text contracts are on review, and both hold: the name is `maxLines: 1` +
/// ellipsis inside an [Expanded], so it clips rather than shoving the timestamp
/// off the trailing edge, and the description (G1, sprint-009 P0) gets a
/// deliberate TWO-line preview in the on-surface body role — the full text lives
/// on the request detail — so it ellipsises on line two instead of growing the
/// card without bound.
///
/// What does NOT hold is the action row underneath them. At 360 pt the Ignore +
/// Offer row overflows by 32 pt in Arabic at default text size, and by 145 pt
/// (EN) / 228 pt (AR) at 200%. This is the state, and the width, where a jeeber
/// loses the "Offer" button off the edge of the screen.
@JeebPreview(name: 'Longest content · 360 pt device', size: _narrowBox)
Widget jeeberFeedCardLongContent() => _hosted(
      _request(
        id: 'req-long',
        senderName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        senderRating: 5,
        tier: JeeberRequestTier.standard,
        itemsSummary:
            '2 shawarma + cola from Barbar, extra garlic, no pickles, and a '
            'large fries — call me when you arrive at the building entrance, '
            'third floor, ring twice',
        distanceFromYouKm: 12.5,
      ),
    );
