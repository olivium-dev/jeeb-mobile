import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_state.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/availability_inactivity_policy.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';

class _MockGateway extends Mock implements AvailabilityGateway {}

void main() {
  late _MockGateway gateway;
  late StreamController<DateTime> ticker;
  late DateTime now;

  setUp(() {
    gateway = _MockGateway();
    ticker = StreamController<DateTime>.broadcast();
    now = DateTime.utc(2026, 5, 17, 9, 0, 0);
  });

  tearDown(() async {
    await ticker.close();
  });

  AvailabilityCubit build({
    AvailabilityInactivityPolicy policy = const AvailabilityInactivityPolicy(),
    Stream<void>? resumeSignals,
  }) {
    return AvailabilityCubit(
      gateway: gateway,
      policy: policy,
      clock: () => now,
      tickerFactory: () => ticker.stream,
      resumeSignals: resumeSignals,
    );
  }

  const online = AvailabilityStatus(
    state: AvailabilityState.online,
    activeDeliveryCount: 0,
  );
  const offline = AvailabilityStatus(
    state: AvailabilityState.offline,
    activeDeliveryCount: 0,
  );

  group('load', () {
    blocTest<AvailabilityCubit, AvailabilityViewState>(
      'fetches the snapshot and transitions to ready',
      build: build,
      setUp: () => when(() => gateway.fetch()).thenAnswer(
        (_) async => const AvailabilityStatus(
          state: AvailabilityState.offline,
          activeDeliveryCount: 0,
        ),
      ),
      act: (c) => c.load(),
      expect: () => [
        predicate<AvailabilityViewState>(
          (s) => s.loadPhase == AvailabilityLoadPhase.loading,
        ),
        predicate<AvailabilityViewState>(
          (s) =>
              s.loadPhase == AvailabilityLoadPhase.ready &&
              !s.status.isOnline,
        ),
      ],
    );

    blocTest<AvailabilityCubit, AvailabilityViewState>(
      'surfaces a load-error phase when the gateway throws',
      build: build,
      setUp: () => when(() => gateway.fetch())
          .thenThrow(const AvailabilityGatewayException('boom')),
      act: (c) => c.load(),
      skip: 1,
      expect: () => [
        predicate<AvailabilityViewState>(
          (s) => s.loadPhase == AvailabilityLoadPhase.loadError,
        ),
      ],
    );
  });

  group('toggle', () {
    blocTest<AvailabilityCubit, AvailabilityViewState>(
      'goes online and clears the toggle-error flag',
      build: build,
      seed: () => const AvailabilityViewState(
        loadPhase: AvailabilityLoadPhase.ready,
        status: AvailabilityStatus.initial,
      ),
      setUp: () => when(() => gateway.toggle(goOnline: any(named: 'goOnline')))
          .thenAnswer(
        (_) async => AvailabilityToggleResult(
          status: AvailabilityStatus(
            state: AvailabilityState.online,
            activeDeliveryCount: 0,
            lastActivityAt: DateTime.utc(2026, 5, 17, 9, 0, 0),
          ),
          location: GoOnlineLocationOutcome.attached,
        ),
      ),
      act: (c) => c.toggle(),
      expect: () => [
        predicate<AvailabilityViewState>(
          (s) => s.isToggleInFlight && !s.toggleError,
        ),
        predicate<AvailabilityViewState>(
          (s) => !s.isToggleInFlight && s.status.isOnline,
        ),
      ],
      verify: (_) {
        verify(() => gateway.toggle(goOnline: true)).called(1);
      },
    );

    blocTest<AvailabilityCubit, AvailabilityViewState>(
      'sets toggleError when the gateway throws',
      build: build,
      seed: () => const AvailabilityViewState(
        loadPhase: AvailabilityLoadPhase.ready,
      ),
      setUp: () => when(() => gateway.toggle(goOnline: any(named: 'goOnline')))
          .thenThrow(const AvailabilityGatewayException('net')),
      act: (c) => c.toggle(),
      skip: 1,
      expect: () => [
        predicate<AvailabilityViewState>(
          (s) => !s.isToggleInFlight && s.toggleError,
        ),
      ],
    );

    test('blocks concurrent toggles', () async {
      final completer = Completer<AvailabilityToggleResult>();
      when(() => gateway.toggle(goOnline: any(named: 'goOnline')))
          .thenAnswer((_) => completer.future);
      final cubit = build();
      final first = cubit.toggle();
      // Second tap while the first is in-flight should be a no-op.
      final second = cubit.toggle();
      expect(cubit.state.isToggleInFlight, isTrue);
      completer.complete(
        AvailabilityToggleResult(
          status: AvailabilityStatus(
            state: AvailabilityState.online,
            activeDeliveryCount: 0,
            lastActivityAt: now,
          ),
        ),
      );
      await Future.wait([first, second]);
      verify(() => gateway.toggle(goOnline: true)).called(1);
      await cubit.close();
    });
  });

  group('inactivity ticker', () {
    test('surfaces the warning once elapsed >= 7h30 and < 8h', () async {
      when(() => gateway.toggle(goOnline: any(named: 'goOnline'))).thenAnswer(
        (_) async => AvailabilityToggleResult(
          status: AvailabilityStatus(
            state: AvailabilityState.online,
            activeDeliveryCount: 0,
            lastActivityAt: now,
          ),
        ),
      );
      final cubit = build();
      await cubit.toggle(); // go online; ticker starts
      expect(cubit.state.status.isOnline, isTrue);
      expect(cubit.state.warningVisible, isFalse);

      // 7h29 elapsed → no warning yet.
      now = now.add(const Duration(hours: 7, minutes: 29));
      ticker.add(now);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.warningVisible, isFalse);

      // 7h30 elapsed → warning fires.
      now = now.add(const Duration(minutes: 1));
      ticker.add(now);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.warningVisible, isTrue);
      expect(cubit.state.status.state, AvailabilityState.online);

      await cubit.close();
    });

    test('flips to autoOffline once elapsed >= 8h', () async {
      when(() => gateway.toggle(goOnline: any(named: 'goOnline'))).thenAnswer(
        (_) async => AvailabilityToggleResult(
          status: AvailabilityStatus(
            state: AvailabilityState.online,
            activeDeliveryCount: 0,
            lastActivityAt: now,
          ),
        ),
      );
      final cubit = build();
      await cubit.toggle();
      now = now.add(const Duration(hours: 8));
      ticker.add(now);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status.state, AvailabilityState.autoOffline);
      expect(cubit.state.warningVisible, isFalse);
      await cubit.close();
    });

    test('extendActivity resets the timer so the warning clears', () async {
      when(() => gateway.toggle(goOnline: any(named: 'goOnline'))).thenAnswer(
        (_) async => AvailabilityToggleResult(
          status: AvailabilityStatus(
            state: AvailabilityState.online,
            activeDeliveryCount: 0,
            lastActivityAt: now,
          ),
        ),
      );
      final cubit = build();
      await cubit.toggle();
      now = now.add(const Duration(hours: 7, minutes: 31));
      ticker.add(now);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.warningVisible, isTrue);

      cubit.extendActivity();
      expect(cubit.state.warningVisible, isFalse);
      // After reset, last activity timestamp moves forward.
      expect(cubit.state.status.lastActivityAt, now);
      await cubit.close();
    });
  });

  group('D2 location freshness', () {
    late StreamController<void> resumes;

    setUp(() {
      resumes = StreamController<void>.broadcast();
      when(() => gateway.refreshLocation())
          .thenAnswer((_) async => GoOnlineLocationOutcome.attached);
    });

    tearDown(() async => resumes.close());

    Future<void> pump() => Future<void>.delayed(Duration.zero);

    test('toggle surfaces the go-online location outcome on the state',
        () async {
      when(() => gateway.toggle(goOnline: any(named: 'goOnline'))).thenAnswer(
        (_) async => const AvailabilityToggleResult(
          status: online,
          location: GoOnlineLocationOutcome.fixFailed,
        ),
      );
      final cubit = build();
      await cubit.toggle();
      expect(cubit.state.locationOutcome, GoOnlineLocationOutcome.fixFailed);
      await cubit.close();
    });

    test('going offline never carries a stale location outcome', () async {
      when(() => gateway.toggle(goOnline: any(named: 'goOnline'))).thenAnswer(
        (_) async => const AvailabilityToggleResult(
          status: offline,
          location: GoOnlineLocationOutcome.attached,
        ),
      );
      final cubit = build();
      cubit.emit(const AvailabilityViewState(
        status: online,
        locationOutcome: GoOnlineLocationOutcome.fixFailed,
      ));
      await cubit.toggle();
      expect(
        cubit.state.locationOutcome,
        GoOnlineLocationOutcome.notApplicable,
      );
      await cubit.close();
    });

    test('a resume while online re-stamps last_location after syncing state',
        () async {
      when(() => gateway.fetch()).thenAnswer((_) async => online);
      final cubit = build(resumeSignals: resumes.stream);
      cubit.emit(const AvailabilityViewState(status: online));

      resumes.add(null);
      await pump();

      verify(() => gateway.fetch()).called(1);
      verify(() => gateway.refreshLocation()).called(1);
      await cubit.close();
    });

    test('a resume while offline touches the network not at all', () async {
      final cubit = build(resumeSignals: resumes.stream);

      resumes.add(null);
      await pump();

      verifyNever(() => gateway.fetch());
      verifyNever(() => gateway.refreshLocation());
      await cubit.close();
    });

    test('a server auto-offline is adopted, NOT resurrected by the refresh',
        () async {
      when(() => gateway.fetch()).thenAnswer((_) async => offline);
      final cubit = build(resumeSignals: resumes.stream);
      cubit.emit(const AvailabilityViewState(status: online));

      resumes.add(null);
      await pump();

      expect(cubit.state.status.isOnline, isFalse);
      verifyNever(() => gateway.refreshLocation());
      await cubit.close();
    });

    test('a failing resume refresh stays silent', () async {
      when(() => gateway.fetch())
          .thenThrow(const AvailabilityGatewayException('offline'));
      final cubit = build(resumeSignals: resumes.stream);
      cubit.emit(const AvailabilityViewState(status: online));

      resumes.add(null);
      await pump();

      expect(cubit.state.toggleError, isFalse);
      expect(cubit.state.status.isOnline, isTrue);
      await cubit.close();
    });

    test('retryLocationAttach clears the warning once a fix lands', () async {
      final cubit = build();
      cubit.emit(const AvailabilityViewState(
        status: online,
        locationOutcome: GoOnlineLocationOutcome.fixFailed,
      ));

      await cubit.retryLocationAttach();

      expect(cubit.state.locationOutcome, GoOnlineLocationOutcome.attached);
      verify(() => gateway.refreshLocation()).called(1);
      await cubit.close();
    });

    test('a resume that lands after the tab is torn down does not emit',
        () async {
      final gate = Completer<AvailabilityStatus>();
      when(() => gateway.fetch()).thenAnswer((_) => gate.future);
      final cubit = build(resumeSignals: resumes.stream);
      cubit.emit(const AvailabilityViewState(status: online));

      resumes.add(null);
      await pump();
      await cubit.close();
      gate.complete(online);

      // Emitting on a closed cubit throws; the guard must swallow the race.
      await expectLater(pump(), completes);
      verifyNever(() => gateway.refreshLocation());
    });

    test('retryLocationAttach is inert while offline', () async {
      final cubit = build();
      await cubit.retryLocationAttach();
      verifyNever(() => gateway.refreshLocation());
      await cubit.close();
    });
  });
}
