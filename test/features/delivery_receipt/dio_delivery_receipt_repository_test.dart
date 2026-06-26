import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';

/// RATING-UNBLOCK (iter6) + S10 Defect B: confirm-receipt must be IDEMPOTENT.
/// In the real two-sided flow the delivery is frequently ALREADY `Done` by the
/// time the customer confirms receipt (the handover-OTP path drove
/// `AtDoor → Done` server-side).
///
/// S10 Defect B hardens this: when the LOADED receipt is already terminal, the
/// repository SKIPS the `Done → Done` transition POST entirely (the frozen SM-1
/// table correctly rejects it with 422 — no point firing it). The COD record
/// (the load-bearing step that unblocks rating) still runs. The legacy 422
/// swallow is retained as a belt-and-braces guard for the race where the server
/// flips to Done between fetchReceipt and confirm — verified below.
void main() {
  group('DioDeliveryReceiptRepository.confirmReceipt — idempotent', () {
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
      repo = DioDeliveryReceiptRepository(dio);
    });

    test(
        'non-terminal (AtDoor): records COD then transitions; both 2xx → '
        'succeeds (happy path)', () async {
      adapter.codStatus = 200;
      adapter.transitionStatus = 200;

      await repo.confirmReceipt(receiptWith('AtDoor'));

      expect(adapter.codHit, isTrue);
      expect(adapter.transitionHit, isTrue);
    });

    test(
        'S10 Defect B — already Done: records COD but SKIPS the transition '
        '(no illegal Done → Done), still succeeds → customer reaches rating',
        () async {
      adapter.codStatus = 200;
      adapter.transitionStatus = 200;

      await repo.confirmReceipt(receiptWith('Done'));

      expect(adapter.codHit, isTrue);
      expect(adapter.transitionHit, isFalse);
    });

    test(
        'race guard: non-terminal load but server returns transition 422 → '
        'SUCCEEDS (idempotent swallow)', () async {
      adapter.codStatus = 200;
      adapter.transitionStatus = 422; // server flipped to Done mid-confirm

      // Must NOT throw — the redundant transition 422 is an idempotent success.
      await repo.confirmReceipt(receiptWith('AtDoor'));

      expect(adapter.codHit, isTrue);
      expect(adapter.transitionHit, isTrue);
    });

    test('COD record itself fails (404) → throws (rating genuinely blocked)',
        () async {
      adapter.codStatus = 404;
      adapter.transitionStatus = 200;

      await expectLater(
        repo.confirmReceipt(receiptWith('AtDoor')),
        throwsA(isA<DeliveryReceiptRepositoryException>()),
      );
      // We never even attempt the transition if COD failed.
      expect(adapter.transitionHit, isFalse);
    });

    test(
        'non-terminal transition 500 (real server error, not already-Done) → '
        'throws', () async {
      adapter.codStatus = 200;
      adapter.transitionStatus = 500;

      await expectLater(
        repo.confirmReceipt(receiptWith('AtDoor')),
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
