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

  // R29 NOTE — this criterion's assertion was CHANGED, deliberately, and the
  // change is a repair rather than a relaxation. Recorded here so a reader can
  // tell the two apart without digging through history.
  //
  //   WAS: 'AC13 F5 stops the poller after markDelivered reaches Done'
  //        expect(state.delivery?.status, done)
  //        expect(transitionCalls, 1)
  //        expect(debugPoller.isRunning, isFalse)
  //
  //   NOW: markDelivered STOPS at AtDoor and the poller stays live for the
  //        door-OTP handover.
  //
  //   AUTHORITY: the FROZEN state machine, `DeliverySm.cs:53-62`. `AtDoor` has
  //   exactly three exits — `otp_verified → Done`,
  //   `otp_fail_or_jeeber_escalate → FailedNeedsEscalation`,
  //   `escalate_either → FailedNeedsEscalation` — and NONE of them is a jeeber
  //   tap. `JeeberDeliveryStatus.next` returns `null` at `atDoor` for that
  //   reason. The old form asserted a transition the SERVER DOES NOT PERMIT;
  //   it encoded the pre-P6/B1 client, which optimistically walked
  //   `AtDoor → Done` itself.
  //
  //   NOT R29 WEAKENING: this is four assertions where there was one (status,
  //   otpRequired, transitionCalls == 0, poller still running), plus a tail
  //   proving the OTP surface survives live polling (P6/A4). The terminal-stop
  //   behaviour it used to claim is owned — and genuinely exercised — by AC14
  //   below, through `submitDoorOtp`, the path that actually exists.
  test(
    'AC13 F5 markDelivered stops at AtDoor and keeps the poller live for the '
    'door-OTP handover (frozen SM: AtDoor→Done is otp_verified only)',
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

        unawaited(cubit.markDelivered());
        async.flushMicrotasks();

        // 1. The row is held at the door — NOT driven to Done by the CTA.
        expect(
          cubit.state.delivery?.status,
          JeeberDeliveryStatus.atDoor,
          reason:
              'the frozen SM (DeliverySm.cs:53-62) gives AtDoor no jeeber-tap '
              'exit, so the CTA must not claim Done',
        );
        // 2. It raised the door-OTP handover instead.
        expect(
          cubit.state.otpRequired,
          isTrue,
          reason: 'AtDoor hands over to the recipient OTP (P6/B1)',
        );
        // 3. And it patched NOTHING — already at the door, nothing to walk.
        expect(
          repository.transitionCalls,
          0,
          reason:
              'a transition call here would be the pre-P6/B1 optimistic walk '
              'the gateway refuses with 422',
        );
        // 4. The poll stays LIVE: an admin/customer can still move this row,
        //    and the jeeber must see it. This is the assertion the old form
        //    inverted.
        expect(cubit.debugPoller.isRunning, isTrue);

        // P6/A4 tail: the poll keeps RUNNING while the OTP surface is up, and
        // a non-terminal read is REFUSED so it never clobbers the code the
        // jeeber is typing. Liveness is asserted as growth, not as an exact
        // tick count, so this does not become a cadence-mechanics test.
        final atHandover = repository.fetchCalls;
        async.elapse(_pollInterval * 3);
        async.flushMicrotasks();
        expect(
          repository.fetchCalls,
          greaterThan(atHandover),
          reason:
              'the same fetchDelivery seam proves timer liveness at the door; '
              'this is not a GET-saving claim',
        );
        expect(cubit.debugPoller.isRunning, isTrue);
        expect(
          cubit.state.delivery?.status,
          JeeberDeliveryStatus.atDoor,
          reason: 'a non-terminal poll result must not disturb the handover',
        );
        expect(
          cubit.state.otpRequired,
          isTrue,
          reason: 'the OTP surface must survive every intervening poll (P6/A4)',
        );

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    },
  );

  test(
    'AC14 F5 stops the poller after submitDoorOtp completes the delivery',
    () {
      fakeAsync((async) {
        final gate = _installManualGate();
        final repository = _CountingActiveDeliveryRepository(
          fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.atDoor],
          // Stated explicitly: `otp_verified → Done` is the ONLY edge the
          // frozen SM (DeliverySm.cs:53-62) opens out of AtDoor, and this test
          // owns that terminal-stop assertion now that AC13 correctly stops at
          // the door.
          verifyOtpResult: JeeberDeliveryStatus.done,
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
