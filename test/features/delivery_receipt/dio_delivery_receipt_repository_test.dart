import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';

/// COD-COMPLETE FIX (fix/cod-complete): confirm-receipt is a SINGLE idempotent
/// SM-1 status PATCH. The customer never records COD — the old
/// `POST /v1/payments/cod_jeeb/record` (a route the gateway 404s) and
/// `POST /v1/delivery/status/transition` (also 404) both dead-ended the customer
/// at "Something went wrong" before they could rate. This suite proves:
///
///   * the confirm→settlement path SUCCEEDS on complete (the reported bug), and
///   * the ONLY write is `PATCH /v1/deliveries/{id}/status` — the real, shipped
///     gateway route — never the fictional COD/transition routes.
void main() {
  group('DioDeliveryReceiptRepository.confirmReceipt — COD-complete fix', () {
    late _RecordingAdapter adapter;
    late Dio dio;
    late DioDeliveryReceiptRepository repo;

    DeliveryReceipt receiptWith(String status) => DeliveryReceipt(
          deliveryId: 'd-1',
          jeeberName: 'Sami',
          jeeberId: 'j-1',
          cashAmount: 5.0,
          currency: 'USD',
          status: status,
        );

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
      repo = DioDeliveryReceiptRepository(dio, originGateway: true);
    });

    test(
        'confirm→settlement SUCCEEDS on complete: non-terminal (AtDoor) PATCHes '
        'status to Done (200) → customer reaches rating (the reported bug)',
        () async {
      adapter.statusPatchStatus = 200;

      await repo.confirmReceipt(receiptWith('AtDoor'));

      // The ONLY write is the real status PATCH on the shipped gateway route.
      expect(adapter.statusPatchHit, isTrue);
      expect(adapter.statusPatchMethod, 'PATCH');
      expect(adapter.statusPatchPath, '/v1/deliveries/d-1/status');
      // The fictional COD-record route is NEVER touched (it was the 404 that
      // hard-failed and blocked rating with "Something went wrong").
      expect(adapter.codHit, isFalse);
      // The fictional POST /v1/delivery/status/transition is gone too.
      expect(adapter.legacyTransitionHit, isFalse);
    });

    test(
        'S10 Defect B — already Done: SKIPS the PATCH entirely (no illegal '
        'Done → Done), succeeds → customer reaches rating', () async {
      adapter.statusPatchStatus = 200;

      await repo.confirmReceipt(receiptWith('Done'));

      expect(adapter.statusPatchHit, isFalse);
      expect(adapter.codHit, isFalse);
    });

    test(
        'race guard: non-terminal load but server returns 422 '
        'transition_not_allowed → SUCCEEDS (idempotent swallow)', () async {
      adapter.statusPatchStatus = 422; // server flipped to Done mid-confirm

      // Must NOT throw — the redundant transition 422 is an idempotent success.
      await repo.confirmReceipt(receiptWith('AtDoor'));

      expect(adapter.statusPatchHit, isTrue);
    });

    test('genuine transition 500 (real server error, not already-Done) → throws',
        () async {
      adapter.statusPatchStatus = 500;

      await expectLater(
        repo.confirmReceipt(receiptWith('AtDoor')),
        throwsA(isA<DeliveryReceiptRepositoryException>()),
      );
    });

    test('transition 404 (route/delivery not found) → throws notFound',
        () async {
      adapter.statusPatchStatus = 404;

      await expectLater(
        repo.confirmReceipt(receiptWith('AtDoor')),
        throwsA(
          isA<DeliveryReceiptRepositoryException>().having(
            (e) => e.failure,
            'failure',
            DeliveryReceiptFailure.notFound,
          ),
        ),
      );
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  int statusPatchStatus = 200;

  bool statusPatchHit = false;
  String? statusPatchMethod;
  String? statusPatchPath;

  // Guards proving the fictional routes are never called again.
  bool codHit = false;
  bool legacyTransitionHit = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.contains('cod_jeeb/record')) {
      codHit = true;
      return _json(const {'recorded': true}, status: 200);
    }
    if (path.contains('status/transition')) {
      legacyTransitionHit = true;
      return _json(const {'status': 'Done'}, status: 200);
    }
    // Real route: PATCH /v1/deliveries/{id}/status
    if (path.contains('/deliveries/') && path.endsWith('/status')) {
      statusPatchHit = true;
      statusPatchMethod = options.method;
      statusPatchPath = path;
      return _json(const {'status': 'Done'}, status: statusPatchStatus);
    }
    return _json(const {}, status: 200);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, Object?> body, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
