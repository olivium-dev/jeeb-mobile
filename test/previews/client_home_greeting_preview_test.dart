// Renders every ClientHomeGreeting widget preview in both locales.
//
// `flutter widget-preview start` is an interactive tool — nothing in CI opens
// it, so a preview that throws would rot silently until someone ran it by hand.
// This test pumps each preview function through the same host wrapper the
// preview canvas uses, in EN and in AR, and fails if any of them throws or
// renders the wrong greeting.
//
// It is deliberately cheap: it asserts the contract the previews exist to make
// visible, not the pixel output (the goldens under test/features/**/goldens do
// that for whole screens).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_greeting_preview.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// The generated `AppLocalizations.delegate` loads its ARB asynchronously,
/// which never settles under `pumpWidget`. Mirrors the seam already used by
/// `test/client_home_greeting_test.dart`.
class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  _syncDelegate = _SyncDelegate({
    'en': File('lib/l10n/app_en.arb').readAsStringSync(),
    'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
  });
}

/// Wraps a preview function the way the preview canvas does: real theme, real
/// localizations, and the shared [jeebPreviewHost] wrapper.
Widget _canvas(Widget Function() preview, Locale locale) {
  return MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

/// Every preview declared in `client_home_greeting_preview.dart`, by name.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Named + avatar': clientHomeGreetingNamed,
  'Generic fallback': clientHomeGreetingFallback,
  'Name, no avatar': clientHomeGreetingInitialsOnly,
  'Synthetic handle suppressed': clientHomeGreetingSyntheticHandle,
  'Long name overflow': clientHomeGreetingLongName,
};

void main() {
  setUpAll(_loadArbs);

  group('ClientHomeGreeting previews render', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final entry in _previews.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (tester) async {
          await tester.pumpWidget(_canvas(entry.value, locale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // The header always renders its two affordances, in every state and
          // both locales: the avatar and the create-request button.
          expect(
            find.byKey(const Key('client-home-greeting-avatar')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('client-home-greeting-add')),
            findsOneWidget,
          );
        });
      }
    }

    // Each preview must render ITS OWN state. Asserting only that "a header
    // appeared" would pass even if every preview rendered the same widget —
    // which is exactly the failure mode the preview canvas's search filter
    // exhibits (it renders by unfiltered index while showing filtered labels,
    // Flutter 3.44.2). These assertions are what distinguish a real binding
    // bug from a canvas display bug.
    const Map<String, String> expectedGreeting = <String, String>{
      'Named + avatar': 'Hello, Sami',
      'Generic fallback': 'Welcome back',
      'Name, no avatar': 'Hello, Layla',
      'Synthetic handle suppressed': 'Welcome back',
      'Long name overflow': 'Hello, Abdulrahman',
    };

    for (final entry in _previews.entries) {
      testWidgets('${entry.key} renders its own state', (tester) async {
        await tester.pumpWidget(_canvas(entry.value, const Locale('en')));
        await tester.pumpAndSettle();

        expect(find.text(expectedGreeting[entry.key]!), findsOneWidget);
      });
    }

    testWidgets('named preview greets the FIRST name only', (tester) async {
      await tester.pumpWidget(
        _canvas(clientHomeGreetingNamed, const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hello, Sami'), findsOneWidget);
      expect(find.textContaining('Fawaz'), findsNothing);
    });

    testWidgets('synthetic handle preview never shows the raw handle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _canvas(clientHomeGreetingSyntheticHandle, const Locale('en')),
      );
      await tester.pumpAndSettle();

      // Audit §T5: the header must degrade to the generic greeting rather than
      // greet an internal account identifier.
      expect(find.textContaining('jeeb-e1a35ea8a520'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
