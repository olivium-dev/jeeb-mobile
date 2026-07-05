// S10 Defect B — DioDeliveryReceiptRepository terminal-status guard.
//
// After the door-OTP handover drives the delivery to `Done` server-side, the
// customer's "Yes, I received it" CTA must NOT fire a second status transition —
// the frozen SM-1 table correctly rejects `Done → Done` with 422. The repository
// skips the transition PATCH entirely when the loaded receipt is already
// terminal.
//
// COD-COMPLETE FIX (fix/cod-complete): there is NO customer-side COD write any
// more (the old `POST /v1/payments/cod_jeeb/record` 404'd and blocked rating),
// and the transition now targets the real, shipped gateway route
// `PATCH /v1/deliveries/{id}/status` instead of the fictional
// `POST /v1/delivery/status/transition`.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';

class _MockDio extends Mock implements Dio {}

const _statusPath = '/v1/deliveries/delivery-xyz/status';

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
      data: const <String, dynamic>{'status': 'Done'},
    );

void main() {
  late _MockDio dio;
  late DioDeliveryReceiptRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioDeliveryReceiptRepository(dio, originGateway: true);
    when(() => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((_) async => _ok());
  });

  test(
      'already-Done receipt does NOT PATCH the transition '
      '(no illegal Done → Done)', () async {
    await repo.confirmReceipt(_receipt(status: 'Done'));

    // The SM-1 transition is NEVER requested for a terminal delivery.
    verifyNever(() => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ));
  });

  test('terminal check is case-insensitive (e.g. "done", "delivered")',
      () async {
    await repo.confirmReceipt(_receipt(status: 'done'));
    await repo.confirmReceipt(_receipt(status: 'Delivered'));

    verifyNever(() => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ));
  });

  test(
      'non-terminal receipt (AtDoor) STILL fires the AtDoor → Done transition '
      'via PATCH /v1/deliveries/{id}/status', () async {
    await repo.confirmReceipt(_receipt(status: 'AtDoor'));

    // The transition targets the REAL, shipped gateway route.
    verify(() => dio.patch<Map<String, dynamic>>(
          _statusPath,
          data: any(named: 'data'),
        )).called(1);
    // The fictional COD-record route is never POSTed.
    verifyNever(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ));
  });
}
