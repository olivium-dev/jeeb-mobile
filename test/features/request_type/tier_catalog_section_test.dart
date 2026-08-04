import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_price_meter.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_row.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// The redesigned rows read `jeebText` / `jeebRoles` / `JeebSemanticColors`
/// off the theme, so the harness installs the real [AppTheme].
Widget _harness(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// MIDNIGHT · R9 — the tier picker section of `/request-type`.
///
/// doc-13 P0-3/P0-4 rule the section back to a compact radio list: no subtitle
/// band, no pricing note, no comparison-table anatomy, `Most picked` on
/// Standard and that tier lit on first paint.
void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      _harness(
        const RequestTypeScreen(repository: FakeTierRepository()),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders five compact radio rows, one per tier', (tester) async {
    await pumpScreen(tester);

    final rows = tester.widgetList<JeebTierRow>(find.byType(JeebTierRow));
    expect(rows.length, 5);
    for (final row in rows) {
      expect(row.variant, JeebTierRowVariant.compact);
      // The one-line summary is the compact row's whole body.
      expect(row.summaryText, isNotEmpty);
    }
  });

  testWidgets('the comparison-table anatomy is gone', (tester) async {
    await pumpScreen(tester);

    // P0-3: 08's price meter, its subtitle band and its pricing note all
    // belong to a screen the app does not draw.
    expect(find.byType(JeebPriceMeter), findsNothing);
    expect(find.byType(JeebInfoNote), findsNothing);
    expect(
      find.text("Same errand, five speeds — pick what it's worth."),
      findsNothing,
    );
    expect(
      find.text(
        'Jeebers set the price — you compare real offers and pick one. '
        'No fixed prices.',
      ),
      findsNothing,
    );
  });

  testWidgets('Most picked badges Standard alone', (tester) async {
    await pumpScreen(tester);

    final rows = tester.widgetList<JeebTierRow>(find.byType(JeebTierRow));
    final badged = rows.where((r) => r.badge != null);
    expect(badged.length, 1);
    expect(badged.single.badge, 'Most picked');
    // Which tier it is follows the catalog flag, not a hardcoded index.
    final standard = FakeTierRepository.defaultCatalog
        .where((Tier t) => t.recommended)
        .single;
    expect(standard.id, TierId.standard);
    expect(badged.single.title, 'Standard');
  });

  testWidgets('Standard is lit on first paint', (tester) async {
    await pumpScreen(tester);

    final rows = tester.widgetList<JeebTierRow>(find.byType(JeebTierRow));
    expect(rows.where((r) => r.selected).single.title, 'Standard');
    expect(
      tester
          .getSemantics(find.bySemanticsIdentifier('request_type_standard_radio'))
          .flagsCollection
          .isChecked,
      CheckedState.isTrue,
    );
  });

  testWidgets('selection is a radio move reported as checked', (tester) async {
    await pumpScreen(tester);

    final eco = find.bySemanticsIdentifier('request_type_eco_radio');
    expect(tester.getSemantics(eco).flagsCollection.isChecked, CheckedState.isFalse);
    await tester.tap(eco);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(eco).flagsCollection.isChecked, CheckedState.isTrue);
    expect(
      tester
          .widgetList<JeebTierRow>(find.byType(JeebTierRow))
          .where((r) => r.selected)
          .length,
      1,
    );
  });

  testWidgets('renders in Arabic RTL without losing a row', (tester) async {
    await pumpScreen(tester, locale: const Locale('ar'));

    expect(tester.takeException(), isNull);
    expect(find.byType(JeebTierRow), findsNWidgets(5));
    expect(find.text('فوري'), findsOneWidget);
  });
}
