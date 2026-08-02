import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/core/lifecycle/polling_source.dart';
import 'package:jeeb_mobile/core/lifecycle/polling_visibility_gate.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/feed_resume_refetcher.dart';

class _OwnershipSpyRepository implements RequestFeedRepository, PollingSource {
  int disposeCalls = 0;
  final List<Object> addedOwners = <Object>[];
  final List<Object> removedOwners = <Object>[];

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport =>
      const Stream<FeedTransportUpdate>.empty();

  @override
  Future<List<DeliveryRequest>> refresh() async => const <DeliveryRequest>[];

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }

  @override
  void addPollInterest(Object owner) {
    addedOwners.add(owner);
  }

  @override
  void removePollInterest(Object owner) {
    removedOwners.add(owner);
  }
}

class _CountingDio extends Fake implements Dio {
  int getCount = 0;
  final List<String> getPaths = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    getCount++;
    getPaths.add(path);
    return Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: const <String, Object>{'items': <Object>[], 'totalCount': 0},
        )
        as Response<T>;
  }
}

void main() {
  setUp(() async => AppResumeSignals.debugReset());

  test(
    'AC5: default owned cubit disposes its per-widget repository on close',
    () async {
      final repository = _OwnershipSpyRepository();
      final cubit = RequestFeedCubit(repository: repository);

      await cubit.close();

      expect(repository.disposeCalls, 1);
    },
  );

  test(
    'AC5: borrowed cubit releases poll interest without disposing the repository',
    () async {
      final repository = _OwnershipSpyRepository();
      final cubit = RequestFeedCubit(
        repository: repository,
        repositoryOwnership: RequestFeedRepositoryOwnership.borrowed,
      )..setPollingVisible(true);

      await cubit.start();
      expect(repository.addedOwners, <Object>[cubit]);

      await cubit.close();

      expect(repository.removedOwners, <Object>[cubit]);
      expect(repository.disposeCalls, 0);
    },
  );

  test(
    'AC5: seeded repository remains outside the shared PollingSource capability',
    () {
      final repository = SeededRequestFeedRepository(const <DeliveryRequest>[]);

      expect(repository, isNot(isA<PollingSource>()));
    },
  );

  test('AC2c: production feed arms no cadence — 60s, 10s or otherwise', () {
    FakeAsync().run((async) {
      final dio = _CountingDio();
      final repository = DioRequestFeedRepository(dio: dio);

      repository.addPollInterest(Object());

      for (final t in const <Duration>[
        Duration(seconds: 10),
        Duration(seconds: 60),
        Duration(minutes: 5),
        Duration(hours: 1),
      ]) {
        async.elapse(t);
        expect(
          dio.getCount,
          0,
          reason: 'a GET appeared after $t of idle time — a poll is back',
        );
      }

      unawaited(repository.dispose());
      async.flushMicrotasks();
    });
  });

  testWidgets(
    'AC3: resume issues exactly one GET — FeedResumeRefetcher owns it, and '
    'nothing follows it',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      final dio = _CountingDio();
      final lifecycleGate = WidgetsBindingAppLifecycleGate();
      final repository = DioRequestFeedRepository(dio: dio);
      final cubit = RequestFeedCubit(
        repository: repository,
        repositoryOwnership: RequestFeedRepositoryOwnership.borrowed,
      );

      try {
        await cubit.start();
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<RequestFeedCubit>.value(
              value: cubit,
              child: PollingVisibilityGate(
                target: cubit,
                isVisible: true,
                child: const FeedResumeRefetcher(child: SizedBox.expand()),
              ),
            ),
          ),
        );
        await tester.pump();

        final foregroundBaseline = dio.getCount;
        for (final state in <AppLifecycleState>[
          AppLifecycleState.inactive,
          AppLifecycleState.paused,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
          await tester.pump();
        }
        expect(dio.getCount, foregroundBaseline);

        final resumeBaseline = dio.getCount;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        await tester.pump();

        expect(
          dio.getCount - resumeBaseline,
          1,
          reason: 'FeedResumeRefetcher must own the only resume GET',
        );
        expect(dio.getPaths.sublist(resumeBaseline), const <String>[
          '/v1/jeebers/me/feed?status=pending',
        ]);

        final settledBaseline = dio.getCount;
        await tester.pump(const Duration(minutes: 5));
        await tester.pump();
        expect(
          dio.getCount,
          settledBaseline,
          reason:
              'five minutes foreground, no push, no user action ⇒ ZERO '
              'repeat calls (POLLING-ELIMINATION-PLAN §0)',
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        if (!cubit.isClosed) {
          unawaited(cubit.close());
        }
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        unawaited(repository.dispose());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        lifecycleGate.dispose();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
      }
    },
  );
}
