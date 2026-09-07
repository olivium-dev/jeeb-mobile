import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/goods_cost/data/dio_goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost_repository.dart';

/// Proves the REAL Dio impl for goods-cost: currency is read from the gateway
/// VERBATIM (no hardcode), the record POST sends the typed amount and echoes
void main() {
  late _RecordingAdapter adapter;
  late Dio dio;
  late DioGoodsCostRepository repo;

  setUp(() {
    adapter = _RecordingAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://gw.test'))
      ..httpClientAdapter = adapter;
    repo = DioGoodsCostRepository(dio);
  });

  group('fetchCurrency', () {
    test('reads the gateway currency verbatim (flat field)', () async {
      adapter.deliveryBody = const {'id': 'd-1', 'currency': 'LBP'};

      final currency = await repo.fetchCurrency('d-1');

      expect(currency, 'LBP');
      expect(adapter.deliveryHit, isTrue);
    });

    test('reads the nested money-object currency', () async {
      adapter.deliveryBody = const {
        'id': 'd-1',
        'amount': {'value': 9.0, 'currency': 'EUR'},
      };

      expect(await repo.fetchCurrency('d-1'), 'EUR');
    });

    test('UX-22: an absent currency is a FAILURE, never a fabricated USD',
        () async {
      adapter.deliveryBody = const {'id': 'd-1'};

      await expectLater(
        repo.fetchCurrency('d-1'),
        throwsA(
          isA<GoodsCostRepositoryException>().having(
            (e) => e.failure,
            'failure',
            GoodsCostFailure.currencyUnavailable,
          ),
        ),
      );
    });

    test('404 → notFound', () async {
      adapter.deliveryStatus = 404;

      await expectLater(
        repo.fetchCurrency('missing'),
        throwsA(
          isA<GoodsCostRepositoryException>().having(
            (e) => e.failure,
            'failure',
            GoodsCostFailure.notFound,
          ),
        ),
      );
    });
  });

  group('recordGoodsCost', () {
    test('POSTs the amount and returns the gateway-confirmed record', () async {
      adapter.recordBody = const {
        'deliveryId': 'd-1',
        'amount': 42.5,
        'currency': 'LBP',
      };

      final result = await repo.recordGoodsCost(deliveryId: 'd-1', amount: 42.5);

      expect(adapter.recordHit, isTrue);
      expect(adapter.sentAmount, 42.5);
      expect(result.deliveryId, 'd-1');
      expect(result.amount, 42.5);
      // Currency is gateway-verbatim, not the client's guess.
      expect(result.currency, 'LBP');
    });

    test('the client amount is never echoed back as a confirmation', () async {
      adapter.recordBody = const {'deliveryId': 'd-1'};

      await expectLater(
        repo.recordGoodsCost(deliveryId: 'd-1', amount: 42.5),
        throwsA(
          isA<GoodsCostRepositoryException>().having(
            (e) => e.failure,
            'failure',
            GoodsCostFailure.amountUnconfirmed,
          ),
        ),
      );
    });

    test('a confirmed amount with no currency yields a null currency, never '
        'an invented one', () async {
      adapter.recordBody = const {'deliveryId': 'd-1', 'amount': 42.5};

      final result =
          await repo.recordGoodsCost(deliveryId: 'd-1', amount: 42.5);

      expect(result.amount, 42.5);
      expect(result.currency, isNull);
    });

    test('422 → validation', () async {
      adapter.recordStatus = 422;

      await expectLater(
        repo.recordGoodsCost(deliveryId: 'd-1', amount: -1),
        throwsA(
          isA<GoodsCostRepositoryException>().having(
            (e) => e.failure,
            'failure',
            GoodsCostFailure.validation,
          ),
        ),
      );
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  Map<String, Object?> deliveryBody = const {'id': 'd-1', 'currency': 'USD'};
  Map<String, Object?> recordBody = const {'currency': 'USD'};
  int deliveryStatus = 200;
  int recordStatus = 200;

  bool deliveryHit = false;
  bool recordHit = false;
  double? sentAmount;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.contains('/goods-cost')) {
      recordHit = true;
      final data = options.data;
      if (data is Map && data['amount'] is num) {
        sentAmount = (data['amount'] as num).toDouble();
      }
      return _json(recordBody, status: recordStatus);
    }
    // BUG-8: the currency read now defaults to the plural `/v1/deliveries/{id}`
    if (path.contains('/v1/deliver')) {
      deliveryHit = true;
      return _json(deliveryBody, status: deliveryStatus);
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
