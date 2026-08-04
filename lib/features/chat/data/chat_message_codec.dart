import '../domain/delivery_chat_message.dart';

const Set<String> kSupportedMessageKinds = <String>{
  'text',
  'photo',
  'voice',
  'image',
  'location',
  'system',
  'offer',
  'offer_card',
  'offer_accepted',
  'offer_rejected',
};

class ChatMessageCodec {
  const ChatMessageCodec(this.currentUserId);

  final String currentUserId;

  static bool isValidRow(Map<String, dynamic> row) {
    final id = row['message_id'] ?? row['id'];
    if (id is! String || id.trim().isEmpty) return false;

    final senderId = row['author_id'] ?? row['senderId'];
    if (senderId is! String || senderId.trim().isEmpty) return false;

    final kind = row['kind'];
    if (kind is! String || !kSupportedMessageKinds.contains(kind)) return false;

    final rawBody = row['body'] ?? row['payload'];
    if (rawBody is! Map && rawBody is! String) return false;
    return true;
  }

  DeliveryChatMessage parse(
    Map<String, dynamic> json, {
    DateTime? fallbackSentAt,
  }) {
    final id =
        (json['message_id'] as String?) ?? (json['id'] as String?) ?? '';
    final senderId =
        (json['author_id'] as String?) ?? (json['senderId'] as String?) ?? '';
    final author = senderId == currentUserId ? ChatAuthor.me : ChatAuthor.them;
    final wireSentAt = sentAtOf(json);
    final sentAt = wireSentAt ?? fallbackSentAt ?? DateTime.now();
    final hasServerTimestamp = wireSentAt != null || fallbackSentAt == null;
    final kind = MessageKind.fromWire(json['kind'] as String?);
    final rawBody = json['body'] ?? json['payload'];
    final Map<String, Object?> body;
    if (rawBody is Map) {
      body = rawBody.cast<String, Object?>();
    } else if (rawBody is String) {
      body = <String, Object?>{'text': rawBody};
    } else {
      body = const <String, Object?>{};
    }
    return build(
      id: id,
      author: author,
      sentAt: sentAt,
      hasServerTimestamp: hasServerTimestamp,
      kind: kind,
      body: body,
    );
  }

  static DateTime? sentAtOf(Map<String, dynamic> json) {
    final raw = json['createdAt'] ??
        json['created_at'] ??
        json['sentAt'] ??
        json['sent_at'];
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || parsed.year <= 1) return null;
    return parsed.toLocal();
  }

  DeliveryChatMessage build({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required bool hasServerTimestamp,
    required MessageKind kind,
    required Map<String, Object?> body,
  }) {
    const status = MessageStatus.delivered;
    switch (kind) {
      case MessageKind.text:
        return DeliveryChatMessage.text(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          text: body['text'] as String? ?? '',
        );
      case MessageKind.image:
        return DeliveryChatMessage.image(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          url: body['url'] as String? ?? '',
          caption: body['caption'] as String? ?? '',
        );
      case MessageKind.voice:
        return DeliveryChatMessage.voice(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          url: body['url'] as String? ?? '',
          durationMs: body['durationMs'] as int? ?? 0,
        );
      case MessageKind.location:
        final lat = body['lat'];
        final lng = body['lng'];
        return DeliveryChatMessage.location(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          lat: lat is num ? lat.toDouble() : 0,
          lng: lng is num ? lng.toDouble() : 0,
          label: body['label'] as String? ?? '',
        );
      case MessageKind.system:
        return DeliveryChatMessage.system(
          id: id,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          text: body['text'] as String? ?? '',
        );
      case MessageKind.offerCard:
        return DeliveryChatMessage.offerCard(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          payload: OfferCardPayload.fromWire(body),
        );
      case MessageKind.offerAccepted:
        return DeliveryChatMessage.offerAccepted(
          id: id,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          payload: SystemOfferPayload.fromWire(body),
        );
      case MessageKind.offerRejected:
        return DeliveryChatMessage.offerRejected(
          id: id,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          payload: SystemOfferPayload.fromWire(body),
        );
      case MessageKind.photo:
        return DeliveryChatMessage.image(
          id: id,
          author: author,
          sentAt: sentAt,
          hasServerTimestamp: hasServerTimestamp,
          status: status,
          url: '',
          caption: body['caption'] as String? ?? '',
        );
    }
  }
}
