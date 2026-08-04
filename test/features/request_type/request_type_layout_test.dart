import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_row.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_location_row.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';

/// redesign-2026-08 · 07 + 08 — geometry, not content.
///
/// The board is drawn on a 440x956 viewport where the catalog never reaches the
/// docked CTA. The devices this ships to are 360dp-class, where it does — and
/// the two apply reports could only guess at that, because a widget test with
/// no real font measures every string with the fallback face and manufactures
/// horizontal overflows that do not exist on device. So this file loads the
/// **shipped Inter** first and then asserts what the phone actually does.
void main() {
  setUpAll(loadInterTestFont);

  Widget harness(Widget child, {Locale locale = const Locale('en'), double textScale = 1}) =>
      MaterialApp(
        theme: withGoldenTestFonts(AppTheme.light()),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, inner) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: inner!,
        ),
        home: child,
      );

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    Locale locale = const Locale('en'),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      harness(
        const RequestTypeScreen(repository: FakeTierRepository()),
        locale: locale,
        textScale: textScale,
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final scenario in const <({String name, Size size, Locale locale})>[
    (name: 'phone 360x780', size: Size(360, 780), locale: Locale('en')),
    (name: 'phone 360x780 ar', size: Size(360, 780), locale: Locale('ar')),
    (name: 'board 440x956', size: Size(440, 956), locale: Locale('en')),
  ]) {
    testWidgets('${scenario.name} lays out the catalog without overflow', (
      tester,
    ) async {
      await pump(tester, scenario.size, locale: scenario.locale);

      expect(find.byType(JeebTierRow), findsNWidgets(5));
      // A RenderFlex overflow surfaces here as a thrown FlutterError; the
      // yellow-and-black stripe is what the owner would see on the device.
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the Deliver-to card clears the docked CTA on a 360dp phone', (
    tester,
  ) async {
    await pump(tester, const Size(360, 780));

    final change =
        find.bySemanticsIdentifier('request_type_change_location_button');
    final viewport = tester.getRect(find.byType(CustomScrollView));

    // The section sits below the fold on a short phone; it must scroll into
    // view rather than being clipped away behind the footer.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.getRect(change).bottom, lessThanOrEqualTo(viewport.bottom));
    // Bottom body padding (`_bodyPadding`): the card must not end flush
    // against the CTA at the end of the scroll.
    final card = tester.getRect(find.byType(RequestLocationRow));
    expect(viewport.bottom - card.bottom, greaterThanOrEqualTo(Spacing.large));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board viewport keeps the deliberate empty tail', (
    tester,
  ) async {
    await pump(tester, const Size(440, 956));

    final viewport = tester.getRect(find.byType(CustomScrollView));
    final card = tester.getRect(
      find.bySemanticsIdentifier('request_type_current_location_label'),
    );
    // `flex:1` on the board (`tpl 399`): the tail of a tall viewport is real
    // emptiness, so the content must not run into the footer.
    expect(card.bottom, lessThan(viewport.bottom - 40));
  });
}
