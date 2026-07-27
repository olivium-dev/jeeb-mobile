import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';

/// Who composed the message. The chat is always a 1:1 between the local user
/// and the counterpart for an active delivery; we keep the role enum on the
/// message so the bubble layout can flip without re-deriving authorship from
/// an id comparison at render time.
enum ChatAuthor { me, them }

/// Lifecycle status of an outgoing message. WhatsApp-style: a single tick once
/// the server has acknowledged delivery, double ticks once the counterpart's
/// device has confirmed read. Incoming messages carry [delivered] from the
/// moment they enter the cubit — the sender's status is what's rendered.
enum MessageStatus { sending, sent, delivered, read, failed }

/// Content kind. The new jeeb chat (parity with Al Rahma's chat-service)
/// extends the original `{text, photo}` MVP with seven additional kinds the
/// broadcasting/accepted/closed flows render natively:
///
///   - `voice`           — voice clip sent by either side (URL in payload)
///   - `image`           — image with a CDN URL (vs MVP `photo` in-memory bytes)
///   - `location`        — sharable lat/lng pin
///   - `system`          — generic system notice ("offer expired", "you joined")
///   - `offerCard`       — Jeeber's offer landing in the broadcasting chat
///   - `offerAccepted`   — system message marking the winning offer
///   - `offerRejected`   — system message marking a withdrawn / lost offer
///
/// `photo` is kept as the legacy MVP value; bubbles that need the in-memory
/// bytes still render through it. New code paths should prefer `image` for
/// CDN-hosted attachments.
enum MessageKind {
  text,
  photo,
  voice,
  image,
  location,
  system,
  offerCard,
  offerAccepted,
  offerRejected;

  /// Parses the wire-shape value emitted by the chat-service (`text`,
  /// `voice`, `offer_card`, …). Unknown values map to [text] so a new kind
  /// added on the backend doesn't crash an older mobile build.
  static MessageKind fromWire(String? raw) {
    switch (raw) {
      case 'text':
        return MessageKind.text;
      case 'photo':
        return MessageKind.photo;
      case 'voice':
        return MessageKind.voice;
      case 'image':
        return MessageKind.image;
      case 'location':
        return MessageKind.location;
      case 'system':
        return MessageKind.system;
      case 'offer':
      case 'offer_card':
        return MessageKind.offerCard;
      case 'offer_accepted':
        return MessageKind.offerAccepted;
      case 'offer_rejected':
        return MessageKind.offerRejected;
      default:
        return MessageKind.text;
    }
  }

  /// Wire-shape value the mobile sends back when posting a message — opposite
  /// direction of [fromWire].
  String get wireName {
    switch (this) {
      case MessageKind.text:
        return 'text';
      case MessageKind.photo:
        return 'photo';
      case MessageKind.voice:
        return 'voice';
      case MessageKind.image:
        return 'image';
      case MessageKind.location:
        return 'location';
      case MessageKind.system:
        return 'system';
      case MessageKind.offerCard:
        return 'offer_card';
      case MessageKind.offerAccepted:
        return 'offer_accepted';
      case MessageKind.offerRejected:
        return 'offer_rejected';
    }
  }

  bool get isSystemNotice =>
      this == MessageKind.system ||
      this == MessageKind.offerAccepted ||
      this == MessageKind.offerRejected;
}

/// Lifecycle a chat conversation moves through. Wire-shape values are
/// snake_case so they round-trip cleanly with the chat-service.
enum ConversationPhase {
  /// Request was just broadcast — multiple Jeeber are dropping offer cards
  /// in real time. Composer is hidden for everyone; the client picks a
  /// winner via [offerCard.acceptCta] which fires the accept saga.
  broadcasting,

  /// Client accepted an offer. The conversation is 1:1 with the winner;
  /// everyone else has been marked `removedAt`. Composer is visible.
  accepted,

  /// Delivery is `Done` (or the conversation otherwise terminated). The
  /// composer is hidden again; messages are read-only.
  closed,

