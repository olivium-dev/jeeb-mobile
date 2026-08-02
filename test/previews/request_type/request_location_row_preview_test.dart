// Render tests for the RequestLocationRow previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The specifics group below pins the two invariants the previews exist to
// watch: the row mirrors under RTL (it is an Arabic-first product), and a long
// label truncates instead of wrapping the row taller.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/previews/request_type/request_location_row_preview.dart';

import '../preview_test_harness.dart';

/// The longest-plausible-address fixture, repeated here so the test fails loudly
/// if the preview's string is edited without updating the expectation.
const String _longAddress =
    'Beirut Central District, Bloc B, Building 27, Floor 4, Apartment 12';

/// `requestTypeCurrentLocation` / `requestTypeChangeLocation` in `app_ar.arb`.
const String _arCurrentLocation = 'الموقع الحالي';

/// Pumps at true phone width so the label actually competes with the action for
/// space — the default 800pt test surface is wide enough to hide both bugs.
Future<void> pumpAtPhoneWidth(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpPreview(tester, preview, locale: locale);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RequestLocationRow',
    const <String, Widget Function()>{
      'Localized default': requestLocationRowDefault,
      'Resolved address': requestLocationRowResolvedAddress,
      'Long address': requestLocationRowLongAddress,
      'Long action label': requestLocationRowLongAction,
      'Unbreakable token': requestLocationRowUnbreakableToken,
    },
    expectedText: const <String, String>{
      'Localized default': 'Current Location',
      'Resolved address': 'Hamra St, Beirut',
      'Long address': _longAddress,
      'Long action label': 'Change pickup location',
      'Unbreakable token': '8G4Q+X9R,BeirutCentralDistrict,Lebanon',
    },
  );

  group('RequestLocationRow preview specifics', () {
    testWidgets('default preview localizes from the ARB, not from hardcoded '
        'English', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        requestLocationRowDefault,
        locale: const Locale('ar'),
      );

      expect(find.text(_arCurrentLocation), findsOneWidget);
      expect(find.text('Current Location'), findsNothing);
    });

    testWidgets('mirrors under RTL: label trails the action, chevron flips', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, requestLocationRowResolvedAddress);
      final Rect enLabel = tester.getRect(find.text('Hamra St, Beirut'));
      final Rect enAction = tester.getRect(find.byType(InkWell));
      expect(
        enLabel.right,
        lessThan(enAction.left),
        reason: 'LTR: the current-location label sits before the action.',
      );
      expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.chevron_right);

      await pumpAtPhoneWidth(
        tester,
        requestLocationRowResolvedAddress,
        locale: const Locale('ar'),
      );
      final Rect arLabel = tester.getRect(find.text('Hamra St, Beirut'));
      final Rect arAction = tester.getRect(find.byType(InkWell));
      expect(
        arLabel.left,
        greaterThan(arAction.right),
        reason: 'RTL: the row must mirror — label on the right, action on the '
            'left. A hardcoded EdgeInsets.only(left:) would break this.',
      );
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        Icons.chevron_left,
        reason: 'Icon does not auto-mirror; DirectionalIcons.disclosure must '
            'swap the glyph under RTL.',
      );
    });

    testWidgets('a long label truncates to one line instead of growing the row',
        (WidgetTester tester) async {
      await pumpAtPhoneWidth(tester, requestLocationRowDefault);
      final double oneLine = tester.getSize(find.text('Current Location')).height;

      await pumpAtPhoneWidth(tester, requestLocationRowLongAddress);
      expect(
        tester.getSize(find.text(_longAddress)).height,
        oneLine,
        reason: '_CurrentLabel has overflow: ellipsis but no maxLines. If this '
            'ever wraps, the row grows and pushes the rest of the '
            'Request-type screen down.',
      );

      await pumpAtPhoneWidth(tester, requestLocationRowUnbreakableToken);
      expect(
        tester
            .getSize(find.text('8G4Q+X9R,BeirutCentralDistrict,Lebanon'))
            .height,
        oneLine,
        reason: 'A token with no break opportunity cannot wrap, so it must '
            'ellipsize rather than paint past the trailing edge.',
      );
    });

    testWidgets('the action keeps both semantics identifiers addressable', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, requestLocationRowDefault);

      expect(
        find.bySemanticsIdentifier('request_type_current_location_label'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('request_type_change_location_button'),
        findsOneWidget,
        reason: 'Semantics(explicitChildNodes: true) is what keeps the inner '
            'button id from being merged away — previews must not regress it.',
      );
    });
  });
}
