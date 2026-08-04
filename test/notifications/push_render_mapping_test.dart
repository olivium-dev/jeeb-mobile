import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/notifications/domain/push_render_mapping.dart';

Map<String, String> _frozenChatData({
  required String conversationId,
  required String messageId,
  required String senderId,
  String title = 'New message',
  String body = 'see you at the door',
}) {
  // Exactly the Contract 9b field shape: all values strings, camelCase
  return <String, String>{
    'type': 'chat',
    'conversationId': conversationId,
    'messageId': messageId,
    'senderId': senderId,
    'requestId': conversationId,
    'title': title,
    'body': body,
  };
}

void main() {
  group('Contract 9b — frozen chat data-message → render fields', () {
    test('maps every field of the frozen byte-shape onto the heads-up', () {
      final data = _frozenChatData(
        conversationId: 'conv-uuid-1',
        messageId: 'msg-uuid-1',
        senderId: 'author-uuid-1',
      );

      final fields = PushRenderFields.fromData(data, messageId: 'msg-uuid-1');

      expect(fields.category, NotificationCategory.chat);
      expect(fields.title, 'New message');
      expect(fields.body, 'see you at the door');
      // messageId is the dedup tag (Contract 9b: two pushes same id collapse).
      expect(fields.dedupTag, 'msg-uuid-1');
      // conversationId (camelCase) is the deep-link key → original thread.
      expect(fields.deepLinkPath, '/chat/conv-uuid-1');
    });

    test('type=chat is NOT bucketed as other (un-routable regression)', () {
      final data = _frozenChatData(
        conversationId: 'c',
        messageId: 'm',
        senderId: 's',
      );
      // Drop the explicit title/body to prove `type` alone routes it.
      data.remove('title');
      data.remove('body');

      final fields = PushRenderFields.fromData(data);

      expect(fields.category, NotificationCategory.chat);
      expect(fields.deepLinkPath, '/chat/c');
    });
  });

  group('Contract 9c.1/9c.2 — foreground ≡ background parity', () {
    test('fromData (bg/data-only) ≡ fromMessage (fg) for one payload', () {
      final data = _frozenChatData(
        conversationId: 'conv-parity',
        messageId: 'msg-parity',
        senderId: 'author-parity',
      );

      // Background/data-only path: built straight from the FCM data map.
      final bg = PushRenderFields.fromData(data, messageId: 'msg-parity');

      // Foreground path: the transport first parses to NotificationMessage
      final domain = NotificationMessage(
        id: 'msg-parity',
        category: NotificationCategory.fromData(data),
        title: data['title']!,
        body: data['body']!,
        receivedAt: DateTime.utc(2026, 6, 28),
        data: data,
      );
      final fg = PushRenderFields.fromMessage(domain);

      expect(fg.title, bg.title);
      expect(fg.body, bg.body);
      expect(fg.dedupTag, bg.dedupTag);
      expect(fg.deepLinkPath, bg.deepLinkPath);
      expect(fg.category, bg.category);
    });
  });

  group('Contract 9c.3 — both directions render identically', () {
    test('client→jeeber and jeeber→client differ only in senderId', () {
      const conversationId = 'conv-twoway';
      final clientToJeeber = PushRenderFields.fromData(
        _frozenChatData(
          conversationId: conversationId,
          messageId: 'm-out',
          senderId: 'client-uuid',
          body: 'on my way',
        ),
        messageId: 'm-out',
      );
      final jeeberToClient = PushRenderFields.fromData(
        _frozenChatData(
          conversationId: conversationId,
          messageId: 'm-in',
          senderId: 'jeeber-uuid',
          body: 'on my way',
        ),
        messageId: 'm-in',
      );

      // The recipient (non-author) renders one heads-up either way; the app
      expect(clientToJeeber.title, jeeberToClient.title);
      expect(clientToJeeber.body, jeeberToClient.body);
      expect(clientToJeeber.category, jeeberToClient.category);
      expect(clientToJeeber.deepLinkPath, '/chat/$conversationId');
      expect(jeeberToClient.deepLinkPath, '/chat/$conversationId');
      // Distinct messageIds → distinct dedup tags → no false collapse.
      expect(clientToJeeber.dedupTag, isNot(jeeberToClient.dedupTag));
    });
  });

  group('Contract 9b defensive defaults — never blank, never crash', () {
    test('missing title falls back to generic; missing body → empty', () {
      final fields = PushRenderFields.fromData(const {
        'type': 'chat',
        'conversationId': 'c-1',
      });

      expect(fields.title, PushRenderFields.genericTitle);
      expect(fields.body, '');
      expect(fields.deepLinkPath, '/chat/c-1');
    });

    test('unknown type renders a heads-up but no-ops on tap (no crash)', () {
      final fields = PushRenderFields.fromData(const {
        'type': 'mystery',
        'title': 'Heads up',
      });

      expect(fields.category, NotificationCategory.other);
      expect(fields.title, 'Heads up');
      expect(fields.deepLinkPath, isNull);
    });

    test('payload with no id yields a null dedup tag (caller synthesises)', () {
      final fields = PushRenderFields.fromData(const {
        'type': 'chat',
        'conversationId': 'c-2',
        'title': 'hi',
      });

      expect(fields.dedupTag, isNull);
    });
  });
}
