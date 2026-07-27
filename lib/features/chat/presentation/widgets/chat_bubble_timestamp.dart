import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_chat_message.dart';

/// Locale-aware "HH:mm" timestamp rendered inside a chat bubble's meta row.
///
/// Shared by the offer card (state 02) and the message-bubble footer (state
/// 03) so the time format is identical across both chat states. Uses
/// [DateFormat.Hm] keyed to the active locale — never a string-built clock —
/// and is laid out start-aligned so the parent decides placement.
class ChatBubbleTimestamp extends StatelessWidget {
  const ChatBubbleTimestamp({
    super.key,
    required this.sentAt,
    this.hasServerTimestamp = true,
    this.color,
  });

  /// When the message was sent — meaningless unless [hasServerTimestamp].
  final DateTime sentAt;

  /// [DeliveryChatMessage.hasServerTimestamp] of the message being rendered.
  /// False → [sentAt] is an ordering anchor and no clock is drawn.
  ///
  /// This used to be re-derived here from the VALUE of [sentAt] (an anchor was
  /// "any instant inside 1970"). The message now carries the fact explicitly, so
  /// an anchor that happens to look like a plausible instant can never be
  /// mistaken for a send time.
  final bool hasServerTimestamp;

  /// Optional override colour; defaults to a muted on-surface variant.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // A message the server returned with no timestamp carries an ordering
    // anchor, not a send time. Render nothing rather than a fabricated clock.
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