  /// Fallback when the chat-service returns a phase we don't know about.
  unknown;

  static ConversationPhase fromWire(String? raw) {
    switch (raw) {
      case 'broadcasting':
        return ConversationPhase.broadcasting;
      case 'accepted':
        return ConversationPhase.accepted;
      case 'closed':
        return ConversationPhase.closed;
      default:
        return ConversationPhase.unknown;
    }
  }
}

/// Payload carried by an `offerCard` message in the broadcasting phase. The
/// shape mirrors the chat-service mock — what the client needs to render the
/// "Kamal Hajj • ★4.9 • $6 • ETA 20m • Accept" card without an extra fetch.
class OfferCardPayload extends Equatable {
  const OfferCardPayload({
    required this.offerId,
    required this.jeeberId,
    required this.jeeberName,
    this.jeeberAvatarUrl,
    this.rating = 0,
    this.ratingCount = 0,
    required this.fee,
    required this.currency,
    required this.etaMinutes,
    this.note = '',
  });

  factory OfferCardPayload.fromWire(Map<String, Object?> body) {
    final fee = body['fee'];
    final rating = body['rating'];
    return OfferCardPayload(
      offerId: body['offerId'] as String? ?? '',
      jeeberId: body['jeeberId'] as String? ?? '',
      jeeberName: body['jeeberName'] as String? ?? '',
      jeeberAvatarUrl: body['jeeberAvatarUrl'] as String?,
      rating: rating is num ? rating.toDouble() : 0,
      ratingCount: body['ratingCount'] as int? ?? 0,
      fee: fee is num ? fee.toDouble() : 0,
      currency: body['currency'] as String? ?? 'USD',
      etaMinutes: body['etaMinutes'] as int? ?? 0,
      note: body['note'] as String? ?? '',
    );
  }

  final String offerId;
  final String jeeberId;
  final String jeeberName;
  final String? jeeberAvatarUrl;
  final double rating;
  final int ratingCount;
  final double fee;
  final String currency;
  final int etaMinutes;
  final String note;

  @override
  List<Object?> get props => [
        offerId,
        jeeberId,
        jeeberName,
        jeeberAvatarUrl,
        rating,
        ratingCount,
        fee,
        currency,
        etaMinutes,
        note,
      ];
}

/// Payload carried by a system `offerAccepted` or `offerRejected` message —
/// enough for the bubble to say "Kamal Hajj's offer was accepted" without
/// re-fetching the offer row.
class SystemOfferPayload extends Equatable {
  const SystemOfferPayload({
    required this.offerId,
    required this.jeeberId,
    required this.jeeberName,
  });

  factory SystemOfferPayload.fromWire(Map<String, Object?> body) {
    return SystemOfferPayload(
      offerId: body['offerId'] as String? ?? '',
      jeeberId: (body['winnerJeeberId'] ?? body['jeeberId']) as String? ?? '',
      jeeberName: (body['winnerJeeberName'] ?? body['jeeberName']) as String? ??
          '',
    );
  }

  final String offerId;
  final String jeeberId;
  final String jeeberName;

  @override
  List<Object?> get props => [offerId, jeeberId, jeeberName];
}

/// Immutable record of a single chat message rendered by the delivery
/// photo-chat UI (T-mobile-016). Distinct from the canonical wire-shape
/// `ChatMessage` (LEAD pin JEB-1423 #14900) which the connection cubit and
/// outbox exchange with the chat-service.
class DeliveryChatMessage extends Equatable {
  const DeliveryChatMessage._({
    required this.id,
    required this.author,
    required this.sentAt,
    required this.status,
    required this.kind,
    this.hasServerTimestamp = true,
    this.text = '',
    this.photoBytes,
    this.photoSource,
    this.imageUrl,
    this.voiceUrl,
    this.voiceDurationMs,
    this.voiceTranscription,
    this.latitude,
    this.longitude,
    this.offerPayload,
    this.systemOfferPayload,
  });

