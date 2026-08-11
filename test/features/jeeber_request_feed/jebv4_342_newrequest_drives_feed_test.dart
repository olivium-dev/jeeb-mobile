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

    // Retargeted 2026-08-11: a delivery push now wakes the order topic, but
    // what this control is about — it must not re-pull the FEED — still holds.
    test(
      'NEGATIVE: a delivery push does not wake the FEED topic',
      () async {
        final feedWakes = <void>[];
        final feedSub = signals
            .streamFor(const {RefreshTopic.feed})
            .listen(feedWakes.add);
        addTearDown(feedSub.cancel);
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
        expect(feedWakes, isEmpty);
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
