// Render tests for the GpsDeniedState previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`: every preview builds in both
// locales, and each one is pinned to a string only IT renders.
//
// The pinned strings are the previews' own scenario captions rather than
// product copy, and that is forced by the widget: [GpsDeniedState] takes no
// content at all — three ARB strings, one optional callback — so all five
// states render identical copy. A suite that pinned the title would pass on
// five copies of the same preview. `every state renders the shipped copy`
// below covers the other half, that the captions really are attached to this
// widget.
//
// Below that, the assertions the canvas can only show a human: that the wired
// CTA is live and the unwired one is a dead end, that the copy localizes, and
// that the widget overflows every host shorter than its content because it has
// no scroll view to absorb one.
//
// One caveat on the overflow numbers. `flutter test` substitutes the
// `FlutterTest` font, whose glyphs are wider than the shipped one's, so the
// content wraps to more lines here than on a device and the *thresholds* below
// are more pessimistic than production. The claim that does NOT depend on the
// font is the structural one — see `nothing here scrolls`: there is no
// [Scrollable] in the subtree, so any shortfall, at any font, is paid in
// overflow rather than in scrolling.

// `Tristate` is a dart:ui type that `package:flutter/semantics.dart` does not
// re-export; it is what `SemanticsFlags.isEnabled` actually returns.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/presentation/widgets/gps_denied_state.dart';
import 'package:jeeb_mobile/previews/location/gps_denied_state_preview.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Full phone slot · CTA wired': gpsDeniedStateWiredCta,
  'Default constructor · CTA dead': gpsDeniedStateNoCallback,
  'Compact 320pt phone': gpsDeniedStateCompactPhone,
  'Short map card (200pt)': gpsDeniedStateShortCard,
  'Landscape phone (740×360)': gpsDeniedStateLandscape,
};

/// The single [Column] inside the widget — its size IS the height the content
/// demands of whatever slot it is dropped into.
final Finder _content = find.descendant(
  of: find.byType(GpsDeniedState),
  matching: find.byType(Column),
);

final Finder _cta = find.text('Open Settings');

/// The tappable core `OmdsPrimaryButton` builds for the CTA.
final Finder _ctaGesture = find
    .descendant(
      of: find.byType(GpsDeniedState),
      matching: find.byType(GestureDetector),
    )
    .first;

