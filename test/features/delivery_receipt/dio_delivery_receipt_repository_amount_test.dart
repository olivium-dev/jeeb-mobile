// Run-22 P1-A regression guard — receipt amount + jeeberName mapping.
//
// Wire evidence (docs/sprints/sprint-009/proof-run22/wire/diag-statusbuckets.txt):
// `GET /v1/deliveries/{id}` returned `"amount":12` while the delivery was
// `Ordered`, but the `amount` key was ABSENT from the same endpoint once the
// delivery reached `Done` — exactly when the receipt screen reads it. The old
// parser defaulted the missing key to `0.0`, which rendered
// "Pay $0.00 cash to the Jeeber" instead of the real $12.00 fee.
//
// Contract now: an absent/zero amount is UNKNOWN (`cashAmount == null` /
// `hasKnownAmount == false`) — never a fabricated zero — so the receipt screen
// degrades to amount-less copy instead of rendering "$0.00". The gateway
// omission itself is flagged to the gateway lane (commit 39db68d was supposed
// to always include `amount` + `jeeberName`).
//
// COD-COMPLETE FIX (fix/cod-complete): the customer no longer records COD at all
// (that ledger is jeeber/server-owned, amount server-authoritative — BR-16), so
// the former "confirmReceipt COD payload" assertions were removed. Only the
// amount/jeeberName READ mapping is exercised here now.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';

const _deliveryId = '51a88521-fd14-417c-a2cc-37f592ac6798';

void main() {
  late _StubAdapter adapter;
  late DioDeliveryReceiptRepository repo;

  setUp(() {
    adapter = _StubAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://origin.test'))
      ..httpClientAdapter = adapter;
    repo = DioDeliveryReceiptRepository(dio, originGateway: true);
  });

  group('fetchReceipt amount mapping', () {
    test('flat numeric amount (live :10090 Ordered shape) parses as-is',
        () async {
      adapter.deliveryBody = {
        'id': _deliveryId,
        'status': 'Ordered',
        'amount': 12,
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.cashAmount, 12.0);
      expect(receipt.hasKnownAmount, isTrue);
      expect(receipt.currency, 'USD');
    });

    test('nested { value, currency } money object parses', () async {
      adapter.deliveryBody = {
        'id': _deliveryId,
        'status': 'AtDoor',
        'amount': {'value': 9.5, 'currency': 'USD'},
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.cashAmount, 9.5);
      expect(receipt.hasKnownAmount, isTrue);
    });

    test('nested { minorUnits, currency } money object parses (requests-list '
        'DTO drift tolerance)', () async {
      adapter.deliveryBody = {
        'id': _deliveryId,
        'status': 'AtDoor',
        'amount': {'minorUnits': 1200, 'currency': 'USD'},
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.cashAmount, 12.0);
      expect(receipt.hasKnownAmount, isTrue);
    });

    test(
        'RUN-22 P1-A: amount key ABSENT (live Done payload) → amount is '
        'UNKNOWN, never a fabricated 0.0', () async {
      // Exact key set the live gateway returned at 03:11:04 for the Done
      // delivery (minus nulls irrelevant to the parse).
      adapter.deliveryBody = {
        'id': _deliveryId,
        'clientId': '300c9cd7-4fc3-4ae2-86c4-a6fcb601eec0',
        'status': 'Done',
        'description': '',
        'jeeberId': '9acb579d-a624-498c-96ac-de0eb507eeac',
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.cashAmount, isNull);
      expect(receipt.hasKnownAmount, isFalse,
          reason: 'absent amount must render as unknown, not \$0.00');
    });

    test('explicit zero amount is also treated as unknown (a priced delivery '
        'never genuinely costs 0)', () async {
      adapter.deliveryBody = {
        'id': _deliveryId,
        'status': 'Done',
        'amount': 0,
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.hasKnownAmount, isFalse);
    });
  });

  group('fetchReceipt jeeberName mapping', () {
    test('camelCase jeeberName maps through', () async {
      adapter.deliveryBody = {
        'id': _deliveryId,
        'status': 'AtDoor',
        'amount': 12,
        'jeeberName': 'Sami K.',
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.jeeberName, 'Sami K.');
    });

    test('snake_case jeeber_name maps through', () async {
      adapter.deliveryBody = {
        'id': _deliveryId,
        'status': 'AtDoor',
        'amount': 12,
        'jeeber_name': 'Sami K.',
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.jeeberName, 'Sami K.');
    });

    test('absent jeeberName degrades to empty string (screen falls back to '
        '"the Jeeber")', () async {
      adapter.deliveryBody = {
        'id': _deliveryId,
        'status': 'Done',
      };

      final receipt = await repo.fetchReceipt(_deliveryId);

      expect(receipt.jeeberName, isEmpty);
    });
  });

}

class _StubAdapter implements HttpClientAdapter {
  Map<String, Object?> deliveryBody = const {'id': _deliveryId, 'status': ''};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    // Real confirm-receipt write: PATCH /v1/deliveries/{id}/status.
    if (path.contains('/deliveries/') && path.endsWith('/status')) {
      return _json(const {'status': 'Done'});
    }
    return _json(deliveryBody);
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
