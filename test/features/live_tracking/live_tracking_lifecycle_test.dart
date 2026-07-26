import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _deliveryId = 'DLV-FM4-F4';
const _pollInterval = Duration(seconds: 1);
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
  tearDown(AppLifecycleGate.debugReset);

  test(
    'AC11 F4 poller is running and ticks with no root gate install and no MaterialApp',
    () {
      fakeAsync((async) {
        final repository = _CountingLiveTrackingRepository(
          <DeliveryTrackingInfo>[_trackingInfo('InTransit')],
        );
        final cubit = LiveTrackingCubit(
          repository: repository,
          deliveryId: _deliveryId,
          pollInterval: _pollInterval,
        );

        async.flushMicrotasks();
        expect(repository.calls, 1);
        expect(cubit.debugPoller.isRunning, isTrue);

        for (var index = 0; index < 3; index++) {
          async.elapse(_pollInterval);
          async.flushMicrotasks();
        }

        expect(repository.calls, 4);
        expect(cubit.debugPoller.debugTickCount, 3);

        unawaited(cubit.close());
        async.flushMicrotasks();
        expect(cubit.debugPoller.isRunning, isFalse);
        expect(async.periodicTimerCount, isZero);
      });
    },
  );

  testWidgets(
    'AC7 F4 stops polling once the delivery is delivered and stays stopped across resume',
    (tester) async {
      _installBindingGate(tester);
      final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
        _trackingInfo('InTransit'),
        _trackingInfo('Done'),
      ]);
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _deliveryId,
        pollInterval: _pollInterval,
      );

      await tester.pump();
      expect(repository.calls, 1);
      expect(cubit.debugPoller.isRunning, isTrue);

      await tester.pump(_pollInterval);
      await tester.pump();
      expect(repository.calls, 2);
      expect(cubit.state.trackingInfo?.isDelivered, isTrue);
      expect(cubit.debugPoller.isRunning, isFalse);

      await _driveToBackground(tester);
      await tester.pump(_pollInterval * 3);
      await _driveToForeground(tester);
      await cubit.refreshNow();
      await tester.pump();

      expect(
        repository.calls,
        2,
        reason:
            'the same repository seam first proves an active timer fetch, then '
            'proves delivered terminality survives the full lifecycle cycle',
      );
      expect(cubit.debugPoller.isRunning, isFalse);
      await cubit.close();
    },
  );

  test('AC8 F4 stops polling once the delivery is cancelled', () {
    fakeAsync((async) {
      final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
        _trackingInfo('InTransit'),
        _trackingInfo('Cancelled'),
      ]);
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _deliveryId,
        pollInterval: _pollInterval,
      );

      async.flushMicrotasks();
      expect(repository.calls, 1);
      expect(cubit.debugPoller.isRunning, isTrue);

      async.elapse(_pollInterval);
      async.flushMicrotasks();
      expect(repository.calls, 2);
      expect(cubit.state.trackingInfo?.isCancelled, isTrue);
      expect(cubit.debugPoller.isRunning, isFalse);

      async.elapse(_pollInterval * 3);
      async.flushMicrotasks();
      expect(
        repository.calls,
        2,
        reason:
            'the same repository seam has a non-zero active baseline before '
            'the cancelled terminal interval is proven silent',
      );
      expect(cubit.debugPoller.isRunning, isFalse);

      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  testWidgets('AC9 F4 fetches exactly once on foreground return', (
    tester,
  ) async {
    _installBindingGate(tester);
    final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
      _trackingInfo('InTransit'),
    ]);
    final cubit = LiveTrackingCubit(
      repository: repository,
      deliveryId: _deliveryId,
      pollInterval: _resumePollInterval,
    );

    await tester.pumpWidget(_trackingHarness(cubit));
    await tester.pump();
    expect(repository.calls, 1);
    expect(cubit.debugPoller.isRunning, isTrue);

    await tester.pump(_resumePollInterval);
    await tester.pump();
    expect(repository.calls, 2);

    await _driveToBackground(tester);
    expect(cubit.debugPoller.isRunning, isFalse);
    final backgroundBaseline = repository.calls;
    await tester.pump(_resumePollInterval * 3);
    expect(repository.calls, backgroundBaseline);

    await _driveToForeground(tester);
    await tester.pump();

    expect(repository.calls, backgroundBaseline + 1);
    expect(cubit.debugPoller.isRunning, isTrue);
    await tester.pump(_resumePollInterval - const Duration(milliseconds: 1));
    expect(
      repository.calls,
      backgroundBaseline + 1,
      reason:
          'tickOnResume is false, so only the existing screen resume hook may '
          'fetch before a fresh full interval elapses',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await cubit.close();
  });

  test('AC10 F4 retry re-arms the poll through an explicit start', () {
    fakeAsync((async) {
      final repository = _CountingLiveTrackingRepository(<DeliveryTrackingInfo>[
        _trackingInfo('Cancelled'),
        _trackingInfo('InTransit'),
      ]);
      final cubit = LiveTrackingCubit(
        repository: repository,
        deliveryId: _deliveryId,
        pollInterval: _pollInterval,
      );

      async.flushMicrotasks();
      expect(repository.calls, 1);
      expect(cubit.debugPoller.isRunning, isFalse);

      cubit.retry();
      async.flushMicrotasks();
      expect(repository.calls, 2);
      expect(cubit.state.trackingInfo?.isCancelled, isFalse);
      expect(cubit.debugPoller.isRunning, isTrue);

      async.elapse(_pollInterval);
      async.flushMicrotasks();
      expect(repository.calls, 3);
      expect(cubit.debugPoller.debugTickCount, 1);

      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });
}
