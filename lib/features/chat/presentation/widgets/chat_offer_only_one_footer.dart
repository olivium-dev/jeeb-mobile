import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/delivery_chat_message.dart';
import 'offer_card_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// Centered helper note under stacked offer cards: "Accept only one offer". Tertiary role.
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

// Widget previews for [ChatOfferOnlyOneFooter] — run with

/// One offer card, built the way `chat_screen.dart` builds it — including the
/// declined presentation (40% opacity, no Decline button) it uses for an offer
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
@JeebPreview(group: 'chat', name: 'One offer', size: Size(390, 300))
Widget chatOfferOnlyOneFooterSingleOffer() => _chatOfferOnlyOneFooterThread(
      offers: <Widget>[
        _chatOfferOnlyOneFooterOfferCard(offerId: 'offer-preview-1', jeeberName: 'Kamal Hajj'),
      ],
    );

/// The state the copy was written for: several jeebers have bid.
/// The note must read as belonging to the whole stack rather than to the last
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
/// This is the only preview here whose width is guaranteed — the render tests
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
/// This is the moment the sentence has to do real work — it is the ONLY on
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
