import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/chat_message.dart';
import 'auto_direction_text.dart';

/// Single message row.
///
/// Bubble alignment is locked to the screen edges (sender right, receiver
/// left) using non-directional `Alignment.centerRight/centerLeft` so it does
/// not flip with the surrounding locale. The text **inside** the bubble
/// picks its own direction from the first strong-directional character so
/// Arabic content right-aligns and English content left-aligns within the
/// same conversation — the WhatsApp behaviour the ticket calls for.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.twoXSmall,
      ),
      child: message.isPhoto
          ? _PhotoBubble(message: message)
          : _TextBubble(message: message),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSender = message.isMine;
    final bubbleColor = isSender
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final textColor = isSender ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Container(
          key: Key('chat-bubble-${message.id}'),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isSender
                  ? const Radius.circular(12)
                  : const Radius.circular(4),
              bottomRight: isSender
                  ? const Radius.circular(4)
                  : const Radius.circular(12),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            Spacing.medium,
            Spacing.medium,
            Spacing.medium,
            Spacing.twoXSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AutoDirectionText(
                message.text,
                style: textTheme.bodyLarge?.copyWith(color: textColor),
              ),
              const SizedBox(height: Spacing.twoXSmall),
              _BubbleFooter(
                message: message,
                color: textColor,
                isSender: isSender,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSender = message.isMine;
    final bubbleColor = isSender
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final onBubble = isSender ? colorScheme.onPrimary : colorScheme.onSurface;
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Container(
          key: Key('chat-photo-${message.id}'),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: isSender
                  ? const Radius.circular(12)
                  : const Radius.circular(4),
              bottomRight: isSender
                  ? const Radius.circular(4)
                  : const Radius.circular(12),
            ),
          ),
          padding: const EdgeInsets.all(Spacing.twoXSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  message.photoBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
              if (message.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    top: Spacing.twoXSmall,
                    left: Spacing.twoXSmall,
                    right: Spacing.twoXSmall,
                  ),
                  child: AutoDirectionText(
                    message.text,
                    style: textTheme.bodyMedium?.copyWith(color: onBubble),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(Spacing.twoXSmall),
                child: _BubbleFooter(
                  message: message,
                  color: onBubble,
                  isSender: isSender,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Time + read-receipt row pinned to the bottom-right of the bubble. Always
/// laid out LTR so the order is always "time → ticks" regardless of the
/// surrounding locale.
class _BubbleFooter extends StatelessWidget {
  const _BubbleFooter({
    required this.message,
    required this.color,
    required this.isSender,
  });

  final ChatMessage message;
  final Color color;
  final bool isSender;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _formatTime(message.sentAt),
            style: textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.8),
            ),
          ),
          if (isSender) ...[
            const SizedBox(width: Spacing.twoXSmall),
            _StatusIcon(
              key: Key('chat-status-${message.id}'),
              status: message.status,
              color: color,
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime sentAt) {
    final h = sentAt.hour % 12 == 0 ? 12 : sentAt.hour % 12;
    final m = sentAt.minute.toString().padLeft(2, '0');
    final period = sentAt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

/// Status tick that mirrors WhatsApp's convention:
///   sending   → clock
///   sent      → single gray tick
///   delivered → double gray ticks
///   read      → double blue ticks
///   failed    → red error glyph
class _StatusIcon extends StatelessWidget {
  const _StatusIcon({super.key, required this.status, required this.color});

  final MessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Icon(
          Icons.access_time,
          size: 14,
          color: color.withValues(alpha: 0.6),
        );
      case MessageStatus.sent:
        return Icon(Icons.done, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageStatus.read:
        return const Icon(
          Icons.done_all,
          size: 14,
          color: Colors.lightBlueAccent,
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}
