import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/branded_splash.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double hi = math.max(a.computeLuminance(), b.computeLuminance());
  final double lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) =>
      _arbByTag.containsKey(locale.languageCode);

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

Widget _harness({Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const BrandedSplash(),
  );
}

void main() {
  setUpAll(_loadArbs);

  testWidgets('renders the bundled logo SVG and localized EN tagline',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Delivery App'), findsOneWidget);
  });

  // Regression guard for the "plain navy square" splash. The widget being
  test('splash logo is non-empty white + orange artwork (not a navy square)', () {
    final svg = File('assets/brand/jeeb_logo.svg').readAsStringSync();

    // Real drawable geometry — at least one filled <path>.
    final fillMatches =
        RegExp(r'fill="([^"]+)"', caseSensitive: false).allMatches(svg);
    final fills = fillMatches
        .map((m) => m.group(1)!.toLowerCase())
        .where((f) => f != 'none')
        .toSet();
    expect(
      RegExp(r'<path').allMatches(svg).length,
      greaterThan(0),
      reason: 'logo SVG has no <path> geometry — would render as a blank/navy square',
    );

    // White glyphs (read on navy) + orange brand accent.
    expect(
      fills.any((f) => f == 'white' || f == '#fff' || f == '#ffffff'),
      isTrue,
      reason: 'wordmark must contain white fills that read on the navy background',
    );
    expect(
      fills.contains('#d73b00'),
      isTrue,
      reason: 'wordmark must contain the orange brand accent fill',
    );

    // The logo must NOT be filled the same navy as the splash background —
    final navyVariants = {'#0b1351', '#0b1351ff'};
    expect(
      fills.intersection(navyVariants),
      isEmpty,
      reason: 'logo fills must contrast with the navy splash background',
    );
  });

  // Confirms the splash actually draws the wordmark asset on the navy field,
  testWidgets('BrandedSplash draws the wordmark asset over the navy background',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    final svgPicture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      svgPicture.bytesLoader,
      isA<SvgAssetLoader>().having(
        (l) => l.assetName,
        'assetName',
        'assets/brand/jeeb_logo.svg',
      ),
      reason: 'splash must draw the brand wordmark asset, not a different drawable',
    );

    // L12/3b: the splash mounts the ratified §8 field, not a flat slab.
    final field = tester.widget<JeebMidnightField>(
      find.descendant(
        of: find.byType(BrandedSplash),
        matching: find.byType(JeebMidnightField),
      ),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.animateDecor, isFalse);
    expect(
      field.glowColor,
      Colors.transparent,
      reason: 'the splash has no tile, so it spends no orange budget',
    );
  });

  testWidgets('exposes Semantics identifiers for QA targeting',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    for (final id in const ['_splash_screen', '_splash_logo', '_splash_tagline']) {
      expect(
        find.bySemanticsIdentifier(id),
        findsOneWidget,
        reason: 'missing Semantics(identifier: "$id")',
      );
    }
  });

  // L12: the tagline used to ink `onSecondary` (page navy) on a
  // `secondaryContainer` slab — 1.17 : 1, effectively invisible.
  testWidgets('the tagline ink clears AA against every navy the field paints',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    final ink = tester
        .widget<Text>(find.text('Delivery App'))
        .style!
        .color!;
    final scheme = AppTheme.midnight().colorScheme;
    expect(ink, scheme.onSecondaryContainer);

    for (final navy in const <Color>[
      JeebMidnight.page,
      JeebMidnight.surface,
      JeebMidnight.surfaceHigh,
    ]) {
      expect(
        _contrast(ink, navy),
        greaterThanOrEqualTo(4.5),
        reason: 'tagline must read on every stop of the §8 base wash',
      );
    }

    // Discrimination: the reverted value fails the same assertion.
    expect(_contrast(scheme.onSecondary, JeebMidnight.surfaceHigh),
        lessThan(1.5));
  });

  testWidgets('both system bands take the Midnight overlay, not raw .light',
      (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(BrandedSplash),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value, AppTheme.systemOverlayStyle);
    expect(region.value.systemNavigationBarColor, JeebMidnight.page);
    expect(
      region.value.systemNavigationBarColor,
      isNot(SystemUiOverlayStyle.light.systemNavigationBarColor),
    );
  });

  testWidgets('mirrors to RTL and shows the Arabic tagline in ar locale',
      (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await tester.pump();

    expect(find.text('تطبيق التوصيل'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(BrandedSplash)));
    expect(dir, TextDirection.rtl);
  });
}
