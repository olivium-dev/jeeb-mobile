import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _deliveryId = 'DLV-FM4-F4';
const _resumePollInterval = Duration(minutes: 1);

class _CountingLiveTrackingRepository implements LiveTrackingRepository {
  _CountingLiveTrackingRepository(this._responses);

  final List<DeliveryTrackingInfo> _responses;
  int calls = 0;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) {
    final index = calls < _responses.length ? calls : _responses.length - 1;
    calls++;
    return Future<DeliveryTrackingInfo>.value(_responses[index]);
  }
}

DeliveryTrackingInfo _trackingInfo(String status) =>
    DeliveryTrackingInfo.fromDeliveryJson(_deliveryId, <String, dynamic>{
      'id': _deliveryId,
      'status': status,
    });

Widget _trackingHarness(LiveTrackingCubit cubit) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: BlocProvider<LiveTrackingCubit>.value(
    value: cubit,
    child: const LiveTrackingScreen(deliveryId: _deliveryId, useLiveMap: false),
  ),
);

Future<void> _driveToBackground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

Future<void> _driveToForeground(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}

WidgetsBindingAppLifecycleGate _installBindingGate(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final gate = WidgetsBindingAppLifecycleGate();
  AppLifecycleGate.install(gate);
  addTearDown(gate.dispose);
  return gate;
}

