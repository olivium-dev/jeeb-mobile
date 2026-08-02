// Render tests for the DmOnboardingAddressField previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. The `testPreviewsRender` block is the standard
// template (see `test/previews/preview_test_harness.dart`); the specifics group
// below pins the two things these previews were written to expose — the
// label/hint type-scale gap, and the fact that the longest shipped hint does
// not fit the width the address step gives it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_address_field.dart';

import '../preview_test_harness.dart';

/// The longest hint the app ships (`dmOnboardingAddressAddressHint`).
const String _kLongestShippedHint = 'Jasmine Tower, Apartment 12B';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DmOnboardingAddressField',
    const <String, Widget Function()>{
      'State · shortest field': dmOnboardingAddressFieldState,
      'Address · longest shipped hint':
          dmOnboardingAddressFieldLongestShippedHint,
      'Long label wraps': dmOnboardingAddressFieldLongLabel,
      'Verbose hint clipped': dmOnboardingAddressFieldVerboseHint,
      'Hint missing': dmOnboardingAddressFieldNoHint,
    },
    expectedText: const <String, String>{
      'State · shortest field': 'State',
      'Address · longest shipped hint': _kLongestShippedHint,
      'Long label wraps': 'Building name, floor, and apartment number',
      'Verbose hint clipped':
          'e.g. Jasmine Tower, 3rd floor, Apartment 12B, next to the pharmacy',
      'Hint missing': 'Street',
    },
  );

  group('DmOnboardingAddressField preview specifics', () {
    testWidgets('hint outweighs its own label on the type scale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingAddressFieldLongestShippedHint);

      final Text label = tester.widget<Text>(find.text('Address'));
      final Text hint = tester.widget<Text>(find.text(_kLongestShippedHint));

      // The widget styles the external label `bodyLarge` (16); OMDS styles the
      // placeholder `headlineLarge` (32, bold). The placeholder is therefore
      // twice the size of the thing naming it — which is what makes the hint,
      // not the label, the state that breaks.
      expect(label.style?.fontSize, 16.0);
      expect(hint.style?.fontSize, 32.0);
      expect(hint.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('longest shipped hint does not fit a 390pt phone', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, dmOnboardingAddressFieldLongestShippedHint);

      final Finder hint = find.text(_kLongestShippedHint);
      final double laidOut = tester.getSize(hint).width;

      final Text widget = tester.widget<Text>(hint);
      final TextPainter painter = TextPainter(
        text: TextSpan(text: _kLongestShippedHint, style: widget.style),
        textDirection: TextDirection.ltr,
      )..layout();
      final double needed = painter.width;
      painter.dispose();

      // Not a golden: the assertion is that the string is wider than the box it
      // is painted into, so the jeeber only ever reads a prefix of the example.
      // Measured on a 390 pt phone: the field is 342 pt wide and leaves 302 pt
      // for a 32 sp bold placeholder — about 17 Latin characters against the
      // ARB entry's 28.
      expect(laidOut, lessThan(310));
      expect(needed, greaterThan(laidOut));
      expect(widget.maxLines, 1);
      expect(widget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('label hugs the leading edge in both text directions', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingAddressFieldState);
      final Rect fieldEn =
          tester.getRect(find.byType(DmOnboardingAddressField));
      expect(tester.getRect(find.text('State')).left, closeTo(fieldEn.left, 0.5));

      await pumpPreview(
        tester,
        dmOnboardingAddressFieldState,
        locale: const Locale('ar'),
      );
      final Rect fieldAr =
          tester.getRect(find.byType(DmOnboardingAddressField));
      expect(
        tester.getRect(find.text('المحافظة')).right,
        closeTo(fieldAr.right, 0.5),
      );
    });

    testWidgets('drives the same semantics identifier the step uses', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, dmOnboardingAddressFieldState);

      // The identifier the integration drivers target. Note that it sits on the
      // wrapper node, not on the focusable input node underneath it — see the
      // preview's library doc.
      expect(
        find.bySemanticsIdentifier('dm_onboarding_address_state_field'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('an empty hint still renders a full-height field', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingAddressFieldNoHint);
      final double blank = tester.getSize(find.byType(TextField)).height;

      await pumpPreview(tester, dmOnboardingAddressFieldState);
      final double hinted = tester.getSize(find.byType(TextField)).height;

      expect(blank, hinted);
    });
  });
}
