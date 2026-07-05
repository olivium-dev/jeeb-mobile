// Isolated native UI test — JeeberHomeScreen (Dashboard tab). Pumps the screen
// directly (it owns its own Scaffold) across the two easy sub-views it branches
// on: State 1 unregistered upsell, and State 2 registered/offline no-requests.
// State 3 (live feed) needs a RequestFeedCubit + online toggle and is left to
// the flow-level tests.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';

import '../support/screen_harness.dart';

/// Registered path: provide the AvailabilityCubit the screen reads (its
/// didChangeDependencies calls load()). The empty ticker stream keeps the test
/// binding free of pending timers.
Widget _registered() {
  final cubit = AvailabilityCubit(
    gateway: InMemoryAvailabilityGateway(),
    tickerFactory: () => const Stream<DateTime>.empty(),
  );
  return BlocProvider<AvailabilityCubit>.value(
    value: cubit,
    child: const JeeberHomeScreen(profileName: 'Kamal'),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jeeber-home: unregistered upsell (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const JeeberHomeScreen(isRegistered: false, profileName: 'Kamal'),
      'jeeber-home__unregistered',
    );
  });

  testWidgets('jeeber-home: registered, offline / no requests (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _registered(),
      'jeeber-home__no-requests',
    );
  });

  testWidgets('jeeber-home: registered, offline / no requests (ar)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _registered(),
      'jeeber-home__no-requests-ar',
      locale: const Locale('ar'),
    );
  });
}
