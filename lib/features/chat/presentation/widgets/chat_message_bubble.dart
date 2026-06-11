import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';
import 'auto_direction_text.dart';
import 'chat_bubble_timestamp.dart';
import 'system_message_bubble.dart';

/// Single message row.
///
/// Bubble alignment is **directional**: the sender's own bubble sits on the
/// trailing edge and the counterpart's on the leading edge, expressed with
/// `AlignmentDirectional` + `BorderRadiusDirectional` so the whole row
/// mirrors with the ambient locale (Figma `design-spec.md` §4/§7-10 mandate a
/// full RTL mirror: self moves to the LEFT and incoming to the RIGHT in
/// Arabic). The text **inside** the bubble still picks its own direction from
/// the first strong-directional character ([AutoDirectionText]) so Arabic and
/// English content read naturally within the same conversation — the
/// WhatsApp behaviour the ticket calls for. The time → ticks meta row is the
/// single deliberately LTR island (see [_BubbleFooter]).
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
    return Semantics(
      identifier: 'chat_detail_message_${message.id}',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.twoXSmall,
        ),
        child: _bodyFor(message),
      ),
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

/// Shared bubble shell for every message kind.
///
/// Owns the three things that must be identical (and directional) across all
/// bubble variants: the leading/trailing alignment, the 70%-max-width
/// constraint, and the tail-corner radius. Using [AlignmentDirectional] and
/// [BorderRadiusDirectional] makes the sender bubble hug the trailing edge
/// and the counterpart bubble hug the leading edge — so the row mirrors
/// automatically in RTL (Arabic: self → left, incoming → right) per the
/// Figma spec, instead of being edge-locked with `Alignment.centerRight`.
class _DirectionalBubble extends StatelessWidget {
  const _DirectionalBubble({
    required this.isSender,
    required this.color,
    required this.bubbleKey,
    required this.padding,
    required this.child,
    this.symmetricRadius = false,
  });

  final bool isSender;
  final Color color;
  final Key bubbleKey;
  final EdgeInsetsGeometry padding;
  final Widget child;

  /// When true, all corners share the same radius (media/voice/location
  /// bubbles have no asymmetric tail in the Figma frame).
  final bool symmetricRadius;

  /// Design-spec §4 "~70% of available width max" ceiling. No OMDS
  /// fractional-width token exists yet (flag F-CHAT-3); kept as the single
  /// file-scoped source of truth instead of a bare inline literal so the
  /// value is named, reviewable, and shared across every bubble kind.
  static const double _bubbleMaxWidthFraction = 0.7;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSender
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        // Shrink-to-content with a ~70% ceiling (design-spec §4). OMDS has no
        // fractional-width token (pilot learning #9 / flag F-CHAT-3), so the
        // ceiling is derived from the brand bubble-width fraction below.
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * _bubbleMaxWidthFraction,
        ),
        child: Container(
          key: bubbleKey,
          decoration: BoxDecoration(color: color, borderRadius: _radius),
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  /// Tail at the bottom-trailing corner for the sender, bottom-leading for the
  /// counterpart — expressed start/end so it mirrors in RTL. The previous
  /// non-directional `BorderRadius.only(bottomLeft/Right)` kept the tail on a
  /// fixed physical side and so failed to mirror.
  BorderRadiusDirectional get _radius {
    const tail = Radius.circular(Spacing.twoXSmall);
    const round = Radius.circular(Spacing.small);
    if (symmetricRadius) {
      return const BorderRadiusDirectional.all(round);
    }
    return BorderRadiusDirectional.only(
      topStart: round,
      topEnd: round,
      bottomStart: isSender ? round : tail,
      bottomEnd: isSender ? tail : round,
    );
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

    return _DirectionalBubble(
      isSender: isSender,
      color: bubbleColor,
      bubbleKey: Key('chat-bubble-${message.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(
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
          _BubbleFooter(message: message, color: textColor, isSender: isSender),
        ],
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
    return _DirectionalBubble(
      isSender: isSender,
      color: bubbleColor,
      bubbleKey: Key('chat-photo-${message.id}'),
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
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.twoXSmall,
                Spacing.twoXSmall,
                Spacing.twoXSmall,
                0,
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
    return _DirectionalBubble(
      isSender: isSender,
      color: bubbleColor,
      symmetricRadius: true,
      bubbleKey: Key('chat-image-${message.id}'),
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
                    errorBuilder: (_, _, _) =>
                        _ImagePlaceholder(color: onBubble),
                  ),
          ),
          if (message.text.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.twoXSmall,
                Spacing.twoXSmall,
                Spacing.twoXSmall,
                0,
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
    return _DirectionalBubble(
      isSender: isSender,
      color: bubbleColor,
      symmetricRadius: true,
      bubbleKey: Key('chat-voice-${message.id}'),
      padding: const EdgeInsetsDirectional.fromSTEB(
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
          _BubbleFooter(message: message, color: onBubble, isSender: isSender),
        ],
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
    return _DirectionalBubble(
      isSender: isSender,
      color: bubbleColor,
      symmetricRadius: true,
      bubbleKey: Key('chat-location-${message.id}'),
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
          _BubbleFooter(message: message, color: onBubble, isSender: isSender),
        ],
      ),
    );
  }
}

/// Time + read-receipt row pinned to the bottom-trailing corner of the bubble.
///
/// Only the **sender's** bubble carries the meta row: Figma node 56560:1605
/// leaves the incoming (counterpart) bubble's timestamp slot empty, so the
/// counterpart footer collapses to nothing (D3 fix). The row owns its own top
/// gap so suppressing it leaves no orphan spacing, and is laid out LTR so the
/// order is always "time → ticks" regardless of the surrounding locale.
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
    if (!isSender) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.twoXSmall),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ChatBubbleTimestamp(
              sentAt: message.sentAt,
              color: color.withValues(alpha: UIConstants.opacityHigh),
            ),
            const SizedBox(width: Spacing.twoXSmall),
            _StatusIcon(
              key: Key('chat-status-${message.id}'),
              status: message.status,
              color: color,
            ),
          ],
        ),
      ),
    );
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
          size: Sizes.medium,
          color: color.withValues(alpha: UIConstants.opacityMedium),
        );
      case MessageStatus.sent:
        return Icon(Icons.done, size: Sizes.medium, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: Sizes.medium, color: color);
      case MessageStatus.read:
        return Semantics(
          identifier: 'chat_detail_message_read',
          label: AppLocalizations.of(context).chatMessageReadA11y,
          child: Icon(
            Icons.done_all,
            size: Sizes.medium,
            color: context.omdsColorTokens.infoColor,
          ),
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: Sizes.medium,
          color: Theme.of(context).colorScheme.error,
        );
    }
  }
}
