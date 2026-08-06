import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/branded_splash.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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

Widget _harness({
  Locale locale = const Locale('en'),
  bool disableAnimations = false,
}) {
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
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: const BrandedSplash(),
  );
}

void main() {
  setUpAll(_loadArbs);

  testWidgets('renders only the bundled logo on the native splash field', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Delivery App'), findsNothing);
  });

  testWidgets('sizes the logo responsively without crowding compact phones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpWidget(_harness(disableAnimations: true));
    await tester.pump();
    expect(tester.widget<SvgPicture>(find.byType(SvgPicture)).width, 152);

    tester.view.physicalSize = const Size(834, 1194);
    await tester.pumpWidget(_harness(disableAnimations: true));
    await tester.pump();
    expect(tester.widget<SvgPicture>(find.byType(SvgPicture)).width, 184);
  });

  testWidgets('logo settles into place and honours reduced motion', (
    tester,
  ) async {
    Finder motion(Type type) => find.descendant(
      of: find.bySemanticsIdentifier('_splash_logo'),
      matching: find.byType(type),
    );

    await tester.pumpWidget(_harness());
    await tester.pump();
    expect(
      tester.widget<FadeTransition>(motion(FadeTransition)).opacity.value,
      1,
    );
    expect(
      tester.widget<ScaleTransition>(motion(ScaleTransition)).scale.value,
      1,
    );

    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.widget<FadeTransition>(motion(FadeTransition)).opacity.value,
      lessThan(0.9),
    );
    expect(
      tester.widget<ScaleTransition>(motion(ScaleTransition)).scale.value,
      greaterThan(1.06),
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester.widget<FadeTransition>(motion(FadeTransition)).opacity.value,
      1,
    );
    expect(
      tester.widget<ScaleTransition>(motion(ScaleTransition)).scale.value,
      1,
    );

    await tester.pumpWidget(_harness(disableAnimations: true));
    await tester.pump();
    expect(
      tester.widget<FadeTransition>(motion(FadeTransition)).opacity.value,
      1,
    );
    expect(
      tester.widget<ScaleTransition>(motion(ScaleTransition)).scale.value,
      1,
    );
  });

  // Regression guard for the "plain navy square" splash. The widget being
  test('splash logo is non-empty white + orange artwork (not a navy square)', () {
    final svg = File('assets/brand/jeeb_logo.svg').readAsStringSync();

    // Real drawable geometry — at least one filled <path>.
    final fillMatches = RegExp(
      r'fill="([^"]+)"',
      caseSensitive: false,
    ).allMatches(svg);
    final fills = fillMatches
        .map((m) => m.group(1)!.toLowerCase())
        .where((f) => f != 'none')
        .toSet();
    expect(
      RegExp(r'<path').allMatches(svg).length,
      greaterThan(0),
      reason:
          'logo SVG has no <path> geometry — would render as a blank/navy square',
    );

    // White glyphs (read on navy) + orange brand accent.
    expect(
      fills.any((f) => f == 'white' || f == '#fff' || f == '#ffffff'),
      isTrue,
      reason:
          'wordmark must contain white fills that read on the navy background',
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
  testWidgets('BrandedSplash draws the wordmark asset over the navy background', (
    tester,
  ) async {
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
      reason:
          'splash must draw the brand wordmark asset, not a different drawable',
    );

    final field = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(BrandedSplash),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(
      field.color,
      JeebMidnight.surface,
      reason: 'Flutter must continue the exact flat navy Android launch field',
    );
  });

  testWidgets('exposes Semantics identifiers for QA targeting', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pump();

    for (final id in const ['_splash_screen', '_splash_logo']) {
      expect(
        find.bySemanticsIdentifier(id),
        findsOneWidget,
        reason: 'missing Semantics(identifier: "$id")',
      );
    }
  });

  testWidgets('both system bands take the Midnight overlay, not raw .light', (
    tester,
  ) async {
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

  testWidgets('preserves RTL locale direction without changing the artwork', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(BrandedSplash)));
    expect(dir, TextDirection.rtl);
  });
}
