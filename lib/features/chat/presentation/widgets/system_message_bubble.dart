import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';

/// Centre-aligned system notice — the kit's [JeebSystemChip] in the thread.
///
/// Two tones, because the board draws two and they mean different things:
///   * `offerAccepted` / `offerRejected` → [JeebSystemChip.filled], a SETTLED
///     FACT ("Offer accepted · 9:12");
///   * `system` → [JeebSystemChip.outlined], a LIVE/PROGRESS event ("Karim is
///     on the way · ETA 20 min"), which is why it is the outlined pill.
///
/// The ` · HH:mm` suffix is appended **only** when the message really carries a
/// server timestamp: an undated row's `sentAt` is an ordering anchor inside
/// 1970, and printing a clock from it is a fabrication
/// (`chat_undated_band_contract_test` exists for exactly this).
class SystemMessageBubble extends StatelessWidget {
  const SystemMessageBubble({super.key, required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    final text = _copyFor(context);
    if (text.isEmpty) return const SizedBox.shrink();
    final label = _labelWithTime(context, text);
    return Padding(
      key: Key('chat-system-${message.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xLarge,
        vertical: Spacing.xSmall,
      ),
      child: _isSettledFact
          ? JeebSystemChip.filled(label: label)
          : JeebSystemChip.outlined(label: label),
    );
  }

  bool get _isSettledFact =>
      message.kind == MessageKind.offerAccepted ||
      message.kind == MessageKind.offerRejected;

  String _labelWithTime(BuildContext context, String copy) {
    if (!message.hasServerTimestamp) return copy;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return AppLocalizations.of(context).chatSystemChipWithTime(
      copy,
      DateFormat.Hm(locale).format(message.sentAt),
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
