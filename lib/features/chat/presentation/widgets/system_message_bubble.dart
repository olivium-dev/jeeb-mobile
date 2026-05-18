import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';

/// Center-aligned system notice — the "Kamal Hajj's offer was accepted"
/// chip that lands in the chat between the offer cards and the 1:1 timeline
/// when the accept saga resolves.
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
