import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

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
    this.color,
  });

  /// When the message was sent.
  final DateTime sentAt;

  /// Optional override colour; defaults to a muted on-surface variant.
  final Color? color;

  @override
  Widget build(BuildContext context) {
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
