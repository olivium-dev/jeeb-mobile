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
  }) {
    return AvailabilityCubit(
      gateway: gateway,
      policy: policy,
      clock: () => now,
      tickerFactory: () => ticker.stream,
    );
  }

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
        (_) async => AvailabilityStatus(
          state: AvailabilityState.online,
          activeDeliveryCount: 0,
          lastActivityAt: DateTime.utc(2026, 5, 17, 9, 0, 0),
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
      final completer = Completer<AvailabilityStatus>();
      when(() => gateway.toggle(goOnline: any(named: 'goOnline')))
          .thenAnswer((_) => completer.future);
      final cubit = build();
      final first = cubit.toggle();
      // Second tap while the first is in-flight should be a no-op.
      final second = cubit.toggle();
      expect(cubit.state.isToggleInFlight, isTrue);
      completer.complete(
        AvailabilityStatus(
          state: AvailabilityState.online,
          activeDeliveryCount: 0,
          lastActivityAt: now,
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
        (_) async => AvailabilityStatus(
          state: AvailabilityState.online,
          activeDeliveryCount: 0,
          lastActivityAt: now,
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
        (_) async => AvailabilityStatus(
          state: AvailabilityState.online,
          activeDeliveryCount: 0,
          lastActivityAt: now,
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
        (_) async => AvailabilityStatus(
          state: AvailabilityState.online,
          activeDeliveryCount: 0,
          lastActivityAt: now,
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
}
