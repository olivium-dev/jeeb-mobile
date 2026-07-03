// G3 REGRESSION GUARD (run-24 CHECK D): the test that would have CAUGHT the
// device failure.
//
// Cycle-4 added NotificationKind.newRequest + BadgeCountCubit rendering and its
// unit tests PASSED — but on real hardware a dismissed `new_request` push left
// the inbox EMPTY and showed NO badge. Root cause: those tests drove the
// FOREGROUND path only (BadgeCountCubit.increment / a fake Dio row the real
// server never emits). A push dismissed while the app is backgrounded/terminated
// is handled ONLY by `firebaseMessagingBackgroundHandler` in a SEPARATE isolate
// that can reach neither the cubit nor the inbox list — so it did nothing
// durable.
//
// This test drives the ACTUAL background entry-point and asserts the durable
// inbox row + the badge that hydrate() derives from it.

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/data/firebase_messaging_transport.dart';
import 'package:jeeb_mobile/core/notifications/data/shared_prefs_local_push_inbox.dart';
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
      'the REAL background entry-point persists a durable inbox row for a '
      'dismissed new_request push (G3 — this is what unit tests missed)',
      () async {
    // A new_request push exactly as jeeb-gateway's NewRequestPushNotifier sends
    // it: `type=new_request` on the FCM data map (+ a legacy category), a flat
    // requestId, and a real notification the user saw and dismissed in the tray.
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
    // resume/cold-start — the badge the device was missing.
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
}
