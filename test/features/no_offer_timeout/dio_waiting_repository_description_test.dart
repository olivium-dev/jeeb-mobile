// G1 (sprint-009 P0) — the waiting screen's request row parse must carry the
// customer's request content. `GET /v1/requests/:id` returns the `description`
// the compose flow POSTed (verified against JeebRequestsController: the
// create requires a non-blank Description and the read echoes it); a dedicated
// short `title` wins when the gateway mints one.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/data/dio_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';

/// Stub Dio serving canned bodies per path prefix (request row + offers list).
class _FakeDio extends Fake implements Dio {
  _FakeDio({required this.requestBody});

  final Map<String, dynamic> requestBody;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    final body = path.startsWith('/v1/requests/')
        ? requestBody
        : <String, dynamic>{'offers': <dynamic>[]};
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body as T,
    );
  }
}

void main() {
  group('DioWaitingRepository request parse', () {
    test(
      'falls back to the wire `description` when no title is minted',
      () async {
        final repo = DioWaitingRepository(
          _FakeDio(
            requestBody: const {
              'id': 'req-1',
              'status': 'pending',
              'offerDeadlineInSeconds': 1800,
              'description': '2 shawarma + cola from Barbar',
            },
          ),
        );

        final waiting = await repo.fetchWaiting('req-1');

        expect(
          waiting.title,
          '2 shawarma + cola from Barbar',
          reason: 'the customer\'s own words must reach the waiting screen',
        );
      },
    );

    test('a dedicated short `title` wins over the description', () async {
      final repo = DioWaitingRepository(
        _FakeDio(
          requestBody: const {
            'id': 'req-1',
            'status': 'pending',
            'offerDeadlineInSeconds': 1800,
            'title': 'Barbar order',
            'description': '2 shawarma + cola from Barbar',
          },
        ),
      );

      final waiting = await repo.fetchWaiting('req-1');

      expect(waiting.title, 'Barbar order');
    });

    test('title stays null when the row carries neither field', () async {
      final repo = DioWaitingRepository(
        _FakeDio(
          requestBody: const {
            'id': 'req-1',
            'status': 'pending',
            'offerDeadlineInSeconds': 1800,
          },
        ),
      );

      final waiting = await repo.fetchWaiting('req-1');

      expect(waiting.title, isNull);
    });

    // P7: a row the server says has NO countdown (terminal) legitimately omits
    // `offerDeadlineInSeconds` — that stays null across repeated reads and is
    // never back-filled with an invented window. (A LIVE row that omits it is a
    // contract violation and throws — see
    // dio_waiting_repository_contract_test.dart T4.1.)
    test(
      'an omitted deadline on a terminal row stays unknown across repeated '
      'reads',
      () async {
        for (final status in const <String>['expired', 'cancelled']) {
          final body = <String, dynamic>{'id': 'req-1', 'status': status};
          final repo = DioWaitingRepository(_FakeDio(requestBody: body));

          final first = await repo.fetchRequest('req-1');
          final second = await repo.fetchRequest('req-1');

          expect(first.remainingAtReceipt, isNull, reason: status);
          expect(second.remainingAtReceipt, isNull, reason: status);
          expect(first.deadline, isNull, reason: status);
        }
      },
    );

    test('anchors the server-supplied remaining seconds exactly', () async {
      final anchor = DateTime.utc(2026, 7, 22, 8, 31, 17);
      final repo = DioWaitingRepository(
        _FakeDio(
          requestBody: const {
            'id': 'req-1',
            'status': 'pending',
            'offerDeadlineInSeconds': 1740,
          },
        ),
        now: () => anchor,
      );

      final waiting = await repo.fetchRequest('req-1');

      expect(waiting.remainingAtReceipt, const Duration(seconds: 1740));
      expect(waiting.receivedAt, anchor);
      // The deadline is DERIVED in the device clock domain, never parsed from a
      // server absolute.
      expect(waiting.deadline, anchor.add(const Duration(seconds: 1740)));
    });

    test('terminal server status wins over stale offers', () async {
      const cases = <String, WaitingRequestPhase>{
        'expired': WaitingRequestPhase.expired,
        'Cancelled': WaitingRequestPhase.cancelled,
        'matched': WaitingRequestPhase.matched,
      };

      for (final entry in cases.entries) {
        final repo = DioWaitingRepository(
          _FakeDio(
            requestBody: {'id': 'req-1', 'status': entry.key, 'offersCount': 2},
          ),
        );

        final waiting = await repo.fetchRequest('req-1');

        expect(waiting.phase, entry.value, reason: entry.key);
        expect(waiting.phase.isTerminal, isTrue, reason: entry.key);
      }
    });
  });
}
