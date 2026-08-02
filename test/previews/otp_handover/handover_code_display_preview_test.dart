// Render tests for the HandoverCodeDisplay previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// The widget renders exactly one string and no localized copy of its own, so
// every `expectedText` pin below is the code itself — deliberately distinct per
// state, which is the only way a pin can prove a preview built ITS OWN state
// rather than repeating the previous one.
//
// The measurements in the specifics group use the widget-test font (every glyph
// one em wide), so the absolute numbers are a worst case; what they pin is the
// ORDERING and the behaviour — hero > compact type scale, LTR digits inside an
// Arabic tree, and the panel never outgrowing the slot it is given.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/otp_handover/presentation/widgets/handover_code_display.dart';

import '../preview_test_harness.dart';

/// The OTP screen's historical key, which every preview here inherits from
/// [HandoverCodeDisplay]'s default `displayKey`.
const Key _codeKey = Key('otpHandover.codeDisplay');

/// The screen padding both call sites impose (`EdgeInsets.all(Spacing.xLarge)`),
/// which the narrow-phone preview reproduces.
const double _pagePadding = 24;

/// Width of the rendered code panel — the padded [Container], not the glyph run.
double _panelWidth(WidgetTester tester) =>
    tester.getSize(find.byKey(_codeKey)).width;

/// The laid-out size of the digit run itself.
Size _codeSize(WidgetTester tester, String code) =>
    tester.getSize(find.text(code));

/// Font size the code is actually painted at.
double _codeFontSize(WidgetTester tester, String code) =>
    tester.renderObject<RenderParagraph>(find.text(code)).text.style!.fontSize!;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'HandoverCodeDisplay',
    const <String, Widget Function()>{
      'Hero · 1234': handoverCodeDisplayHero,
      'Compact in-card · 5678': handoverCodeDisplayCompact,
      'Bidi guard · 0450': handoverCodeDisplayBidiGuard,
      'Narrow phone · 320 pt': handoverCodeDisplayNarrowPhone,
      'Widened code · 481902': handoverCodeDisplayWidenedCode,
    },
    expectedText: const <String, String>{
      // One code per state: a pin can only be satisfied by its own state.
      'Hero · 1234': '1234',
      'Compact in-card · 5678': '5678',
      'Bidi guard · 0450': '0450',
      'Narrow phone · 320 pt': '9061',
      'Widened code · 481902': '481902',
    },
  );

  group('HandoverCodeDisplay preview specifics', () {
    testWidgets('compact is a type-scale change, not a padding tweak', (
      WidgetTester tester,
    ) async {
      // The two previews exist as a pair because these are the two surfaces
      // that ship. If `compact` ever stops being the ~half-size variant, the
      // at-door card and the OTP screen stop looking like one component.
      await pumpPreview(tester, handoverCodeDisplayHero);
      final double heroFont = _codeFontSize(tester, '1234');
      final double heroHeight = _codeSize(tester, '1234').height;

      await pumpPreview(tester, handoverCodeDisplayCompact);
      final double compactFont = _codeFontSize(tester, '5678');
      final double compactHeight = _codeSize(tester, '5678').height;

      // displayLarge (57) vs headlineLarge (32) in the app's own text theme.
      expect(heroFont, 57);
      expect(compactFont, 32);
      expect(compactHeight, lessThan(heroHeight));
    });

    testWidgets('the digits keep LTR order inside an Arabic tree', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(
        tester,
        handoverCodeDisplayBidiGuard,
        locale: const Locale('ar'),
      );

      // The tree around the panel mirrors...
      expect(
        Directionality.of(tester.element(find.byType(HandoverCodeDisplay))),
        TextDirection.rtl,
      );
      // ...the digits must not. `0450` mirrored reads as `0540`, a different
      // code, and the only thing preventing it is the Directionality pin in
      // HandoverCodeDisplay.build.
      expect(
        tester.renderObject<RenderParagraph>(find.text('0450')).textDirection,
        TextDirection.ltr,
      );

      // The live region announces the digits one at a time, under the Arabic
      // label — a screen-reader user hears the code even when the visual
      // rendering is the one that broke.
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('otp_handover_code_display'),
      );
      expect(node.value, '0 4 5 0');
      expect(node.label, contains('رمز التسليم'));

      // Documented defect, pinned so it cannot be lost: the Semantics wrapper
      // sets neither `container` nor `explicitChildNodes`, so the code Text
      // MERGES into the live region and its unspaced run lands in the label
      // beside the spaced `value`. TalkBack therefore hears the code twice —
      // once as a run a screen reader is free to read as the number "four
      // hundred fifty", once digit by digit. `container: true` on the
      // Semantics in HandoverCodeDisplay.build would drop the first.
      expect(node.label, contains('0450'));

      handle.dispose();
    });

    testWidgets('the narrow-phone preview really is pinned to 320 pt', (
      WidgetTester tester,
    ) async {
      // The render harness pumps an 800 px viewport and ignores JeebPreview.size,
      // so a state about width has to carry its own pin or it is silently
      // reviewed at 800 pt.
      await pumpPreview(tester, handoverCodeDisplayNarrowPhone);

      expect(_panelWidth(tester), 320 - _pagePadding * 2);
    });

    testWidgets('the code WRAPS mid-number when it does not fit', (
      WidgetTester tester,
    ) async {
      // This pins a defect, deliberately. HandoverCodeDisplay has no FittedBox,
      // no maxLines and no ellipsis, and Flutter's line breaker falls back to
      // breaking a digit run anywhere rather than overflowing it — so a code
      // that does not fit is rendered as stacked fragments (`906` / `1`), not
      // clipped and not scaled down.
      //
      // If a FittedBox / AutoSizeText fix lands, this expectation SHOULD fail:
      // change it to assert a single line, and delete this comment.
      await pumpPreview(tester, handoverCodeDisplayHero);
      final double oneLine = _codeSize(tester, '1234').height;

      await pumpPreview(tester, handoverCodeDisplayNarrowPhone);
      expect(
        _codeSize(tester, '9061').height,
        greaterThan(oneLine),
        reason:
            'the 4-digit code fits on one line at 320 pt only while the '
            'glyphs are narrow; it wraps rather than shrinking',
      );
      // What does hold: the panel never grows past the slot it was given.
      expect(_panelWidth(tester), lessThanOrEqualTo(320 - _pagePadding * 2));
    });

    testWidgets('a widened code is rendered and announced verbatim', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      // Nothing in this widget enforces the 4-digit contract — only the
      // jeeber's submit button does (`code.length == 4`). A widened code is
      // shown, and announced, exactly as it arrived.
      await pumpPreview(tester, handoverCodeDisplayWidenedCode);

      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('otp_handover_code_display'),
            )
            .value,
        '4 8 1 9 0 2',
      );
      // 390 pt phone minus the page padding: the panel fills it and no more.
      expect(_panelWidth(tester), lessThanOrEqualTo(390 - _pagePadding * 2));

      handle.dispose();
    });
  });
}