void main() {
  // b02 P0: the resume bus is a process-wide singleton with a 2 s coalescing
  setUp(() async => AppResumeSignals.debugReset());

  tearDown(AppLifecycleGate.debugReset);

  // b02 wave C / N7. These tests used to assert the 5s `LifecyclePoller`'s

  test('N7 (was AC11) no root gate install, no MaterialApp: a push drives the '
      'read and elapsed time does NOT', () {
    fakeAsync((async) {
      final repository = _CountingLiveTrackingRepository(
        <DeliveryTrackingInfo>[_trackingInfo('InTransit')],
      );
      final bus = StreamController<void>.broadcast();
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _deliveryId,
        refreshSignals: bus.stream,
      );

      async.flushMicrotasks();
      expect(repository.calls, 1);
      expect(cubit.debugPushRefreshWired, isTrue);

      for (var index = 0; index < 3; index++) {
        bus.add(null);
        async.flushMicrotasks();
      }
      expect(repository.calls, 4, reason: 'three pushes → three reads');

      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(repository.calls, 4,
          reason: 'five minutes with no push is zero reads');
      expect(async.periodicTimerCount, isZero);

      unawaited(cubit.close());
      async.flushMicrotasks();
      expect(cubit.debugPushRefreshWired, isFalse);
      bus.close();
    });
  });

  testWidgets(
    'AC7 stops reading once the delivery is delivered and stays stopped across '
    'resume',
    (tester) async {
      _installBindingGate(tester);
      final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
        _trackingInfo('InTransit'),
        _trackingInfo('Done'),
      ]);
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _deliveryId,
        refreshSignals: bus.stream,
      );

      await tester.pump();
      expect(repository.calls, 1);
      expect(cubit.debugPushRefreshWired, isTrue);

      bus.add(null);
      await tester.pump();
      expect(repository.calls, 2);
      expect(cubit.state.trackingInfo?.isDelivered, isTrue);
      expect(cubit.debugPushRefreshWired, isFalse);
      expect(cubit.debugPositionReadCount, 0,
          reason: 'a terminal row must never have read a courier position — '
              'there is no moving jeeber to plot on a completed trip. (This '
              'replaces `debugPositionStreamWired`, which reported on a stream '
              'that no longer exists: jeeb-gateway #333 deleted the SSE geo '
              'alias — guard Sse_Alias_Route_Is_Gone.)');

      await _driveToBackground(tester);
      await tester.pump(const Duration(minutes: 3));
      await _driveToForeground(tester);
      // The resume backstop must ALSO honour terminality.
      await cubit.refreshNow();
      bus.add(null);
      await tester.pump();

      expect(
        repository.calls,
        2,
        reason:
            'the same repository seam first proves a push-driven fetch, then '
            'proves delivered terminality survives the full lifecycle cycle, a '
            'later push, AND the resume hook',
      );
      expect(cubit.debugPushRefreshWired, isFalse);
      await cubit.close();
    },
  );

  test('AC8 stops reading once the delivery is cancelled', () {
    fakeAsync((async) {
      final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
        _trackingInfo('InTransit'),
        _trackingInfo('Cancelled'),
      ]);
      final bus = StreamController<void>.broadcast();
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _deliveryId,
        refreshSignals: bus.stream,
      );

      async.flushMicrotasks();
      expect(repository.calls, 1);
      expect(cubit.debugPushRefreshWired, isTrue);

      bus.add(null);
      async.flushMicrotasks();
      expect(repository.calls, 2);
      expect(cubit.state.trackingInfo?.isCancelled, isTrue);
      expect(cubit.debugPushRefreshWired, isFalse);

      for (var i = 0; i < 3; i++) {
        bus.add(null);
        async.flushMicrotasks();
      }
      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(
        repository.calls,
        2,
        reason:
            'the same repository seam has a non-zero active baseline before '
            'the cancelled terminal window is proven silent for BOTH further '
            'pushes and elapsed time',
      );

      unawaited(cubit.close());
      async.flushMicrotasks();
      bus.close();
    });
  });

  testWidgets('AC9 fetches exactly once on foreground return', (tester) async {
    _installBindingGate(tester);
    final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
      _trackingInfo('InTransit'),
    ]);
    final bus = StreamController<void>.broadcast();
    addTearDown(bus.close);
    final cubit = LiveTrackingCubit(
      repository: repository,
      deliveryId: _deliveryId,
      refreshSignals: bus.stream,
    );

    await tester.pumpWidget(_trackingHarness(cubit));
    await tester.pump();
    await tester.pump();
    final afterMount = repository.calls;

    // No cadence: sitting on the screen buys nothing.
    await tester.pump(_resumePollInterval);
    await tester.pump();
    expect(repository.calls, afterMount,
        reason: 'the 5s poll is gone — dwelling on the screen adds no reads');

    await _driveToBackground(tester);
    await tester.pump();
    await tester.pump();
    final backgroundBaseline = repository.calls;
    await tester.pump(_resumePollInterval * 3);
    expect(repository.calls, backgroundBaseline,
        reason: 'a backgrounded screen reads nothing at all now — no cadence '
            'and no push can reach it');

    // ONE paused → resumed pair, driven directly. The `_driveToForeground`
    final beforeResume = repository.calls;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    // The resume backstop is UNCHANGED and now MORE load-bearing: it catches a
    expect(repository.calls, beforeResume + 1);
    await tester.pump(_resumePollInterval);
    await tester.pump();
    expect(
      repository.calls,
      beforeResume + 1,
      reason:
          'only the screen resume hook may fetch; there is no interval left '
          'that could add a second read',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await cubit.close();
  });

  test('AC10 retry re-arms the watchers through an explicit re-fetch', () {
    fakeAsync((async) {
      final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
        _trackingInfo('Cancelled'),
        _trackingInfo('InTransit'),
      ]);
      final bus = StreamController<void>.broadcast();
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _deliveryId,
        refreshSignals: bus.stream,
      );

      async.flushMicrotasks();
      expect(repository.calls, 1);
      expect(cubit.debugPushRefreshWired, isFalse,
          reason: 'a cold load onto a terminal row must never arm anything');

      cubit.retry();
      async.flushMicrotasks();
      expect(repository.calls, 2);
      expect(cubit.state.trackingInfo?.isCancelled, isFalse);
      expect(cubit.debugPushRefreshWired, isTrue,
          reason: 'retry landing on a LIVE row must arm the push subscription — '
              'otherwise Retry paints once and the screen goes deaf');

      bus.add(null);
      async.flushMicrotasks();
      expect(repository.calls, 3);

      unawaited(cubit.close());
      async.flushMicrotasks();
      bus.close();
    });
  });
}
