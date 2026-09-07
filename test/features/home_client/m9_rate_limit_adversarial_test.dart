import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ScriptedRepository implements ClientHomeRepository {
  _ScriptedRepository(this.snapshots);

  final List<ClientHomeSnapshot> snapshots;
  int calls = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    final index = calls < snapshots.length ? calls : snapshots.length - 1;
    calls += 1;
    return snapshots[index];
  }
}

const _recovered = ClientHomeRequest(
  id: 'recovered-request',
  title: 'Recovered request',
  status: ClientRequestStatus.searching,
  destinationLabel: 'Test destination',
);

void _withFailedRateLimit(
  void Function(
    FakeAsync async,
    _ScriptedRepository repository,
    ClientHomeCubit cubit,
    StreamController<void> signals,
  )
  verify,
) {
  fakeAsync((async) {
    final repository = _ScriptedRepository([
      const ClientHomeSnapshot(
        rateLimited: true,
        retryAfter: Duration(seconds: 30),
        requestsFailure: ServerFailure(status: 503),
        inProgressFailure: RateLimitedFailure(),
      ),
      const ClientHomeSnapshot(pending: [_recovered]),
    ]);
    final signals = StreamController<void>.broadcast();
    final cubit = ClientHomeCubit(
      repository: repository,
      greetingNameProvider: () => 'Sami',
      refreshSignals: signals.stream,
      cancelledRequestSignals: const Stream<String>.empty(),
      now: async.getClock(DateTime(2026)).now,
    );
    try {
      unawaited(cubit.load());
      async.flushMicrotasks();
      expect(cubit.state.status, ClientHomeStatus.failed);
      expect(repository.calls, 1);
      verify(async, repository, cubit, signals);
    } finally {
      unawaited(cubit.close());
      unawaited(signals.close());
      async.flushMicrotasks();
    }
    expect(async.nonPeriodicTimerCount, 0);
  });
}

