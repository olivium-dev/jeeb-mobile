// G3 recovery-trigger tests: the jeeber feed refetches on app RESUME and on
// shell-tab REFOCUS (mirroring the customer home's TabVisibility re-pull),
// so a request whose push was dismissed is findable the moment the jeeber
// looks — without waiting for a WS event or a manual pull-to-refresh.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/feed_resume_refetcher.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';

class _MockRepo extends Mock implements RequestFeedRepository {}

void main() {
  late _MockRepo repo;
  late RequestFeedCubit cubit;
  late int refreshCalls;

  setUp(() {
    repo = _MockRepo();
    refreshCalls = 0;
    when(() => repo.requests)
        .thenAnswer((_) => const Stream<DeliveryRequest>.empty());
    when(() => repo.transport)
        .thenAnswer((_) => const Stream<FeedTransportUpdate>.empty());
    when(() => repo.refresh()).thenAnswer((_) async {
      refreshCalls += 1;
      return const <DeliveryRequest>[];
    });
    when(() => repo.dispose()).thenAnswer((_) async {});
    cubit = RequestFeedCubit(repository: repo);
  });

  tearDown(() => cubit.close());

  Widget harness({required bool isVisible}) {
    return MaterialApp(
      home: BlocProvider<RequestFeedCubit>.value(
        value: cubit,
        child: TabVisibility(
          isVisible: isVisible,
          child: const FeedResumeRefetcher(child: SizedBox.expand()),
        ),
      ),
    );
  }

  testWidgets(
      'tab refocus (off-screen → on-screen) silently re-pulls the feed',
      (tester) async {
    await tester.pumpWidget(harness(isVisible: true));
    await tester.pump();
    final baseline = refreshCalls;

    // Off-screen: no fetch.
    await tester.pumpWidget(harness(isVisible: false));
    await tester.pump();
    expect(refreshCalls, baseline, reason: 'going off-screen must not fetch');

    // Back on-screen: exactly one silent refresh.
    await tester.pumpWidget(harness(isVisible: true));
    await tester.pump();
    await tester.pump();
    expect(refreshCalls, baseline + 1,
        reason: 'regaining the tab must re-pull the snapshot (G3)');
  });

  testWidgets('first frame does NOT auto-refresh (start() owns the initial '
      'snapshot — no double fetch)', (tester) async {
    await tester.pumpWidget(harness(isVisible: true));
    await tester.pump();
    expect(refreshCalls, 0);
  });

  testWidgets('app resume re-pulls the feed', (tester) async {
    await tester.pumpWidget(harness(isVisible: true));
    await tester.pump();
    final baseline = refreshCalls;

    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(refreshCalls, baseline,
        reason: 'backgrounding must not fetch');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(refreshCalls, baseline + 1,
        reason: 'returning to the foreground must re-pull the snapshot (G3)');

    // Restore the default so later tests in the suite see a live app.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('outside the shell (no TabVisibility) the refocus trigger is '
      'inert — no spurious fetches', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RequestFeedCubit>.value(
          value: cubit,
          child: const FeedResumeRefetcher(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(refreshCalls, 0);
  });
}
