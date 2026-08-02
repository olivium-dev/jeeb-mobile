import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';
import 'auto_direction_text.dart';
import 'chat_bubble_timestamp.dart';
import 'system_message_bubble.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Single message row.
/// Bubble alignment is **directional**: the sender's own bubble sits on the
/// trailing edge and the counterpart's on the leading edge, expressed with
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
      container: true,
      explicitChildNodes: true,
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
        return _TextBubble(message: message);
    }
  }
}

/// Shared bubble shell for every message kind.
/// Owns the three things that must be identical (and directional) across all
/// bubble variants: the leading/trailing alignment, the 70%-max-width
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

  final bool symmetricRadius;

  static const double _bubbleMaxWidthFraction = 0.7;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSender
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
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
    final authorLabel = isSender ? 'You' : 'Jeeber';
    final l10n = AppLocalizations.of(context);
    final bubble = _DirectionalBubble(
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
            child: (message.photoBytes?.isNotEmpty ?? false)
                ? Image.memory(
                    message.photoBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _ImagePlaceholder(color: onBubble),
                  )
                : _ImagePlaceholder(color: onBubble),
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
    return Semantics(label: l10n.chatPhotoA11y(authorLabel), child: bubble);
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
    final authorLabel = isSender ? 'You' : 'Jeeber';
    final l10n = AppLocalizations.of(context);
    final bubble = _DirectionalBubble(
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
            child: _imageContent(message, onBubble),
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
    return Semantics(label: l10n.chatImageA11y(authorLabel), child: bubble);
  }

  Widget _imageContent(DeliveryChatMessage message, Color onBubble) {
    final bytes = message.photoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _ImagePlaceholder(color: onBubble),
      );
    }
    final url = message.imageUrl ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return OmdsCachedImage(
        url: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _ImagePlaceholder(color: onBubble),
      );
    }
    return _ImagePlaceholder(color: onBubble);
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
    final isSender = message.isMine;
    final bubbleColor = isSender
        ? colorScheme.primary
        : colorScheme.surfaceContainerHigh;
    final onBubble = isSender ? colorScheme.onPrimary : colorScheme.onSurface;
    final durationSecs = ((message.voiceDurationMs ?? 0) / 1000).round();
    final authorLabel = isSender ? 'You' : 'Jeeber';
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.chatVoiceNoteA11y(authorLabel, durationSecs),
      child: _DirectionalBubble(
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
            _VoicePlayerRow(message: message, onBubble: onBubble),
            if (message.voiceTranscription != null)
              _TranscriptionText(
                text: message.voiceTranscription!,
                color: onBubble,
              ),
            _BubbleFooter(
              message: message,
              color: onBubble,
              isSender: isSender,
            ),
          ],
        ),
      ),
    );
  }
}

class _VoicePlayerRow extends StatelessWidget {
  const _VoicePlayerRow({required this.message, required this.onBubble});

  final DeliveryChatMessage message;
  final Color onBubble;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
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
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).round();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TranscriptionText extends StatelessWidget {
  const _TranscriptionText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final display = text == '__unavailable__'
        ? l10n.chatVoiceNoteTranscriptionUnavailable
        : l10n.chatVoiceNoteTranscription(text);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.twoXSmall),
      child: Text(
        display,
        style: textTheme.bodySmall?.copyWith(
          color: color.withValues(alpha: UIConstants.opacityHigh),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
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
              hasServerTimestamp: message.hasServerTimestamp,
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

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({super.key, required this.status, required this.color});

  final MessageStatus status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return Semantics(
          identifier: 'chat_detail_message_sending',
          label: AppLocalizations.of(context).chatMessageSendingA11y,
          child: Icon(
            Icons.access_time,
            size: Sizes.medium,
            color: color.withValues(alpha: UIConstants.opacityMedium),
          ),
        );
      case MessageStatus.sent:
        return Semantics(
          identifier: 'chat_detail_message_sent',
          label: AppLocalizations.of(context).chatMessageSentA11y,
          child: Icon(Icons.done, size: Sizes.medium, color: color),
        );
      case MessageStatus.delivered:
        return Semantics(
          identifier: 'chat_detail_message_delivered',
          label: AppLocalizations.of(context).chatMessageDeliveredA11y,
          child: Icon(Icons.done_all, size: Sizes.medium, color: color),
        );
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
        return Semantics(
          identifier: 'chat_detail_message_failed',
          label: AppLocalizations.of(context).chatMessageFailedA11y,
          child: Icon(
            Icons.error_outline,
            size: Sizes.medium,
            color: Theme.of(context).colorScheme.error,
          ),
        );
    }
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [ChatMessageBubble] — run with

/// One fixed instant for every fixture, so the rendered clock is stable and a
/// diff in the canvas is always a layout change, never a passing minute.
final DateTime _chatMessageBubbleSentAt = DateTime(2026, 6, 11, 9, 41);

/// Full-width host: the bubble aligns itself inside whatever box it is given,
/// so the column must stretch or every bubble renders centred and the
Widget _chatMessageBubbleHosted(List<DeliveryChatMessage> messages) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final DeliveryChatMessage message in messages)
          ChatMessageBubble(message: message),
      ],
    );

