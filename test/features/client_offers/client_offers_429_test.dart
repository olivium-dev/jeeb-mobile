import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/rate_limit_interceptor.dart';
import 'package:jeeb_mobile/core/network/single_flight_get.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_state.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/dio_waiting_repository.dart';

/// FIX-A (fix/neworder-429-dedupe): a 429 on the offers cold-load must NOT drop
/// the "Choose a Jeeber" screen to the connection-error page, and duplicate
/// concurrent `GET /v1/offers?requestId` reads must collapse to ONE wire call.

/// Scripted adapter: returns a per-request scripted [ResponseBody] and counts
/// wire hits (a request suppressed by [RateLimitInterceptor] never reaches it).
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);
  final ResponseBody Function(RequestOptions options) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];
  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options);
  }

  @override
  void close({bool force = false}) {}
}

/// Gated adapter (holds responses in flight) counting wire hits — for the
/// cross-repo single-flight collapse test.
class _GatedAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];
  final Completer<void> gate = Completer<void>();
  int get callCount => requests.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await gate.future;
    return ResponseBody.fromString('{"items":[]}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(int status, {Map<String, List<String>>? headers}) =>
    ResponseBody.fromString('{"items":[]}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?headers,
    });

/// Fake repository whose first N `fetchOffers` calls raise a rate-limit, then
/// succeeds — proves the cubit rides out the back-off instead of failing.
class _FlakyRateLimitedRepository implements OffersRepository {
  _FlakyRateLimitedRepository({required this.failuresBeforeSuccess});
  int failuresBeforeSuccess;
  int fetchCalls = 0;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    fetchCalls++;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw const OffersRepositoryException(
        OffersFailure.rateLimited,
        'rate limited',
        Duration(seconds: 3),
      );
    }
    return OffersSnapshot(
      offers: const [],
      windowExpiresAt: DateTime.utc(2026, 1, 1, 0, 15),
      requestIsOpen: true,
    );
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async =>
      OfferAcceptResult.empty;
}

void main() {
  group('DioOffersRepository maps rate-limit signals to a retryable failure',
      () {
    test('a real 429 → OffersFailure.rateLimited carrying Retry-After',
        () async {
      final adapter = _ScriptedAdapter(
        (_) => _body(429, headers: {'retry-after': ['30']}),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
        ..httpClientAdapter = adapter;
      final repo = DioOffersRepository(dio);

      await expectLater(
        repo.fetchOffers('r1'),
        throwsA(
          isA<OffersRepositoryException>()
              .having((e) => e.failure, 'failure', OffersFailure.rateLimited)
              .having((e) => e.retryAfter, 'retryAfter',
                  const Duration(seconds: 30)),
        ),
      );
    });

    test('the RateLimitInterceptor suppression-cancel → rateLimited (not fatal)',
        () async {
      // First read trips the 429 and opens the Retry-After window; the next
      // read is suppressed locally (DioExceptionType.cancel) — which must ALSO
      // map to rateLimited, never network/unknown (the fatal branches).
      var wireHits = 0;
      final adapter = _ScriptedAdapter((_) {
        wireHits++;
        return wireHits == 1
            ? _body(429, headers: {'retry-after': ['30']})
            : _body(200);
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
        ..interceptors.add(RateLimitInterceptor(maxJitter: Duration.zero))
        ..httpClientAdapter = adapter;
      final repo = DioOffersRepository(dio);

      await expectLater(
        repo.fetchOffers('r1'),
        throwsA(isA<OffersRepositoryException>()
            .having((e) => e.failure, 'failure', OffersFailure.rateLimited)),
      );
      // Second call is short-circuited by the open window — never hits the wire.
      await expectLater(
        repo.fetchOffers('r1'),
        throwsA(isA<OffersRepositoryException>()
            .having((e) => e.failure, 'failure', OffersFailure.rateLimited)),
      );
      expect(adapter.callCount, 1);
    });
  });

  test('shared coalescer collapses offers + waiting probes onto ONE wire call',
      () async {
    final adapter = _GatedAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..httpClientAdapter = adapter;
    final shared = SingleFlightGet(dio);
    final offersRepo = DioOffersRepository(dio, coalescer: shared);
    final waitingRepo = DioWaitingRepository(dio, coalescer: shared);

    // Two DIFFERENT repos probe `GET /v1/offers?requestId=r1` at the same
    // instant — the shared single-flight must collapse them to one wire call.
    final a = offersRepo.fetchOffers('r1');
    final b = waitingRepo.fetchOfferCount('r1');

    adapter.gate.complete();
    await a;
    await b;
    // The two different repos' identical offer probes collapsed to one wire
    // call. Offer-review additionally reads the owner-scoped request status.
    expect(
      adapter.requests.where((request) => request.path == '/v1/offers'),
      hasLength(1),
    );
    expect(
      adapter.requests.where((request) => request.path == '/v1/requests/r1'),
      hasLength(1),
    );
    expect(adapter.callCount, 2);
  });

  group('ClientOffersCubit does not fail the screen on a rate-limited load',
      () {
    test('429 keeps the screen loading, auto-retries, then loads — never failed',
        () async {
      final repo = _FlakyRateLimitedRepository(failuresBeforeSuccess: 2);
      final emitted = <OffersScreenStatus>[];
      final cubit = ClientOffersCubit(
        repository: repo,
        requestId: 'r1',
        now: () => DateTime.utc(2026, 1, 1),
        // Empty tick streams so no real poll/clock timers leak into the binding.
        pollTicks: const Stream<void>.empty(),
        clockTicks: const Stream<void>.empty(),
        // Deterministic instant retry so the back-off fires without a real wait.
        retryDelay: (_) => Future<void>.value(),
      );
      cubit.stream.listen((s) => emitted.add(s.status));

      await cubit.load();
      // Cold load hit a 429: still loading, NOT failed.
      expect(cubit.state.status, OffersScreenStatus.loading);

      // Drain the auto-retry chain (two rate-limits, then success).
      await pumpEventQueue();

      expect(cubit.state.status, OffersScreenStatus.loaded);
      expect(repo.fetchCalls, 3); // 2 suppressed + 1 success
      // The fatal connection-error state was NEVER entered.
      expect(emitted, isNot(contains(OffersScreenStatus.failed)));
      expect(cubit.state.error, isNull);

      await cubit.close();
    });
  });
}
