import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

/// S0-PUSH-10 — FCM PUSH PAYLOAD CONTRACT (Sprint-3 Contract 9b / 10b).
///
/// Locks the app's FCM-data-message RECEIVE contract field-for-field against the
/// FROZEN gateway `EventPushNotifier` chat `data` shape so any drift between the
/// gateway DTO and the app parser FAILS this suite. The committed fixture
/// `test/fixtures/fcm_chat_push_contract.json` IS the byte-shape both sides lock
/// to (sprint-03/contract.md §9b):
///
/// ```json
/// { "type":"chat", "conversationId":"<uuid>", "messageId":"<uuid>",
///   "senderId":"<author uuid>", "requestId":"<uuid>",
///   "title":"<string>", "body":"<preview>" }
/// ```
///
/// Unlike the pre-existing `notification_deep_link_test` / `chat_push_chain_6msg`
/// tests — which hand-build a `NotificationMessage` and so SKIP the real FCM
/// decode — every assertion here drives the production
/// `FirebaseMessagingTransport._toDomain` decode by feeding a real
/// data-only `RemoteMessage` through `initialMessage()` (the single shared
/// decoder used by the foreground, opened-app, and cold-start paths). That is
/// the surface Contract 10 (gateway) must match byte-for-byte.
///
/// Failing-first proof (lane notes): rename a field in the fixture file →
/// `the frozen 9b payload decodes...` + `the committed fixture locks...` go RED;
/// restore → GREEN.

/// The exact set of keys the FROZEN Contract 9b data block carries. The .NET
/// side (Contract 10b) asserts the same six required keys + `body`.
const Set<String> kContractKeys = <String>{
  'type',
  'conversationId',
  'messageId',
  'senderId',
  'requestId',
  'title',
  'body',
};

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

