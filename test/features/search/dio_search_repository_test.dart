// Unit guard for `DioSearchRepository` — the gateway free-text search BFF
// parser (Sprint-5 Stream C; coverage added Sprint-15).
//
// Pins the parse contract in isolation off a stubbed Dio (resolve/reject
// interceptor, the dio_tier_repository_test.dart precedent — no real socket):
//   * a well-formed `{results:[...]}` payload maps to typed SearchResults;
//   * a result with an EMPTY or MISSING `id` is DROPPED at parse time so it can
//     never become a dead-tap row NOR collide on the `search_result_<id>`
//     semantics id with another empty-id row (FIX #2);
//   * `404` maps to the honest `SearchFailure.unavailable` (negative path).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/search/data/dio_search_repository.dart';
import 'package:jeeb_mobile/features/search/domain/search_repository.dart';

Dio _dioWith(Object? body, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response(data: body, statusCode: status, requestOptions: options),
        );
      },
    ),
  );
  return dio;
}

Dio _dioRejecting({required int status}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(statusCode: status, requestOptions: options),
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('DioSearchRepository — parse contract', () {
    test('maps a well-formed results payload to typed hits (happy path)',
        () async {
      final dio = _dioWith({
        'results': [
          {'id': 'r1', 'type': 'order', 'title': 'Order 1', 'ref': 'd-1'},
          {'id': 'r2', 'type': 'chat', 'title': 'Chat 2'},
        ],
      });
      final results = await DioSearchRepository(dio: dio).search('x');

      expect(results.map((r) => r.id), ['r1', 'r2']);
      expect(results.first.kind, SearchResultKind.order);
      expect(results.first.refId, 'd-1');
      expect(results[1].kind, SearchResultKind.conversation);
    });

    test(
        'drops results with an empty or missing id — no dead-tap rows, no '
        'duplicate search_result_ semantics ids (FIX #2)', () async {
      final dio = _dioWith({
        'results': [
          {'id': 'r1', 'type': 'order', 'title': 'Order 1', 'ref': 'd-1'},
          {'id': '', 'type': 'order', 'title': 'Ghost (empty id)'},
          {'type': 'conversation', 'title': 'No id at all'},
          {'id': '   ', 'type': 'chat', 'title': 'Whitespace id'},
          {'id': 'r2', 'type': 'chat', 'title': 'Chat 2'},
        ],
      });
      final results = await DioSearchRepository(dio: dio).search('x');

      // Only the two addressable rows survive — the three id-less rows (which
      // would render a dead InkWell AND a duplicated `search_result_` id) are
      // dropped at parse time.
      expect(results.map((r) => r.id), ['r1', 'r2']);
      expect(results.every((r) => r.id.trim().isNotEmpty), isTrue);
    });

    test('404 maps to SearchFailure.unavailable (negative path)', () async {
      final repo = DioSearchRepository(dio: _dioRejecting(status: 404));
      await expectLater(
        repo.search('x'),
        throwsA(
          isA<SearchRepositoryException>().having(
            (e) => e.failure,
            'failure',
            SearchFailure.unavailable,
          ),
        ),
      );
    });
  });
}
