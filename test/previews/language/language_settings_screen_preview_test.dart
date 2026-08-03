// Render tests for the LanguageSettingsScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

const Key _enRow = Key('language-row-en');
const Key _arRow = Key('language-row-ar');
const Key _list = Key('language-settings-list');

/// Big enough that a pinned 390x844 card is never clipped by the tester's
/// default 800x600 desktop surface.
const Size _kPhoneSurface = Size(430, 900);

/// The compact ceiling frame plus room for the dev caption above it.
const Size _kCompactSurface = Size(360, 620);

/// The three pieces of copy this screen paints, each scoped to the ONE place it
/// is painted.
const String _kAppBarTitle = 'app-bar title';

final Map<String, Finder> _titleFinders = <String, Finder>{
  _kAppBarTitle:
      find.descendant(of: find.byType(AppBar), matching: find.text('Language')),
  'section header':
      find.descendant(of: find.byKey(_list), matching: find.text('Language')),
  'row title · en':
      find.descendant(of: find.byKey(_enRow), matching: find.text('English')),
  'row title · ar':
      find.descendant(of: find.byKey(_arRow), matching: find.text('العربية')),
};

/// Every preview in this file, so the invariants below can be asserted across
/// all of them instead of once per state.
const Map<String, Widget Function()> _kPreviews = <String, Widget Function()>{
  'Reference · follows the app locale':
      languageSettingsScreenFollowsAppLocale,
  'English saved': languageSettingsScreenEnglishSaved,
  'Arabic saved': languageSettingsScreenArabicSaved,
  'Cold start · unsupported device locale': languageSettingsScreenColdStart,
  'Unsupported saved value · falls through':
      languageSettingsScreenUnsupportedSavedValue,
  'Compact 320x568 · layout ceiling': languageSettingsScreenCompactCeiling,
};

