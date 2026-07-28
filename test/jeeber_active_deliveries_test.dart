// Tests for the jeeber active-deliveries feature (iter6 real-flow blocker fix).
//
// Verifies:
//   - ActiveDeliverySummary.fromJson parses the gateway OrderListItem shape
//     (id, conversationId, status, title, dropoff.address) and chatRouteId
//     prefers the conversation id.
//   - DioActiveDeliveriesRepository drops Done rows and rows with no id.
//   - ActiveDeliveriesCubit emits loaded with the repo's deliveries; an empty
//     result leaves the banner empty (hasDeliveries == false).
//   - LIVE-ROUTE (iter6, 2026-06-22): the *real* DioActiveDeliveriesRepository
//     hits the live gateway route `GET /v1/deliveries?role=jeeber` (NOT the
//     mock-era `/deliveries?stage=active` that the LIVE gateway answers with an
//     empty `{"shipments":[],"count":0}`) and parses the live `{items:[...]}`
//     envelope — so the #71 dashboard banner populates with the accepted
//     delivery. Verified live on :10090: an accepted delivery
//     (jeeber b4c26077) is returned by `/v1/deliveries?role=jeeber` as
//     `{items:[{id, status:"accepted", jeeberId, ...}], totalCount:1}`.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/data/dio_active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';

/// A [Dio] whose every request is short-circuited to [responseBody] while the
/// outgoing path + query are captured (the codebase's existing Dio-repo test
/// idiom — see `test/dio_saved_location_repository_test.dart`). No network.
class _Captured {
  String? path;
  Map<String, dynamic>? query;
}

