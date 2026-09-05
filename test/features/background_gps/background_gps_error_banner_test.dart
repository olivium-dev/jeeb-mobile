// BGPS-01 / OFF-03 — `BackgroundGpsPhase.error` was emitted by two paths and
// rendered by NO widget: the delivery ran blind. It now has a banner and a
// resume act.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/features/background_gps/application/background_gps_state.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);

class _InertRepo implements ActiveDeliveryRepository {
  const _InertRepo();

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async =>
      const JeeberDelivery(
        id: 'DLV-770001',
        status: JeeberDeliveryStatus.inTransit,
        dropOff: _dropOff,
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

ActiveDeliveryCubit _seeded(BackgroundGpsPhase phase) => ActiveDeliveryCubit(
      repository: const _InertRepo(),
      deliveryId: 'DLV-770001',
      refreshSignals: const Stream<void>.empty(),
    )..emit(ActiveDeliveryState(
        mode: ActiveDeliveryMode.ready,
        delivery: const JeeberDelivery(
          id: 'DLV-770001',
          status: JeeberDeliveryStatus.inTransit,
          dropOff: _dropOff,
        ),
        gpsPhase: phase,
      ));

Widget _host(ActiveDeliveryCubit cubit, Locale locale) => wrapForTest(
      ActiveDeliveryJeeberScreen(
        deliveryId: 'DLV-770001',
        cubit: cubit,
        onOpenChat: () {},
      ),
      locale: locale,
    );

void main() {
  testWidgets('the stopped-uploader banner and its resume CTA render, EN + AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      useReduceMotion(tester);
      final cubit = _seeded(BackgroundGpsPhase.error);
      await tester.pumpWidget(_host(cubit, locale));
      await tester.pumpAndSettle();

      expect(cubit.state.isGpsFailed, isTrue);
      expect(
        find.bySemanticsIdentifier('active_delivery_gps_stopped'),
        findsOneWidget,
        reason: 'locale: $locale',
      );
      expect(
        find.bySemanticsIdentifier('active_delivery_gps_resume_cta'),
        findsOneWidget,
      );
      await cubit.close();
    }
  });

  testWidgets('a healthy uploader renders neither', (tester) async {
    useReduceMotion(tester);
    final cubit = _seeded(BackgroundGpsPhase.tracking);
    await tester.pumpWidget(_host(cubit, const Locale('en')));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('active_delivery_gps_stopped'),
      findsNothing,
    );
    await cubit.close();
  });

  testWidgets('tapping resume does not throw with no uploader wired',
      (tester) async {
    useReduceMotion(tester);
    final cubit = _seeded(BackgroundGpsPhase.error);
    await tester.pumpWidget(_host(cubit, const Locale('en')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsIdentifier('active_delivery_gps_resume_cta'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await cubit.close();
  });
}
