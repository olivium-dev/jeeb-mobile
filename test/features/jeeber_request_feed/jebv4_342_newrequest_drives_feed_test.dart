import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';

/// JEBV4-342 (b02) — `new_request` push drives the jeeber feed.
///
/// Two halves, tested separately and then end-to-end:
///   A. [PushNotificationHandler] PUBLISHES on [PushRefreshSignals] for a
///      `new_request` push (it previously did not, for any payload).
///   B. [RequestFeedCubit] SUBSCRIBES and re-pulls its snapshot.
///
/// Every test here drives the poll to a cadence far longer than the test's own
/// lifetime, so a refetch can only be attributed to the push. That is the whole
/// point of the ticket: the feed already refreshed eventually via its 60s
/// safety-net poll, which is why "the push works" looked true in review while
/// the subscriber did not exist.
class _MockRepo extends Mock implements RequestFeedRepository {}

class _FakeTransport implements PushTransport {
  final _foreground = StreamController<NotificationMessage>.broadcast();
  final _opened = StreamController<NotificationMessage>.broadcast();
  final _token = StreamController<String>.broadcast();

  void emitForeground(NotificationMessage m) => _foreground.add(m);

  @override
  Stream<NotificationMessage> get onForegroundMessage => _foreground.stream;

  @override
  Stream<NotificationMessage> get onMessageOpenedApp => _opened.stream;

  @override
  Stream<String> get onTokenRefresh => _token.stream;

  @override
  Future<String?> getToken() async => null;

  @override
  Future<PushPermissionStatus> requestPermission() async =>
      PushPermissionStatus.granted;

  @override
  Future<NotificationMessage?> initialMessage() async => null;

  @override
  Future<void> dispose() async {
    await _foreground.close();
    await _opened.close();
    await _token.close();
  }
}

/// The payload the gateway actually emits, transcribed field-for-field from
/// `jeeb-gateway/src/JeebGateway/Notifications/NewRequestPushNotifier.cs`
/// `BuildPayloadAsync` (:445-475). Note `category: "delivery"` sitting next to
/// `type: "new_request"` — the legacy value for pre-sprint-009 APKs — and BOTH
/// id spellings at :469-470. `NotificationCategory.fromData` must let `type`
/// win, or this push buckets as a delivery and the whole wire is untested.
NotificationMessage _realGatewayNewRequestPush({
  String id = 'fcm-msg-1',
  String requestId = '9f1c2b6e-1111-4222-8333-444455556666',
}) {
  final data = <String, String>{
    'title': 'New delivery request',
    'body': 'A customer needs a delivery. Tap to view and bid. • Standard',
    'type': 'new_request',
    'category': 'delivery',
    'audience': 'jeebers',
    'audience_role': 'jeeber',
    'priority': 'high',
    'requestId': requestId,
    'request_id': requestId,
    'tierId': 'standard',
  };
  return NotificationMessage(
    id: id,
    category: NotificationCategory.fromData(data),
    title: data['title']!,
    body: data['body']!,
    receivedAt: DateTime.utc(2026, 7, 26, 20, 0),
    data: data,
  );
}

