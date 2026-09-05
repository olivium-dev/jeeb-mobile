// S10 Defect B — DioDeliveryReceiptRepository terminal-status guard.

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
          options: any(named: 'options'),
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
          options: any(named: 'options'),
        ));
  });

  test('terminal check is case-insensitive (e.g. "done", "delivered")',
      () async {
    await repo.confirmReceipt(_receipt(status: 'done'));
    await repo.confirmReceipt(_receipt(status: 'Delivered'));

    verifyNever(() => dio.patch<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
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
          options: any(named: 'options'),
        )).called(1);
    // The fictional COD-record route is never POSTed.
    verifyNever(() => dio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        ));
  });
}
