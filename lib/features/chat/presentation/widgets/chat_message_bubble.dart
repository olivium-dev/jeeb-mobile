import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_chat_bubble.dart';
import '../../../../core/widgets/jeeb/jeeb_waveform.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_chat_message.dart';
import '../chat_redesign_l10n.dart';
import 'auto_direction_text.dart';
import 'system_message_bubble.dart';

/// Single message row — the redesign-2026-08 screen-21 thread bubble.
///
/// Geometry (the `18/18/18/6` directional tail, the 78% ceiling, the `11/14`
/// padding, the meta line, the Ø32 play disc and the 120×74 photo tile) is
/// **kit-owned** by [JeebChatBubble] / [JeebChatMedia]. This widget owns only
/// what belongs to the message: the frozen identifiers and keys, the per-kind
/// routing, the image source precedence, and the a11y sentences.
///
/// Bubble alignment stays **directional** (`AlignmentDirectional` +
/// `BorderRadiusDirectional`, both inside the kit), so the row mirrors with the
/// ambient locale. The text INSIDE the bubble still picks its own direction
/// from the first strong-directional character ([AutoDirectionText]) so Arabic
/// and English content read naturally within one conversation; it is passed as
/// `child:` with **no style**, because the kit installs the body ramp.
///
/// Two deliberate divergences from the pre-redesign bubble, both from the
/// board:
///   * the **incoming** bubble now carries its timestamp (the render draws
///     `9:24`), reversing the documented D3 decision;
///   * the **read** state is the localized WORD after a `·`, never a
///     double blue tick — `JeebSemanticColors.readTick` is banned.
///
/// Per-kind routing:
///   text             → text bubble
///   photo            → photo tile (legacy MVP in-memory bytes)
///   image            → photo tile (CDN URL)
///   voice            → inert play disc + waveform (no audio player exists)
///   location         → icon + text shell
///   system/accepted  → [SystemMessageBubble] (centred chip)
///   offerCard        → handled by `ChatScreen` directly, never reaches here.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.clustered = false,
  });

  final DeliveryChatMessage message;

  /// True when the previous row is a message from the SAME author, in which
  /// case the rows tighten into one visual block. This is how the board's
  /// single "voice + photo" bubble is rendered honestly: the wire carries two
  /// messages (`MessageKind` is one-of), so we draw two bubbles and cluster
  /// them rather than faking a bubble that could hold both.
  final bool clustered;

  @override
  Widget build(BuildContext context) {
    if (message.isSystemNotice) {
      return SystemMessageBubble(message: message);
    }
    // `container: true` + `explicitChildNodes: true` make the per-message
    // wrapper a Semantics *boundary*. Without it the outer
    // `chat_detail_message_<id>` node auto-merges its descendants and swallows
    // the status node's `chat_detail_message_read` identifier, so neither
    // Maestro nor a screen reader can address the read-receipt independently.
    // The boundary keeps the per-message id AND surfaces the inner status id as
    // its own queryable node.
    return Semantics(
      identifier: 'chat_detail_message_${message.id}',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        // The board's 24 gutter (html:31); a clustered row halves its top gap.
        padding: EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          clustered ? Sizes.threeXSmall : Spacing.twoXSmall,
          Spacing.xLarge,
          Spacing.twoXSmall,
        ),
        child: _bodyFor(context, message),
      ),
    );
  }

  Widget _bodyFor(BuildContext context, DeliveryChatMessage message) {
    switch (message.kind) {
      case MessageKind.photo:
        return _PhotoBubble(message: message);
      case MessageKind.image:
        return _ImageBubble(message: message);
      case MessageKind.voice:
        return _VoiceBubble(message: message);
      case MessageKind.location:
        return _LocationBubble(message: message);
      case MessageKind.text:
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

/// Which side of the thread [message] belongs to.
JeebChatBubbleSide _sideOf(DeliveryChatMessage message) => message.isMine
    ? JeebChatBubbleSide.outgoing
    : JeebChatBubbleSide.incoming;

/// The formatted clock for [message], or null when the server never dated it.
///
/// An undated row gets NO clock, ever: its ordering anchor sits in 1970 and
/// rendering `00:00` over a live thread is a fabrication
/// (`chat_undated_band_contract_test`).
String? _timeOf(BuildContext context, DeliveryChatMessage message) {
  if (!message.hasServerTimestamp) return null;
  final String locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.Hm(locale).format(message.sentAt);
}

/// The delivery status node for an OUTGOING message.
///
/// Counterpart bubbles return null — they carry a time and never a status
/// (there is no read-receipt to report about someone else's message). All five
/// identifiers and their existing a11y labels are unchanged; only `read` swaps
/// its double-tick Icon for the localized word.
JeebChatStatus? _statusOf(BuildContext context, DeliveryChatMessage message) {
  if (!message.isMine) return null;
  final l10n = AppLocalizations.of(context);
  final Key nodeKey = Key('chat-status-${message.id}');
  switch (message.status) {
    case MessageStatus.sending:
      return JeebChatStatus.icon(
        Icons.access_time,
        identifier: 'chat_detail_message_sending',
        semanticLabel: l10n.chatMessageSendingA11y,
        nodeKey: nodeKey,
      );
    case MessageStatus.sent:
      return JeebChatStatus.icon(
        Icons.done,
        identifier: 'chat_detail_message_sent',
        semanticLabel: l10n.chatMessageSentA11y,
        nodeKey: nodeKey,
      );
    case MessageStatus.delivered:
      return JeebChatStatus.icon(
        Icons.done_all,
        identifier: 'chat_detail_message_delivered',
        semanticLabel: l10n.chatMessageDeliveredA11y,
        nodeKey: nodeKey,
      );
    case MessageStatus.read:
      return JeebChatStatus.text(
        ChatRedesignL10n.of(context).messageReadLabel,
        identifier: 'chat_detail_message_read',
        semanticLabel: l10n.chatMessageReadA11y,
        nodeKey: nodeKey,
      );
    case MessageStatus.failed:
      return JeebChatStatus.icon(
        Icons.error_outline,
        iconColor: Theme.of(context).colorScheme.error,
        identifier: 'chat_detail_message_failed',
        semanticLabel: l10n.chatMessageFailedA11y,
        nodeKey: nodeKey,
      );
  }
}

String _authorLabel(DeliveryChatMessage message) =>
    message.isMine ? 'You' : 'Jeeber';

String _formatDuration(int ms) {
  final int totalSeconds = (ms / 1000).round();
  final int minutes = (totalSeconds / 60).floor();
  final int seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    return JeebChatBubble(
      side: _sideOf(message),
      time: _timeOf(context, message),
      status: _statusOf(context, message),
      bubbleKey: Key('chat-bubble-${message.id}'),
      // No style: the kit installs the body ramp and the side's ink.
      child: AutoDirectionText(message.text),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final Uint8List? bytes = message.photoBytes;
    // P4/P5: `photoBytes!` crashed on a bytes-less `photo` row, and
    // `Image.memory` had no `errorBuilder`, so undecodable bytes threw an
    // `ErrorWidget` into the thread. Both degrade to the placeholder.
    final Widget? photo = (bytes != null && bytes.isNotEmpty)
        ? Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const _TilePlaceholder(),
          )
        : null;
    return Semantics(
      label: l10n.chatPhotoA11y(_authorLabel(message)),
      child: JeebChatBubble(
        side: _sideOf(message),
        media: JeebChatMedia.photo(photo: photo),
        time: _timeOf(context, message),
        status: _statusOf(context, message),
        bubbleKey: Key('chat-photo-${message.id}'),
        child: message.text.isEmpty ? null : AutoDirectionText(message.text),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.chatImageA11y(_authorLabel(message)),
      child: JeebChatBubble(
        side: _sideOf(message),
        media: JeebChatMedia.photo(photo: _imageContent(message)),
        time: _timeOf(context, message),
        status: _statusOf(context, message),
        bubbleKey: Key('chat-image-${message.id}'),
        child: message.text.isEmpty ? null : AutoDirectionText(message.text),
      ),
    );
  }

  /// P4/P5 source precedence — UNCHANGED. Local bytes WIN: the sender's own
  /// just-captured frame, or a peer image already resolved through the
  /// authenticated CDN read proxy, so the photo renders with no round trip and
  /// no blink.
  ///
  /// A bare [DeliveryChatMessage.imageUrl] is a CDN `object_ref`
  /// (`chat_attachment/<guid>.jpg`), NOT a fetchable URL: handing it to
  /// [OmdsCachedImage] would issue a doomed unauthenticated GET. Only an
  /// ABSOLUTE http(s) value (a legacy/external image) is passed through.
  /// Null falls through to the kit's placeholder tile.
  Widget? _imageContent(DeliveryChatMessage message) {
    final Uint8List? bytes = message.photoBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _TilePlaceholder(),
      );
    }
    final String url = message.imageUrl ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return OmdsCachedImage(
        url: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const _TilePlaceholder(),
      );
    }
    return null;
  }
}