void main() {
  for (final withPushes in [false, true]) {
    test('M9 hidden retry expiry waits for return; pushes=$withPushes', () {
      _withFailedRateLimit((async, repository, cubit, signals) {
        unawaited(cubit.load());
        cubit.setPollingVisible(false);
        for (var retry = 0; retry < 3; retry++) {
          unawaited(cubit.load());
          unawaited(cubit.refresh());
          if (withPushes) signals.add(null);
        }
        async.flushMicrotasks();
        expect(async.nonPeriodicTimerCount, 1);
        async.elapse(const Duration(seconds: 29));
        expect(repository.calls, 1);
        async.elapse(const Duration(seconds: 1));
        expect(
          repository.calls,
          1,
          reason: 'expiry must not read while hidden',
        );
        async.elapse(const Duration(minutes: 1));
        expect(repository.calls, 1, reason: 'hidden retry debt stays deferred');
        cubit.setPollingVisible(true);
        async.flushMicrotasks();
        expect(repository.calls, 2, reason: 'all debt becomes one return read');
        expect(cubit.state.pending.single.id, _recovered.id);
        cubit.setPollingVisible(true);
        async.elapse(const Duration(minutes: 1));
        expect(repository.calls, 2);
      });
    });
  }

  test('M9 visible retries and pushes coalesce into one expiry read', () {
    _withFailedRateLimit((async, repository, cubit, signals) {
      for (var retry = 0; retry < 3; retry++) {
        unawaited(cubit.load());
        unawaited(cubit.refresh());
        signals.add(null);
      }
      async.flushMicrotasks();
      expect(async.nonPeriodicTimerCount, 1);
      async.elapse(const Duration(seconds: 29));
      expect(repository.calls, 1);
      async.elapse(const Duration(seconds: 1));
      expect(repository.calls, 2);
      expect(cubit.state.pending.single.id, _recovered.id);
      async.elapse(const Duration(minutes: 1));
      expect(repository.calls, 2);
    });
  });

  for (final expireBeforeClose in [false, true]) {
    test(
      'M9 close cancels retry timer or debt; expired=$expireBeforeClose',
      () {
        _withFailedRateLimit((async, repository, cubit, signals) {
          unawaited(cubit.load());
          cubit.setPollingVisible(false);
          signals.add(null);
          async.flushMicrotasks();
          if (expireBeforeClose) async.elapse(const Duration(seconds: 30));
          expect(repository.calls, 1);
          unawaited(cubit.close());
          async.flushMicrotasks();
          expect(async.nonPeriodicTimerCount, 0);
          signals.add(null);
          cubit.setPollingVisible(true);
          async.elapse(const Duration(minutes: 1));
          expect(repository.calls, 1);
        });
      },
    );
  }

  test('M9 failed-screen load retry honors mixed 503/429 backoff', () async {
    final repository = _ScriptedRepository([
      const ClientHomeSnapshot(
        rateLimited: true,
        retryAfter: Duration(seconds: 30),
        requestsFailure: ServerFailure(status: 503),
        inProgressFailure: RateLimitedFailure(
          retryAfter: Duration(seconds: 30),
        ),
      ),
    ]);
    final cubit = ClientHomeCubit(
      repository: repository,
      greetingNameProvider: () => 'Sami',
    );
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, ClientHomeStatus.failed);
    expect(cubit.state.error, isA<ServerFailure>());
    expect(repository.calls, 1);

    // _FailedLayout's retry callback invokes load().
    await cubit.load();
    expect(
      repository.calls,
      1,
      reason: 'Retry must not read again inside the 30-second window',
    );
  });

  test(
    'M9 partial recovery after all-429 merges rows and clears request errors',
    () async {
      final repository = _ScriptedRepository([
        const ClientHomeSnapshot(
          rateLimited: true,
          retryAfter: Duration(milliseconds: 1),
          requestsFailure: RateLimitedFailure(),
          inProgressFailure: RateLimitedFailure(),
          recentFailure: RateLimitedFailure(),
        ),
        const ClientHomeSnapshot(
          pending: [_recovered],
          rateLimited: true,
          retryAfter: Duration(seconds: 30),
          inProgressFailure: RateLimitedFailure(),
          recentFailure: RateLimitedFailure(),
        ),
      ]);
      final cubit = ClientHomeCubit(
        repository: repository,
        greetingNameProvider: () => 'Sami',
      );
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.pendingError, isA<RateLimitedFailure>());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await cubit.refresh();
      expect(repository.calls, 2, reason: 'The backoff must have expired');
      expect(cubit.state.status, ClientHomeStatus.ready);
      expect(cubit.state.refreshError, isA<RateLimitedFailure>());
      expect(cubit.state.inProgressError, isA<RateLimitedFailure>());
      expect(
        {
          'pendingIds': cubit.state.pending.map((row) => row.id).toList(),
          'pendingError': cubit.state.pendingError,
          'repliesError': cubit.state.repliesError,
        },
        {
          'pendingIds': ['recovered-request'],
          'pendingError': null,
          'repliesError': null,
        },
        reason: 'Successful request data must replace the prior all-429 state',
      );
    },
  );

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
      'M9 ${locale.languageCode}: real Dio failures and screen Retry honor backoff',
      (tester) async {
        useReduceMotion(tester);
        tester.view.physicalSize = const Size(440, 956);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final reads = <String>[];
        final dio = Dio(BaseOptions(baseUrl: 'https://home.invalid'));
        addTearDown(() => dio.close(force: true));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              reads.add(options.path);
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<dynamic>(
                    requestOptions: options,
                    statusCode: options.path == '/requests' ? 503 : 429,
                    headers: Headers.fromMap({
                      'retry-after': ['30'],
                    }),
                  ),
                ),
              );
            },
          ),
        );
        final cubit = ClientHomeCubit(
          repository: DioClientHomeRepository(dio),
          greetingNameProvider: () => 'Sami',
        );
        await tester.pumpWidget(
          wrapForTest(
            BlocProvider.value(
              value: cubit,
              child: const Scaffold(body: ClientHomeScreen()),
            ),
            locale: locale,
          ),
        );
        await cubit.load();
        await tester.pumpAndSettle();
        expect(cubit.state.status, ClientHomeStatus.failed);
        expect(cubit.state.error, isA<ServerFailure>());
        expect(reads, containsAll(['/requests', '/deliveries']));
        final initialReads = reads.length;
        final retry = find.bySemanticsIdentifier('client_home_retry_cta');
        expect(retry, findsOneWidget);
        await tester.ensureVisible(retry);
        await tester.pumpAndSettle();
        for (var tap = 0; tap < 3; tap++) {
          await tester.tap(retry);
          await tester.pumpAndSettle();
          expect(reads, hasLength(initialReads));
          expect(cubit.state.status, ClientHomeStatus.failed);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await cubit.close();
        semantics.dispose();
      },
    );
  }
}
