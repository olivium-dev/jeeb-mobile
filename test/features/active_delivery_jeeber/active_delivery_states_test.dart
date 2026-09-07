// TEST-17 / LR-30 / LR-33 — every rung of the active-delivery screen is
// findable by identifier and every act carries one, in EN and AR.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/active_delivery_jeeber_screen_fixtures.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _InertRepo implements ActiveDeliveryRepository {
  const _InertRepo();

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) =>
      Future<JeeberDelivery>.error(
        const ActiveDeliveryException.typed(ActiveDeliveryFailure.network),
      );

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async => to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'https://cdn.jeeb.app/p.jpg';
}

ActiveDeliveryCubit _seeded(ActiveDeliveryState state) => ActiveDeliveryCubit(
      repository: const _InertRepo(),
      deliveryId: 'DLV-770001',
      refreshSignals: const Stream<void>.empty(),
    )..emit(state);

Future<void> _pump(
  WidgetTester tester,
  ActiveDeliveryCubit cubit,
  Locale locale,
) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapForTest(
      ActiveDeliveryJeeberScreen(
        deliveryId: 'DLV-770001',
        cubit: cubit,
        onOpenChat: () {},
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('loading rung is findable ($locale)', (tester) async {
      final cubit = _seeded(ActiveDeliveryJeeberScreenFixtures.loading);
      await _pump(tester, cubit, locale);
      expect(
        find.bySemanticsIdentifier('active_delivery_loading'),
        findsOneWidget,
      );
      await cubit.close();
    });

    testWidgets('error rung carries an identified retry ($locale)',
        (tester) async {
      final cubit = _seeded(ActiveDeliveryJeeberScreenFixtures.loadFailed);
      await _pump(tester, cubit, locale);
      expect(
        find.bySemanticsIdentifier('active_delivery_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('active_delivery_retry_cta'),
        findsOneWidget,
      );
      await cubit.close();
    });

    testWidgets('a 404 offers an EXIT, never an inert retry ($locale)',
        (tester) async {
      final cubit = _seeded(
        ActiveDeliveryJeeberScreenFixtures.loadFailedNotFound,
      );
      await _pump(tester, cubit, locale);
      expect(
        find.bySemanticsIdentifier('active_delivery_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('active_delivery_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('active_delivery_exit_cta'),
        findsOneWidget,
      );
      await cubit.close();
    });

    testWidgets('a warm poll failure renders the refresh strip over the rows '
        '($locale)', (tester) async {
      final cubit = _seeded(
        ActiveDeliveryJeeberScreenFixtures.refreshFailedWarm,
      );
      await _pump(tester, cubit, locale);

      // Refresh keeps the rows: the error rung never took the screen.
      expect(find.bySemanticsIdentifier('active_delivery_error'), findsNothing);
      expect(
        find.bySemanticsIdentifier('active_delivery_refresh_failed'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('active_delivery_refresh_failed_retry_cta'),
        findsOneWidget,
      );

      await tester.tap(
        find.bySemanticsIdentifier(
          'active_delivery_refresh_failed_dismiss_cta',
        ),
      );
      await tester.pumpAndSettle();
      expect(cubit.state.refreshFailure, isNull);
      expect(
        find.bySemanticsIdentifier('active_delivery_refresh_failed'),
        findsNothing,
      );
      await cubit.close();
    });

    testWidgets('the proof-photo snack fires ONCE, not on every later emit '
        '($locale)', (tester) async {
      // The listener only sees CHANGES, so the failure has to arrive after
      // the first frame — exactly as the camera leg delivers it.
      final cubit = _seeded(ActiveDeliveryJeeberScreenFixtures.inTransit);
      await _pump(tester, cubit, locale);
      cubit.emit(ActiveDeliveryJeeberScreenFixtures.proofPhotoPermissionDenied);
      await tester.pump();
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('active_delivery_proof_photo_error'),
        findsOneWidget,
      );
      // The listener acknowledged, so an unrelated emit cannot re-fire it.
      expect(cubit.state.proofPhotoFailure, isNull);

      // Clear the bar, then move the state for an unrelated reason: before the
      // ack the listener re-fired the snack on every emit.
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('active_delivery_proof_photo_error'),
        findsNothing,
      );

      cubit.emit(cubit.state.copyWith(note: 'unrelated'));
      await tester.pump();
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('active_delivery_proof_photo_error'),
        findsNothing,
      );
      await cubit.close();
    });

    testWidgets('the GPS-stopped banner and its resume act ($locale)',
        (tester) async {
      final cubit = _seeded(
        ActiveDeliveryJeeberScreenFixtures.gpsUploadStopped,
      );
      await _pump(tester, cubit, locale);
      expect(
        find.bySemanticsIdentifier('active_delivery_gps_stopped'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('active_delivery_gps_resume_cta'),
        findsOneWidget,
      );
      await cubit.close();
    });
  }

  testWidgets('the unavailable shell has a headline of its own and an exit',
      (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      wrapForTest(
        ActiveDeliveryJeeberScreen(deliveryId: '', onOpenChat: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('active_delivery_unavailable'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('active_delivery_exit_cta'),
      findsOneWidget,
    );
  });
}
