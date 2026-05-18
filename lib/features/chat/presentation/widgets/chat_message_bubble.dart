import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_chat_message.dart';
import 'auto_direction_text.dart';
import 'system_message_bubble.dart';

/// Single message row.
///
/// Bubble alignment is locked to the screen edges (sender right, receiver
/// left) using non-directional `Alignment.centerRight/centerLeft` so it does
/// not flip with the surrounding locale. The text **inside** the bubble
/// picks its own direction from the first strong-directional character so
/// Arabic content right-aligns and English content left-aligns within the
/// same conversation — the WhatsApp behaviour the ticket calls for.
///
/// Per-kind routing:
///   text             → [_TextBubble]
///   photo            → [_PhotoBubble] (legacy MVP in-memory bytes)
///   image            → [_ImageBubble] (CDN URL)
///   voice            → [_VoiceBubble] (placeholder waveform + play)
///   location         → [_LocationBubble]
///   system/accepted  → [SystemMessageBubble] (center chip)
///   offerCard        → handled by `ChatScreen` directly, never reaches here.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({super.key, required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystemNotice) {
      return SystemMessageBubble(message: message);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.twoXSmall,
      ),
      child: _bodyFor(message),
    );
  }

  Widget _bodyFor(DeliveryChatMessage message) {
    switch (message.kind) {
      case MessageKind.text:
        return _TextBubble(message: message);
      case MessageKind.photo:
        return _PhotoBubble(message: message);
      case MessageKind.image:
        return _ImageBubble(message: message);
      case MessageKind.voice:
        return _VoiceBubble(message: message);
      case MessageKind.location:
        return _LocationBubble(message: message);
      case MessageKind.system:
      case MessageKind.offerCard:
      case MessageKind.offerAccepted:
      case MessageKind.offerRejected:
        // System notices flow through the early-return above. Offer cards
        // are owned by the broadcasting screen and never reach this bubble.
        // A text fallback keeps the UI rendering if something slips through.
        return _TextBubble(message: message);
    }
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message});

  final DeliveryChatMessage message;

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
              topLeft: const Radius.circular(Spacing.small),
              topRight: const Radius.circular(Spacing.small),
              bottomLeft: isSender
                  ? const Radius.circular(Spacing.small)
                  : const Radius.circular(Spacing.twoXSmall),
              bottomRight: isSender
                  ? const Radius.circular(Spacing.twoXSmall)
                  : const Radius.circular(Spacing.small),
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

  final DeliveryChatMessage message;

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
              topLeft: const Radius.circular(Spacing.small),
              topRight: const Radius.circular(Spacing.small),
              bottomLeft: isSender
                  ? const Radius.circular(Spacing.small)
                  : const Radius.circular(Spacing.twoXSmall),
              bottomRight: isSender
                  ? const Radius.circular(Spacing.twoXSmall)
                  : const Radius.circular(Spacing.small),
            ),
          ),
          padding: const EdgeInsets.all(Spacing.twoXSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: OmdsBorderRadius.xSmall,
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

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSender = message.isMine;
    final bubbleColor = isSender
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final onBubble = isSender ? colorScheme.onPrimary : colorScheme.onSurface;
    final url = message.imageUrl ?? '';
    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Container(
          key: Key('chat-image-${message.id}'),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: OmdsBorderRadius.small,
          ),
          padding: const EdgeInsets.all(Spacing.twoXSmall),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: OmdsBorderRadius.xSmall,
                child: url.isEmpty
                    ? _ImagePlaceholder(color: onBubble)
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) =>
                            _ImagePlaceholder(color: onBubble),
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

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Sizes.fiveXLarge * 3,
      height: Sizes.fiveXLarge * 2,
      alignment: Alignment.center,
      color: color.withValues(alpha: UIConstants.opacityLow),
      child: Icon(
        Icons.image_outlined,
        size: Sizes.threeXLarge,
        color: color.withValues(alpha: UIConstants.opacityMedium),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.message});

  final DeliveryChatMessage message;

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
          key: Key('chat-voice-${message.id}'),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: OmdsBorderRadius.small,
          ),
          padding: const EdgeInsets.fromLTRB(
            Spacing.medium,
            Spacing.small,
            Spacing.medium,
            Spacing.twoXSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: onBubble),
                  const SizedBox(width: Spacing.xSmall),
                  Expanded(
                    child: Container(
                      height: Sizes.twoXSmall,
                      decoration: BoxDecoration(
                        color: onBubble.withValues(alpha: UIConstants.opacityLow),
                        borderRadius: OmdsBorderRadius.pill,
                      ),
                    ),
                  ),
                  const SizedBox(width: Spacing.xSmall),
                  Text(
                    _formatDuration(message.voiceDurationMs ?? 0),
                    style: textTheme.labelMedium?.copyWith(color: onBubble),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.twoXSmall),
              _BubbleFooter(
                message: message,
                color: onBubble,
                isSender: isSender,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.message});

  final DeliveryChatMessage message;

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
          key: Key('chat-location-${message.id}'),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: OmdsBorderRadius.small,
          ),
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: onBubble),
                  const SizedBox(width: Spacing.xSmall),
                  Expanded(
                    child: Text(
                      message.text.isEmpty
                          ? '${message.latitude?.toStringAsFixed(4)}, ${message.longitude?.toStringAsFixed(4)}'
                          : message.text,
                      style: textTheme.bodyMedium?.copyWith(color: onBubble),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xSmall),
              _BubbleFooter(
                message: message,
                color: onBubble,
                isSender: isSender,
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

  final DeliveryChatMessage message;
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
              color: color.withValues(alpha: UIConstants.opacityHigh),
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
          color: color.withValues(alpha: UIConstants.opacityMedium),
        );
      case MessageStatus.sent:
        return Icon(Icons.done, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 14,
          color: context.omdsColorTokens.infoColor,
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
