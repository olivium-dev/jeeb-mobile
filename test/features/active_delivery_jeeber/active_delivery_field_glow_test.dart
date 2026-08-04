// R18's field glow, read off the widget. The M6 census re-measured this tile's
// bottom bloom at .26 — one notch above the ratified single alpha .24, so it is
// a per-screen `glowColor` override and the goldens cannot see the difference.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _Repo implements ActiveDeliveryRepository {
  const _Repo();

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async =>
      const JeeberDelivery(
        id: 'd1',
        status: JeeberDeliveryStatus.inTransit,
        dropOff: DropOffAddress(
          label: 'Rue Monot 42',
          detail: 'Ring twice',
          lat: 33.9,
          lng: 35.5,
        ),
        amountText: r'$8.00',
      );

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async => to;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'proof://x';

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;
}

Future<JeebMidnightField> _pumpField(WidgetTester tester) async {
  final cubit = ActiveDeliveryCubit(
    repository: const _Repo(),
    deliveryId: 'd1',
    refreshSignals: const Stream<void>.empty(),
  );
  addTearDown(cubit.close);
  await cubit.loadDelivery();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.midnight(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ActiveDeliveryJeeberScreen(
        deliveryId: 'd1',
        cubit: cubit,
        onOpenChat: () {},
      ),
    ),
  );
  await tester.pump();

  final Finder finder = find.byType(JeebMidnightField);
  expect(finder, findsOneWidget, reason: 'R18 draws exactly one field');
  return tester.widget<JeebMidnightField>(finder);
}

void main() {
  group('R18 active delivery — field glow', () {
    testWidgets('overrides the ratified .24 with its measured .26', (
      tester,
    ) async {
      final JeebMidnightField field = await _pumpField(tester);

      expect(field.glowColor, isNotNull);
      expect(
        field.glowColor!.a,
        closeTo(0.26, 0.002),
        reason: 'board 18-r18 measures rgba(215,59,0,.26) under the pill row',
      );
      expect(field.glowColor!.r, JeebMidnight.orange.r);
    });

    testWidgets('keeps the bottom anchor the tile draws', (tester) async {
      final JeebMidnightField field = await _pumpField(tester);

      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.bottom);
    });
  });
}
