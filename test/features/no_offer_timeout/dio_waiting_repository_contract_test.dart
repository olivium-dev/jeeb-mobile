// P7 T4 — LEGACY-KEY REJECTION: the acceptance proof that the clean break is
// real.
//
// Before the ruling the waiting repository read a legacy absolute key (see the
// T4.1 payload below) that the gateway NEVER emitted and, on the resulting
// null, the cubit fabricated a 5-minute countdown unrelated to the tier TTL.
// The wire contract is now exactly one key: `offerDeadlineInSeconds`, a
// server-relative remaining value.
//
// This whole file would have PASSED trivially before the change (a legacy-only
// payload used to parse fine and silently produce a fabricated window). It is
// the test that pins "no compatibility shim, no fallback, no fabrication".

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/data/dio_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';

/// Stub Dio serving one canned request row; the offers probe returns empty.
class _FakeDio extends Fake implements Dio {
  _FakeDio(this.requestBody);

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

final DateTime _now = DateTime.utc(2026, 7, 25, 12);

DioWaitingRepository _repo(Map<String, dynamic> body, {DateTime? now}) =>
    DioWaitingRepository(_FakeDio(body), now: () => now ?? _now);

Matcher _throwsContract(Matcher messageMatcher) => throwsA(
  isA<WaitingException>()
      .having((e) => e.failure, 'failure', WaitingFailure.contractViolation)
      .having((e) => e.message, 'message', messageMatcher),
);

void main() {
  group('T4 — offer-wait contract (no legacy alias, no fabrication)', () {
    test(
      'T4.1 — a legacy-only payload is REJECTED, never silently accepted',
      () async {
        final repo = _repo(const {
          'status': 'pending',
          'broadcastExpiresAt': '2026-07-25T18:00:00Z',
        });

        await expectLater(
          repo.fetchRequest('req-legacy'),
          _throwsContract(
            allOf(contains('offerDeadlineInSeconds'), contains('req-legacy')),
          ),
        );
      },
    );

    test(
      'T4.2 — the contract field anchors against the injected clock',
      () async {
        final repo = _repo(const {
          'status': 'pending',
          'offerDeadlineInSeconds': 1740,
          'serverNow': '2026-07-25T09:00:00Z',
        });

        final waiting = await repo.fetchRequest('req-1');

        expect(waiting.remainingAtReceipt, const Duration(seconds: 1740));
        expect(waiting.receivedAt, _now);
        expect(waiting.phase, WaitingRequestPhase.broadcasting);
      },
    );

    test('T4.3 — a stringly-typed deadline is a contract violation', () async {
      final repo = _repo(const {
        'status': 'pending',
        'offerDeadlineInSeconds': '1740',
      });

      await expectLater(
        repo.fetchRequest('req-1'),
        _throwsContract(contains('String')),
      );
    });

    test(
      'T4.4 — a negative remaining is clock jitter, NOT a contract break',
      () async {
        final repo = _repo(const {
          'status': 'pending',
          'offerDeadlineInSeconds': -3,
        });

        final waiting = await repo.fetchRequest('req-1');

        expect(waiting.remainingAtReceipt, Duration.zero);
        expect(waiting.deadline, _now);
      },
    );

    test('T4.5 — an expired row legitimately carries no deadline', () async {
      final repo = _repo(const {'status': 'expired'});

      final waiting = await repo.fetchRequest('req-1');

      expect(waiting.remainingAtReceipt, isNull);
      expect(waiting.deadline, isNull);
      expect(waiting.phase, WaitingRequestPhase.expired);
    });

    test('T4.6 — an accepted row legitimately carries no deadline', () async {
      final repo = _repo(const {'status': 'accepted'});

      final waiting = await repo.fetchRequest('req-1');

      expect(waiting.remainingAtReceipt, isNull);
      expect(waiting.phase.isTerminal, isTrue);
    });

    // Mobile treats `matched` as terminal while the gateway still ships a
    // deadline for it (it is pre-acceptance server-side). A non-null value on a
    // terminal phase is accepted and simply unused; only ABSENCE on a live
    // phase throws. See plan §3.3.
    test(
      'T4.7 — a deadline on a terminal `matched` row is accepted, unused',
      () async {
        final repo = _repo(const {
          'status': 'matched',
          'offerDeadlineInSeconds': 900,
        });

        final waiting = await repo.fetchRequest('req-1');

        expect(waiting.phase, WaitingRequestPhase.matched);
        expect(waiting.remainingAtReceipt, const Duration(seconds: 900));
      },
    );

    test('T4.8 — the deadline is DERIVED from the relative value', () async {
      final anchor = DateTime.utc(2026, 7, 25, 12);
      final repo = _repo(const {
        'status': 'pending',
        'offerDeadlineInSeconds': 600,
        // A server absolute is present and deliberately IGNORED — parsing it
        // would reintroduce handset-clock-skew corruption.
        'offerDeadlineAt': '2026-07-25T23:59:00Z',
      }, now: anchor);

      final waiting = await repo.fetchRequest('req-1');

      expect(waiting.deadline, DateTime.utc(2026, 7, 25, 12, 10));
    });

    test('an offers-arrived row without the field also violates', () async {
      final repo = _repo(const {'status': 'pending', 'offersCount': 2});

      await expectLater(
        repo.fetchRequest('req-offers'),
        _throwsContract(contains('offersArrived')),
      );
    });
  });
}
