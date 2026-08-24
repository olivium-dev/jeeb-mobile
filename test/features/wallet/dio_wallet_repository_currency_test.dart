// c3-3 — the wallet snapshot reports the server's currency or nothing at all;
// a missing code must never be fabricated back into 'USD'.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/wallet/data/dio_wallet_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(Map<String, dynamic> data) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: 200,
    );

void main() {
  late _MockDio dio;
  late DioWalletRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioWalletRepository(dio);
  });

  group('DioWalletRepository — currency (c3-3)', () {
    test('a body WITHOUT currency parses to the empty code, not a fabricated '
        "'USD'", () async {
      String? capturedPath;
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments.first as String;
        return _resp(const {'availableBalance': 5});
      });

      final balance = await repo.fetchBalance();

      expect(capturedPath, '/v1/jeeb/wallet');
      expect(balance.currency, '');
      expect(balance.currency, isNot('USD'),
          reason: 'an absent server currency is unknown, never assumed USD');
      expect(balance.availableBalance, 5.0);
    });

    test('a server-sent currency code passes through verbatim', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _resp(const {'currency': 'USD', 'availableBalance': 5}),
      );

      final balance = await repo.fetchBalance();

      expect(balance.currency, 'USD');
      expect(balance.availableBalance, 5.0);
    });
  });
}
