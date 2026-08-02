// QA-PRE for JEB-1423 (T-MOB-FIX-005). Smoke-binds the surface that the OLD

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';

void main() {
  group('DeliveryChatMessage (post-rename) surface contract', () {
    test('text factory exposes the pinned getters', () {
      final msg = DeliveryChatMessage.text(
        id: 'm-1',
        author: ChatAuthor.me,
        sentAt: DateTime.utc(2026, 5, 17, 9, 0),
        status: MessageStatus.sending,
        text: 'hello',
      );
      expect(msg.id, 'm-1');
      expect(msg.author, ChatAuthor.me);
      expect(msg.sentAt, DateTime.utc(2026, 5, 17, 9, 0));
      expect(msg.status, MessageStatus.sending);
      expect(msg.kind, MessageKind.text);
      expect(msg.text, 'hello');
      expect(msg.photoBytes, isNull);
      expect(msg.photoSource, isNull);
      expect(msg.isText, isTrue);
      expect(msg.isPhoto, isFalse);
      expect(msg.isMine, isTrue);
    });

    test('photo factory exposes the pinned getters', () {
      final bytes = Uint8List.fromList(const [1, 2, 3, 4]);
      final msg = DeliveryChatMessage.photo(
        id: 'm-2',
        author: ChatAuthor.them,
        sentAt: DateTime.utc(2026, 5, 17, 9, 1),
        status: MessageStatus.delivered,
        bytes: bytes,
        source: PhotoSource.camera,
      );
      expect(msg.id, 'm-2');
      expect(msg.author, ChatAuthor.them);
      expect(msg.kind, MessageKind.photo);
      expect(msg.photoBytes, bytes);
      expect(msg.photoSource, PhotoSource.camera);
      expect(msg.text, isEmpty);
      expect(msg.isPhoto, isTrue);
      expect(msg.isText, isFalse);
      expect(msg.isMine, isFalse);
    });

    test('photo factory accepts a caption', () {
      final msg = DeliveryChatMessage.photo(
        id: 'm-3',
        author: ChatAuthor.me,
        sentAt: DateTime.utc(2026, 5, 17),
        status: MessageStatus.sending,
        bytes: Uint8List.fromList(const [9, 9, 9]),
        source: PhotoSource.gallery,
        caption: 'look',
      );
      expect(msg.text, 'look');
    });

    test('copyWith(status:) returns a DeliveryChatMessage with new status', () {
      final msg = DeliveryChatMessage.text(
        id: 'm-4',
        author: ChatAuthor.me,
        sentAt: DateTime.utc(2026, 5, 17),
        status: MessageStatus.sending,
        text: 'hi',
      );
      final updated = msg.copyWith(status: MessageStatus.sent);
      expect(updated, isA<DeliveryChatMessage>());
      expect(updated.status, MessageStatus.sent);
      expect(updated.id, 'm-4');
      expect(updated.text, 'hi');
      expect(updated.author, ChatAuthor.me);
    });
  });

  group('Sibling enums survive the rename', () {
    test('ChatAuthor has me and them', () {
      expect(ChatAuthor.values, containsAll(<ChatAuthor>[
        ChatAuthor.me,
        ChatAuthor.them,
      ]));
    });

    test('MessageStatus has sending, sent, delivered, read, failed', () {
      // chat_message_bubble.dart switches on every one of these; if any value
      expect(MessageStatus.values.map((s) => s.name).toSet(), <String>{
        'sending',
        'sent',
        'delivered',
        'read',
        'failed',
      });
    });

    test('MessageKind keeps text + photo and adds the new chat kinds', () {
      // Legacy invariant — the MVP photo chat still relies on these two.
      expect(
        MessageKind.values.toSet(),
        containsAll(<MessageKind>{MessageKind.text, MessageKind.photo}),
      );
      // The unified jeeb chat (parity with Al Rahma's chat-service) extends
      expect(MessageKind.values.toSet(), <MessageKind>{
        MessageKind.text,
        MessageKind.photo,
        MessageKind.voice,
        MessageKind.image,
        MessageKind.location,
        MessageKind.system,
        MessageKind.offerCard,
        MessageKind.offerAccepted,
        MessageKind.offerRejected,
      });
    });
  });
}
