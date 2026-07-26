import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _deliveryId = 'DLV-FM4-F5';
const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);
const _pollInterval = Duration(seconds: 1);
const _resumePollInterval = Duration(minutes: 1);

JeeberDelivery _delivery(JeeberDeliveryStatus status) =>
    JeeberDelivery(id: _deliveryId, status: status, dropOff: _dropOff);

class _CountingActiveDeliveryRepository implements ActiveDeliveryRepository {
  _CountingActiveDeliveryRepository({
    required List<JeeberDeliveryStatus> fetchStatuses,
    this.verifyOtpResult = JeeberDeliveryStatus.done,
  }) : _fetchStatuses = fetchStatuses;

  final List<JeeberDeliveryStatus> _fetchStatuses;
  final JeeberDeliveryStatus verifyOtpResult;

  int fetchCalls = 0;
  int transitionCalls = 0;
  int verifyOtpCalls = 0;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) {
    final index = fetchCalls < _fetchStatuses.length
        ? fetchCalls
        : _fetchStatuses.length - 1;
    fetchCalls++;
    return Future<JeeberDelivery>.value(_delivery(_fetchStatuses[index]));
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) {
    transitionCalls++;
    return Future<JeeberDeliveryStatus>.value(to);
  }

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) {
    verifyOtpCalls++;
    return Future<JeeberDeliveryStatus>.value(verifyOtpResult);
  }

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) => Future<String>.value('proof://$_deliveryId');
}

Widget _activeDeliveryHarness(ActiveDeliveryCubit cubit) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: ActiveDeliveryJeeberScreen(
    deliveryId: _deliveryId,
    cubit: cubit,
    onOpenChat: _noop,
  ),
);

void _noop() {}

ManualAppLifecycleGate _installManualGate() {
  final gate = ManualAppLifecycleGate(isForeground: false);
  AppLifecycleGate.install(gate);
  return gate;
}

void _installBindingGate(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final gate = WidgetsBindingAppLifecycleGate();
  AppLifecycleGate.install(gate);
  addTearDown(gate.dispose);
}

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

