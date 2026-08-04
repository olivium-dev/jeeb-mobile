// Sprint-3 S0-OAD-04/05 — Delivery-leg contract test (Leg 5, L1 s3/delivery).

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';

const _deliveryId = 'req-uuid-0001';

void main() {
  late _RecordingAdapter adapter;
  late Dio dio;
  late _RecordingCdnAssetGateway cdn;

  setUp(() {
    adapter = _RecordingAdapter();
    cdn = _RecordingCdnAssetGateway();
    // ORIGIN-ONLY base (ARCH-01): host is irrelevant to the contract — the
    dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
  });

  DioActiveDeliveryRepository originRepo() => DioActiveDeliveryRepository(
        dio,
        originGateway: true,
        cdnAssetGateway: cdn,
      );
  DioActiveDeliveryRepository mockRepo() => DioActiveDeliveryRepository(
        dio,
        originGateway: false,
        cdnAssetGateway: cdn,
      );

  group('Proof-photo upload (D3, JEBV4-200) — real bytes via CDN broker', () {
    test('uploadProofPhoto streams the REAL image bytes to the CDN broker '
        'under the proof_of_delivery slot, returning the object_ref', () async {
      final payload = Uint8List.fromList(
        List<int>.generate(4096, (i) => (i * 7) % 256),
      );
      final ref = await originRepo().uploadProofPhoto(
        deliveryId: _deliveryId,
        bytes: payload,
      );
      // The bytes handed to the broker are the actual image payload — never a
      expect(cdn.lastBytes, equals(payload));
      expect(cdn.lastSlot, CdnUploadSlot.proofOfDelivery);
      expect(ref, cdn.returnedRef);
    });

    test('a CDN upload failure surfaces as ActiveDeliveryFailure.server',
        () async {
      cdn.failure = const CdnUploadException('boom');
      await expectLater(
        originRepo().uploadProofPhoto(
          deliveryId: _deliveryId,
          bytes: Uint8List.fromList(const [1, 2, 3]),
        ),
        throwsA(
          isA<ActiveDeliveryException>().having(
            (e) => e.failure,
            'failure',
            ActiveDeliveryFailure.server,
          ),
        ),
      );
    });
  });

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
      expect(body.keys.toSet(), {'to', 'evidenceUrl'});
      expect(body['to'], 'Picked');
      expect(body['evidenceUrl'], isNull);
      expect(body.containsKey('deliveryId'), isFalse);
      expect(result, JeeberDeliveryStatus.picked);
    });

    // P6/B1: the app no longer DRIVES the atDoor→Done edge (markDelivered stops
    test('evidenceUrl is carried on the body when present', () async {
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

  // P6/B3 + P6/B4 — the transition-error mapper reads the STRUCTURED `reason`
  group('P6 — structured reason match, 400 ≠ 422', () {
    Future<ActiveDeliveryFailure> failureFor({
      required int status,
      required Map<String, Object?> body,
      required JeeberDeliveryStatus from,
      required JeeberDeliveryStatus to,
    }) async {
      adapter.patchStatus = status;
      adapter.onPatch = (path, data) => _json(body, status: status);
      try {
        await originRepo().transition(
          deliveryId: _deliveryId,
          from: from,
          to: to,
        );
      } on ActiveDeliveryException catch (e) {
        return e.failure;
      }
      fail('expected the PATCH to throw an ActiveDeliveryException');
    }

    test('a: 422 reason=otp_required on AtDoor→Done ⇒ otpRequired', () async {
      expect(
        await failureFor(
          status: 422,
          body: const {
            'reason': 'otp_required',
            'from': 'AtDoor',
            'to': 'Done',
            'trigger': 'otp_verified',
          },
          from: JeeberDeliveryStatus.atDoor,
          to: JeeberDeliveryStatus.done,
        ),
        ActiveDeliveryFailure.otpRequired,
      );
    });

    test('b: 422 reason=transition_not_allowed on AtDoor→Done ⇒ otpRequired '
        '(belt-and-braces — the LIVE 2026-07-25 incident body)', () async {
      expect(
        await failureFor(
          status: 422,
          body: const {
            'reason': 'transition_not_allowed',
            'from': 'AtDoor',
            'to': 'Done',
          },
          from: JeeberDeliveryStatus.atDoor,
          to: JeeberDeliveryStatus.done,
        ),
        ActiveDeliveryFailure.otpRequired,
      );
    });

    test('c: 422 transition_not_allowed on any OTHER edge ⇒ invalidTransition',
        () async {
      expect(
        await failureFor(
          status: 422,
          body: const {
            'reason': 'transition_not_allowed',
            'from': 'Ordered',
            'to': 'InTransit',
          },
          from: JeeberDeliveryStatus.ordered,
          to: JeeberDeliveryStatus.inTransit,
        ),
        ActiveDeliveryFailure.invalidTransition,
      );
    });

    test('d: 400 from the gateway body resolver ⇒ badRequest, NOT '
        'invalidTransition', () async {
      expect(
        await failureFor(
          status: 400,
          body: const {
            'title': 'A canonical target is required '
                '(provide one of: to, trigger, status).',
          },
          from: JeeberDeliveryStatus.ordered,
          to: JeeberDeliveryStatus.picked,
        ),
        ActiveDeliveryFailure.badRequest,
      );
    });

    test('e: prose containing "otp" must NOT raise the OTP prompt — the old '
        'substring scan got this wrong', () async {
      expect(
        await failureFor(
          status: 422,
          body: const {
            'reason': 'transition_not_allowed',
            'detail': 'the otp handover has not started',
          },
          from: JeeberDeliveryStatus.ordered,
          to: JeeberDeliveryStatus.picked,
        ),
        ActiveDeliveryFailure.invalidTransition,
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

/// Records the bytes + slot the repository hands to the CDN broker, so a test
/// can assert a proof upload transmits REAL image bytes (JEBV4-200).
class _RecordingCdnAssetGateway implements CdnAssetGateway {
  Uint8List? lastBytes;
  CdnUploadSlot? lastSlot;
  String? lastContentType;
  final String returnedRef = 'cdn://obj/proof-ref-0001';
  CdnUploadException? failure;

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (failure != null) throw failure!;
    lastSlot = slot;
    lastBytes = bytes;
    lastContentType = contentType;
    return returnedRef;
  }

  /// P4/P5: the active-delivery origin routes never READ a CDN asset.
  @override
  Future<Uint8List> fetchAsset(String objectRef) async => Uint8List(0);
}

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
