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

/// Content kind. Photo messages keep their bytes in-memory (the picker output)
/// so the bubble can render them through a [MemoryImage] without a round trip
/// to the network during the MVP. A real backend run would upload the bytes
/// and swap in a CDN URL; the cubit's gateway hook lives for that swap.
enum MessageKind { text, photo }

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
    this.text = '',
    this.photoBytes,
    this.photoSource,
  });

  factory DeliveryChatMessage.text({
    required String id,
    required ChatAuthor author,
    required DateTime sentAt,
    required MessageStatus status,
    required String text,
  }) => DeliveryChatMessage._(
        id: id,
        author: author,
        sentAt: sentAt,
        status: status,
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

  final String id;
  final ChatAuthor author;
  final DateTime sentAt;
  final MessageStatus status;
  final MessageKind kind;

  /// Text body for text messages; photo caption (optional) for photo messages.
  final String text;

  /// Compressed JPEG bytes for photo messages. Null for text messages.
  final Uint8List? photoBytes;

  /// Source the photo came from. Mainly retained for analytics; the bubble
  /// renders the same regardless of camera vs gallery.
  final PhotoSource? photoSource;

  bool get isMine => author == ChatAuthor.me;
  bool get isPhoto => kind == MessageKind.photo;
  bool get isText => kind == MessageKind.text;

  DeliveryChatMessage copyWith({MessageStatus? status}) {
    return DeliveryChatMessage._(
      id: id,
      author: author,
      sentAt: sentAt,
      status: status ?? this.status,
      kind: kind,
      text: text,
      photoBytes: photoBytes,
      photoSource: photoSource,
    );
  }

  @override
  List<Object?> get props => [
        id,
        author,
        sentAt,
        status,
        kind,
        text,
        photoBytes?.length,
        photoSource,
      ];
}
