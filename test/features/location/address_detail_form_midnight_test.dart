import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
import 'package:jeeb_mobile/features/location/data/fake_address_form_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/presentation/screens/address_detail_form_screen.dart';
import 'package:omds/omds.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const SavedLocation _pinned = SavedLocation(
  id: 'addr-home',
  label: 'Home',
  latitude: 33.8886,
  longitude: 35.4955,
  category: SavedLocationCategory.home,
  address: 'Sassine Square, Ashrafieh',
);

/// The shared `wrapForTest` themes `ThemeData.light()`; these assertions read
/// Midnight inks off the widget, so the harness has to mount the real theme.
Widget _harness({SavedLocation? existing}) => MaterialApp(
  theme: AppTheme.midnight(),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: AddressDetailFormScreen(
    userId: 'u1',
    repository: const FakeAddressFormRepository(),
    existing: existing,
    addressId: existing?.id,
  ),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The board canvas. The default 800x600 test surface builds only the first
/// two lazily-built fields, which is not the layout under review.
void _boardCanvas(WidgetTester tester) {
  tester.view.physicalSize = const Size(440, 956);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('MIDNIGHT M3-29: R22\'s content field, top-end glow, still', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(existing: _pinned));
    await _settle(tester);

    final field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField).first,
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
    expect(field.animateDecor, isFalse);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, Colors.transparent);
  });

  testWidgets(
    'MIDNIGHT M3-29: field labels are band labels, NOT the orange floating '
    'Material label (OmdsTextField hard-codes colorScheme.primary)',
    (tester) async {
      _boardCanvas(tester);
      await tester.pumpWidget(_harness(existing: _pinned));
      await _settle(tester);

      // Every OmdsTextField ships hint-only; a labelText would float in
      // #D73B00 because the package overrides inputDecorationTheme.
      final fields = tester.widgetList<OmdsTextField>(
        find.byType(OmdsTextField),
      );
      expect(fields, hasLength(5));
      for (final f in fields) {
        expect(f.labelText, isNull);
        expect(f.hintText, isNotNull);
      }
      // The labels moved out to R22's band header — one per field plus the
      // map band's own.
      expect(find.byType(JeebSectionLabel), findsNWidgets(6));
      expect(find.text('LABEL'), findsOneWidget);
      expect(find.text('CASH-ON-DELIVERY PHONE'), findsOneWidget);
    },
  );

  testWidgets(
    'MIDNIGHT M3-29: the pin band states the chosen coordinate (R11 carry-in)',
    (tester) async {
      await tester.pumpWidget(_harness(existing: _pinned));
      await _settle(tester);

      expect(
        find.bySemanticsIdentifier('address_form_pin_coordinate'),
        findsOneWidget,
      );
      expect(find.text('33.8886, 35.4955'), findsOneWidget);
      // Two markers now: the band's centre pin and the coordinate row's.
      // Both are R11's danger-red, never orange.
      final glyphs = tester.widgetList<Icon>(find.byIcon(Icons.location_on));
      final scheme = AppTheme.midnight().colorScheme;
      expect(glyphs, hasLength(2));
      for (final g in glyphs) {
        expect(g.color, scheme.error);
        expect(g.color, isNot(scheme.primary));
      }
    },
  );

  testWidgets(
    'MIDNIGHT M3-29: with NO pin the band says so instead of a coordinate — '
    'the only reading a Q-021 discarded Confirm gets',
    (tester) async {
      await tester.pumpWidget(_harness());
      await _settle(tester);

      expect(find.text('Pick a location on the map'), findsOneWidget);
      expect(find.byIcon(Icons.add_location_alt), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsNothing);
    },
  );
}
