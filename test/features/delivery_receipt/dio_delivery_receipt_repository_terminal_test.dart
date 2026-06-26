// S10 Defect B — DioDeliveryReceiptRepository terminal-status guard.
//
// After the door-OTP handover drives the delivery to `Done` server-side, the
// customer's "Yes, I received it" CTA must NOT fire a second
// `POST /v1/delivery/status/transition` — the frozen SM-1 table correctly
// rejects `Done → Done` with 422. The repository now skips the transition POST
// entirely when the loaded receipt is already terminal, while still recording
// the (idempotent, load-bearing) cash-on-delivery settlement so the customer
// proceeds to rating.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';

class _MockDio extends Mock implements Dio {}

const _codPath = '/v1/payments/cod_jeeb/record';
const _transitionPath = '/v1/delivery/status/transition';

DeliveryReceipt _receipt({required String status}) => DeliveryReceipt(
      deliveryId: 'delivery-xyz',
      jeeberName: 'Kamal',
      jeeberId: 'user-jeeber-002',
      cashAmount: 9.0,
      currency: 'USD',
      status: status,
    );

Response<Map<String, dynamic>> _ok() => Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: const <String, dynamic>{},
    );

void main() {
  late _MockDio dio;
  late DioDeliveryReceiptRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioDeliveryReceiptRepository(dio);
    when(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((_) async => _ok());
  });

  test(
      'already-Done receipt records COD but does NOT POST the transition '
      '(no illegal Done → Done)', () async {
    await repo.confirmReceipt(_receipt(status: 'Done'));

    // COD settlement still recorded (load-bearing, idempotent).
    verify(() => dio.post<Map<String, dynamic>>(
          _codPath,
          data: any(named: 'data'),
        )).called(1);
    // The SM-1 transition is NEVER requested for a terminal delivery.
    verifyNever(() => dio.post<Map<String, dynamic>>(
          _transitionPath,
          data: any(named: 'data'),
        ));
  });

  test('terminal check is case-insensitive (e.g. "done", "delivered")',
      () async {
    await repo.confirmReceipt(_receipt(status: 'done'));
    await repo.confirmReceipt(_receipt(status: 'Delivered'));

    verifyNever(() => dio.post<Map<String, dynamic>>(
          _transitionPath,
          data: any(named: 'data'),
        ));
  });

  test('non-terminal receipt (AtDoor) STILL fires the AtDoor → Done transition',
      () async {
    await repo.confirmReceipt(_receipt(status: 'AtDoor'));

    verify(() => dio.post<Map<String, dynamic>>(
          _codPath,
          data: any(named: 'data'),
        )).called(1);
    // AtDoor is non-terminal → the SM-1 AtDoor → Done transition still fires.
    verify(() => dio.post<Map<String, dynamic>>(
          _transitionPath,
          data: any(named: 'data'),
        )).called(1);
  });
}
