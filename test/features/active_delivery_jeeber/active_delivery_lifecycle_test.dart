import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
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
  // b02 P0: the resume bus is a process-wide singleton with a 2 s coalescing
  // floor. Without a per-test reset the floor bleeds across cases in this file
  // (they run milliseconds apart) and a genuine resume in test N is silently
  // folded into test N-1's window.
  setUp(() async => AppResumeSignals.debugReset());

  tearDown(AppLifecycleGate.debugReset);

  // b02 wave C — N6. Every test below used to assert the 5s `LifecyclePoller`'s
  // CADENCE MECHANICS (isRunning / debugTickCount / one fetch per elapsed
  // interval). That poller is deleted: a `type=delivery` push now drives the
  // re-read (`Notifications/DeliveryStatusPushNotifier.cs:211`, fanned to BOTH
  // parties by `Controllers/DeliveriesController.cs:1296-1300`).
  //
  // The cadence assertions are therefore gone BY DESIGN — they described a
  // mechanism that no longer exists. Every BEHAVIOURAL claim they were
  // protecting is re-asserted here in push form, and the two that mattered most
  // are strengthened rather than relaxed:
  //   * AC13's P6/A4 claim (a non-terminal read must not clobber the door-OTP
  //     entry) now fires a real push at the OTP surface instead of waiting for
  //     a tick — a push can land mid-typing exactly as a tick could.
  //   * AC14's terminal-stop claim is now "the subscription is RETIRED", which
  //     is stronger than "the timer is stopped": the bus is app-wide, so an
  //     unretired subscription would keep re-reading a Done row on every
  //     unrelated push, forever.
  // The pure cadence tests (old AC12/AC16) are replaced by the inverse claim:
  // elapsed wall-clock with no push produces ZERO reads.

  test('N6 (was AC16) no root gate install, no MaterialApp: a push drives the '
      'read and elapsed time does NOT', () {
    fakeAsync((async) {
      final repository = _CountingActiveDeliveryRepository(
        fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.picked],
      );
      final bus = StreamController<void>.broadcast();
      final cubit = ActiveDeliveryCubit(
        repository: repository,
        deliveryId: _deliveryId,
        refreshSignals: bus.stream,
      );

      unawaited(cubit.loadDelivery());
      async.flushMicrotasks();
      expect(repository.fetchCalls, 1);
      expect(cubit.debugPushRefreshWired, isTrue);

      for (var index = 0; index < 3; index++) {
        bus.add(null);
        async.flushMicrotasks();
      }
      expect(repository.fetchCalls, 4, reason: 'three pushes → three re-reads');

      // The inverse of the old cadence claim: TIME alone now buys nothing.
      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(repository.fetchCalls, 4,
          reason: 'five minutes with no push is zero reads');
      expect(async.periodicTimerCount, isZero);

      unawaited(cubit.close());
      async.flushMicrotasks();
      expect(cubit.debugPushRefreshWired, isFalse);
      bus.close();
    });
  });

  test('N6 (was AC12) a push while backgrounded still re-reads — the bus is the '
      'gate, and there is no cadence left to gate', () {
    fakeAsync((async) {
      final gate = _installManualGate();
      final repository = _CountingActiveDeliveryRepository(
        fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.picked],
      );
      final bus = StreamController<void>.broadcast();
      final cubit = ActiveDeliveryCubit(
        repository: repository,
        deliveryId: _deliveryId,
        refreshSignals: bus.stream,
      );

      unawaited(cubit.loadDelivery());
      async.flushMicrotasks();
      expect(repository.fetchCalls, 1);

      // The old form asserted the poller was PARKED here (gate not foreground)
      // and resumed on setForeground(true). A push carries no such gate — and
      // must not: a foreground push arriving for a live delivery is precisely
      // the event the jeeber needs, and only ONE read answers it.
      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(repository.fetchCalls, 1, reason: 'no cadence to fire');

      gate.setForeground(true);
      async.flushMicrotasks();
      expect(repository.fetchCalls, 1,
          reason: 'a gate flip is not a read trigger; only load, push, resume '
              'and the jeeber own writes read');

      bus.add(null);
      async.flushMicrotasks();
      expect(repository.fetchCalls, 2);

      unawaited(cubit.close());
      async.flushMicrotasks();
      bus.close();
    });
  });

  // R29 NOTE — preserved from the poll era, and still exact. The assertion set
  // is unchanged except that "the poller stays running" became "the push
  // subscription stays armed", and the liveness tail fires a real push.
  //
  //   AUTHORITY: the FROZEN state machine, `DeliverySm.cs:53-62`. `AtDoor` has
  //   exactly three exits — `otp_verified -> Done`,
  //   `otp_fail_or_jeeber_escalate -> FailedNeedsEscalation`,
  //   `escalate_either -> FailedNeedsEscalation` — and NONE of them is a jeeber
  //   tap. `JeeberDeliveryStatus.next` returns `null` at `atDoor` for that
  //   reason.
  test(
    'AC13 markDelivered stops at AtDoor and keeps the push subscription armed '
    'for the door-OTP handover (frozen SM: AtDoor->Done is otp_verified only)',
    () {
      fakeAsync((async) {
        _installManualGate().setForeground(true);
        final repository = _CountingActiveDeliveryRepository(
          fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.atDoor],
        );
        final bus = StreamController<void>.broadcast();
        final cubit = ActiveDeliveryCubit(
          repository: repository,
          deliveryId: _deliveryId,
          refreshSignals: bus.stream,
        );

        unawaited(cubit.loadDelivery());
        async.flushMicrotasks();
        bus.add(null);
        async.flushMicrotasks();
        expect(repository.fetchCalls, 2);
        expect(cubit.debugPushRefreshWired, isTrue);

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
        // 4. The subscription stays ARMED: an admin/customer can still move
        //    this row, and the jeeber must see it.
        expect(cubit.debugPushRefreshWired, isTrue);

        // P6/A4 tail, now stronger: a real push lands WHILE the OTP surface is
        // up. The read happens, and the non-terminal result is REFUSED so it
        // never clobbers the code the jeeber is typing.
        final atHandover = repository.fetchCalls;
        bus.add(null);
        async.flushMicrotasks();
        expect(
          repository.fetchCalls,
          greaterThan(atHandover),
          reason: 'the push path is live at the door — this is not a '
              'GET-saving claim',
        );
        expect(cubit.debugPushRefreshWired, isTrue);
        expect(
          cubit.state.delivery?.status,
          JeeberDeliveryStatus.atDoor,
          reason: 'a non-terminal push result must not disturb the handover',
        );
        expect(
          cubit.state.otpRequired,
          isTrue,
          reason: 'the OTP surface must survive every intervening push (P6/A4)',
        );

        unawaited(cubit.close());
        async.flushMicrotasks();
        bus.close();
      });
    },
  );

  test(
    'AC14 retires the push subscription after submitDoorOtp completes the '
    'delivery',
    () {
      fakeAsync((async) {
        _installManualGate().setForeground(true);
        final repository = _CountingActiveDeliveryRepository(
          fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.atDoor],
          // Stated explicitly: `otp_verified -> Done` is the ONLY edge the
          // frozen SM (DeliverySm.cs:53-62) opens out of AtDoor, and this test
          // owns that terminal-stop assertion now that AC13 correctly stops at
          // the door.
          verifyOtpResult: JeeberDeliveryStatus.done,
        );
        final bus = StreamController<void>.broadcast();
        final cubit = ActiveDeliveryCubit(
          repository: repository,
          deliveryId: _deliveryId,
          refreshSignals: bus.stream,
        );

        unawaited(cubit.loadDelivery());
        async.flushMicrotasks();
        bus.add(null);
        async.flushMicrotasks();
        expect(repository.fetchCalls, 2);
        expect(cubit.debugPushRefreshWired, isTrue);

        unawaited(cubit.submitDoorOtp('1234'));
        async.flushMicrotasks();
        expect(cubit.state.delivery?.status, JeeberDeliveryStatus.done);
        expect(repository.verifyOtpCalls, 1);
        expect(cubit.debugPushRefreshWired, isFalse);

        // STRONGER than the old timer claim: the bus is app-wide, so an
        // unretired subscription would keep re-reading this Done row on every
        // unrelated push for the rest of the session.
        for (var i = 0; i < 3; i++) {
          bus.add(null);
          async.flushMicrotasks();
        }
        async.elapse(const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(
          repository.fetchCalls,
          2,
          reason:
              'the same fetchDelivery seam proves a non-zero live baseline; '
              'OTP completion must produce zero GET delta for both pushes AND '
              'elapsed time',
        );

        unawaited(cubit.close());
        async.flushMicrotasks();
        bus.close();
      });
    },
  );

  testWidgets('AC15 fetches exactly once on foreground return', (tester) async {
    _installBindingGate(tester);
    final repository = _CountingActiveDeliveryRepository(
      fetchStatuses: <JeeberDeliveryStatus>[JeeberDeliveryStatus.picked],
    );
    final bus = StreamController<void>.broadcast();
    addTearDown(bus.close);
    final cubit = ActiveDeliveryCubit(
      repository: repository,
      deliveryId: _deliveryId,
      refreshSignals: bus.stream,
    );

    await cubit.loadDelivery();
    await tester.pumpWidget(_activeDeliveryHarness(cubit));
    await tester.pump();
    expect(repository.fetchCalls, 1);

    // No cadence: sitting on the screen buys nothing.
    await tester.pump(_resumePollInterval);
    await tester.pump();
    expect(repository.fetchCalls, 1);

    await _driveToBackground(tester);
    final backgroundBaseline = repository.fetchCalls;
    await tester.pump(_resumePollInterval * 3);
    expect(repository.fetchCalls, backgroundBaseline);

    await _driveToForeground(tester);
    await tester.pump();

    // The resume backstop is UNCHANGED and still load-bearing: it catches a
    // push the OS dropped or coalesced while the process was backgrounded.
    // EXACTLY one read — never a double-fetch.
    expect(repository.fetchCalls, backgroundBaseline + 1);
    await tester.pump(_resumePollInterval);
    expect(
      repository.fetchCalls,
      backgroundBaseline + 1,
      reason: 'the screen resume hook is the only resume-time reader, and it '
          'fires once',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await cubit.close();
  });
}
