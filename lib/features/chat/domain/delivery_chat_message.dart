import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';

/// Kept on message to avoid re-deriving authorship from id at render time.
enum ChatAuthor { me, them }

enum MessageStatus { sending, sent, delivered, read, failed }

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

  /// Unknown wire values map to [text] so new kinds don't crash old builds.
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

enum ConversationPhase {
  broadcasting,
  accepted,
  closed,
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

class DeliveryChatMessage extends Equatable {
  const DeliveryChatMessage._({
    required this.id,
    required this.author,
    required this.sentAt,
    required this.status,
    required this.kind,
    this.hasServerTimestamp = true,
    this.orderAnchor,
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
    this.imageLoadFailed = false,
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

  factory DeliveryChatMessage.image({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required String url,
    String caption = '',
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
  final DateTime sentAt;
  final MessageStatus status;
  final MessageKind kind;
  /// Set by the codec from the wire, NOT derived from [sentAt]: an undated row
  /// keeps a real fallback [sentAt], so any derived getter would wrongly say true.
  final bool hasServerTimestamp;
  /// TRAP: minted once at compose, dropped by server echo; never mutate in copyWith.
  final DateTime? orderAnchor;

  DateTime get sortAt => orderAnchor ?? sentAt;

  final String text;
  final Uint8List? photoBytes;
  final PhotoSource? photoSource;
  final String? imageUrl;
  final String? voiceUrl;
  final int? voiceDurationMs;

  final String? voiceTranscription;

  final double? latitude;
  final double? longitude;
  final OfferCardPayload? offerPayload;
  final SystemOfferPayload? systemOfferPayload;

  /// The bytes behind [imageUrl] could not be fetched — the tile offers a
  /// reload instead of a permanent placeholder (F36).
  final bool imageLoadFailed;

  bool get isMine => author == ChatAuthor.me;
  bool get isPhoto => kind == MessageKind.photo;
  bool get isText => kind == MessageKind.text;
  bool get isSystemNotice => kind.isSystemNotice;
  bool get isOfferCard => kind == MessageKind.offerCard;

  DeliveryChatMessage copyWith({
    MessageStatus? status,
    String? voiceTranscription,
    DateTime? sentAt,
    Uint8List? photoBytes,
    bool? imageLoadFailed,
  }) {
    return DeliveryChatMessage._(
      id: id,
      author: author,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      hasServerTimestamp: hasServerTimestamp,
      // TRAP: anchor minted once at compose, dropped at server echo; copyWith never changes it.
      orderAnchor: orderAnchor,
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
      imageLoadFailed: imageLoadFailed ?? this.imageLoadFailed,
    );
  }

  /// Only way to set orderAnchor.
  DeliveryChatMessage anchoredAt(DateTime anchor) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
        hasServerTimestamp: hasServerTimestamp,
        orderAnchor: anchor,
        kind: kind,
        text: text,
        photoBytes: photoBytes,
        photoSource: photoSource,
        imageUrl: imageUrl,
        voiceUrl: voiceUrl,
        voiceDurationMs: voiceDurationMs,
        voiceTranscription: voiceTranscription,
        latitude: latitude,
        longitude: longitude,
        offerPayload: offerPayload,
        systemOfferPayload: systemOfferPayload,
        imageLoadFailed: imageLoadFailed,
      );

  @override
  List<Object?> get props => [
        id,
        author,
        sentAt,
        status,
        hasServerTimestamp,
        orderAnchor,
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
        imageLoadFailed,
      ];
}