void main() {
  group('A · the real gateway payload categorises as newRequest', () {
    test('type=new_request wins over the legacy category=delivery', () {
      expect(
        _realGatewayNewRequestPush().category,
        NotificationCategory.newRequest,
      );
    });

    test('and it carries both id spellings', () {
      final data = _realGatewayNewRequestPush().data;
      expect(data['requestId'], isNotEmpty);
      expect(data['request_id'], isNotEmpty);
      expect(data['requestId'], data['request_id']);
    });
  });

  group('B · handler publishes a refresh signal for new_request', () {
    late _FakeTransport transport;
    late PushRefreshSignals signals;
    late PushNotificationHandler handler;
    late List<void> fired;
    late StreamSubscription<void> sub;

    setUp(() {
      transport = _FakeTransport();
      signals = PushRefreshSignals();
      fired = <void>[];
      sub = signals.stream.listen(fired.add);
      handler = PushNotificationHandler(
        transport: transport,
        badgeCount: BadgeCountCubit(),
        refreshSignals: signals,
        localRoles: () => const {'jeeber'},
      );
    });

    tearDown(() async {
      await sub.cancel();
      await handler.close();
      await signals.dispose();
    });

    test('a foreground new_request push fires the bus', () async {
      transport.emitForeground(_realGatewayNewRequestPush());
      await Future<void>.delayed(Duration.zero);
      expect(fired, hasLength(1));
    });

    test(
      'and it fires even with NO id on the payload — the signal is payload-less',
      () async {
        // Guards the branch choice: `newRequest` sits on the id-less branch
        // beside `offerAccepted`, not inside the id-guarded `orderish` set. If
        // someone later moves it, this reds. A whole-snapshot refetch must not
        // be hostage to a field it never reads.
        final data = <String, String>{'type': 'new_request'};
        transport.emitForeground(NotificationMessage(
          id: 'no-id-payload',
          category: NotificationCategory.fromData(data),
          title: 'New delivery request',
          body: '',
          receivedAt: DateTime.utc(2026, 7, 26, 20, 1),
          data: data,
        ));
        await Future<void>.delayed(Duration.zero);
        expect(fired, hasLength(1));
      },
    );

    test(
      'NEGATIVE: an unrelated category with no id does NOT fire the bus',
      () async {
        // Proves the id-guard below the new branch is intact — the edit widened
        // exactly one category, not the whole function.
        final data = <String, String>{'type': 'delivery'};
        transport.emitForeground(NotificationMessage(
          id: 'delivery-no-id',
          category: NotificationCategory.fromData(data),
          title: 'Delivery',
          body: '',
          receivedAt: DateTime.utc(2026, 7, 26, 20, 2),
          data: data,
        ));
        await Future<void>.delayed(Duration.zero);
        expect(fired, isEmpty);
      },
    );
  });

  group('C · RequestFeedCubit subscribes to refreshSignals', () {
    late _MockRepo repo;
    late StreamController<DeliveryRequest> requests;
    late StreamController<FeedTransportUpdate> transport;
    late StreamController<void> refreshSignals;

    setUp(() {
      repo = _MockRepo();
      requests = StreamController<DeliveryRequest>.broadcast();
      transport = StreamController<FeedTransportUpdate>.broadcast();
      refreshSignals = StreamController<void>.broadcast();
      when(() => repo.requests).thenAnswer((_) => requests.stream);
      when(() => repo.transport).thenAnswer((_) => transport.stream);
      when(() => repo.refresh())
          .thenAnswer((_) async => const <DeliveryRequest>[]);
      when(() => repo.dispose()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await requests.close();
      await transport.close();
      await refreshSignals.close();
    });

    RequestFeedCubit build({Stream<void>? signals}) => RequestFeedCubit(
          repository: repo,
          // Far longer than this test lives, so no poll tick can be mistaken
          // for the push-driven refetch.
          sweepInterval: const Duration(hours: 1),
          refreshSignals: signals,
        );

    test('a signal triggers exactly one extra refresh()', () async {
      final cubit = build(signals: refreshSignals.stream);
      await cubit.start();
      verify(() => repo.refresh()).called(1); // the start() snapshot

      refreshSignals.add(null);
      await Future<void>.delayed(Duration.zero);
      verify(() => repo.refresh()).called(1); // the push-driven one

      await cubit.close();
    });

    test('NEGATIVE: with refreshSignals null, a signal changes nothing',
        () async {
      // The pre-JEBV4-342 behaviour, pinned. If this ever passes for the wrong
      // reason (a refetch appearing without a subscription) the wire is not
      // where the code claims it is.
      final cubit = build();
      await cubit.start();
      verify(() => repo.refresh()).called(1);

      refreshSignals.add(null);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => repo.refresh());

      await cubit.close();
    });

    test('close() cancels the subscription — no refresh after close', () async {
      final cubit = build(signals: refreshSignals.stream);
      await cubit.start();
      verify(() => repo.refresh()).called(1);

      await cubit.close();
      refreshSignals.add(null);
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => repo.refresh());
    });

    test('a second start() does not double-subscribe', () async {
      // Two subscriptions would fire two refetches per push — a self-inflicted
      // doubling of the load the ticket exists to reduce.
      final cubit = build(signals: refreshSignals.stream);
      await cubit.start();
      await cubit.start();
      verify(() => repo.refresh()).called(2); // one per start()

      refreshSignals.add(null);
      await Future<void>.delayed(Duration.zero);
      verify(() => repo.refresh()).called(1);

      await cubit.close();
    });
  });

  group('D · end-to-end: push in, feed refetch out', () {
    test('handler → PushRefreshSignals → RequestFeedCubit.refresh()', () async {
      final repo = _MockRepo();
      final requests = StreamController<DeliveryRequest>.broadcast();
      final transportUpdates =
          StreamController<FeedTransportUpdate>.broadcast();
      when(() => repo.requests).thenAnswer((_) => requests.stream);
      when(() => repo.transport).thenAnswer((_) => transportUpdates.stream);
      when(() => repo.refresh())
          .thenAnswer((_) async => const <DeliveryRequest>[]);
      when(() => repo.dispose()).thenAnswer((_) async {});

      final signals = PushRefreshSignals();
      final pushTransport = _FakeTransport();
      final handler = PushNotificationHandler(
        transport: pushTransport,
        badgeCount: BadgeCountCubit(),
        refreshSignals: signals,
        localRoles: () => const {'jeeber'},
      );
      final cubit = RequestFeedCubit(
        repository: repo,
        sweepInterval: const Duration(hours: 1),
        refreshSignals: signals.stream,
      );
      await cubit.start();
      verify(() => repo.refresh()).called(1);

      pushTransport.emitForeground(_realGatewayNewRequestPush());
      await Future<void>.delayed(Duration.zero);

      verify(() => repo.refresh()).called(1);

      await cubit.close();
      await handler.close();
      await signals.dispose();
      await requests.close();
      await transportUpdates.close();
    });
  });
}
