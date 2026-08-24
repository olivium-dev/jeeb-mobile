import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';

/// S0-PUSH-10 — FCM PUSH PAYLOAD CONTRACT (Sprint-3 Contract 9b / 10b).
/// Locks the app's FCM-data-message RECEIVE contract field-for-field against the

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

    expect(fixture.keys.toSet(), kContractKeys,
        reason: 'fixture drifted from the FROZEN Contract 9b field set');

    expect(fixture.containsKey('title'), isTrue);
    expect(fixture.containsKey('body'), isTrue);

    expect(fixture['conversationId'], fixture['requestId']);
    expect(fixture['type'], 'chat');
  });

  test('the frozen 9b payload decodes through the real transport to a chat '
      'NotificationMessage that deep-links to the original thread', () async {
    final fixture = _loadContractFixture();

    final message = await _decodeThroughTransport(fixture);

    expect(message.category, NotificationCategory.chat);
    expect(message.id, fixture['messageId']);
    expect(message.title, fixture['title']);
    expect(message.body, fixture['body']);
    expect(deepLinkForMessage(message), '/chat/${fixture['conversationId']}');
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

    expect(withOtherSender.category, original.category);
    expect(withOtherSender.title, original.title);
    expect(withOtherSender.body, original.body);
    expect(deepLinkForMessage(withOtherSender),
        deepLinkForMessage(original));
    expect(original.data['senderId'], fixture['senderId']);
  });

  test('a nested single-quote `data` blob is hoisted by the transport decode '
      'so a chat push still resolves to /chat/<requestId>', () async {
    // The live gateway chat push nests routing fields inside a single
    final message = await _decodeThroughTransport(<String, dynamic>{
      'data': "{'conversationId': '99b73825-9383-4aec-987d-169c02d96f64', "
          "'requestId': '7a5dffbd-6c05-4068-9b79-0cec377cae0f', 'type': 'chat'}",
      'title': 'New message',
      'body': 'Customer here',
    });

    expect(message.category, NotificationCategory.chat);
    expect(
      deepLinkForMessage(message),
      '/chat/7a5dffbd-6c05-4068-9b79-0cec377cae0f',
    );
  });

  group('drift detection — a renamed or dropped field breaks the contract', () {
    test('a chat push is un-routable only when EVERY recognized routing key '
        'drifts (requestId is the proven primary key; conversationId a fallback)',
        () async {
      // Proven sprint-006/007 routing (notification_deep_link.dart): the chat
      final partialDrift = _loadContractFixture()
        ..['conversationIdX'] = '11111111-1111-4111-8111-111111111111'
        ..remove('conversationId');
      final resilient = await _decodeThroughTransport(partialDrift);
      expect(resilient.category, NotificationCategory.chat);
      expect(deepLinkForMessage(resilient),
          '/chat/${partialDrift['requestId']}');

      // A push is genuinely un-routable only when EVERY recognized routing key
      final fullDrift = _loadContractFixture()
        ..remove('conversationId')
        ..remove('requestId');
      final message = await _decodeThroughTransport(fullDrift);
      expect(message.category, NotificationCategory.chat);
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
      expect(message.body, isNotEmpty);
    });
  });

  test('Contract 9a guard: even if the gateway WRONGLY attaches an FCM '
      'notification block, the in-data title/body remain authoritative for '
      'category + deep link', () async {
    final fixture = _loadContractFixture();

    // A notification block must NOT change routing — the discriminator + ids
    final message = await _decodeThroughTransport(
      fixture,
      withNotificationBlock:
          const RemoteNotification(title: 'native', body: 'native'),
    );

    expect(message.category, NotificationCategory.chat);
    expect(deepLinkForMessage(message), '/chat/${fixture['conversationId']}');
  });

  test('run-19 push-D: a dual-stamped new_request payload '
      '(type=new_request + legacy category=delivery) decodes through the '
      'transport to category=newRequest and deep-links to the request screen '
      '— the KNOWN type wins over the legacy category so the jeeber tap lands '
      'on the request, not the order surface', () async {
    // NewRequestPushNotifier stamps BOTH a `type=new_request` discriminator and
    final message = await _decodeThroughTransport(<String, dynamic>{
      'messageId': 'msg-run19',
      'type': 'new_request',
      'category': 'delivery',
      'requestId': '7a5dffbd-6c05-4068-9b79-0cec377cae0f',
      'request_id': '7a5dffbd-6c05-4068-9b79-0cec377cae0f',
      'tierId': 'tier-gold',
      'title': 'New request nearby',
      'body': 'A customer needs a jeeber',
    });

    expect(message.category, NotificationCategory.newRequest);
    expect(
      deepLinkForMessage(message),
      '/jeeber/requests/7a5dffbd-6c05-4068-9b79-0cec377cae0f',
    );
  });

  // W6-T3 / CONTRACT §3 — the guard-2 auto-withdraw push. `type` is the
  // discriminator mobile routes on; `category` alone is the fallback rung.
  group('wallet-guard withdraw push → NotificationCategory.wallet', () {
    test('the frozen wire type resolves to wallet', () {
      expect(
        NotificationCategory.fromData(
          const {'type': 'offer_withdrawn_insufficient_balance'},
        ),
        NotificationCategory.wallet,
      );
    });

    test('the sibling wallet_insufficient_balance type resolves to wallet', () {
      expect(
        NotificationCategory.fromData(
          const {'type': 'wallet_insufficient_balance'},
        ),
        NotificationCategory.wallet,
      );
    });

    test('the upstream `jeeb.`-prefixed event type is prefix-normalised to '
        'wallet', () {
      expect(
        NotificationCategory.fromData(
          const {'type': 'jeeb.offer_withdrawn_insufficient_balance'},
        ),
        NotificationCategory.wallet,
      );
    });

    test('a category-only payload still lands on wallet (direct-fallback rung: '
        'the live route stamps category=wallet, the direct one category='
        'delivery — which is why routing is on `type` first)', () {
      expect(
        NotificationCategory.fromData(const {'category': 'wallet'}),
        NotificationCategory.wallet,
      );
    });
  });
}
