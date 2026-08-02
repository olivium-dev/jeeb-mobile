// Render tests for the BottomSheetSafeArea previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT title, because a
// suite that only asked "did something render?" would pass on five copies of
// the same sheet.
//
// This widget also needs a second kind of test the other preview suites do not.
// Half of what it computes — the nav-bar inset — is read from the raw
// FlutterView, which NO widget can substitute, so the canvas always renders it
// as zero. `tester.view` is the only place that half can be seeded, so the
// geometry group below is the only proof that these previews are reviewing a
// widget that reserves anything at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/layout/bottom_inset.dart';
import 'package:jeeb_mobile/previews/core/bottom_sheet_safe_area_preview.dart';

import '../preview_test_harness.dart';

/// Simulated soft-button navigation bar inset — the same 48 dp
/// `test/core/layout/bottom_inset_test.dart` uses for the 3-button case.
const double _kNavBarInsetDp = 48;

/// The keyboard height the keyboard-open previews seed.
const double _kKeyboardDp = 300;

/// Seeds the FlutterView's nav-bar inset, where the helper reads it from.
///
/// `padding` is seeded alongside `viewPadding` because the preview host wraps
/// every preview in a [SafeArea], which pads from `MediaQuery.padding`; seeding
/// only one of the two would model a device that does not exist.
void _seedNavBar(WidgetTester tester, {double dp = _kNavBarInsetDp}) {
  final double dpr = tester.view.devicePixelRatio;
  tester.view.viewPadding = FakeViewPadding(bottom: dp * dpr);
  tester.view.padding = FakeViewPadding(bottom: dp * dpr);
  addTearDown(tester.view.reset);
}

/// The bottom padding [BottomSheetSafeArea] resolved, in logical pixels.
double _reservedInset(WidgetTester tester) {
  final Padding padding = tester.widget<Padding>(
    find
        .descendant(
          of: find.byType(BottomSheetSafeArea),
          matching: find.byType(Padding),
        )
        .first,
  );
  return padding.padding.resolve(TextDirection.ltr).bottom;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'BottomSheetSafeArea',
    const <String, Widget Function()>{
      'Keyboard closed': bottomSheetSafeAreaKeyboardClosed,
      'Keyboard open': bottomSheetSafeAreaKeyboardOpen,
      'Tall body': bottomSheetSafeAreaTallBody,
      'Modal route': bottomSheetSafeAreaInModalRoute,
      'Modal route · keyboard open':
          bottomSheetSafeAreaInModalRouteWithKeyboard,
    },
    expectedText: const <String, String>{
      'Keyboard closed': 'Sheet CTA, keyboard closed',
      'Keyboard open': 'Sheet CTA, keyboard open',
      'Tall body': 'Tall sheet body',
      'Modal route': 'Inside a modal sheet',
      'Modal route · keyboard open': 'Modal sheet, keyboard open',
    },
  );

  group('BottomSheetSafeArea preview geometry', () {
    testWidgets('keyboard-closed preview still reserves the nav-bar inset', (
      WidgetTester tester,
    ) async {
      _seedNavBar(tester);
      await pumpPreview(tester, bottomSheetSafeAreaKeyboardClosed);

      // The exact regression the widget exists for: viewInsets.bottom is 0 here,
      // so a keyboard-only padding would reserve nothing and hand the CTA to the
      // soft buttons.
      expect(_reservedInset(tester), _kNavBarInsetDp);
    });

    testWidgets('keyboard-open preview sums keyboard and nav bar', (
      WidgetTester tester,
    ) async {
      _seedNavBar(tester);
      await pumpPreview(tester, bottomSheetSafeAreaKeyboardOpen);

      expect(_reservedInset(tester), _kKeyboardDp + _kNavBarInsetDp);
    });

    testWidgets('the two keyboard states are not the same rendering', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, bottomSheetSafeAreaKeyboardClosed);
      final double closed = _reservedInset(tester);

      await pumpPreview(tester, bottomSheetSafeAreaKeyboardOpen);
      final double open = _reservedInset(tester);

      expect(closed, 0);
      expect(open, _kKeyboardDp);
    });

    testWidgets('the inset readout reports what the widget computed', (
      WidgetTester tester,
    ) async {
      _seedNavBar(tester);
      await pumpPreview(tester, bottomSheetSafeAreaKeyboardOpen);

      // Not decoration: this line is how a reviewer in the canvas tells a gap
      // caused by the keyboard from one caused by the nav bar.
      expect(
        find.text('reserved 348 dp = keyboard 300 + nav bar 48'),
        findsOneWidget,
      );
    });

    testWidgets('nested inside a SafeArea, the nav-bar inset is reserved TWICE',
        (WidgetTester tester) async {
      _seedNavBar(tester);
      await pumpPreview(tester, bottomSheetSafeAreaKeyboardClosed);

      // jeebPreviewHost wraps every preview in Scaffold(body: SafeArea(...)),
      // which already consumed the 48 dp bottom padding. sheetBottomInset reads
      // the raw FlutterView, so it cannot see that and adds 48 again: the CTA
      // ends up ~96 dp + the body's own 16 dp padding clear of the screen edge.
      // Correct for a real sheet (nothing above it consumes the padding), a
      // double pad anywhere else — unlike scrollBodyBottomInset, which reads
      // MediaQuery and is documented as double-pad safe.
      final double screenBottom = tester.getRect(find.byType(Scaffold)).bottom;
      final double ctaBottom = tester.getRect(find.text('Apply')).bottom;

      expect(screenBottom - ctaBottom, greaterThan(2 * _kNavBarInsetDp));
    });
  });

  group('BottomSheetSafeArea preview specifics', () {
    testWidgets('the modal previews use the real bottom-sheet route', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, bottomSheetSafeAreaInModalRoute);

      // Pushed through showModalBottomSheet, not hand-placed: the widget's whole
      // reason to exist is this framing, where no ancestor SafeArea reserves the
      // nav-bar inset for the body.
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('the bare previews carry no bottom-sheet frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, bottomSheetSafeAreaKeyboardClosed);

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('the keyboard inset survives the modal route', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, bottomSheetSafeAreaInModalRouteWithKeyboard);

      // The half of the extension's contract that only this preview covers:
      // whatever showModalBottomSheet does to the padding, viewInsets is
      // propagated into the sheet intact, so the CTA still clears the keyboard.
      expect(_reservedInset(tester), _kKeyboardDp);
    });
  });
}
