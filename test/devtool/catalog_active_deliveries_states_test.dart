// The active-delivery CARD had no catalog coverage: the only banner state
// seeded 2 deliveries, which trips the disclosure threshold and renders a
// summary row with zero cards. These pin the 1-delivery state that fixes it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_accent_frame_card.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/sync_app_localizations.dart';

void main() {
  final CatalogEntry entry = kScreenCatalog.singleWhere(
    (CatalogEntry e) => e.feature == 'jeeber_active_deliveries',
  );

  Future<void> pumpState(WidgetTester tester, CatalogState state) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: state.builder),
      ),
    );
    await tester.pumpAndSettle();
  }

  CatalogState stateWhere(bool Function(String label) match) =>
      entry.states.singleWhere((CatalogState s) => match(s.label));

  group('jeeber_active_deliveries catalog states', () {
    testWidgets('a 1-delivery state exists and renders the card itself', (
      WidgetTester tester,
    ) async {
      await pumpState(tester, stateWhere((String l) => l.startsWith('One ')));

      final Finder cards = find.byType(JeebAccentFrameCard);
      expect(
        cards,
        findsOneWidget,
        reason: 'one delivery is under the threshold, so it renders expanded',
      );
      expect(
        tester.widget<JeebAccentFrameCard>(cards).fill,
        JeebAccentFrameFill.accentTint,
        reason: 'the accent-tint fill rung is the treatment being captured',
      );
      // The three elements the disclosure row was hiding.
      expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_active_delivery_manage_delivery-9003'),
        findsOneWidget,
      );
      expect(find.textContaining('Badaro'), findsOneWidget);
    });

    testWidgets('the pre-existing 2-delivery state still renders ZERO cards', (
      WidgetTester tester,
    ) async {
      await pumpState(
        tester,
        stateWhere((String l) => l.startsWith('Populated')),
      );

      expect(
        find.byType(JeebAccentFrameCard),
        findsNothing,
        reason: 'this is the gap: 2 collapses to a disclosure row, no cards',
      );
      expect(
        find.bySemanticsIdentifier('jeeber_active_deliveries_view_all'),
        findsOneWidget,
      );
    });

    testWidgets('the new state is APPENDED — older capture indices hold', (
      WidgetTester tester,
    ) async {
      expect(entry.states.first.label, startsWith('Populated'));
      expect(entry.states[1].label, startsWith('Empty'));
      expect(entry.states.last.label, startsWith('One '));
    });
  });
}
