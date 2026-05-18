// QA-PRE for JEB-1423 (T-MOB-FIX-005). Smoke-binds the surface that the OLD
// (T-mobile-016) presentation feature relies on, after ENG (JEB-1425) renames
// the current `ChatMessage` (delivery photo-chat UI) to `DeliveryChatMessage`
// per the LEAD pin (comment #14900, Decision 5).
//
// State on main: `lib/features/chat/domain/delivery_chat_message.dart` does
// NOT yet exist. Per the hardened DoD on JEB-1424, this test is EXPECTED to
// compile-fail until ENG creates the file with the class+enum surface below.
// Post-ENG, it must pass — it pins the API contract for the 8 OLD callers:
//
//   1. lib/features/chat/application/chat_cubit.dart
//   2. lib/features/chat/application/chat_state.dart
//   3. lib/features/chat/domain/chat_gateway.dart
//   4. lib/features/chat/data/in_memory_chat_gateway.dart
//   5. lib/features/chat/presentation/chat_screen.dart
//   6. lib/features/chat/presentation/widgets/chat_message_bubble.dart
//   7. test/chat_cubit_test.dart
//   8. test/chat_screen_test.dart
//
// Surface pinned: `.text(...)` + `.photo(...)` factories, getters
// (id/author/sentAt/status/kind/text/photoBytes/photoSource/isMine/isPhoto/
// isText), `copyWith(status:)`, and the three sibling enums (ChatAuthor,
// MessageStatus, MessageKind). If ENG drops any of these in the rename, this
// smoke catches it before chat_cubit_test/chat_screen_test do.

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
      // disappears in the rename, the bubble loses a case and CI fails.
      expect(MessageStatus.values.map((s) => s.name).toSet(), <String>{
        'sending',
        'sent',
        'delivered',
        'read',
        'failed',
      });
    });

    test('MessageKind has text and photo', () {
      expect(MessageKind.values.toSet(), <MessageKind>{
        MessageKind.text,
        MessageKind.photo,
      });
    });
  });
}
