import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';

/// Skip reason for a11y expectations locking `AppTheme.light()`/`dark()` facts.
/// `app.dart` ships midnight in both slots; those schemes are preview-only now.
const String kStalePaletteLockSkip =
    'Locks AppTheme.light()/dark() palette facts that MIDNIGHT superseded; '
    'those schemes are preview/Dev-Tool only. Owner follow-up: re-point at '
    'AppTheme.midnight() or delete.';

/// The real `AppLocalizations.delegate` reads its ARB from the asset bundle,
class _SyncArbDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncArbDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncArbDelegate old) => false;
}

late _SyncArbDelegate _delegate;

/// Call from `setUpAll`.
void loadPreviewArbs() {
  _delegate = _SyncArbDelegate(<String, String>{
    'en': File('lib/l10n/app_en.arb').readAsStringSync(),
    'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
  });
}

/// Wraps a preview the way the preview canvas does: real themes, real
Widget previewCanvas(Widget Function() preview, Locale locale) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: <LocalizationsDelegate<Object?>>[
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // Midnight kit illustrations loop forever by design, so a preview that
    // mounts one can never `pumpAndSettle` without reduce motion.
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: jeebPreviewHost(preview()),
  );
}

/// Pumps [preview] and returns once settled.
Future<void> pumpPreview(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// Standard suite for one widget's previews.
void testPreviewsRender(
  String widgetName,
  Map<String, Widget Function()> previews, {
  Map<String, String> expectedText = const <String, String>{},
}) {
  group('$widgetName previews', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in previews.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (
          WidgetTester tester,
        ) async {
          await pumpPreview(tester, entry.value, locale: locale);
          expect(tester.takeException(), isNull);
        });
      }
    }

    expectedText.forEach((String state, String text) {
      testWidgets('$state renders its own state', (WidgetTester tester) async {
        await pumpPreview(tester, previews[state]!);
        expect(find.text(text), findsOneWidget);
      });
    });
  });
}
