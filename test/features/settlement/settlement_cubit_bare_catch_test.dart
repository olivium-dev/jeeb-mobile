// SET-01/SET-02: settlement never hangs on `loading`, and its state carries a
// machine reason rather than an English sentence.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settlement/data/dio_settlement_repository.dart';
import 'package:jeeb_mobile/features/settlement/domain/settlement_repository.dart';

/// Answers every GET with one canned body.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.body, {this.status = 200});

  final Object? body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

DioSettlementRepository _repo(Object? body, {int status = 200}) =>
    DioSettlementRepository(
      Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = _ScriptedAdapter(body, status: status),
    );

void main() {
  test('a `statements` member that is a MAP maps to SettlementFailure.parse, '
      'not an escaping TypeError', () async {
    await expectLater(
      _repo(const {'statements': <String, Object?>{}}).fetchStatements(),
      throwsA(isA<SettlementException>().having(
        (e) => e.failure,
        'failure',
        SettlementFailure.parse,
      )),
    );
  });

  test('a wrong-typed statement field maps to parse too', () async {
    await expectLater(
      _repo(const {
        'statements': <Object?>[
          {'id': 42, 'weekLabel': 'W1'},
        ],
      }).fetchStatements(),
      throwsA(isA<SettlementException>().having(
        (e) => e.failure,
        'failure',
        SettlementFailure.parse,
      )),
    );
  });

  test('a 500 carries the machine reason and NO "HTTP 500" text', () async {
    try {
      await _repo(const <String, Object?>{}, status: 500).fetchStatements();
      fail('expected a SettlementException');
    } on SettlementException catch (e) {
      expect(e.failure, SettlementFailure.server);
      expect(e.toString(), isNot(contains('HTTP')));
      expect(e.toString(), isNot(contains('500')));
    }
  });

  test('a 404 maps to notFound', () async {
    await expectLater(
      _repo(const <String, Object?>{}, status: 404).fetchStatements(),
      throwsA(isA<SettlementException>().having(
        (e) => e.failure,
        'failure',
        SettlementFailure.notFound,
      )),
    );
  });
}