/// The degraded state of a resolved image: the SAME glyph the kit's photo tile
/// draws when no image was resolved at all, so an undecodable frame and a
/// missing one look identical instead of one of them going blank.
class _TilePlaceholder extends StatelessWidget {
  const _TilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: JeebChatMedia.photoGlyphSize,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final int durationSecs = ((message.voiceDurationMs ?? 0) / 1000).round();
    final String? transcription = message.voiceTranscription;
    return Semantics(
      label: l10n.chatVoiceNoteA11y(_authorLabel(message), durationSecs),
      child: JeebChatBubble(
        side: _sideOf(message),
        media: JeebChatMedia.voice(
          waveform: const JeebWaveform.inBubble(),
          label: _formatDuration(message.voiceDurationMs ?? 0),
          // B-04: no audio player exists anywhere in the app. The disc renders
          // inert, with no Semantics and no identifier — an id on a permanent
          // no-op is the defect class B-04 was raised for.
          onPlay: null,
        ),
        time: _timeOf(context, message),
        status: _statusOf(context, message),
        bubbleKey: Key('chat-voice-${message.id}'),
        child: transcription == null
            ? null
            : _TranscriptionText(text: transcription),
      ),
    );
  }
}

class _TranscriptionText extends StatelessWidget {
  const _TranscriptionText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String display = text == '__unavailable__'
        ? l10n.chatVoiceNoteTranscriptionUnavailable
        : l10n.chatVoiceNoteTranscription(text);
    // No colour: the bubble's DefaultTextStyle already carries the side's ink,
    // so italics is the only override.
    return Text(display, style: const TextStyle(fontStyle: FontStyle.italic));
  }
}

class _LocationBubble extends StatelessWidget {
  const _LocationBubble({required this.message});

  final DeliveryChatMessage message;

  @override
  Widget build(BuildContext context) {
    final Color ink = JeebChatBubble.bodyInkOf(context, _sideOf(message));
    return JeebChatBubble(
      side: _sideOf(message),
      time: _timeOf(context, message),
      status: _statusOf(context, message),
      bubbleKey: Key('chat-location-${message.id}'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: Sizes.large, color: ink),
          const SizedBox(width: Spacing.xSmall),
          Flexible(
            child: Text(
              message.text.isEmpty
                  ? '${message.latitude?.toStringAsFixed(4)}, ${message.longitude?.toStringAsFixed(4)}'
                  : message.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
