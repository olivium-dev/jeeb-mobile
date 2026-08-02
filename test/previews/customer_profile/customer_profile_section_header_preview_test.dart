// Render tests for the CustomerProfileSectionHeader previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The `expectedText` map below binds each state to a string only that state
// puts on screen, so a suite that accidentally rendered the same header five
// times fails instead of passing. Underneath it, the specifics group pins the
// three things this widget is actually made of and that `find.text` cannot
// see: the gutter/rhythm geometry, the paragraph mirroring, and the ink colour.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_icon_disc.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_row.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_section_header.dart';
import 'package:jeeb_mobile/previews/customer_profile/customer_profile_section_header_preview.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Account (production)': customerProfileSectionHeaderAccount,
  'Support (production)': customerProfileSectionHeaderSupport,
  'Account → Support boundary': customerProfileSectionHeaderBoundary,
  'Longest ARB title, 320pt device':
      customerProfileSectionHeaderLongestTitleCompact,
  'Empty title (invisible, still spaced)':
      customerProfileSectionHeaderEmptyTitle,
};

/// The widget's own padding, restated from `customer_profile_section_header.dart`
/// (`Spacing.xLarge` / `Spacing.large` / `Spacing.xSmall`) so a change to either
/// side shows up here as a failure rather than as a silent redesign.
const double _gutter = 24;
const double _padAbove = 20;
const double _padBelow = 8;

/// `Sizes.twoXLarge` (the 32dp icon disc) + `Spacing.xSmall` (the 8pt gap the
/// row puts between disc and label).
const double _discToLabel = 32 + 8;

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double hi = math.max(a.computeLuminance(), b.computeLuminance());
  final double lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

/// The union of the laid-out glyph boxes of [text], in paragraph-local
/// coordinates.
///
/// The `Text`'s own render box spans the full width of its parent in BOTH text
/// directions, so it cannot tell LTR from RTL. Where the glyphs actually landed
/// inside that box can.
Rect _glyphSpan(WidgetTester tester, String text) {
  final RenderParagraph paragraph =
      tester.renderObject<RenderParagraph>(find.text(text));
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  expect(boxes, isNotEmpty, reason: '"$text" laid out no glyphs');
  return boxes
      .map((TextBox b) => b.toRect())
      .reduce((Rect a, Rect b) => a.expandToInclude(b));
}

