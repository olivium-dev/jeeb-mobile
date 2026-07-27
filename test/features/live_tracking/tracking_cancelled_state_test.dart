import 'dart:async';
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
    test('P6/A3: Cancelled / cancelled / canceled are cancelled; expired is '
        'EXPIRED', () {
      for (final s in ['Cancelled', 'cancelled', 'canceled']) {
        final i = _fromStatus(s);
        expect(i.lifecycle, TrackingLifecycle.cancelled,
            reason: '$s must parse as terminal cancelled');
        expect(i.isCancelled, isTrue);
        expect(i.isExpired, isFalse);
        expect(i.isPollTerminal, isTrue);
      }
      final e = _fromStatus('expired');
      expect(e.lifecycle, TrackingLifecycle.expired);
      expect(e.isExpired, isTrue);
      expect(e.isCancelled, isFalse);
      expect(e.isPollTerminal, isTrue);
    });

    test('P6/A1: FailedNeedsEscalation / disputed park under review and KEEP '
        'polling', () {
      for (final s in ['FailedNeedsEscalation', 'disputed']) {
        final i = _fromStatus(s);
        expect(i.lifecycle, TrackingLifecycle.failed,
            reason: '$s must parse as the admin-parked side state');
        expect(i.isUnderReview, isTrue);
        expect(i.isPollTerminal, isFalse); // <- the A1 fix
        expect(i.isCancelled, isFalse);
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

  // b02 wave C / N7: the 5s poll became a `type=delivery` push subscription, so
  // "stops polling" is now "retires the subscription and takes no read on a
  // later push". That is the STRONGER claim: the bus is app-wide, so an
  // unretired subscription would keep re-reading a cancelled row on every
  // unrelated push for the rest of the session — where before it merely kept a
  // timer alive on one screen.
  group('LiveTrackingCubit terminal cancelled (scenario matrix #9)', () {
    test('stops reading once the row is cancelled', () async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('Cancelled'));

      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        refreshSignals: bus.stream,
      );
      // Initial fetch resolves the terminal row.
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.trackingInfo?.isCancelled, isTrue);
      expect(cubit.debugPushRefreshWired, isFalse);

      // Several pushes AND elapsed time — neither may produce a read.
      for (var i = 0; i < 3; i++) {
        bus.add(null);
        await Future<void>.delayed(Duration.zero);
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      verify(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .called(1);
      await cubit.close();
    });

    test('P6/A3: stops reading once the row is expired', () async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('expired'));

      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        refreshSignals: bus.stream,
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.trackingInfo?.isExpired, isTrue);
      expect(cubit.debugPushRefreshWired, isFalse);

      bus.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      verify(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .called(1);
      await cubit.close();
    });

    test('P6/A1: LiveTrackingCubit does NOT stop on FailedNeedsEscalation',
        () async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('FailedNeedsEscalation'));
      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        refreshSignals: bus.stream,
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.debugPushRefreshWired, isTrue,
          reason: 'SM edges 12/13 can still resolve an escalated row — the '
              'customer must keep receiving its transitions');
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
      verify(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .called(greaterThan(1));
      await cubit.close();
    });

    test('an active row keeps listening (control)', () async {
      final repo = _MockRepo();
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('InTransit'));

      final bus = StreamController<void>.broadcast();
      addTearDown(bus.close);
      final cubit = LiveTrackingCubit(
        repository: repo,
        deliveryId: 'DLV-770001',
        refreshSignals: bus.stream,
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.debugPushRefreshWired, isTrue);
      bus.add(null);
      await Future<void>.delayed(Duration.zero);
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
        refreshSignals: const Stream<void>.empty(),
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
        refreshSignals: const Stream<void>.empty(),
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
