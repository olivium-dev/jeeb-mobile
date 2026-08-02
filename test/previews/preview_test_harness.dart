// Shared harness for preview render tests.
//
// Every preview test asks the same question — "does this preview build and show
// its own state, in English and in Arabic?" — so the MaterialApp/theme/l10n
// boilerplate lives here once instead of in ~170 files.
//
// Usage:
//
//   void main() {
//     setUpAll(loadPreviewArbs);
//
//     testPreviewsRender('MyWidget', const <String, Widget Function()>{
//       'Empty': myWidgetEmpty,
//       'Loaded': myWidgetLoaded,
//     }, expectedText: const <String, String>{
//       'Empty': 'Nothing here yet',
//       'Loaded': 'Two items',
//     });
//   }

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/previews/harness/jeeb_preview.dart';

/// The real `AppLocalizations.delegate` reads its ARB from the asset bundle,
/// which never settles under `pumpWidget`. This reads the same files from disk
/// so previews localize synchronously in tests.
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
/// localizations, and the shared [jeebPreviewHost].
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
///
/// Asserts each preview builds without throwing in BOTH locales, and — when
/// [expectedText] supplies a string for that state — that it renders ITS OWN
/// state. The second half matters: a suite that only checks "something
/// rendered" passes even when every preview shows the same widget.
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
