import 'dart:async';
// P6 (UT-12) — the customer tracking screen's lifecycle bodies.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _MockRepo extends Mock implements LiveTrackingRepository {}

DeliveryTrackingInfo _fromStatus(String status) =>
    DeliveryTrackingInfo.fromDeliveryJson(
      'DLV-770001',
      <String, dynamic>{'id': 'DLV-770001', 'status': status},
    );

Widget _harness(LiveTrackingCubit cubit) => MaterialApp(
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
        // No keyless GoogleMap in tests.
        child: const LiveTrackingScreen(
          deliveryId: 'DLV-770001',
          useLiveMap: false,
        ),
      ),
    );

Future<LiveTrackingCubit> _pumpStatus(WidgetTester tester, String status) async {
  final repo = _MockRepo();
  when(() => repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
      .thenAnswer((_) async => _fromStatus(status));
  final cubit = LiveTrackingCubit(
    repository: repo,
    deliveryId: 'DLV-770001',
    // Long enough that no background tick fires mid-test.
    refreshSignals: const Stream<void>.empty(),
  );
  await tester.pumpWidget(_harness(cubit));
  await tester.pump();
  await tester.pump();
  return cubit;
}

void main() {
  testWidgets('a: a cancelled row renders the cancelled body and no stepper',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = await _pumpStatus(tester, 'Cancelled');

    expect(
      find.byKey(const Key('live-tracking-cancelled-state')),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('tracking_stepper'), findsNothing);
    expect(find.text('This delivery was cancelled and is no longer active. '
        'You can create a new request any time.'), findsOneWidget);

    semantics.dispose();
    await cubit.close();
  });

  testWidgets('b: an expired row renders its OWN body + CTA, with copy that '
      'differs from cancelled (P6/A3)', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = await _pumpStatus(tester, 'expired');

    expect(
      find.byKey(const Key('live-tracking-expired-state')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('live-tracking-cancelled-state')),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier('tracking_expired_home_cta'),
      findsOneWidget,
    );
    expect(find.text('Delivery expired'), findsOneWidget);
    // The pre-fix bug: expired reused the cancelled copy verbatim.
    expect(
      find.text('This delivery was cancelled and is no longer active. '
          'You can create a new request any time.'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('tracking_stepper'), findsNothing);

    semantics.dispose();
    await cubit.close();
  });

  testWidgets('c: an escalated row renders the under-review body — NOT a '
      'stepper rewound to step 1 (P6/A1)', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = await _pumpStatus(tester, 'FailedNeedsEscalation');

    expect(
      find.byKey(const Key('live-tracking-under-review-state')),
      findsOneWidget,
    );
    expect(find.text('Delivery under review'), findsOneWidget);
    // THE pre-fix symptom: the active layout with the stepper at "Ordered".
    expect(find.bySemanticsIdentifier('tracking_stepper'), findsNothing);
    // Still live — no exit affordance.
    expect(
      find.bySemanticsIdentifier('tracking_cancelled_home_cta'),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier('tracking_expired_home_cta'),
      findsNothing,
    );

    semantics.dispose();
    await cubit.close();
  });

  testWidgets('d: at the door the third step reads "At Door" but keeps the '
      'tracking_step_in_transit identifier (P6/A5)', (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = await _pumpStatus(tester, 'AtDoor');

    expect(find.bySemanticsIdentifier('tracking_stepper'), findsOneWidget);
    final node = tester.getSemantics(
      find.bySemanticsIdentifier('tracking_step_in_transit'),
    );
    // Relabelled…
    expect(node.value, 'At Door');
    // …but the id a Maestro flow addresses is unchanged.
    expect(node.identifier, 'tracking_step_in_transit');
    expect(find.bySemanticsIdentifier('tracking_step_at_door'), findsNothing);

    semantics.dispose();
    await cubit.close();
  });

  testWidgets('e: in transit the same node reads the in-transit label',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final cubit = await _pumpStatus(tester, 'InTransit');

    final node = tester.getSemantics(
      find.bySemanticsIdentifier('tracking_step_in_transit'),
    );
    expect(node.value, 'In transit');

    semantics.dispose();
    await cubit.close();
  });
}
