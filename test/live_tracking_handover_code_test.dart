import 'dart:async';
// G4 (sprint-009 P0) — the customer SEES their handover code.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/handover_code_store.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _MockRepo extends Mock implements LiveTrackingRepository {}

class _MemoryStore implements HandoverCodeStore {
  _MemoryStore([Map<String, String>? seed]) : rows = {...?seed};

  final Map<String, String> rows;

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    rows[deliveryId] = code;
  }

  @override
  Future<String?> read({required String deliveryId}) async => rows[deliveryId];

  @override
  Future<void> clear({required String deliveryId}) async {
    rows.remove(deliveryId);
  }
}

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
        child: const LiveTrackingScreen(
          deliveryId: 'DLV-770001',
          useLiveMap: false,
        ),
      ),
    );

LiveTrackingCubit _cubit(
  _MockRepo repo, {
  HandoverCodeStore? store,
}) =>
    LiveTrackingCubit(
      repository: repo,
      deliveryId: 'DLV-770001',
      refreshSignals: const Stream<void>.empty(),
      handoverCodeStore: store,
    );

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    // Wide surface so the tracking column lays out fully.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('LiveTrackingCubit — local code hydration (G4)', () {
    test('re-hydrates the persisted code into state (restart-safe)', () async {
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('InTransit'));
      final store = _MemoryStore({'DLV-770001': '1234'});

      final cubit = _cubit(repo, store: store);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.handoverCode, '1234');
      await cubit.close();
    });

    test('no persisted code → state.handoverCode stays null', () async {
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('InTransit'));

      final cubit = _cubit(repo, store: _MemoryStore());
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.handoverCode, isNull);
      await cubit.close();
    });
  });

  group('At-door prominence (G4)', () {
    testWidgets(
        'AtDoor + known code → code rendered INLINE in the at-door card '
        'with the share instruction AND the Show OTP CTA', (tester) async {
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('AtDoor'));
      final cubit = _cubit(repo, store: _MemoryStore({'DLV-770001': '1234'}));

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();
      await tester.pump();

      expect(find.text('1234'), findsOneWidget,
          reason: 'the code itself must be visible at the hand-off moment');
      expect(find.byKey(const Key('tracking.atDoorCode')), findsOneWidget);
      expect(
        find.text('Share this code with your Jeeber when they arrive'),
        findsOneWidget,
      );
      // The full-screen route stays reachable.
      expect(find.byKey(const Key('tracking.otpCta')), findsOneWidget);
      await cubit.close();
    });

    testWidgets(
        'AtDoor without a known code → pre-fix card copy, no inline code '
        '(the OTP screen owns the SMS fallback)', (tester) async {
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('AtDoor'));
      final cubit = _cubit(repo, store: _MemoryStore());

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tracking.atDoorCode')), findsNothing);
      expect(
        find.text('Share your code with your Jeeber to confirm the handover.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('tracking.otpCta')), findsOneWidget);
      await cubit.close();
    });
  });

  group('Pre-at-door discoverability (G4)', () {
    testWidgets(
        'InTransit + known code → compact "Delivery code" row with the code',
        (tester) async {
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('InTransit'));
      final cubit = _cubit(repo, store: _MemoryStore({'DLV-770001': '1234'}));

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tracking.codeRowValue')), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(find.text('Delivery code'), findsOneWidget);
      // Not the at-door card (that is the prominent surface).
      expect(find.byKey(const Key('tracking.atDoorCode')), findsNothing);
      await cubit.close();
    });

    // P0 (2026-07-31, ship-p0 run g5). This test used to assert
    testWidgets(
        'InTransit WITHOUT a cached code → the row is STILL there, as the '
        'Show OTP CTA (the only unconditional route to the code)',
        (tester) async {
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('InTransit'));
      final cubit = _cubit(repo, store: _MemoryStore());

      await tester.pumpWidget(_harness(cubit));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('tracking.codeRowValue')), findsOneWidget);
      expect(find.text('Delivery code'), findsOneWidget);
      expect(find.text('Show OTP'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('Arabic locale renders the at-door share-code instruction',
        (tester) async {
      when(() =>
              repo.fetchDeliveryStatus(deliveryId: any(named: 'deliveryId')))
          .thenAnswer((_) async => _fromStatus('AtDoor'));
      final cubit = _cubit(repo, store: _MemoryStore({'DLV-770001': '1234'}));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: BlocProvider<LiveTrackingCubit>.value(
            value: cubit,
            child: const LiveTrackingScreen(
              deliveryId: 'DLV-770001',
              useLiveMap: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('شارك هذا الرمز مع جيبرك عند وصوله'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      await cubit.close();
    });
  });
}