/// How many lines [text] wrapped onto, counted from the laid-out glyph boxes.
///
/// Line COUNTS rather than pixel heights: `flutter_test` substitutes its own
/// metrics for Inter, so an absolute height measured here would be a property
/// of the test font rather than of the layout.
int _lineCount(WidgetTester tester, String text) {
  final RenderParagraph paragraph =
      tester.renderObject<RenderParagraph>(find.text(text));
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return boxes.map((TextBox b) => b.top.round()).toSet().length;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerProfileSectionHeader',
    _previews,
    expectedText: const <String, String>{
      // The two shipping headers, as the real ARB spells them.
      'Account (production)': 'Account',
      'Support (production)': 'Support',
      // Pinned on the row BELOW the header, which no other state renders — the
      // header itself says "Support" here, same as the state above it, so
      // keying on the header would not tell the two apart.
      'Account → Support boundary': 'Contact us',
      'Longest ARB title, 320pt device': 'What the client says',
      // The state's whole content IS the empty string: exactly one `Text`
      // rendering nothing. No other preview here produces one.
      'Empty title (invisible, still spaced)': '',
    },
  );

  group('CustomerProfileSectionHeader preview specifics', () {
    testWidgets('indents to the 24pt gutter with 20 above / 8 below', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileSectionHeaderAccount);

      final Rect header =
          tester.getRect(find.byType(CustomerProfileSectionHeader));
      final Rect title = tester.getRect(find.text('Account'));

      expect(title.left - header.left, _gutter);
      expect(header.right - title.right, _gutter);
      expect(title.top - header.top, _padAbove);
      expect(header.bottom - title.bottom, _padBelow);

      // The asymmetry is the grouping signal, not a rounding artefact.
      expect(
        title.top - header.top,
        greaterThan(header.bottom - title.bottom),
        reason: 'the header must bind to the section BELOW it',
      );
    });

    testWidgets('the paragraph mirrors in Arabic, though the padding cannot', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileSectionHeaderAccount);
      final Size enBox = tester.getSize(find.text('Account'));
      final Rect enGlyphs = _glyphSpan(tester, 'Account');

      await pumpPreview(
        tester,
        customerProfileSectionHeaderAccount,
        locale: const Locale('ar'),
      );
      // The ARB value the screen test already pins.
      final Size arBox = tester.getSize(find.text('الحساب'));
      final Rect arGlyphs = _glyphSpan(tester, 'الحساب');

      // `EdgeInsetsDirectional` mirrors, but 24/24 is symmetric — so the
      // paragraph gets the same box in both directions and the box itself
      // proves nothing. (It is the same box only because `_stretched` gives the
      // header the width its production parent gives it; loose, both would
      // shrink-wrap to their own glyph runs and differ for the wrong reason.)
      expect(arBox.width, enBox.width);

      // The glyphs are where the mirroring is observable.
      expect(
        enGlyphs.left,
        lessThan(1.0),
        reason: 'English must start at the leading (left) edge',
      );
      expect(
        arBox.width - arGlyphs.right,
        lessThan(1.0),
        reason: 'Arabic must start at the leading (right) edge — if this fails '
            'the title is left-aligned inside a right-to-left screen',
      );
      expect(arGlyphs.left, greaterThan(enGlyphs.left + 100));
    });

    testWidgets('aligns with the row DISC, 40pt before the row label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileSectionHeaderBoundary);

      final Rect title = tester.getRect(find.text('Support'));
      final Rect disc =
          tester.getRect(find.byType(CustomerProfileIconDisc).first);
      final Rect rowLabel = tester.getRect(find.text('Contact us'));

      expect(title.left, _gutter);
      expect(
        disc.left,
        title.left,
        reason: 'design §1/§4: the header indents to the screen gutter, i.e. to '
            'the row icon — not to the row label',
      );
      expect(rowLabel.left - title.left, _discToLabel);
    });

    testWidgets('leaves more air above itself than below', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileSectionHeaderBoundary);

      final Rect title = tester.getRect(find.text('Support'));
      final Rect rowAbove =
          tester.getRect(find.byType(CustomerProfileRow).first);
      final Rect rowBelow = tester.getRect(find.byType(CustomerProfileRow).at(1));

      final double above = title.top - rowAbove.bottom;
      final double below = rowBelow.top - title.bottom;

      expect(above, _padAbove);
      expect(below, _padBelow);
      expect(
        above,
        greaterThan(below),
        reason: 'the boundary must read as "Support owns what follows", not as '
            'a divider floating between two equal groups',
      );
    });

    testWidgets('the longest ARB title wraps rather than clipping at 200%', (
      WidgetTester tester,
    ) async {
      const String longest = 'What the client says';

      await pumpPreview(
        tester,
        customerProfileSectionHeaderLongestTitleCompact,
      );
      expect(tester.takeException(), isNull);
      // The host really is the compact device, not the 800pt test surface.
      expect(tester.getSize(find.byType(CustomerProfileSectionHeader)).width,
          320.0);
      // Deliberately NOT asserted as "one line at 1.0": `flutter_test`
      // substitutes its own metrics for Inter, so the wrap point here is a
      // property of the test font. What is asserted below is that the count
      // GROWS, which is a property of the layout.
      final int linesAt100 = _lineCount(tester, longest);

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(
        tester,
        customerProfileSectionHeaderLongestTitleCompact,
      );

      // No `maxLines`, no `overflow`: it degrades by wrapping. If either is
      // ever added, this becomes an ellipsis and the count stops growing.
      final int linesAt200 = _lineCount(tester, longest);
      expect(linesAt200, greaterThan(linesAt100));
      expect(linesAt200, greaterThanOrEqualTo(2));
      expect(
        tester.takeException(),
        isNull,
        reason: 'wrapping must not produce an overflow stripe',
      );
    });

    testWidgets('an empty title is invisible but costs a full header band', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileSectionHeaderAccount);
      final double titledHeight =
          tester.getSize(find.byType(CustomerProfileSectionHeader)).height;

      await pumpPreview(tester, customerProfileSectionHeaderEmptyTitle);
      final double emptyHeight =
          tester.getSize(find.byType(CustomerProfileSectionHeader)).height;

      expect(find.text(''), findsOneWidget);
      expect(
        emptyHeight,
        titledHeight,
        reason: 'an empty title paints nothing yet still reserves 20 + a full '
            'line + 8, so callers see an unexplained gap between two rows '
            'rather than a missing section',
      );
      expect(emptyHeight, greaterThan(_padAbove + _padBelow));
    });

    testWidgets('is not announced as a heading', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, customerProfileSectionHeaderAccount);

      // Documents today's behaviour rather than endorsing it: the widget wraps
      // its title in no `Semantics`, so TalkBack/VoiceOver read "Account" as
      // ordinary text and heading navigation cannot jump between the Account
      // and Support sections. The grouping is purely visual.
      expect(
        tester.getSemantics(find.text('Account')).flagsCollection.isHeader,
        isFalse,
        reason: 'if this ever fails the widget grew `Semantics(header: true)` — '
            'delete this expectation, it was a gap not a contract',
      );

      handle.dispose();
    });

    test('the title ink clears AA in light and fails it badly in dark', () {
      // The title paints with `colorScheme.secondaryContainer` — a container
      // role, i.e. a fill meant to sit BEHIND ink.
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        _contrast(light.secondaryContainer, light.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'the light scheme hard-codes that role to the brand navy, so '
            'navy-on-white clears AA by a mile — it must not regress',
      );

      // The dark scheme is `ColorScheme.fromSeed(_jeebNavy, dark)`, where the
      // role resolves to what M3 actually means by a container: a dark fill, on
      // a surface of nearly the same tone. Measured 1.98:1.
      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(
        _contrast(dark.secondaryContainer, dark.surface),
        lessThan(3.0),
        reason: 'if this ever passes 3:1 the palette or the role was fixed — '
            'delete this expectation and the note in the preview library doc. '
            'Until then the Account/Support headers are near-invisible in dark '
            'mode; the correct role is `onSurface` or `onSecondaryContainer`, '
            'never a `*Container` one (app_theme.dart says so itself).',
      );
    });
  });
}