DeliveryChatMessage _chatMessageBubbleText(
  String id,
  ChatAuthor author,
  String body, {
  MessageStatus status = MessageStatus.read,
  bool hasServerTimestamp = true,
}) =>
    DeliveryChatMessage.text(
      id: id,
      author: author,
      sentAt: _chatMessageBubbleSentAt,
      status: status,
      text: body,
      hasServerTimestamp: hasServerTimestamp,
    );

/// The directional contract, in one card: an incoming message followed by the
/// reply to it.
@JeebPreview(group: 'chat', name: 'Incoming + reply', size: Size(390, 200))
Widget chatMessageBubblePair() => _chatMessageBubbleHosted(<DeliveryChatMessage>[
      _chatMessageBubbleText('them-1', ChatAuthor.them, "I'm at the pharmacy now — which brand?"),
      _chatMessageBubbleText('me-1', ChatAuthor.me, 'The blue box, please'),
    ]);

/// Every send state stacked, because the tick glyph is the only difference
/// between "it went" and "it silently did not".
@JeebPreview(group: 'chat', name: 'Status ladder', size: Size(390, 540))
Widget chatMessageBubbleStatusLadder() => _chatMessageBubbleHosted(<DeliveryChatMessage>[
      _chatMessageBubbleText('st-1', ChatAuthor.me, 'sending — still on this phone',
          status: MessageStatus.sending),
      _chatMessageBubbleText('st-2', ChatAuthor.me, 'sent — the server has it',
          status: MessageStatus.sent),
      _chatMessageBubbleText('st-3', ChatAuthor.me, 'delivered — on their device',
          status: MessageStatus.delivered),
      _chatMessageBubbleText('st-4', ChatAuthor.me, 'read — they opened the thread',
          status: MessageStatus.read),
      _chatMessageBubbleText('st-5', ChatAuthor.me, 'failed — this one never left',
          status: MessageStatus.failed),
    ]);

/// Layout ceiling: the longest message a client plausibly types.
/// The bubble is capped at ~70% of the available width (design-spec §4) with
@JeebPreview(group: 'chat', name: 'Longest plausible message', size: Size(390, 470))
Widget chatMessageBubbleLongText() => _chatMessageBubbleHosted(<DeliveryChatMessage>[
      _chatMessageBubbleText(
        'long-1',
        ChatAuthor.me,
        'Hi! Please pick up the two large bags of ice, a pack of paper cups, '
        'and the birthday cake reserved under the name Fawaz — the counter '
        'staff already have it boxed and paid for, so you only need to show '
        'them this message.',
      ),
    ]);

/// Mixed-script thread: the bubble edge and the text direction are decided
/// SEPARATELY, and this is the only state that proves it.
@JeebPreview(group: 'chat', name: 'Arabic message in an EN thread', size: Size(390, 230))
Widget chatMessageBubbleMixedScript() => _chatMessageBubbleHosted(<DeliveryChatMessage>[
      _chatMessageBubbleText('bidi-1', ChatAuthor.me, 'وصلت للبناية، أنا عند المصعد'),
      _chatMessageBubbleText('bidi-2', ChatAuthor.me, 'Coming down now, one minute'),
    ]);

/// P4/P5 regression, made visible: an image row whose only source is a CDN
/// `object_ref`.
@JeebPreview(group: 'chat', name: 'Image with no local bytes', size: Size(390, 210))
Widget chatMessageBubbleImageNoBytes() => _chatMessageBubbleHosted(<DeliveryChatMessage>[
      DeliveryChatMessage.image(
        id: 'img-1',
        author: ChatAuthor.me,
        sentAt: _chatMessageBubbleSentAt,
        status: MessageStatus.sent,
        url: 'chat_attachment/9f2c41e8-3d55-4f0a-b1c7-0a2e6f8d1b44.jpg',
        caption: 'Left it with the concierge',
      ),
    ]);

/// A history row the server returned with no usable `created_at`.
/// Such a row is a REAL message — it renders — but its `sentAt` is an ORDERING
@JeebPreview(group: 'chat', name: 'Undated history row', size: Size(390, 250))
Widget chatMessageBubbleUndated() => _chatMessageBubbleHosted(<DeliveryChatMessage>[
      _chatMessageBubbleText('undated-1', ChatAuthor.me, 'No created_at came back for this row',
          hasServerTimestamp: false),
      _chatMessageBubbleText('dated-1', ChatAuthor.me, 'This one carries a real send time'),
    ]);
