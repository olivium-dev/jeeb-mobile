import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/delivery_chat_message.dart';
import 'offer_card_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// Centered helper note under the stacked offer cards in the broadcasting
/// chat (Figma node 56535:6659): "Accept only one offer".
///
/// Renders in the brand-accent (tertiary/orange) role to match the Figma
/// emphasis, with the copy resolved through [AppLocalizations].
class ChatOfferOnlyOneFooter extends StatelessWidget {
  const ChatOfferOnlyOneFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'chat_detail_offer_only_one_note',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context).chatOfferAcceptOnlyOne,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
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
// Render tests: test/previews/chat/chat_offer_only_one_footer_preview_test.dart
// ===========================================================================

// Widget previews for [ChatOfferOnlyOneFooter] — run with
// `flutter widget-preview start`.
//
// The footer takes no parameters: it renders one localized line ("Accept only
// one offer") centered under the stacked offer cards of a broadcasting chat.
// So what varies below is the CONTEXT it has to hold up in — how many offer
// cards sit above it, how narrow the device is, and what the neighbouring card
// is doing — because that is where this widget actually fails, not in its own
// body.
//
// Every preview keeps at least one [OfferCardBubble] above the note, because
// production gates the footer on `state.offerCards.isNotEmpty` (see `_rows()`
// in `chat_screen.dart`, regression-tested in
// `test/features/chat/dev_chat_sending_fixture_test.dart`). A preview of the
// note floating alone would show a state the app never ships.
//
// The offer fixtures reuse the values of the existing widget test
// (`test/features/chat/offer_card_bubble_widget_test.dart`) so the two stay
// comparable. Nothing here touches a repository: [OfferCardBubble] is a
// stateless view over a domain object, and `jeeberAvatarUrl` is left null so
// no image is ever fetched.
//
// **What you will see in the canvas, and why it is not this widget's fault.**
// The offer cards above the note paint overflow stripes at phone width: the
// Decline + Accept row inside [OfferCardBubble] needs ~500 logical px and
// overflows by 97 px at 390 pt (EN) — measured, not guessed. The note itself is
// clean at 320 pt and at 200% text in both locales. That neighbouring bug is
// invisible to `offer_card_bubble_widget_test.dart` only because widget tests
// run in an 800 px viewport, which is the whole reason previews at real device
// sizes are worth having.

/// One offer card, built the way `chat_screen.dart` builds it — including the
/// declined presentation (40% opacity, no Decline button) it uses for an offer
/// the client already turned down.
Widget _chatOfferOnlyOneFooterOfferCard({
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
Widget _chatOfferOnlyOneFooterThread({required List<Widget> offers, double? width}) {
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
@JeebPreview(group: 'chat', name: 'One offer', size: Size(390, 300))
Widget chatOfferOnlyOneFooterSingleOffer() => _chatOfferOnlyOneFooterThread(
      offers: <Widget>[
        _chatOfferOnlyOneFooterOfferCard(offerId: 'offer-preview-1', jeeberName: 'Kamal Hajj'),
      ],
    );

/// The state the copy was written for: several jeebers have bid.
///
/// The note must read as belonging to the whole stack rather than to the last
/// card above it — it is centered while every card is start-aligned, which is
/// the only visual cue carrying that distinction.
@JeebPreview(group: 'chat', name: 'Offer stack', size: Size(390, 560))
Widget chatOfferOnlyOneFooterOfferStack() => _chatOfferOnlyOneFooterThread(
      offers: <Widget>[
        _chatOfferOnlyOneFooterOfferCard(
          offerId: 'offer-preview-2a',
          jeeberName: 'Layla Nasr',
          fee: 28.0,
          etaMinutes: 15,
          rating: 4.9,
        ),
        _chatOfferOnlyOneFooterOfferCard(
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
@JeebPreview(group: 'chat', name: 'Narrow phone · declined offer', size: Size(360, 360))
Widget chatOfferOnlyOneFooterNarrowPhone() => _chatOfferOnlyOneFooterThread(
      width: 360,
      offers: <Widget>[
        _chatOfferOnlyOneFooterOfferCard(
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
@JeebPreview(group: 'chat', name: 'Accept in flight', size: Size(390, 560))
Widget chatOfferOnlyOneFooterAcceptInFlight() => _chatOfferOnlyOneFooterThread(
      offers: <Widget>[
        _chatOfferOnlyOneFooterOfferCard(
          offerId: 'offer-preview-4a',
          jeeberName: 'Rami Aoun',
          isAccepting: true,
        ),
        _chatOfferOnlyOneFooterOfferCard(
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
@JeebPreview(group: 'chat', name: 'Long neighbour content', size: Size(390, 420))
Widget chatOfferOnlyOneFooterLongContent() => _chatOfferOnlyOneFooterThread(
      offers: <Widget>[
        _chatOfferOnlyOneFooterOfferCard(
          offerId: 'offer-preview-5',
          jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
          fee: 120.0,
          etaMinutes: 90,
          note: 'I am two streets away and can take the parcel right now, '
              'but the building has no lift so please meet me at the door.',
        ),
      ],
    );
