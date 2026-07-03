// sprint-009 scenario matrix #9/#10 (feat/request-scenarios).
//
// PROVES:
//  1. DeliveryTrackingInfo parses the terminal/side lifecycle axis from every
//     canonical + legacy status token (DeliveryStatusAlias table, ADR-002 §3),
//     and the previously-dropped aliases heading_off ⇒ InTransit and
//     rated ⇒ Done now land on the right stage.
//  2. LiveTrackingCubit stops polling once the row is terminal cancelled.
//  3. LiveTrackingScreen renders the graceful `tracking_cancelled_state`
//     (OmdsEmptyState + "Delivery cancelled" + back-home CTA) instead of a
//     live "Ordered" stepper for a cancelled/expired delivery — the pre-fix
//     dead-end.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omds/omds.dart';

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
        child:
            const LiveTrackingScreen(deliveryId: 'DLV-770001', useLiveMap: false),
      ),
    );

void main() {
  group('DeliveryTrackingInfo lifecycle axis (scenario matrix #9)', () {
    test('canonical Cancelled + legacy cancelled/canceled/expired are '
        'terminal cancelled', () {
      for (final status in ['Cancelled', 'cancelled', 'canceled', 'expired']) {
        final info = _fromStatus(status);
        expect(info.lifecycle, TrackingLifecycle.cancelled,
            reason: '$status must parse as terminal cancelled');
        expect(info.isCancelled, isTrue);
      }
    });

    test('FailedNeedsEscalation + legacy disputed are the failed side state',
        () {
      for (final status in ['FailedNeedsEscalation', 'disputed']) {
        final info = _fromStatus(status);
        expect(info.lifecycle, TrackingLifecycle.failed,
            reason: '$status must parse as the admin-parked side state');
        expect(info.isCancelled, isFalse);
      }
    });

    test('every forward-stage token stays active', () {
      for (final status in [
        'Ordered',
        'accepted',
        'Picked',
        'picked_up',
        'InTransit',
        'heading_off',
        'AtDoor',
        'at_door',
        'Done',
        'delivered',
        'rated',
      ]) {
        expect(_fromStatus(status).lifecycle, TrackingLifecycle.active,
            reason: '$status must stay lifecycle-active');
      }
    });
  });

  group('DeliveryTrackingInfo legacy alias stages (scenario matrix #10)', () {
    test('heading_off ⇒ InTransit (DeliveryStatusAlias)', () {
      expect(_fromStatus('heading_off').currentStage, TrackingStage.inTransit);
    });

    test('rated ⇒ Done reads as delivered', () {
      final info = _fromStatus('rated');
      expect(info.currentStage, TrackingStage.delivered);
      expect(info.isDelivered, isTrue);
    });
  });

  group('LiveTrackingCubit terminal cancelled (scenario matrix #9)', () {
    test('stops polling once the row is cancelled', () async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('Cancelled'));

      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        pollInterval: const Duration(milliseconds: 20),
      );
      // Initial fetch resolves the terminal row.
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.trackingInfo?.isCancelled, isTrue);

      // Long enough for several 20ms poll ticks — none may fire.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      verify(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .called(1);
      await cubit.close();
    });

    test('an active row keeps polling (control)', () async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('InTransit'));

      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        pollInterval: const Duration(milliseconds: 20),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      verify(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .called(greaterThan(1));
      await cubit.close();
    });
  });

  group('LiveTrackingScreen cancelled terminal state (scenario matrix #9)',
      () {
    testWidgets(
        'a cancelled delivery renders tracking_cancelled_state — no live '
        'stepper, no retry loop', (tester) async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('Cancelled'));
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        pollInterval: const Duration(days: 1),
      );

      await tester.pumpWidget(_harness(cubit));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('tracking_cancelled_state'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('live-tracking-cancelled-state')),
        findsOneWidget,
      );
      expect(find.byType(OmdsEmptyState), findsOneWidget);
      expect(find.text('Delivery cancelled'), findsOneWidget);
      expect(
        find.byKey(const Key('tracking-cancelled-home-cta')),
        findsOneWidget,
      );
      // The live stepper and error state must NOT render for a terminal row.
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.text('Ordered'), findsNothing);

      await cubit.close();
    });

    testWidgets('an active delivery still renders the live body (control)',
        (tester) async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('InTransit'));
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        pollInterval: const Duration(days: 1),
      );

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('tracking_cancelled_state'),
        findsNothing,
      );
      await cubit.close();
    });
  });
}