Dio _capturingDio(Object? responseBody, _Captured captured, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        captured.path = options.path;
        captured.query = options.queryParameters;
        handler.resolve(
          Response(
            data: responseBody,
            statusCode: status,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

class _FakeRepo implements ActiveDeliveriesRepository {
  _FakeRepo(this._result);

  final List<ActiveDeliverySummary> _result;
  int calls = 0;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    calls++;
    return _result;
  }
}

void main() {
  group('ActiveDeliverySummary.fromJson', () {
    test('parses the gateway OrderListItem shape', () {
      final s = ActiveDeliverySummary.fromJson(const {
        'id': 'req-1',
        'status': 'InTransit',
        'conversationId': 'conv-9',
        'title': 'Flash delivery request',
        'pickup': {'address': 'Hamra'},
        'dropoff': {'address': 'Achrafieh'},
      });
      expect(s.id, 'req-1');
      expect(s.status, JeeberDeliveryStatus.inTransit);
      expect(s.conversationId, 'conv-9');
      expect(s.title, 'Flash delivery request');
      expect(s.pickupAddress, 'Hamra');
      expect(s.dropoffAddress, 'Achrafieh');
      // BUG-18 client side: chatRouteId prefers the request id (==
      // correlationKey) over the conversation id, so chat-detail resolves
      // correlationKey-first without a wasted 404 probe.
      expect(s.chatRouteId, 'req-1');
      expect(s.isActive, isTrue);
    });

    test('chatRouteId falls back to the delivery id when no conversation', () {
      final s = ActiveDeliverySummary.fromJson(const {
        'id': 'req-2',
        'status': 'ordered',
      });
      expect(s.conversationId, isNull);
      expect(s.chatRouteId, 'req-2');
    });

    test('Done status is not active', () {
      final s = ActiveDeliverySummary.fromJson(const {
        'id': 'req-3',
        'status': 'Done',
      });
      expect(s.status, JeeberDeliveryStatus.done);
      expect(s.isActive, isFalse);
    });
  });

  group('ActiveDeliveriesCubit', () {
    test('start() loads deliveries and emits loaded', () async {
      final repo = _FakeRepo([
        ActiveDeliverySummary.fromJson(const {
          'id': 'req-1',
          'status': 'Ordered',
          'conversationId': 'conv-1',
          'title': 'Flash delivery request',
        }),
      ]);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, ActiveDeliveriesPhase.loaded);
      expect(cubit.state.hasDeliveries, isTrue);
      expect(cubit.state.deliveries.single.id, 'req-1');
      expect(repo.calls, 1);
    });

    test('empty result → banner stays empty (hasDeliveries false)', () async {
      final repo = _FakeRepo(const []);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, ActiveDeliveriesPhase.loaded);
      expect(cubit.state.hasDeliveries, isFalse);
    });

    test('start() is idempotent (no double initial load scheduling)', () async {
      final repo = _FakeRepo(const []);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      cubit.start();
      cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls, 1);
    });

    // PUSH-UI-REACTION (2026-07-05): a push (offer_accepted / delivery-status)
    // publishes on the shared refresh bus; this cubit must re-pull IMMEDIATELY
    // instead of waiting for its (long) poll tick — the exact wire that was
    // missing when the accepted delivery didn't surface until a force-restart.
    test('a refresh signal triggers an immediate refetch', () async {
      final signals = StreamController<void>.broadcast();
      addTearDown(signals.close);
      final repo = _FakeRepo([
        ActiveDeliverySummary.fromJson(const {
          'id': 'req-won',
          'status': 'accepted',
          'title': 'Flash delivery request',
        }),
      ]);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        // Long poll so the ONLY refetch under test comes from the push signal.
        pollInterval: const Duration(hours: 1),
        refreshSignals: signals.stream,
      );
      addTearDown(cubit.close);

      cubit.start();
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 1); // initial load

      // Simulate the push handler publishing an "offer accepted" refetch signal.
      signals.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls, 2); // re-pulled off the push, not the poll
      expect(cubit.state.hasDeliveries, isTrue);
      expect(cubit.state.deliveries.single.id, 'req-won');
    });

    test('with no refresh signal wired the poll path is unaffected (no crash)',
        () async {
      final repo = _FakeRepo(const []);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        pollInterval: const Duration(hours: 1),
        // refreshSignals intentionally omitted (bare-harness / null path).
      );
      addTearDown(cubit.close);

      cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls, 1);
      expect(cubit.state.phase, ActiveDeliveriesPhase.loaded);
    });
  });

  group('DioActiveDeliveriesRepository — live route + shape (iter6 banner)', () {
    // The live-gateway envelope (JeebOrdersListController.ListDeliveries), shaped
    // exactly like the proven `:10090 /v1/deliveries?role=jeeber` response for
    // the accepted delivery f2244baa assigned to jeeber b4c26077.
    final liveBody = <String, dynamic>{
      'items': [
        {
          'id': 'f2244baa-ff25-4316-b723-c08a80cd3da9',
          'displayId': 'f2244baa',
          'status': 'accepted',
          'title': 'Flash delivery request',
          'tier': '0be308ce-01b5-5cb9-a3e8-9adb60668d9c',
          'jeeberId': 'b4c26077-0985-40a1-b799-ec001bc9ad10',
          'pickup': {'address': 'Home', 'lat': 33.8886, 'lng': 35.4955},
          'dropoff': {'address': 'Home', 'lat': 33.8886, 'lng': 35.4955},
        },
      ],
      'page': 1,
      'pageSize': 50,
      'totalCount': 1,
      'totalPages': 1,
    };

    test('fetches the LIVE /v1/deliveries route with role=jeeber (not the '
        'mock-era /deliveries?stage=active)', () async {
      final captured = _Captured();
      final repo = DioActiveDeliveriesRepository(_capturingDio(liveBody, captured));

      await repo.listActive();

      // The path carries the /v1 prefix (the mock-era bare `/deliveries` is the
      // route the LIVE gateway answers with an empty `{shipments:[],count:0}`).
      expect(captured.path, '/v1/deliveries');
      expect(captured.path, startsWith('/v1/'));
      expect(captured.path, isNot(equals('/deliveries')));
      // Scoped to the bearer jeeber's assigned deliveries.
      expect(captured.query?['role'], 'jeeber');
    });

    test('parses the live `items` envelope into the accepted delivery so the '
        'banner populates', () async {
      final captured = _Captured();
      final repo = DioActiveDeliveriesRepository(_capturingDio(liveBody, captured));

      final result = await repo.listActive();

      // The live response is keyed on `items` (NOT the mock-era `shipments`).
      expect(result, hasLength(1));
      final d = result.single;
      expect(d.id, 'f2244baa-ff25-4316-b723-c08a80cd3da9');
      // The live gateway emits `status:"accepted"`, which is not one of the
      // five jeeber transition stages — `fromApi` defensively maps the unknown
      // string to `ordered` (the start of the Ordered→…→Done machine). The row
      // is still ACTIVE (not Done), so the banner shows and the jeeber can tap
      // through to chat → Start delivery.
      expect(d.status, JeeberDeliveryStatus.ordered);
      expect(d.title, 'Flash delivery request');
      expect(d.dropoffAddress, 'Home');
      // hasDeliveries-equivalent: the banner shows because the list is non-empty.
      expect(d.isActive, isTrue);
    });

    test('the mock-era empty `{shipments:[],count:0}` shape yields no rows '
        '(regression guard for the wrong endpoint)', () async {
      final captured = _Captured();
      final repo = DioActiveDeliveriesRepository(
        _capturingDio(const {'shipments': <dynamic>[], 'count': 0}, captured),
      );

      final result = await repo.listActive();

      // No `items` key → empty list → banner self-hides. This is exactly what
      // the LIVE gateway returns for the WRONG (mock-era) `/deliveries` path, so
      // this asserts the repo never silently parses that shape into rows.
      expect(result, isEmpty);
    });
  });

  // b02 wave D. This cubit has THREE independently-timed triggers — the 60s
  // poller, the push bus and the visibility/resume tick — and only the poller
  // ever coordinated with itself. A jeeber whose offer is accepted receives
  // `offer_accepted` and, moments later, the first `type=delivery` transition:
  // two bus events well inside one `GET /v1/deliveries?role=jeeber` round trip.
  // Overlapping, the later-issued read can complete FIRST and repaint the card
  // from the OLDER snapshot.
  group('ActiveDeliveriesCubit — single flight', () {
    test('two push signals inside one round trip produce ONE read, and the '
        'latch releases afterwards', () async {
      final gate = Completer<void>();
      var calls = 0;
      final repository = _GatedActiveDeliveriesRepository(
        onCall: () => calls++,
        gate: () => gate.future,
      );
      final signals = StreamController<void>.broadcast();
      addTearDown(signals.close);
      final cubit = ActiveDeliveriesCubit(
        repository: repository,
        pollInterval: const Duration(hours: 1),
        refreshSignals: signals.stream,
      );
      addTearDown(cubit.close);

      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1, reason: 'the second signal must collapse onto the first');

      gate.complete();
      await Future<void>.delayed(Duration.zero);

      signals.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2, reason: 'a latch that never released would freeze the '
          'card on its first snapshot forever');
    });
  });
}

/// Repository whose `listActive` can be held open, so a second trigger lands
/// while the first read is genuinely in flight — the only state in which a
/// single-flight latch means anything.
class _GatedActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  _GatedActiveDeliveriesRepository({required this.onCall, required this.gate});

  final void Function() onCall;
  final Future<void> Function() gate;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    onCall();
    await gate();
    return const <ActiveDeliverySummary>[];
  }
}
