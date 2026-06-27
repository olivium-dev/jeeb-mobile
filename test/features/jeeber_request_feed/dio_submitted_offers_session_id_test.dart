// S0-OAD-03 identity-cleanup regression: DioSubmittedOffersRepository must scope
// the submitted-offers list to the REAL AUTHENTICATED SESSION jeeber id resolved
// from AuthTokenStore — NEVER a hardcoded `user-jeeber-002` fixture id.
//
// Failing-first proof: before the fix the screens passed
// `SessionSeamBootstrap.jeeberUserId` (== 'user-jeeber-002') into the repo, so a
// real jeeber's offers were queried against the mock fixture id. These tests
// pin that the query param now carries the session id (and that a hardcoded
// fixture id never leaks).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_submitted_offers_repository.dart';

class _MockDio extends Mock implements Dio {}

/// In-memory [AuthTokenStore] — the session/auth source under test.
class _FakeTokenStore implements AuthTokenStore {
  _FakeTokenStore(this._userId);
  final String? _userId;

  @override
  Future<String?> get userId async => _userId;

  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
  @override
  Future<bool> get hasToken async => false;
  @override
  Future<void> clear() async {}
  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {}
}

void main() {
  late _MockDio dio;

  setUp(() {
    dio = _MockDio();
    when(() => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        data: const {'items': <dynamic>[]},
        statusCode: 200,
      ),
    );
  });

  Map<String, dynamic> capturedQuery() {
    final captured = verify(() => dio.get<Map<String, dynamic>>(
          any(),
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured;
    return (captured.last as Map).cast<String, dynamic>();
  }

  test('scopes ?jeeberId= to the REAL session id from AuthTokenStore '
      '(not the hardcoded user-jeeber-002)', () async {
    final repo = DioSubmittedOffersRepository(
      dio: dio,
      tokenStore: _FakeTokenStore('jeeber-session-77'),
    );

    await repo.listSubmitted();

    final query = capturedQuery();
    expect(query['jeeberId'], 'jeeber-session-77');
    expect(query['jeeberId'], isNot('user-jeeber-002'),
        reason: 'the live jeeber id must come from the session, never a fixture');
  });

  test('an explicit jeeberId override (mock seam / tests) still wins', () async {
    final repo = DioSubmittedOffersRepository(
      dio: dio,
      jeeberId: 'explicit-seam-id',
      tokenStore: _FakeTokenStore('jeeber-session-77'),
    );

    await repo.listSubmitted();

    expect(capturedQuery()['jeeberId'], 'explicit-seam-id');
  });

  test('omits ?jeeberId= entirely when the session has no id '
      '(gateway re-scopes from the bearer sub — §6B)', () async {
    final repo = DioSubmittedOffersRepository(
      dio: dio,
      tokenStore: _FakeTokenStore(null),
    );

    await repo.listSubmitted();

    expect(capturedQuery().containsKey('jeeberId'), isFalse);
  });
}
