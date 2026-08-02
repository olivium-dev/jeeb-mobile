import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_chat_message.dart';

/// Locale-aware "HH:mm" timestamp in chat bubble meta row via DateFormat.Hm.
class ChatBubbleTimestamp extends StatelessWidget {
  const ChatBubbleTimestamp({
    super.key,
    required this.sentAt,
    this.hasServerTimestamp = true,
    this.color,
  });

  final DateTime sentAt;

  // Was re-derived from sentAt value (anchor was "any instant inside 1970"). Message now
  // carries the fact explicitly, so anchor that looks plausible cannot be mistaken for send time.
  final bool hasServerTimestamp;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Server-returned message with no timestamp carries ordering anchor, not send time.
    // Render nothing rather than fabricated clock.
    if (!hasServerTimestamp) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Text(
        DateFormat.Hm(locale).format(sentAt),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color ??
              theme.colorScheme.onSurfaceVariant
                  .withValues(alpha: UIConstants.opacityHigh),
        ),
      ),
    );
  }
}
