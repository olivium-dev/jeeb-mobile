// Sprint-3 S0-OAD-04/05 — Delivery-leg contract test (Leg 5, L1 s3/delivery).
//
// Locks Contract 8 (delivery lifecycle state machine + frozen origin-only
// `:10090` routes) at the WIRE level, with a recording HttpClientAdapter — no
// host hardcoded, no deploy needed. [LIVE-NOW via fixtures]; the live `:10090`
// round-trip is [DEPLOY-GATED] behind S0-BE-07.
//
// Proves:
//  - Origin `:10090` reads via the plural  GET   /v1/deliveries/{id}   (8c).
//  - Origin `:10090` writes via            PATCH /v1/deliveries/{id}/status
//    body { to, evidenceUrl } — deliveryId in PATH not body, `to` CapitalCase
//    matching the frozen forward machine, evidenceUrl explicit-null when absent
//    (8b).
//  - EVERY forward edge Ordered→Picked→InTransit→AtDoor→Done emits the exact
//    CapitalCase `to` on the PATCH (the FROZEN single-source-of-truth machine).
//  - AtDoor→Done without a verified door OTP comes back 422 {otp_required} →
//    ActiveDeliveryFailure.otpRequired (8d gate), distinct from a bad-transition
//    422 → ActiveDeliveryFailure.invalidTransition.
//  - The door-OTP close-tail POST /v1/deliveries/{id}/otp/verify {code} drives
//    AtDoor→Done (8d) on the origin base.
//  - The legacy `:4010` mock routes (GET /v1/delivery/{id},
//    POST /v1/delivery/status/transition with deliveryId in body) are PRESERVED
//    when originGateway:false — additive, no regression.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _RecordingAdapter();
    // ORIGIN-ONLY base (ARCH-01): host is irrelevant to the contract — the
    // recording adapter never opens a socket. Path-shape is what we assert.
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioActiveDeliveryRepository originRepo() =>
      DioActiveDeliveryRepository(dio, originGateway: true);
  DioActiveDeliveryRepository mockRepo() =>
      DioActiveDeliveryRepository(dio, originGateway: false);

  group('Origin :10090 (Contract 8) — frozen plural routes', () {
    test('fetchDelivery reads GET /v1/deliveries/{id} (plural, 8c) and parses '
        'the delivery row', () async {
      adapter.onGet = (path) => _json({
            'id': _deliveryId,
            'status': 'Picked',
            'dropoff': {'label': 'Verdun', 'lat': 33.88, 'lng': 35.49},
          });

      final delivery = await originRepo().fetchDelivery(_deliveryId);

      expect(adapter.lastGetPath, '/v1/deliveries/$_deliveryId');
      expect(delivery.id, _deliveryId);
      expect(delivery.status, JeeberDeliveryStatus.picked);
    });

    test('transition writes PATCH /v1/deliveries/{id}/status with body '
        '{ to, evidenceUrl } — deliveryId in PATH not body (8b)', () async {
      adapter.onPatch = (path, data) => _json({'status': 'Picked'});

      final result = await originRepo().transition(
        deliveryId: _deliveryId,
        from: JeeberDeliveryStatus.ordered,
        to: JeeberDeliveryStatus.picked,
      );

      expect(adapter.lastMethod, 'PATCH');
      expect(adapter.lastPath, '/v1/deliveries/$_deliveryId/status');
      final body = adapter.lastBody! as Map;
      // FROZEN byte-shape: only { to, evidenceUrl }. No deliveryId/senderId/
      // trigger leaks into the origin body.
      expect(body.keys.toSet(), {'to', 'evidenceUrl'});
      expect(body['to'], 'Picked');
      expect(body['evidenceUrl'], isNull);
      expect(body.containsKey('deliveryId'), isFalse);
      expect(result, JeeberDeliveryStatus.picked);
    });

    test('evidenceUrl is carried on the body when present (final-step proof)',
        () async {
      adapter.onPatch = (path, data) => _json({'status': 'Done'});

      await originRepo().transition(
        deliveryId: _deliveryId,
        from: JeeberDeliveryStatus.atDoor,
        to: JeeberDeliveryStatus.done,
        evidenceUrl: 'https://cdn.jeeb.app/proof/$_deliveryId.jpg',
      );

      final body = adapter.lastBody! as Map;
      expect(body['to'], 'Done');
      expect(body['evidenceUrl'], 'https://cdn.jeeb.app/proof/$_deliveryId.jpg');
    });

    // The FROZEN forward machine, edge by edge — each `to` must serialize to the
    // exact CapitalCase wire value the gateway SM table matches against (8a).
    final forwardEdges = <(JeeberDeliveryStatus, JeeberDeliveryStatus, String)>[
      (JeeberDeliveryStatus.ordered, JeeberDeliveryStatus.picked, 'Picked'),
      (JeeberDeliveryStatus.picked, JeeberDeliveryStatus.inTransit, 'InTransit'),
      (JeeberDeliveryStatus.inTransit, JeeberDeliveryStatus.atDoor, 'AtDoor'),
      (JeeberDeliveryStatus.atDoor, JeeberDeliveryStatus.done, 'Done'),
    ];
    for (final edge in forwardEdges) {
      test('forward edge ${edge.$1.apiValue}→${edge.$2.apiValue} PATCHes '
          'to="${edge.$3}"', () async {
        adapter.onPatch = (path, data) => _json({'status': edge.$3});

        final result = await originRepo().transition(
          deliveryId: _deliveryId,
          from: edge.$1,
          to: edge.$2,
        );

        final body = adapter.lastBody! as Map;
        expect(body['to'], edge.$3);
        expect(result, edge.$2);
      });
    }

    test('AtDoor→Done returns 422 {otp_required} → otpRequired (8d gate), '
        'NOT invalidTransition', () async {
      adapter.patchStatus = 422;
      adapter.onPatch =
          (path, data) => _json({'code': 'otp_required'}, status: 422);

      Object? caught;
      try {
        await originRepo().transition(
          deliveryId: _deliveryId,
          from: JeeberDeliveryStatus.atDoor,
          to: JeeberDeliveryStatus.done,
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<ActiveDeliveryException>());
      expect(
        (caught! as ActiveDeliveryException).failure,
        ActiveDeliveryFailure.otpRequired,
      );
    });

    test('a plain 422 (no otp token) → invalidTransition', () async {
      adapter.patchStatus = 422;
      adapter.onPatch =
          (path, data) => _json({'code': 'bad_transition'}, status: 422);

      Object? caught;
      try {
        await originRepo().transition(
          deliveryId: _deliveryId,
          from: JeeberDeliveryStatus.ordered,
          to: JeeberDeliveryStatus.inTransit, // skip = invalid
        );
      } catch (e) {
        caught = e;
      }
      expect(
        (caught! as ActiveDeliveryException).failure,
        ActiveDeliveryFailure.invalidTransition,
      );
    });

    test('door-OTP verify POSTs /v1/deliveries/{id}/otp/verify {code} and '
        'completes AtDoor→Done (8d)', () async {
      adapter.onGet = (path) => _json({'code': '1234'}); // issue-on-demand
      adapter.onPost = (path, data) => _json({'status': 'Done'});

      final status = await originRepo().verifyDoorOtp(
        deliveryId: _deliveryId,
        code: '1234',
      );

      expect(adapter.lastPath, '/v1/deliveries/$_deliveryId/otp/verify');
      final body = adapter.lastBody! as Map;
      expect(body['code'], '1234');
      expect(status, JeeberDeliveryStatus.done);
    });

    // LIVE :10090 ground truth (request driven to Done): the handover sequence
    // is GET /v1/deliveries/{id}/otp (issue/trigger) → POST .../otp/verify
    // { code }. Pin the EXACT verb+path of BOTH calls so a future refactor can't
    // silently drop the issue-on-demand GET or drift the verify verb/body.
    test('verifyDoorOtp issues GET /v1/deliveries/{id}/otp THEN POSTs '
        'otp/verify {code} — exact verbs+paths, in order', () async {
      adapter.onGet = (path) => _json({'triggered': true, 'code': '1234'});
      adapter.onPost = (path, data) => _json({'verified': true, 'status': 'Done'});

      await originRepo().verifyDoorOtp(deliveryId: _deliveryId, code: '1234');

      expect(
        adapter.calls,
        [
          ('GET', '/v1/deliveries/$_deliveryId/otp'),
          ('POST', '/v1/deliveries/$_deliveryId/otp/verify'),
        ],
        reason: 'issue-on-demand GET must precede the verify POST',
      );
    });

    // The legacy POST /v1/deliveries/{id}/verify-otp is DEAD on the live
    // upstream-flagged binary (400 otp-not-in-handover-state). Guard against any
    // regression back to that suffix: NO call may target `verify-otp`, and the
    // verify must use the `otp/verify` suffix.
    test('verifyDoorOtp never touches the DEAD legacy verify-otp route',
        () async {
      adapter.onGet = (path) => _json({'triggered': true, 'code': '1234'});
      adapter.onPost = (path, data) => _json({'verified': true, 'status': 'Done'});

      await originRepo().verifyDoorOtp(deliveryId: _deliveryId, code: '1234');

      expect(
        adapter.calls.any((c) => c.$2.contains('verify-otp')),
        isFalse,
        reason: 'the un-versioned /deliveries/{id}/verify-otp path is dead',
      );
      expect(
        adapter.calls.any((c) => c.$1 == 'POST' && c.$2.endsWith('/otp/verify')),
        isTrue,
      );
    });
  });

  group('Legacy :4010 mock routes — PRESERVED (no regression)', () {
    test('fetchDelivery reads the singular GET /v1/delivery/{id}', () async {
      adapter.onGet = (path) => _json({
            'id': _deliveryId,
            'status': 'Ordered',
            'dropoff': {'label': 'Verdun', 'lat': 33.88, 'lng': 35.49},
          });

      await mockRepo().fetchDelivery(_deliveryId);

      expect(adapter.lastGetPath, '/v1/delivery/$_deliveryId');
    });

    test('transition POSTs /v1/delivery/status/transition with deliveryId in '
        'the body (legacy shape)', () async {
      adapter.onPost = (path, data) => _json({'status': 'Picked'});

      await mockRepo().transition(
        deliveryId: _deliveryId,
        from: JeeberDeliveryStatus.ordered,
        to: JeeberDeliveryStatus.picked,
      );

      expect(adapter.lastMethod, 'POST');
      expect(adapter.lastPath, '/v1/delivery/status/transition');
      final body = adapter.lastBody! as Map;
      expect(body['deliveryId'], _deliveryId);
      expect(body['to'], 'Picked');
      expect(body['trigger'], 'jeeber');
    });
  });
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

class _RecordingAdapter implements HttpClientAdapter {
  ResponseBody Function(String path)? onGet;
  ResponseBody Function(String path, Object? data)? onPost;
  ResponseBody Function(String path, Object? data)? onPatch;

  int patchStatus = 200;

  String? lastMethod;
  String? lastPath;
  String? lastGetPath;
  Object? lastBody;

  /// Ordered (method, path) log of every call — lets a test assert the exact
  /// issue→verify sequence and guard against dead-route regressions.
  final List<(String, String)> calls = <(String, String)>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.path;
    calls.add((options.method, options.path));
    if (options.method == 'GET') {
      lastGetPath = options.path;
      return onGet?.call(options.path) ?? _json(const {});
    }
    lastBody = options.data;
    if (options.method == 'PATCH') {
      return onPatch?.call(options.path, options.data) ??
          _json(const {}, status: patchStatus);
    }
    return onPost?.call(options.path, options.data) ?? _json(const {});
  }
}