/// [previewCanvas] with the real font faces installed on the theme, and an
/// optional text scaler.
Widget _languageSettingsScreenCanvas(
  Widget Function() preview,
  Locale locale, {
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: jeebPreviewHost(preview()),
  );
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  /// Pumps [preview] on a surface large enough to hold its pinned device box.
  Future<void> pumpOnDevice(
    WidgetTester tester,
    Widget Function() preview, {
    Size surface = _kPhoneSurface,
    Locale locale = const Locale('en'),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPreview(tester, preview, locale: locale);
  }

  /// The rendered icon inside the row with [key], or null when it has none.
  IconData? iconOf(WidgetTester tester, Key key) {
    final Finder icons = find.descendant(
      of: find.byKey(key),
      matching: find.byType(Icon),
    );
    if (icons.evaluate().isEmpty) return null;
    return tester.widget<Icon>(icons.first).icon;
  }

  testPreviewsRender(
    'LanguageSettingsScreen',
    _kPreviews,
    // The dev caption is the ONLY string that differs between these states —
    expectedText: const <String, String>{
      'Reference · follows the app locale':
          LanguageSettingsScreenCaptions.followsAppLocale,
      'English saved': LanguageSettingsScreenCaptions.englishSaved,
      'Arabic saved': LanguageSettingsScreenCaptions.arabicSaved,
      'Cold start · unsupported device locale':
          LanguageSettingsScreenCaptions.coldStart,
      'Unsupported saved value · falls through':
          LanguageSettingsScreenCaptions.unsupportedSavedValue,
      'Compact 320x568 · layout ceiling':
          LanguageSettingsScreenCaptions.compactCeiling,
    },
  );

  group('LanguageSettingsScreen previews · the tick', () {
    testWidgets('exactly one row is ticked in EVERY state and locale', (
      WidgetTester tester,
    ) async {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        for (final MapEntry<String, Widget Function()> entry
            in _kPreviews.entries) {
          await pumpOnDevice(tester, entry.value, locale: locale);
          expect(
            find.descendant(
              of: find.byKey(_list),
              matching: find.byIcon(Icons.check),
            ),
            findsOneWidget,
            reason: '${entry.key} · ${locale.languageCode}',
          );
        }
      }
    });

    testWidgets('the reference state follows the AMBIENT locale', (
      WidgetTester tester,
    ) async {
      // Nothing is persisted, so the cubit resolves to the device locale, which
      await pumpOnDevice(tester, languageSettingsScreenFollowsAppLocale);
      expect(iconOf(tester, _enRow), Icons.check);
      expect(iconOf(tester, _arRow), isNot(Icons.check));

      await pumpOnDevice(
        tester,
        languageSettingsScreenFollowsAppLocale,
        locale: const Locale('ar'),
      );
      expect(iconOf(tester, _arRow), Icons.check);
      expect(iconOf(tester, _enRow), isNot(Icons.check));
    });

    testWidgets('a saved choice PINS the tick, whatever the app locale is', (
      WidgetTester tester,
    ) async {
      // The persisted key is read before the device locale, so these two states
      await pumpOnDevice(tester, languageSettingsScreenArabicSaved);
      expect(iconOf(tester, _arRow), Icons.check);
      // …in an ENGLISH, LTR screen: the divergent reading only a dev surface
      expect(find.text('Language'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byKey(_list))),
        TextDirection.ltr,
      );

      await pumpOnDevice(
        tester,
        languageSettingsScreenEnglishSaved,
        locale: const Locale('ar'),
      );
      expect(iconOf(tester, _enRow), Icons.check);
      expect(find.text('اللغة'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byKey(_list))),
        TextDirection.rtl,
      );
    });

    testWidgets('an UNSUPPORTED saved value falls through to the device', (
      WidgetTester tester,
    ) async {
      // `_isSupported` rejects `de` and resolution continues to the device
      await pumpOnDevice(tester, languageSettingsScreenUnsupportedSavedValue);
      expect(iconOf(tester, _arRow), Icons.check);
      expect(iconOf(tester, _enRow), isNot(Icons.check));
    });

    testWidgets('the cold start is INDISTINGUISHABLE from a saved English', (
      WidgetTester tester,
    ) async {
      // Nothing persisted + an unsupported device locale resolves to the hard
      await pumpOnDevice(tester, languageSettingsScreenColdStart);
      expect(iconOf(tester, _enRow), Icons.check);
      expect(iconOf(tester, _arRow), isNot(Icons.check));
      // No third row, no "follow system" affordance —
      expect(find.byType(OmdsSettingsRow), findsNWidgets(2));
    });
  });

  group('LanguageSettingsScreen previews · the unticked row', () {
    testWidgets('renders a DISCLOSURE CHEVRON, not an empty slot', (
      WidgetTester tester,
    ) async {
      // FINDING, pinned so a fix has to come through here: `_LanguageRow` passes
      await pumpOnDevice(tester, languageSettingsScreenEnglishSaved);

      expect(tester.widget<OmdsSettingsRow>(find.byKey(_arRow)).trailing, isNull);
      expect(iconOf(tester, _arRow), Icons.chevron_right);
      // And it is a real chevron on the ticked row's counterpart only: the
      expect(
        find.descendant(of: find.byKey(_list), matching: find.byIcon(Icons.chevron_right)),
        findsOneWidget,
      );
    });

    testWidgets('and it mirrors in AR, which only makes it more convincing', (
      WidgetTester tester,
    ) async {
      await pumpOnDevice(
        tester,
        languageSettingsScreenArabicSaved,
        locale: const Locale('ar'),
      );
      // `Icons.chevron_right` is `matchTextDirection: true`, so the glyph is
      expect(iconOf(tester, _enRow), Icons.chevron_right);
      final RenderParagraph title = tester.renderObject<RenderParagraph>(
        find.text('English'),
      );
      expect(title.textDirection, TextDirection.rtl);
    });
  });

  group('LanguageSettingsScreen previews · the 320x568 ceiling', () {
    /// Pumps the ceiling card with the REAL faces and a text scaler.
    Future<void> pumpCeiling(
      WidgetTester tester, {
      double textScale = 1.0,
      Locale locale = const Locale('en'),
    }) async {
      await tester.binding.setSurfaceSize(_kCompactSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _languageSettingsScreenCanvas(
          languageSettingsScreenCompactCeiling,
          locale,
          textScale: textScale,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('nothing overflows at 100% or at 200% text, in either locale', (
      WidgetTester tester,
    ) async {
      for (final double scale in const <double>[1.0, 2.0]) {
        for (final Locale locale in const <Locale>[
          Locale('en'),
          Locale('ar'),
        ]) {
          await pumpCeiling(tester, textScale: scale, locale: locale);
          expect(
            tester.takeException(),
            isNull,
            reason: '320x568 · ${scale}x · ${locale.languageCode}',
          );
          expect(find.byKey(_list), findsOneWidget);
        }
      }
    });

    testWidgets('200% really applies, and no title wraps at 320 pt', (
      WidgetTester tester,
    ) async {
      // Nothing on this screen has a `maxLines` or an `overflow`: the
      Map<String, double> heights(WidgetTester tester) => <String, double>{
            for (final MapEntry<String, Finder> entry in _titleFinders.entries)
              if (entry.key != _kAppBarTitle)
                entry.key: tester
                    .renderObject<RenderParagraph>(entry.value)
                    .textSize
                    .height,
          };

      await pumpCeiling(tester, textScale: 1.0);
      final Map<String, double> single = heights(tester);

      await pumpCeiling(tester, textScale: 2.0);
      final Map<String, double> doubled = heights(tester);

      single.forEach((String label, double height) {
        expect(
          doubled[label]!,
          greaterThan(height * 1.5),
          reason: '$label did not scale — the 200% variant is not being applied',
        );
        expect(
          doubled[label]!,
          lessThan(height * 3),
          reason: '$label wrapped onto a second line at 200% on 320 pt',
        );
      });
    });

    testWidgets('the app-bar title STOPS scaling and the header overtakes it', (
      WidgetTester tester,
    ) async {
      // FINDING, measured with the real faces and pinned here: `AppBar` wraps
      double heightOf(WidgetTester tester, String label) => tester
          .renderObject<RenderParagraph>(_titleFinders[label]!)
          .textSize
          .height;

      await pumpCeiling(tester, textScale: 1.0);
      final double barAt100 = heightOf(tester, _kAppBarTitle);
      expect(barAt100, greaterThan(heightOf(tester, 'section header')));

      await pumpCeiling(tester, textScale: 2.0);
      final double barAt200 = heightOf(tester, _kAppBarTitle);
      // Clamped: nowhere near 2x, and still inside the 56 pt toolbar.
      expect(barAt200 / barAt100, lessThan(1.5));
      expect(barAt200, lessThanOrEqualTo(kToolbarHeight));
      expect(
        tester
            .renderObject<RenderParagraph>(_titleFinders[_kAppBarTitle]!)
            .didExceedMaxLines,
        isFalse,
      );
      // …and the relationship at 100% has inverted.
      expect(heightOf(tester, 'section header'), greaterThan(barAt200));
    });

    testWidgets('"Language" is painted TWICE, one under the other', (
      WidgetTester tester,
    ) async {
      // FINDING, pinned: the app bar's centred headline and the only section
      await pumpCeiling(tester);
      expect(find.text('Language'), findsNWidgets(2));

      await pumpCeiling(tester, locale: const Locale('ar'));
      expect(find.text('اللغة'), findsNWidgets(2));
    });
  });
}
