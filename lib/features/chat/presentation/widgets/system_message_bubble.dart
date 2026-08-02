import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Center-aligned system notice: "offer was accepted" chip in chat.
class SystemMessageBubble extends StatelessWidget {
  const SystemMessageBubble({super.key, required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _copyFor(context);
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: Key('chat-system-${message.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.twoXSmall,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: OmdsBorderRadius.pill,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  String _copyFor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payload = message.systemOfferPayload;
    switch (message.kind) {
      case MessageKind.offerAccepted:
        if (payload == null) return l10n.chatSystemOfferAcceptedGeneric;
        return l10n.chatSystemOfferAcceptedNamed(payload.jeeberName);
      case MessageKind.offerRejected:
        if (payload == null) return l10n.chatSystemOfferRejectedGeneric;
        return l10n.chatSystemOfferRejectedNamed(payload.jeeberName);
      case MessageKind.system:
        return message.text;
      default:
        return '';
    }
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [SystemMessageBubble] — run with

/// One frozen instant for every fixture. The bubble paints no clock, but the
/// timeline around it does, and a fixed value keeps a canvas diff a layout
final DateTime _systemMessageBubbleFrozenAt = DateTime(2026, 6, 18, 9, 25);

DeliveryChatMessage _systemMessageBubbleAccepted(String id, String jeeberName) =>
    DeliveryChatMessage.offerAccepted(
      id: id,
      sentAt: _systemMessageBubbleFrozenAt,
      payload: SystemOfferPayload(
        offerId: 'offer-$id',
        jeeberId: 'j-$id',
        jeeberName: jeeberName,
      ),
    );

DeliveryChatMessage _systemMessageBubbleRejected(String id, String jeeberName) =>
    DeliveryChatMessage.offerRejected(
      id: id,
      sentAt: _systemMessageBubbleFrozenAt,
      payload: SystemOfferPayload(
        offerId: 'offer-$id',
        jeeberId: 'j-$id',
        jeeberName: jeeberName,
      ),
    );

DeliveryChatMessage _systemMessageBubbleSystem(String id, String text) =>
    DeliveryChatMessage.system(id: id, sentAt: _systemMessageBubbleFrozenAt, text: text);

/// Full-width host: the bubble centres itself inside whatever box it is given,
/// so the column has to stretch or "is it centred?" becomes unanswerable.
Widget _systemMessageBubbleHosted(List<DeliveryChatMessage> messages, {double? width}) {
  final Widget body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final DeliveryChatMessage message in messages)
        SystemMessageBubble(message: message),
    ],
  );
  if (width == null) return body;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, child: body),
  );
}

/// Offer accepted · named (matrix: direction-symmetric pill, copy length varies).
@JeebPreview(
  group: 'chat',
  name: 'Offer accepted · named',
  size: Size(390, 120),
  matrix: true,
)
Widget systemMessageBubbleAccepted() =>
    _systemMessageBubbleHosted(<DeliveryChatMessage>[_systemMessageBubbleAccepted('sys-accepted-1', 'Kamal Hajj')]);

/// Offer accepted · nameless (payload with empty name, dead fallback path).
@JeebPreview(
  group: 'chat',
  name: 'Offer accepted · nameless payload',
  size: Size(390, 90),
)
Widget systemMessageBubbleAcceptedNameless() =>
    _systemMessageBubbleHosted(<DeliveryChatMessage>[_systemMessageBubbleAccepted('sys-accepted-2', '')]);

/// Offer withdrawn · named (different ARB key, copy is only differentiator).
@JeebPreview(
  group: 'chat',
  name: 'Offer withdrawn · named',
  size: Size(390, 90),
)
Widget systemMessageBubbleRejected() =>
    _systemMessageBubbleHosted(<DeliveryChatMessage>[_systemMessageBubbleRejected('sys-rejected-1', 'Rana')]);

/// Server notice (verbatim text, no localization or direction detection).
@JeebPreview(
  group: 'chat',
  name: 'Server notice · verbatim',
  size: Size(390, 150),
)
Widget systemMessageBubbleServerNotice() => _systemMessageBubbleHosted(<DeliveryChatMessage>[
      _systemMessageBubbleSystem('sys-note-1', 'Your request expired before a Jeeber accepted it.'),
      _systemMessageBubbleSystem('sys-note-2', 'انتهت مهلة الطلب قبل أن يقبله أي جيبر.'),
    ]);

/// Long name: layout ceiling at 390dp (326x160 at 200%, ~3.3x taller, still reads as chip).
@JeebPreview(
  group: 'chat',
  name: 'Long name at 390dp',
  size: Size(390, 230),
  matrix: true,
)
Widget systemMessageBubbleLongName() => _systemMessageBubbleHosted(
      <DeliveryChatMessage>[
        _systemMessageBubbleAccepted('sys-accepted-3', 'Abdulrahman Al-Muhandis Al-Trabulsi'),
      ],
      width: 390,
    );

/// Empty + unsupported collapse (empty rows shrink, one real pill proves paint).
@JeebPreview(
  group: 'chat',
  name: 'Empty + unsupported collapse',
  size: Size(390, 100),
)
Widget systemMessageBubbleCollapsed() => _systemMessageBubbleHosted(<DeliveryChatMessage>[
      _systemMessageBubbleSystem('sys-empty', ''),
      DeliveryChatMessage.text(
        id: 'sys-wrong-kind',
        author: ChatAuthor.them,
        sentAt: _systemMessageBubbleFrozenAt,
        status: MessageStatus.delivered,
        text: 'a text message must never paint as a system chip',
      ),
      _systemMessageBubbleAccepted('sys-accepted-4', 'Ziad'),
    ]);
