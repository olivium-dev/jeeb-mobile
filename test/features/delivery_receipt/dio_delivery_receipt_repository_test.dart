import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';

/// RATING-UNBLOCK (iter6): confirm-receipt must be IDEMPOTENT. In the real
/// two-sided flow the delivery is frequently ALREADY `Done` by the time the
/// customer confirms receipt (the handover-OTP path drove `AtDoor → Done`
/// server-side). The redundant transition then returns 422
/// `transition_not_allowed`. That 422 is NOT a failure — the COD record (the
/// load-bearing step that unblocks rating) already 2xx'd, so confirmReceipt must
/// SUCCEED and let the customer reach the star-rating screen.
void main() {
  group('DioDeliveryReceiptRepository.confirmReceipt — idempotent on 422', () {
    late _RecordingAdapter adapter;
    late Dio dio;
    late DioDeliveryReceiptRepository repo;

    const receipt = DeliveryReceipt(
      deliveryId: 'd-1',
      jeeberName: 'Sami',
      jeeberId: 'j-1',
      cashAmount: 5.0,
      currency: 'USD',
      status: 'Done',
    );

    setUp(() {
      adapter = _RecordingAdapter();
      dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = adapter;
      repo = DioDeliveryReceiptRepository(dio);
    });

    test('records COD then transitions; both 2xx → succeeds (happy path)',
        () async {
      adapter.codStatus = 200;
      adapter.transitionStatus = 200;

      await repo.confirmReceipt(receipt);

      expect(adapter.codHit, isTrue);
      expect(adapter.transitionHit, isTrue);
    });

    test('COD 200 but transition 422 (already Done) → SUCCEEDS (idempotent), '
        'so the customer reaches the rating screen', () async {
      adapter.codStatus = 200;
      adapter.transitionStatus = 422; // delivery already Done

      // Must NOT throw — the redundant transition 422 is an idempotent success.
      await repo.confirmReceipt(receipt);

      expect(adapter.codHit, isTrue);
      expect(adapter.transitionHit, isTrue);
    });

    test('COD record itself fails (404) → throws (rating genuinely blocked)',
        () async {
      adapter.codStatus = 404;
      adapter.transitionStatus = 200;

      await expectLater(
        repo.confirmReceipt(receipt),
        throwsA(isA<DeliveryReceiptRepositoryException>()),
      );
      // We never even attempt the transition if COD failed.
      expect(adapter.transitionHit, isFalse);
    });

    test('transition 500 (real server error, not already-Done) → throws',
        () async {
      adapter.codStatus = 200;
      adapter.transitionStatus = 500;

      await expectLater(
        repo.confirmReceipt(receipt),
        throwsA(isA<DeliveryReceiptRepositoryException>()),
      );
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  int codStatus = 200;
  int transitionStatus = 200;
  bool codHit = false;
  bool transitionHit = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.contains('cod_jeeb/record')) {
      codHit = true;
      return _json(const {'recorded': true}, status: codStatus);
    }
    if (path.contains('status/transition')) {
      transitionHit = true;
      return _json(
        const {'status': 'Done'},
        status: transitionStatus,
      );
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