/// Pumps [preview] into a real device box instead of the 800x600 test surface,
/// optionally at a raised text scale.
///
/// Every geometry assertion here needs this: the previews leave HEIGHT to the
/// canvas box declared in the annotation, so a test that used the default
/// surface would measure a box no state actually declares.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget Function() preview, {
  required Size size,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'GpsDeniedState',
    _previews,
    expectedText: const <String, String>{
      'Full phone slot · CTA wired': 'Full phone slot · CTA wired',
      'Default constructor · CTA dead': 'Default constructor · CTA dead',
      'Compact 320pt phone': 'Compact 320pt phone',
      'Short map card (200pt)': 'Short map card (200pt)',
      'Landscape phone (740×360)': 'Landscape phone (740×360)',
    },
  );

  group('GpsDeniedState preview wiring', () {
    testWidgets('every state renders the shipped ARB copy', (
      WidgetTester tester,
    ) async {
      // The widget takes no copy arguments, so this is what AC4 says today. If
      // someone edits the three `captureLocationGpsDenied*` keys and not this
      // test, this is what says so.
      await pumpPreview(tester, gpsDeniedStateWiredCta);

      expect(find.text('Location access required'), findsOneWidget);
      expect(
        find.text('Grant location permission to pin your drop-off point.'),
        findsOneWidget,
      );
      expect(_cta, findsOneWidget);
    });

    testWidgets('the wired CTA is really live', (WidgetTester tester) async {
      // A preview wired to `() {}` looks identical to one wired to nothing at
      // all; the tally is what tells the two apart in the canvas.
      await pumpPreview(tester, gpsDeniedStateWiredCta);
      expect(find.text('settings opened 0'), findsOneWidget);

      await tester.tap(_cta);
      await tester.pumpAndSettle();

      expect(find.text('settings opened 1'), findsOneWidget);
    });

    testWidgets('the default constructor ships a CTA that cannot be tapped', (
      WidgetTester tester,
    ) async {
      // `isEnabled: onOpenSettings != null` — so `const GpsDeniedState()` is a
      // dead end: the copy tells the user to grant permission and the only
      // control on the surface swallows the tap. No exception, no feedback,
      // nothing on screen to say why.
      await pumpPreview(tester, gpsDeniedStateNoCallback);
      expect(_cta, findsOneWidget);

      await tester.tap(_cta);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('settings opened'), findsNothing);
    });
  });

  group('GpsDeniedState preview a11y', () {
    testWidgets('the CTA is tappable but carries no button role', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than in a tearDown: the end-of-test handle
      // verification runs BEFORE tearDowns and fails on a live handle.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, gpsDeniedStateWiredCta);

      final SemanticsData data =
          tester.getSemantics(_ctaGesture).getSemanticsData();

      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, 'Open Settings');

      // The gap. `OmdsPrimaryButton` is a bare [GestureDetector], and unlike
      // `CaptureLocationScreen`'s own pin CTA — which wraps it in
      // `Semantics(identifier: …, button: true)` — this widget wraps it in
      // nothing. A screen reader announces "Open Settings" with no role and no
      // hint that it can be activated, on a screen whose entire purpose is to
      // get the user to activate it.
      expect(data.flagsCollection.isButton, isFalse);

      handle.dispose();
    });

    testWidgets('the disabled CTA exposes no tap action either', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, gpsDeniedStateNoCallback);

      final SemanticsData data =
          tester.getSemantics(_ctaGesture).getSemanticsData();

      // Not merely inert to touch: with `onTap` null the node carries no tap
      // action AND the `isEnabled` tristate is `none` — not `isFalse`. So
      // assistive tech is told nothing at all, rather than being told the
      // control is unavailable, and the label reads like a live one.
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(data.flagsCollection.isEnabled, Tristate.none);

      handle.dispose();
    });

    testWidgets('the icon does not follow the text scaler', (
      WidgetTester tester,
    ) async {
      final Finder icon = find.byIcon(Icons.location_off_rounded);

      await _pumpAt(tester, gpsDeniedStateWiredCta, size: const Size(390, 1400));
      expect(tester.getSize(icon).height, 56);

      await _pumpAt(
        tester,
        gpsDeniedStateWiredCta,
        size: const Size(390, 1400),
        textScale: 2.0,
      );

      // `Sizes.fiveXLarge` is a raw logical size, and [Icon] does not scale by
      // default, so at the accessibility ceiling the glyph stays 56 pt while
      // every line of type around it doubles. Not a defect on its own — it is
      // the reason the content height below grows by a little less than 2x —
      // but it is why the icon reads as small in the `EN 200% text` renderings.
      expect(tester.getSize(icon).height, 56);
    });
  });

  group('GpsDeniedState preview geometry', () {
    testWidgets('nothing here scrolls', (WidgetTester tester) async {
      await pumpPreview(tester, gpsDeniedStateWiredCta);

      // The font-independent root cause of every overflow below:
      // `Center > Padding > Column` with no [SingleChildScrollView]. A slot
      // shorter than the content cannot be scrolled, so the shortfall is paid
      // in an overflow stripe in debug and a silent clip in release — and the
      // first thing off the bottom edge is the CTA.
      expect(
        find.descendant(
          of: find.byType(GpsDeniedState),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    testWidgets('content roughly doubles at the 200% ceiling', (
      WidgetTester tester,
    ) async {
      const Size tall = Size(390, 1400);

      await _pumpAt(tester, gpsDeniedStateWiredCta, size: tall);
      final double atDefault = tester.getSize(_content).height;

      await _pumpAt(tester, gpsDeniedStateWiredCta, size: tall, textScale: 2.0);
      final double atCeiling = tester.getSize(_content).height;

      // Measured on a slot tall enough that neither reading overflows, so
      // these are the heights the widget DEMANDS rather than the heights it
      // was given. The ratio is what the three overflow tests below are: the
      // widget asks a phone-height slot for a phone-height column, and asks
      // for twice that at 200% with no way to give any of it back.
      expect(atCeiling, greaterThan(1.9 * atDefault));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the short map card overflows at its declared box', (
      WidgetTester tester,
    ) async {
      // The box this preview declares to the canvas: 390x200. Roughly 210 pt
      // of icon + copy + CTA in about 180 pt of slot.
      await _pumpAt(tester, gpsDeniedStateShortCard, size: const Size(390, 200));

      expect(
        tester.takeException().toString(),
        contains('overflowed'),
        reason: 'a fixed-height map card cannot hold this widget',
      );
    });

    testWidgets('landscape overflows at the 200% ceiling', (
      WidgetTester tester,
    ) async {
      // Same defect from the accessibility side: at default text this state
      // fits its 740x360 box comfortably, and doubling the type overruns it.
      await _pumpAt(tester, gpsDeniedStateLandscape, size: const Size(740, 360));
      expect(tester.takeException(), isNull);

      await _pumpAt(
        tester,
        gpsDeniedStateLandscape,
        size: const Size(740, 360),
        textScale: 2.0,
      );

      expect(tester.takeException().toString(), contains('overflowed'));
    });

    testWidgets('a compact phone overflows a FULL screen body at 200%', (
      WidgetTester tester,
    ) async {
      // The worst of the three, because there is no host to blame: 320x560 is
      // the whole body of the narrowest supported phone, not a card and not a
      // sheet. At the accessibility ceiling the content still does not fit,
      // and the CTA is what goes over the edge.
      await _pumpAt(
        tester,
        gpsDeniedStateCompactPhone,
        size: const Size(320, 560),
        textScale: 2.0,
      );

      expect(tester.takeException().toString(), contains('overflowed'));
    });
  });

  group('GpsDeniedState preview localization', () {
    testWidgets('the copy localizes and the layout stays centred', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        gpsDeniedStateWiredCta,
        locale: const Locale('ar'),
      );

      expect(find.text('مطلوب إذن الموقع'), findsOneWidget);
      expect(find.text('فتح الإعدادات'), findsOneWidget);
      expect(find.text('Location access required'), findsNothing);

      // The padding is [EdgeInsetsDirectional] and the column is centred, so
      // there is nothing to mirror and nothing to catch — pinned so a future
      // asymmetric layout (an icon beside the text, a leading-aligned CTA)
      // cannot land without this failing.
      final Rect widgetBox = tester.getRect(find.byType(GpsDeniedState));
      final Rect content = tester.getRect(_content);
      expect(
        content.left - widgetBox.left,
        moreOrLessEquals(widgetBox.right - content.right, epsilon: 0.5),
      );
    });
  });
}
