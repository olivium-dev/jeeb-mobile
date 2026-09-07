// JHOME-04 / JHOME-05 / NET-11: the availability cold read has three honest
// outcomes — ready, not-registered, and a CLASSIFIED failure.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_state.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// `fetch()` raises a raw TypeError — the shape a malformed envelope produces
/// and the one a typed-only catch used to let strand the screen on loading.
class _ParseBreakingGateway implements AvailabilityGateway {
  const _ParseBreakingGateway();

  @override
  Future<AvailabilityStatus> fetch() async =>
      (<Object?>[] as AvailabilityStatus);

  @override
  Future<AvailabilityToggleResult> toggle({required bool goOnline}) async =>
      (<Object?>[] as AvailabilityToggleResult);

  @override
  Future<GoOnlineLocationOutcome> refreshLocation() async =>
      GoOnlineLocationOutcome.notApplicable;
}

class _CountingGateway implements AvailabilityGateway {
  _CountingGateway(this.failure);

  final AppFailure failure;
  int reads = 0;

  @override
  Future<AvailabilityStatus> fetch() async {
    reads++;
    throw AvailabilityGatewayException.from(failure);
  }

  @override
  Future<AvailabilityToggleResult> toggle({required bool goOnline}) async =>
      throw AvailabilityGatewayException.from(failure);

  @override
  Future<GoOnlineLocationOutcome> refreshLocation() async =>
      throw AvailabilityGatewayException.from(failure);
}

Widget _host(AvailabilityCubit cubit, {Locale locale = const Locale('en')}) =>
    wrapForTest(
      BlocProvider<AvailabilityCubit>.value(
        value: cubit,
        child: const JeeberHomeScreen(profileName: 'Kamal'),
      ),
      locale: locale,
    );

AvailabilityCubit _cubit(AvailabilityGateway gateway) => AvailabilityCubit(
      gateway: gateway,
      tickerFactory: () => const Stream<DateTime>.empty(),
    );

void main() {
  group('cubit', () {
    test('a raw TypeError reaches loadError instead of pinning `loading`',
        () async {
      final cubit = _cubit(const _ParseBreakingGateway());
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.loadPhase, AvailabilityLoadPhase.loadError);
      expect(cubit.state.loadError, isNotNull);
    });

    test('a 404 is notRegistered, NOT a silent "offline"', () async {
      final cubit = _cubit(const NotRegisteredAvailabilityGateway());
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.loadPhase, AvailabilityLoadPhase.notRegistered);
      expect(cubit.state.loadError, isNull);
      expect(cubit.state.status.state, isNot(AvailabilityState.online));
    });

    test('a toggle TypeError clears the in-flight flag', () async {
      final cubit = _cubit(const _ParseBreakingGateway());
      addTearDown(cubit.close);

      await cubit.toggle();

      expect(cubit.state.isToggleInFlight, isFalse);
      expect(cubit.state.toggleError, isTrue);
      expect(cubit.state.toggleFailure, isNotNull);
    });
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a 404 renders the not-registered block, not the feed',
        (tester) async {
      final cubit = _cubit(const NotRegisteredAvailabilityGateway());
      addTearDown(cubit.close);

      useReduceMotion(tester);
      await tester.pumpWidget(_host(cubit, locale: locale));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_home_not_registered_state'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('jeeber_home_error'), findsNothing);
    });

    testWidgets('[$tag] a FORBIDDEN read offers an exit, never an inert Retry',
        (tester) async {
      final cubit = _cubit(
        const FailingAvailabilityGateway(ForbiddenFailure()),
      );
      addTearDown(cubit.close);

      useReduceMotion(tester);
      await tester.pumpWidget(_host(cubit, locale: locale));
      await cubit.load();
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('jeeber_home_error'), findsOneWidget);
      // An unrecoverable kind draws the EXIT pill under the exit id; the
      // retry id must be absent or the ratchet counts an exit as a Retry.
      expect(
        find.bySemanticsIdentifier('jeeber_home_load_error_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_home_exit_cta'),
        findsOneWidget,
      );
    });
  }

  testWidgets('the retry CTA re-reads availability', (tester) async {
    final gateway = _CountingGateway(const NetworkFailure());
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    useReduceMotion(tester);
    // The screen issues its own cold read in initState.
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();
    final baseline = gateway.reads;
    expect(baseline, greaterThan(0));

    await tester.tap(
      find.bySemanticsIdentifier('jeeber_home_load_error_retry_cta'),
    );
    await tester.pumpAndSettle();

    expect(gateway.reads, greaterThan(baseline));
  });
}