void main() {
  tearDown(AppLifecycleGate.debugReset);

  test(
    'AC16 F5 poller is running and ticks with no root gate install and no MaterialApp',
    () {
      fakeAsync((async) {
        final repository = _CountingActiveDeliveryRepository(
          fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.picked],
        );
        final cubit = ActiveDeliveryCubit(
          repository: repository,
          deliveryId: _deliveryId,
          pollInterval: _pollInterval,
        );

        unawaited(cubit.loadDelivery());
        async.flushMicrotasks();
        expect(repository.fetchCalls, 1);
        expect(cubit.debugPoller.isRunning, isTrue);

        for (var index = 0; index < 3; index++) {
          async.elapse(_pollInterval);
          async.flushMicrotasks();
        }

        expect(repository.fetchCalls, 4);
        expect(cubit.debugPoller.debugTickCount, 3);

        unawaited(cubit.close());
        async.flushMicrotasks();
        expect(cubit.debugPoller.isRunning, isFalse);
        expect(async.periodicTimerCount, isZero);
      });
    },
  );

  test('AC12 F5 polls once per interval while canPoll is true', () {
    fakeAsync((async) {
      final gate = _installManualGate();
      final repository = _CountingActiveDeliveryRepository(
        fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.picked],
      );
      final cubit = ActiveDeliveryCubit(
        repository: repository,
        deliveryId: _deliveryId,
        pollInterval: _pollInterval,
      );

      unawaited(cubit.loadDelivery());
      async.flushMicrotasks();
      expect(repository.fetchCalls, 1);
      expect(cubit.debugPoller.isRunning, isFalse);

      gate.setForeground(true);
      expect(cubit.debugPoller.isRunning, isTrue);
      async.elapse(_pollInterval - const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(repository.fetchCalls, 1);

      async.elapse(const Duration(milliseconds: 1));
      async.flushMicrotasks();
      expect(repository.fetchCalls, 2);

      async.elapse(_pollInterval);
      async.flushMicrotasks();
      expect(repository.fetchCalls, 3);
      expect(cubit.debugPoller.isRunning, isTrue);

      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  test('AC13 F5 stops the poller after markDelivered reaches Done', () {
    fakeAsync((async) {
      final gate = _installManualGate();
      final repository = _CountingActiveDeliveryRepository(
        fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.atDoor],
      );
      final cubit = ActiveDeliveryCubit(
        repository: repository,
        deliveryId: _deliveryId,
        pollInterval: _pollInterval,
      );

      unawaited(cubit.loadDelivery());
      async.flushMicrotasks();
      gate.setForeground(true);
      async.elapse(_pollInterval);
      async.flushMicrotasks();
      expect(repository.fetchCalls, 2);
      expect(cubit.debugPoller.isRunning, isTrue);

      unawaited(cubit.markDelivered());
      async.flushMicrotasks();
      expect(cubit.state.delivery?.status, JeeberDeliveryStatus.done);
      expect(repository.transitionCalls, 1);
      expect(cubit.debugPoller.isRunning, isFalse);

      async.elapse(_pollInterval * 3);
      async.flushMicrotasks();
      expect(
        repository.fetchCalls,
        2,
        reason:
            'the same fetchDelivery seam proves a non-zero live baseline; the '
            'post-Done assertion is timer liveness, not a GET-saving claim',
      );
      expect(cubit.debugPoller.isRunning, isFalse);

      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  test(
    'AC14 F5 stops the poller after submitDoorOtp completes the delivery',
    () {
      fakeAsync((async) {
        final gate = _installManualGate();
        final repository = _CountingActiveDeliveryRepository(
          fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.atDoor],
        );
        final cubit = ActiveDeliveryCubit(
          repository: repository,
          deliveryId: _deliveryId,
          pollInterval: _pollInterval,
        );

        unawaited(cubit.loadDelivery());
        async.flushMicrotasks();
        gate.setForeground(true);
        async.elapse(_pollInterval);
        async.flushMicrotasks();
        expect(repository.fetchCalls, 2);
        expect(cubit.debugPoller.isRunning, isTrue);

        unawaited(cubit.submitDoorOtp('1234'));
        async.flushMicrotasks();
        expect(cubit.state.delivery?.status, JeeberDeliveryStatus.done);
        expect(repository.verifyOtpCalls, 1);
        expect(cubit.debugPoller.isRunning, isFalse);

        async.elapse(_pollInterval * 3);
        async.flushMicrotasks();
        expect(
          repository.fetchCalls,
          2,
          reason:
              'the same fetchDelivery seam proves a non-zero live baseline; '
              'OTP completion must cancel timer liveness with zero GET delta',
        );
        expect(cubit.debugPoller.isRunning, isFalse);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    },
  );

  testWidgets('AC15 F5 fetches exactly once on foreground return', (
    tester,
  ) async {
    _installBindingGate(tester);
    final repository = _CountingActiveDeliveryRepository(
      fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.picked],
    );
    final cubit = ActiveDeliveryCubit(
      repository: repository,
      deliveryId: _deliveryId,
      pollInterval: _resumePollInterval,
    );

    await cubit.loadDelivery();
    await tester.pumpWidget(_activeDeliveryHarness(cubit));
    await tester.pump();
    expect(repository.fetchCalls, 1);
    expect(cubit.debugPoller.isRunning, isTrue);

    await tester.pump(_resumePollInterval);
    await tester.pump();
    expect(repository.fetchCalls, 2);

    await _driveToBackground(tester);
    expect(cubit.debugPoller.isRunning, isFalse);
    final backgroundBaseline = repository.fetchCalls;
    await tester.pump(_resumePollInterval * 3);
    expect(repository.fetchCalls, backgroundBaseline);

    await _driveToForeground(tester);
    await tester.pump();

    expect(repository.fetchCalls, backgroundBaseline + 1);
    expect(cubit.debugPoller.isRunning, isTrue);
    await tester.pump(_resumePollInterval - const Duration(milliseconds: 1));
    expect(
      repository.fetchCalls,
      backgroundBaseline + 1,
      reason:
          'tickOnResume is false, so only the existing screen resume hook may '
          'fetch before a fresh full interval elapses',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await cubit.close();
  });
}
