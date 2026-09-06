// G3 REGRESSION GUARD (run-24 CHECK D): the test that would have CAUGHT the

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/data/shared_prefs_local_push_inbox.dart';
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
      'the REAL background entry-point persists a durable inbox row for a '
      'dismissed new_request push (G3 — this is what unit tests missed)',
      () async {
    // A new_request push exactly as jeeb-gateway's NewRequestPushNotifier sends
    const message = RemoteMessage(
      messageId: 'bg-msg-1',
      data: <String, dynamic>{
        'type': 'new_request',
        'category': 'delivery', // legacy stamp — must NOT win
        'requestId': 'req-42',
      },
      notification: RemoteNotification(
        title: 'New request nearby',
        body: '2 shawarma + cola from Barbar',
      ),
    );

    // Drive the ACTUAL FCM background isolate entry-point.
    await firebaseMessagingBackgroundHandler(message);

    final prefs = await SharedPreferences.getInstance();
    final inbox = SharedPrefsLocalPushInbox(prefs: prefs);
    final records = await inbox.readAll();

    expect(records, hasLength(1),
        reason: 'a dismissed background push must leave a durable trail');
    final record = records.single;
    expect(record.type, kNewRequestPushType);
    expect(record.ref, 'req-42', reason: 'requestId must ride the ref chain');
    expect(record.title, 'New request nearby');
    expect(record.read, isFalse);
    expect(record.seenInFeed, isFalse);
  });

  test('a background new_request push produces a Dashboard-tab badge on hydrate',
      () async {
    const message = RemoteMessage(
      messageId: 'bg-msg-2',
      data: <String, dynamic>{'type': 'new_request', 'requestId': 'req-7'},
      notification: RemoteNotification(title: 't', body: 'b'),
    );
    await firebaseMessagingBackgroundHandler(message);

    // The main-isolate cubit re-derives its counts from the SAME store on
    final prefs = await SharedPreferences.getInstance();
    final badge = BadgeCountCubit(inbox: SharedPrefsLocalPushInbox(prefs: prefs));
    addTearDown(badge.close);

    expect(badge.state, const BadgeCounts(),
        reason: 'a fresh cubit starts empty (background isolate never touched it)');
    await badge.hydrate();
    expect(badge.state.newRequests, 1,
        reason: 'hydrate surfaces the background push as a feed-tab badge (G3)');
    expect(badge.state.unread, 1);
  });

  test('a background push of a NON-new_request type is NOT persisted locally '
      '(the server inbox already sources it — no double row)', () async {
    const message = RemoteMessage(
      messageId: 'bg-msg-3',
      data: <String, dynamic>{'type': 'chat', 'conversationId': 'c-1'},
      notification: RemoteNotification(title: 'msg', body: 'hi'),
    );
    await firebaseMessagingBackgroundHandler(message);

    final prefs = await SharedPreferences.getInstance();
    final inbox = SharedPrefsLocalPushInbox(prefs: prefs);
    expect(await inbox.readAll(), isEmpty,
        reason: 'chat/offer are server-sourced; local persistence would double');
  });

  const driverMessage = RemoteMessage(
    messageId: 'bg-aud-1',
    data: <String, dynamic>{
      'type': 'new_request',
      'requestId': 'req-aud',
      'audience_role': 'driver',
    },
    notification: RemoteNotification(title: 't', body: 'b'),
  );

  test(
      'AUDIENCE GUARD (C-3): a client-only roles snapshot drops a driver '
      'new_request — no inbox row, no badge', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RoleAvailabilityCubit.availableRolesPrefKey: <String>['client'],
    });
    await firebaseMessagingBackgroundHandler(driverMessage);

    final prefs = await SharedPreferences.getInstance();
    final inbox = SharedPrefsLocalPushInbox(prefs: prefs);
    expect(await inbox.readAll(), isEmpty,
        reason: 'a customer-only session must not accrue jeeber inbox rows');
    final badge = BadgeCountCubit(inbox: inbox);
    addTearDown(badge.close);
    await badge.hydrate();
    expect(badge.state.newRequests, 0, reason: 'no row ⇒ no badge');
  });

  test(
      'FAIL-OPEN: an ABSENT roles snapshot persists the driver row unchanged '
      '(never gate on the active role)', () async {
    // setUp cleared prefs, so no snapshot key exists — pre-getMe state.
    await firebaseMessagingBackgroundHandler(driverMessage);

    final prefs = await SharedPreferences.getInstance();
    final records = await SharedPrefsLocalPushInbox(prefs: prefs).readAll();
    expect(records, hasLength(1),
        reason: 'unknown roles must never eat a push');
    expect(records.single.ref, 'req-aud');
  });

  test('a dual-role (jeeber) snapshot keeps the driver row', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      RoleAvailabilityCubit.availableRolesPrefKey: <String>[
        'client',
        'jeeber',
      ],
    });
    await firebaseMessagingBackgroundHandler(driverMessage);

    final prefs = await SharedPreferences.getInstance();
    final records = await SharedPrefsLocalPushInbox(prefs: prefs).readAll();
    expect(records, hasLength(1));
    expect(records.single.ref, 'req-aud');
  });

  test(
      'WRITE↔READ contract: RoleAvailabilityCubit persists the exact snapshot '
      'the background isolate gates on', () async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = RoleAvailabilityCubit(const RoleAvailability(), prefs);
    addTearDown(cubit.close);
    cubit.setAvailableRoles(const <String>['client']);

    await firebaseMessagingBackgroundHandler(driverMessage);
    expect(await SharedPrefsLocalPushInbox(prefs: prefs).readAll(), isEmpty);
  });

  test('a new_request nested inside a stringified data blob is still persisted '
      '(hoist path)', () async {
    const message = RemoteMessage(
      messageId: 'bg-msg-4',
      data: <String, dynamic>{
        'data': "{'type':'new_request','requestId':'req-99'}",
      },
      notification: RemoteNotification(title: 't', body: 'b'),
    );
    await firebaseMessagingBackgroundHandler(message);

    final prefs = await SharedPreferences.getInstance();
    final inbox = SharedPrefsLocalPushInbox(prefs: prefs);
    final records = await inbox.readAll();
    expect(records, hasLength(1));
    expect(records.single.ref, 'req-99');
  });

  // F7: the isolate has no keystore; the owner stamp in prefs is the only thing
  // that keeps a background row out of the next account's inbox.
  group('F7 background owner stamping', () {
    const ownedMessage = RemoteMessage(
      messageId: 'bg-own-1',
      data: <String, dynamic>{'type': 'new_request', 'requestId': 'req-own'},
      notification: RemoteNotification(title: 't', body: 'b'),
    );

    test('the isolate stamps the row with the owner mirrored in prefs',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPrefsLocalPushInbox.ownerPrefKey: 'user-a',
      });
      await firebaseMessagingBackgroundHandler(ownedMessage);

      final prefs = await SharedPreferences.getInstance();
      final asOwner =
          SharedPrefsLocalPushInbox(prefs: prefs, ownerId: 'user-a');
      expect((await asOwner.readAll()).single.ref, 'req-own');
    });

    test('a row written for user-a never reaches user-b', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPrefsLocalPushInbox.ownerPrefKey: 'user-a',
      });
      await firebaseMessagingBackgroundHandler(ownedMessage);

      final prefs = await SharedPreferences.getInstance();
      final other = SharedPrefsLocalPushInbox(prefs: prefs, ownerId: 'user-b');
      expect(await other.readAll(), isEmpty);

      final badge = BadgeCountCubit(inbox: other);
      addTearDown(badge.close);
      await badge.hydrate();
      expect(badge.state.newRequests, 0, reason: 'no leak into the badge');
    });
  });
}
