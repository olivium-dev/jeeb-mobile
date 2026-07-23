import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';

class _GoldenDeliveryRepository implements ActiveDeliveryRepository {
  const _GoldenDeliveryRepository(this.delivery);

  final JeeberDelivery delivery;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async => delivery;

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
  }) async => 'proof://golden';

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;
}

void main() {
  setUpAll(loadInterTestFont);

  const scenarios = <({String name, Locale locale, double textScale})>[
    (name: 'english_phone', locale: Locale('en'), textScale: 1),
    (name: 'arabic_rtl_phone', locale: Locale('ar'), textScale: 1),
    (name: 'english_200_percent_text', locale: Locale('en'), textScale: 2),
  ];

  for (final scenario in scenarios) {
    testWidgets('active delivery ${scenario.name} golden', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final isArabic = scenario.locale.languageCode == 'ar';
      final cubit = ActiveDeliveryCubit(
        repository: _GoldenDeliveryRepository(
          JeeberDelivery(
            id: 'delivery-golden',
            status: JeeberDeliveryStatus.picked,
            dropOff: DropOffAddress(
              label: isArabic ? 'شارع الحمرا، بيروت' : '12 Market Street',
              detail: isArabic ? 'الطابق الثاني' : 'Second floor',
              lat: 33.8938,
              lng: 35.5018,
            ),
          ),
        ),
        deliveryId: 'delivery-golden',
        pollInterval: const Duration(days: 1),
      );
      await cubit.loadDelivery();
      await cubit.close();

      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('active-delivery-golden'),
          child: MaterialApp(
            theme: withGoldenTestFonts(AppTheme.light()),
            locale: scenario.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              SyncAppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: _a11yBuilder(scenario.textScale),
            home: ActiveDeliveryJeeberScreen(
              deliveryId: 'delivery-golden',
              cubit: cubit,
              onOpenChat: _noop,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(
          tester.element(find.byType(ActiveDeliveryJeeberScreen)),
        ),
        isArabic ? TextDirection.rtl : TextDirection.ltr,
      );
      await expectLater(
        find.byKey(const Key('active-delivery-golden')),
        matchesGoldenFile('goldens/active_delivery_${scenario.name}.png'),
      );
    });
  }
}

TransitionBuilder _a11yBuilder(double textScale) {
  return (context, child) {
    final scaled = MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale));
    return MediaQuery(
      data: scaled,
      child: Builder(
        builder: (scaledContext) => jeebA11yBuilder(scaledContext, child),
      ),
    );
  };
}

void _noop() {}
