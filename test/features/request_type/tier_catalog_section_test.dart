import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_price_meter.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_row.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// The redesigned rows read `jeebText` / `jeebRoles` / `JeebSemanticColors`
/// off the theme, so the harness installs the real [AppTheme] rather than
/// `wrapForTest`'s bare `ThemeData.light()`.
Widget _harness(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: AppTheme.light(),
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

/// redesign-2026-08 · screen 08 — the tier catalog rendered as the picker
/// section of `/request-type`. The frozen `request_type_<tier>_radio`
/// identifiers and the "nothing is pre-selected" rule are covered by
/// `request_type_deliberate_selection_test.dart`; this file pins what 08 adds:
/// the catalog row variant, the relative price meter, the SLA / vehicle lines
/// and the pricing note.
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

  testWidgets('renders five catalog rows with the board price levels', (
    tester,
  ) async {
    await pumpScreen(tester);

    final rows = tester.widgetList<JeebTierRow>(find.byType(JeebTierRow));
    expect(rows.length, 5);
    for (final row in rows) {
      expect(row.variant, JeebTierRowVariant.catalog);
    }
    // Flash 4 · Express 3 · Standard 2 · On-the-Way 2 · Eco 1 (08 tpl 426-495).
    expect(rows.map((r) => r.priceLevel).toList(), <int>[4, 3, 2, 2, 1]);
    expect(find.byType(JeebPriceMeter), findsNWidgets(5));
    // The vehicle glyph ships on all five rows (C7), not on Flash alone.
    expect(rows.every((r) => r.metaIcon != null), isTrue);
  });

  testWidgets('SLA chips render from the catalog data, not board literals', (
    tester,
  ) async {
    await pumpScreen(tester);

    final rows = tester.widgetList<JeebTierRow>(find.byType(JeebTierRow));
    // FakeTierRepository: flash 60min, express 180, standard 240, onTheWay
    // null, eco 1440. A null SLA is the opportunistic tier — "Flexible".
    expect(rows.first.slaLabel, '≤ 1 hr');
    expect(rows.elementAt(3).slaLabel, 'Flexible');
    // Only the numeric chips are LTR-isolated; the prose one follows the
    // ambient direction.
    expect(rows.first.slaForceLtr, isTrue);
    expect(rows.elementAt(3).slaForceLtr, isFalse);
    for (final row in rows) {
      expect(row.metaLabel, isNotEmpty);
    }
  });

  testWidgets('exactly one row carries the recommended badge', (tester) async {
    await pumpScreen(tester);

    final rows = tester.widgetList<JeebTierRow>(find.byType(JeebTierRow));
    // Which tier it is follows the catalog flag, not a hardcoded index.
    expect(rows.where((r) => r.badge != null).length, 1);
  });

  testWidgets('the pricing note closes the catalog', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(JeebInfoNote), findsOneWidget);
    expect(
      find.text(
        'Jeebers set the price — you compare real offers and pick one. '
        'No fixed prices.',
      ),
      findsOneWidget,
    );
    expect(
      find.text("Same errand, five speeds — pick what it's worth."),
      findsOneWidget,
    );
  });

  testWidgets('selection is a fill swap reported as selected', (tester) async {
    await pumpScreen(tester);

    final eco = find.bySemanticsIdentifier('request_type_eco_radio');
    expect(
      tester.getSemantics(eco).flagsCollection.isSelected,
      Tristate.isFalse,
    );
    await tester.tap(eco);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(eco).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .widgetList<JeebTierRow>(find.byType(JeebTierRow))
          .where((r) => r.selected)
          .length,
      1,
    );
  });

  testWidgets('renders in Arabic RTL without losing the SLA chips', (
    tester,
  ) async {
    await pumpScreen(tester, locale: const Locale('ar'));

    expect(tester.takeException(), isNull);
    final rows = tester.widgetList<JeebTierRow>(find.byType(JeebTierRow));
    expect(rows.length, 5);
    // The band is localized but the latin numeral stays LTR-isolated inside
    // the chip (the kit wraps it; here we only pin that the copy survives).
    expect(rows.first.slaLabel, '≤ 1 ساعة');
    expect(find.text('≤ 1 ساعة'), findsOneWidget);
  });
}
