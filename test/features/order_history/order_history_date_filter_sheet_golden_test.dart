import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/accessibility/accessibility.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_date_filter_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';

void main() {
  setUpAll(loadInterTestFont);

  const scenarios = <({String name, Locale locale, double textScale})>[
    (name: 'english_phone', locale: Locale('en'), textScale: 1),
    (name: 'arabic_rtl_phone', locale: Locale('ar'), textScale: 1),
    (name: 'english_200_percent_text', locale: Locale('en'), textScale: 2),
  ];

  for (final scenario in scenarios) {
    testWidgets('order-history filter ${scenario.name} golden', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext sheetContext;
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('filter-sheet-golden'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
            home: Builder(
              builder: (context) {
                sheetContext = context;
                return const Scaffold(body: SizedBox.expand());
              },
            ),
          ),
        ),
      );

      showOrderHistoryDateFilterSheet(
        context: sheetContext,
        initial: const OrderDateRange(),
      );
      await tester.pumpAndSettle();

      final title = find.text(
        scenario.locale.languageCode == 'ar'
            ? 'تصفية حسب التاريخ'
            : 'Filter by date',
      );
      expect(title, findsOneWidget);
      expect(
        Directionality.of(tester.element(title)),
        scenario.locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
      );
      await _expectGoldenWithLinuxDiagnostic(
        find.byKey(const Key('filter-sheet-golden')),
        goldenPath: 'goldens/order_history_filter_${scenario.name}.png',
        failureStem: 'order_history_filter_${scenario.name}',
      );
    });
  }
}

Future<void> _expectGoldenWithLinuxDiagnostic(
  Finder finder, {
  required String goldenPath,
  required String failureStem,
}) async {
  try {
    await expectLater(finder, matchesGoldenFile(goldenPath));
  } catch (_) {
    if (Platform.isLinux) {
      await _emitPng(
        failureStem,
        File(
          'test/features/order_history/failures/'
          '${failureStem}_testImage.png',
        ),
      );
    }
    rethrow;
  }
}

Future<void> _emitPng(String stem, File file) async {
  if (!file.existsSync()) return;
  final encoded = base64Encode(await file.readAsBytes());
  const chunkSize = 4000;
  for (var offset = 0; offset < encoded.length; offset += chunkSize) {
    final end = (offset + chunkSize).clamp(0, encoded.length);
    debugPrintSynchronously(
      'GOLDEN_BASE64_CHUNK:$stem:${encoded.substring(offset, end)}',
    );
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