  factory DeliveryChatMessage.text({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required String text,
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.text,
        text: text,
      );

  factory DeliveryChatMessage.photo({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required Uint8List bytes,
    required PhotoSource source,
    String caption = '',
  }) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
        kind: MessageKind.photo,
        text: caption,
        photoBytes: bytes,
        photoSource: source,
      );

  /// Network-hosted image — the post-MVP replacement for `photo`. The cubit
  /// uses this for inbound messages once the CDN is wired.
  factory DeliveryChatMessage.image({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required String url,
    String caption = '',

    /// P4/P5: locally-held bytes for this image, when available — the sender's
    /// own just-captured frame (renders instantly, no round trip) or a peer
    /// image already resolved through the CDN read proxy. Null → the bubble
    /// falls back to [url].
    Uint8List? bytes,
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.image,
        text: caption,
        imageUrl: url,
        photoBytes: bytes,
      );

  factory DeliveryChatMessage.voice({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required String url,
    int durationMs = 0,
    String? transcription,
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.voice,
        voiceUrl: url,
        voiceDurationMs: durationMs,
        voiceTranscription: transcription,
      );

  factory DeliveryChatMessage.location({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required double lat,
    required double lng,
    String label = '',
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.location,
        text: label,
        latitude: lat,
        longitude: lng,
      );

  factory DeliveryChatMessage.system({
    required String id,
    required DateTime sentAt,
    required String text,
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        // System messages are render-only — author is forced to `them` so the
        // bubble doesn't pretend the local user authored a server notice.
        author: ChatAuthor.them,
        sentAt: sentAt,
        status: MessageStatus.delivered,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.system,
        text: text,
      );

  factory DeliveryChatMessage.offerCard({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required OfferCardPayload payload,
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.offerCard,
        offerPayload: payload,
      );

  factory DeliveryChatMessage.offerAccepted({
    required String id,
    required DateTime sentAt,
    required SystemOfferPayload payload,
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        author: ChatAuthor.them,
        sentAt: sentAt,
        status: MessageStatus.delivered,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.offerAccepted,
        systemOfferPayload: payload,
      );

  factory DeliveryChatMessage.offerRejected({
    required String id,
    required DateTime sentAt,
    required SystemOfferPayload payload,
    bool hasServerTimestamp = true,
  }) => DeliveryChatMessage._(
        id: id,
        author: ChatAuthor.them,
        sentAt: sentAt,
        status: MessageStatus.delivered,
        hasServerTimestamp: hasServerTimestamp,
        kind: MessageKind.offerRejected,
        systemOfferPayload: payload,
      );

  final String id;
  final ChatAuthor author;

  /// When the message was sent — OR, when [hasServerTimestamp] is false, an
  /// ordering anchor with no absolute meaning. Always read the flag first.
  final DateTime sentAt;
  final MessageStatus status;
  final MessageKind kind;

  // ---------------------------------------------------------------------------
  // Rows the server did not date
  // ---------------------------------------------------------------------------
  //
  // A history row is a REAL message even when the wire carries no usable
  // timestamp. The decoder used to reject such a row outright, which turned a
  // full thread into a rendered empty state (the bilateral empty-thread
  // defect). It now decodes the row and puts an ORDERING ANCHOR in [sentAt].
  //
  // An anchor has to satisfy two things at once:
  //   * ORDER — the timeline is sorted by [sentAt] (`ChatCubit._ordered`), so
  //     the anchor has to encode the row's position in the server's array,
  //     which is the only sequence information an undated row carries.
  //   * HONESTY — an anchor is not a send time, so nothing may render it as one.
  //
  // Honesty used to be derived from the VALUE: an anchor was "any [sentAt]
  // inside 1970-01-01", which forced every anchor to the epoch and cost twice.
  // Ordering: an undated counterpart row sorted below EVERY locally composed
  // bubble (which keeps the real clock), so a live thread read "all of theirs,
  // then all of mine" for the whole session. Honesty: any consumer that forgot
  // the window check rendered a 1970 date divider, a 00:00 clock, or a TTL that
  // expired 56 years ago — a whole class of bug one missed call away.
  //
  // The flag is now carried explicitly, which frees the anchor to be whatever
  // the timeline finds useful. `ChatCubit` re-bases undated rows into a band
  // immediately BELOW the earliest dated message in the thread, preserving the
  // server's array order — so nothing lands in 1970 and nothing outranks a
  // message that carries a real clock.

  /// True when [sentAt] is a real send time (server `created_at`, or the local
  /// clock for a message this device composed / a live frame stamped at
  /// arrival). False when it is an ordering anchor: the message still renders,
  /// but no surface may present [sentAt] as a clock, a date, or a TTL base.
  final bool hasServerTimestamp;

  /// Text body for text messages; photo/image caption for photo/image
  /// messages; system-notice copy for `system` kind.
  final String text;

  /// Compressed JPEG bytes for legacy MVP photo messages.
  final Uint8List? photoBytes;

  /// Source the photo came from. Mainly retained for analytics.
  final PhotoSource? photoSource;

  /// CDN URL for `image` kind messages.
  final String? imageUrl;

  /// CDN URL for `voice` kind messages.
  final String? voiceUrl;
  final int? voiceDurationMs;

  /// AI-generated transcription for `voice` kind messages. Null until the
  /// upload resolves or if transcription timed out (shown as "unavailable").
  final String? voiceTranscription;

  /// Lat/lng for `location` kind messages.
  final double? latitude;
  final double? longitude;

  /// Payload for `offerCard` kind messages.
  final OfferCardPayload? offerPayload;

  /// Payload for `offerAccepted` / `offerRejected` system messages.
  final SystemOfferPayload? systemOfferPayload;

  bool get isMine => author == ChatAuthor.me;
  bool get isPhoto => kind == MessageKind.photo;
  bool get isText => kind == MessageKind.text;
  bool get isSystemNotice => kind.isSystemNotice;
  bool get isOfferCard => kind == MessageKind.offerCard;

  DeliveryChatMessage copyWith({
    MessageStatus? status,
    String? voiceTranscription,

    /// Re-base this message's ORDERING ANCHOR. Only meaningful when
    /// [hasServerTimestamp] is false: `ChatCubit` lays the undated rows of a
    /// thread out relative to its dated ones, so the anchor a decoder handed
    /// out is provisional. Passing this on a DATED message would forge a send
    /// time — the timeline never does.
    DateTime? sentAt,

    /// Locally-held attachment bytes. A re-decode of the same wire row carries
    /// the CDN ref but not the bytes the device already holds, so reconciling a
    /// row onto an existing one carries them across rather than blinking the
    /// image back to its placeholder.
    Uint8List? photoBytes,
  }) {
    return DeliveryChatMessage._(
      id: id,
      author: author,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      hasServerTimestamp: hasServerTimestamp,
      kind: kind,
      text: text,
      photoBytes: photoBytes ?? this.photoBytes,
      photoSource: photoSource,
      imageUrl: imageUrl,
      voiceUrl: voiceUrl,
      voiceDurationMs: voiceDurationMs,
      voiceTranscription: voiceTranscription ?? this.voiceTranscription,
      latitude: latitude,
      longitude: longitude,
      offerPayload: offerPayload,
      systemOfferPayload: systemOfferPayload,
    );
  }

  @override
  List<Object?> get props => [
        id,
        author,
        sentAt,
        status,
        hasServerTimestamp,
        kind,
        text,
        photoBytes?.length,
        photoSource,
        imageUrl,
        voiceUrl,
        voiceDurationMs,
        voiceTranscription,
        latitude,
        longitude,
        offerPayload,
        systemOfferPayload,
      ];
}
