/// Widget previews for [ChatOfferOnlyOneFooter] — run with
/// `flutter widget-preview start`.
///
/// The footer takes no parameters: it renders one localized line ("Accept only
/// one offer") centered under the stacked offer cards of a broadcasting chat.
/// So what varies below is the CONTEXT it has to hold up in — how many offer
/// cards sit above it, how narrow the device is, and what the neighbouring card
/// is doing — because that is where this widget actually fails, not in its own
/// body.
///
/// Every preview keeps at least one [OfferCardBubble] above the note, because
/// production gates the footer on `state.offerCards.isNotEmpty` (see `_rows()`
/// in `chat_screen.dart`, regression-tested in
/// `test/features/chat/dev_chat_sending_fixture_test.dart`). A preview of the
/// note floating alone would show a state the app never ships.
///
/// The offer fixtures reuse the values of the existing widget test
/// (`test/features/chat/offer_card_bubble_widget_test.dart`) so the two stay
/// comparable. Nothing here touches a repository: [OfferCardBubble] is a
/// stateless view over a domain object, and `jeeberAvatarUrl` is left null so
/// no image is ever fetched.
///
/// **What you will see in the canvas, and why it is not this widget's fault.**
/// The offer cards above the note paint overflow stripes at phone width: the
/// Decline + Accept row inside [OfferCardBubble] needs ~500 logical px and
/// overflows by 97 px at 390 pt (EN) — measured, not guessed. The note itself is
/// clean at 320 pt and at 200% text in both locales. That neighbouring bug is
/// invisible to `offer_card_bubble_widget_test.dart` only because widget tests
/// run in an 800 px viewport, which is the whole reason previews at real device
/// sizes are worth having.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/chat/domain/delivery_chat_message.dart';
import '../../features/chat/presentation/widgets/chat_offer_only_one_footer.dart';
import '../../features/chat/presentation/widgets/offer_card_bubble.dart';

/// One offer card, built the way `chat_screen.dart` builds it — including the
/// declined presentation (40% opacity, no Decline button) it uses for an offer
/// the client already turned down.
Widget _offerCard({
  required String offerId,
  required String jeeberName,
  double fee = 35.0,
  int etaMinutes = 20,
  double rating = 4.8,
  String note = 'Fast delivery guaranteed',
  bool isAccepting = false,
  bool acceptDisabled = false,
  bool declined = false,
}) {
  final Widget card = OfferCardBubble(
    message: DeliveryChatMessage.offerCard(
      id: 'msg-$offerId',
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 1, 12),
      status: MessageStatus.delivered,
      payload: OfferCardPayload(
        offerId: offerId,
        jeeberId: 'j-$offerId',
        jeeberName: jeeberName,
        fee: fee,
        currency: 'USD',
        etaMinutes: etaMinutes,
        note: note,
        rating: rating,
      ),
    ),
    onAccept: (_) {},
    onDecline: declined ? null : (_) {},
    isAccepting: isAccepting,
    acceptDisabled: acceptDisabled || declined,
  );
  return declined ? Opacity(opacity: 0.4, child: card) : card;
}

/// Mirrors the chat timeline that hosts the footer: a vertically padded
/// [ListView] whose last row is the note.
///
/// A [ListView] (not a [Column]) because that is what `chat_screen.dart` uses,
/// and because it is the difference between "the note is pushed below the fold"
/// and "the frame throws an overflow" when text scales to 200%.
Widget _thread({required List<Widget> offers, double? width}) {
  final Widget timeline = ListView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: <Widget>[...offers, const ChatOfferOnlyOneFooter()],
  );
  if (width == null) return timeline;
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: width, child: timeline),
  );
}

/// The minimum real state: one offer arrived, so the note appears for the first
/// time.
///
/// With a single card the copy is at its least justified — it is a promise
/// about offers that have not arrived yet — so this is the rendering to check
/// the note reads as guidance and not as an error under the card.
@JeebPreview(name: 'One offer', size: Size(390, 300))
Widget chatOfferOnlyOneFooterSingleOffer() => _thread(
      offers: <Widget>[
        _offerCard(offerId: 'offer-preview-1', jeeberName: 'Kamal Hajj'),
      ],
    );

/// The state the copy was written for: several jeebers have bid.
///
/// The note must read as belonging to the whole stack rather than to the last
/// card above it — it is centered while every card is start-aligned, which is
/// the only visual cue carrying that distinction.
@JeebPreview(name: 'Offer stack', size: Size(390, 560))
Widget chatOfferOnlyOneFooterOfferStack() => _thread(
      offers: <Widget>[
        _offerCard(
          offerId: 'offer-preview-2a',
          jeeberName: 'Layla Nasr',
          fee: 28.0,
          etaMinutes: 15,
          rating: 4.9,
        ),
        _offerCard(
          offerId: 'offer-preview-2b',
          jeeberName: 'Tarek Mansour',
        ),
      ],
    );

/// Narrow phone (360 pt), pinned to that width by the preview itself.
///
/// This is the only preview here whose width is guaranteed — the render tests
/// pump in an 800 px viewport and ignore [JeebPreview.size], so every other
/// state below is only as narrow as the canvas box the reviewer opens it in.
///
/// It shows a DECLINED offer (the 40%-opacity, Accept-only card
/// `chat_screen.dart` renders once the client taps Decline) for a mechanical
/// reason worth knowing: a live two-button card cannot be boxed at any phone
/// width without tripping the [OfferCardBubble] overflow described above, and
/// an overflow assertion in a neighbour would drown out the thing under review.
/// The note is what tells the client the thread is still open after a decline.
@JeebPreview(name: 'Narrow phone · declined offer', size: Size(360, 360))
Widget chatOfferOnlyOneFooterNarrowPhone() => _thread(
      width: 360,
      offers: <Widget>[
        _offerCard(
          offerId: 'offer-preview-3',
          jeeberName: 'Nour Haddad',
          fee: 42.0,
          etaMinutes: 35,
          declined: true,
        ),
      ],
    );

/// Accept in flight: one card is accepting, the rest are disabled.
///
/// This is the moment the sentence has to do real work — it is the ONLY on
/// screen explanation for why the other Accept button just went dead. If the
/// note is ever hidden while `acceptingOfferId != null`, the disabled cards
/// read as a bug.
@JeebPreview(name: 'Accept in flight', size: Size(390, 560))
Widget chatOfferOnlyOneFooterAcceptInFlight() => _thread(
      offers: <Widget>[
        _offerCard(
          offerId: 'offer-preview-4a',
          jeeberName: 'Rami Aoun',
          isAccepting: true,
        ),
        _offerCard(
          offerId: 'offer-preview-4b',
          jeeberName: 'Ziad Sfeir',
          acceptDisabled: true,
        ),
      ],
    );

/// Longest plausible neighbour content: a long jeeber name and a long offer
/// note above the footer.
///
/// The card grows; the footer must not. If the note ends up visually swallowed
/// by the card above at 200% text — or if the tall card pushes it out of the
/// viewport entirely — that is the failure this preview is here to surface.
@JeebPreview(name: 'Long neighbour content', size: Size(390, 420))
Widget chatOfferOnlyOneFooterLongContent() => _thread(
      offers: <Widget>[
        _offerCard(
          offerId: 'offer-preview-5',
          jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
          fee: 120.0,
          etaMinutes: 90,
          note: 'I am two streets away and can take the parcel right now, '
              'but the building has no lift so please meet me at the door.',
        ),
      ],
    );