/// Loads the committed contract fixture as a raw map (the single source of
/// truth for the byte-shape — mutating the file flips the lock tests).
Map<String, dynamic> _loadContractFixture() {
  final raw =
      File('test/fixtures/fcm_chat_push_contract.json').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// Mirrors the push service's `data = {k: str(v)}` flatten — every FCM data
/// value arrives as a string on the wire.
Map<String, dynamic> _flattenToWire(Map<String, dynamic> data) =>
    data.map((key, value) => MapEntry(key, value?.toString() ?? ''));

/// Decodes [data] through the PRODUCTION transport exactly as a real inbound
/// FCM message would, asserting nothing — returns the parsed domain message.
/// [withNotificationBlock] models the contract-FORBIDDEN (Contract 9a) case
/// where the gateway wrongly attaches an FCM `notification` block.
Future<NotificationMessage> _decodeThroughTransport(
  Map<String, dynamic> data, {
  RemoteNotification? withNotificationBlock,
}) async {
  final messaging = _MockFirebaseMessaging();
  final remote = RemoteMessage(
    messageId: data['messageId']?.toString(),
    data: _flattenToWire(data),
    notification: withNotificationBlock,
    sentTime: DateTime.utc(2026, 6, 27),
  );
  when(() => messaging.getInitialMessage()).thenAnswer((_) async => remote);
  final transport = FirebaseMessagingTransport(messaging: messaging);
  final parsed = await transport.initialMessage();
  await transport.dispose();
  return parsed!;
}

void main() {
  test('the committed fixture is byte-shape-locked: EXACTLY the Contract 9b '
      'keys, data-only (title/body live INSIDE data), conversationId==requestId',
      () {
    final fixture = _loadContractFixture();

    // Field-for-field key lock — adding, removing, or renaming any key in the
    // fixture (i.e. drift from the gateway DTO) fails here.
    expect(fixture.keys.toSet(), kContractKeys,
        reason: 'fixture drifted from the FROZEN Contract 9b field set');

    // Contract 9a: a chat push is DATA-ONLY — title + body are required keys
    // INSIDE data (the bg isolate renders from data[title]/data[body]); there
    // is no separate FCM notification block.
    expect(fixture.containsKey('title'), isTrue);
    expect(fixture.containsKey('body'), isTrue);

    // 8a/9b convention: deliveryId == conversationId == requestId.
    expect(fixture['conversationId'], fixture['requestId']);
    expect(fixture['type'], 'chat');
  });

  test('the frozen 9b payload decodes through the real transport to a chat '
      'NotificationMessage that deep-links to the original thread', () async {
    final fixture = _loadContractFixture();

    final message = await _decodeThroughTransport(fixture);

    // type=chat discriminator resolves to the chat category (NOT `other`).
    expect(message.category, NotificationCategory.chat);
    // messageId is the dedup id/tag.
    expect(message.id, fixture['messageId']);
    // title/body recovered from data (data-only render contract).
    expect(message.title, fixture['title']);
    expect(message.body, fixture['body']);
    // conversationId (camelCase) is the deep-link key → original thread.
    expect(deepLinkForMessage(message), '/chat/${fixture['conversationId']}');
    // The full byte-shape survives onto the domain envelope's data map.
    expect(message.data.keys.toSet(), kContractKeys);
  });

  test('senderId is carried in data but NEVER drives parse/identity/routing '
      '(me-scoped drop — identity is resolved server-side from the bearer)',
      () async {
    final fixture = _loadContractFixture();
    final swapped = Map<String, dynamic>.from(fixture)
      ..['senderId'] = '99999999-9999-4999-8999-999999999999';

    final original = await _decodeThroughTransport(fixture);
    final withOtherSender = await _decodeThroughTransport(swapped);

    // Changing senderId changes nothing the app acts on.
    expect(withOtherSender.category, original.category);
    expect(withOtherSender.title, original.title);
    expect(withOtherSender.body, original.body);
    expect(deepLinkForMessage(withOtherSender),
        deepLinkForMessage(original));
    // It is merely passed through on data, not promoted to an identity field.
    expect(original.data['senderId'], fixture['senderId']);
  });

  group('drift detection — a renamed or dropped field breaks the contract', () {
    test('a chat push is un-routable only when EVERY recognized routing key '
        'drifts (requestId is the proven primary key; conversationId a fallback)',
        () async {
      // Proven sprint-006/007 routing (notification_deep_link.dart): the chat
      // thread resolves by requestId FIRST — the chat-detail screen looks the
      // conversation up via correlationKey == requestId, and routing by the
      // conversationId 404s that first probe. conversationId / snake-case
      // variants remain accepted fallbacks. So renaming conversationId ALONE is
      // NOT un-routable: requestId still resolves the thread (resilience).
      final partialDrift = _loadContractFixture()
        ..['conversationIdX'] = '11111111-1111-4111-8111-111111111111'
        ..remove('conversationId');
      final resilient = await _decodeThroughTransport(partialDrift);
      expect(resilient.category, NotificationCategory.chat);
      expect(deepLinkForMessage(resilient),
          '/chat/${partialDrift['requestId']}');

      // A push is genuinely un-routable only when EVERY recognized routing key
      // drifts/drops — the real contract regression this guard protects against.
      final fullDrift = _loadContractFixture()
        ..remove('conversationId')
        ..remove('requestId');
      final message = await _decodeThroughTransport(fullDrift);
      expect(message.category, NotificationCategory.chat);
      // No requestId / conversationId / snake / legacy key present → cannot
      // resolve the thread.
      expect(deepLinkForMessage(message), isNull);
    });

    test('renaming the `type` discriminator buckets the push as `other` and '
        'strips its deep link', () async {
      final drifted = _loadContractFixture()..['type'] = 'chatx';

      final message = await _decodeThroughTransport(drifted);

      expect(message.category, NotificationCategory.other);
      expect(deepLinkForMessage(message), isNull);
    });

    test('dropping `title` degrades the bg heads-up to an empty title '
        '(9b: title is required in data)', () async {
      final drifted = _loadContractFixture()..remove('title');

      final message = await _decodeThroughTransport(drifted);

      expect(message.title, '');
      // body still present, so the message is not wholly silent.
      expect(message.body, isNotEmpty);
    });
  });

  test('Contract 9a guard: even if the gateway WRONGLY attaches an FCM '
      'notification block, the in-data title/body remain authoritative for '
      'category + deep link', () async {
    final fixture = _loadContractFixture();

    // A notification block must NOT change routing — the discriminator + ids
    // live in data, which is the only path that deep-links in background.
    final message = await _decodeThroughTransport(
      fixture,
      withNotificationBlock:
          const RemoteNotification(title: 'native', body: 'native'),
    );

    expect(message.category, NotificationCategory.chat);
    expect(deepLinkForMessage(message), '/chat/${fixture['conversationId']}');
  });
}
