// Render tests for the FeedbackHeader previews.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_header.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Client rates the jeeber': feedbackHeaderClientAudience,
  'Jeeber rates the client': feedbackHeaderJeeberAudience,
  'Compact 320pt device': feedbackHeaderCompact,
  'In screen context': feedbackHeaderInScreenContext,
  'Bounded 240pt band (greedy column)': feedbackHeaderBoundedBand,
};

/// The three ARB strings this widget can put on screen, as `app_en.arb` spells
/// them. Restated here so a copy edit that changes the audience wording has to
const String _title = 'We appreciate your feedback';
const String _subtitleJeeber =
    'We are always looking for ways to improve your experience. Please take a '
    'moment to evaluate the delivery man.';
const String _subtitleClient =
    'We are always looking for ways to improve your experience. Please take a '
    'moment to evaluate the client.';

/// `app_ar.arb`'s title. The screen has no English fallback, so this is what
/// proves the header localizes rather than merely mirroring.
const String _titleAr = 'نقدّر ملاحظاتك';

/// The content column each host width leaves the header: the phone/compact
/// width minus `_FeedbackScrollArea`'s two `Spacing.large` gutters.
const double _phoneContentWidth = 390 - 40;
const double _compactContentWidth = 320 - 40;

/// `Spacing.small`, restated from `feedback_header.dart` so a change to the
/// title/subtitle gap shows up here as a failure rather than as a silent
const double _titleToSubtitle = 12;

/// `Spacing.xLarge` — what `_FeedbackContent` puts between the header and each
/// of its neighbours.
const double _neighbourGap = 24;

/// The band `feedbackHeaderBoundedBand` drops the header into.
const double _bandHeight = 240;

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double hi = math.max(a.computeLuminance(), b.computeLuminance());
  final double lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

/// How many lines [text] wrapped onto, counted from the laid-out glyph boxes.
/// Line COUNTS rather than pixel heights: `flutter_test` substitutes its own
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
    'FeedbackHeader',
    _previews,
    expectedText: const <String, String>{
      // The audience switch is the widget's only input, so the two production
      'Client rates the jeeber': _subtitleJeeber,
      'Jeeber rates the client': _subtitleClient,
      // Caption-bound: same widget, same two strings, different box. The
      'Compact 320pt device': '320pt device — narrowest supported',
      // Bound to a neighbour no other state renders, rather than to a caption.
      'In screen context': 'Rate Sami Fawaz',
      'Bounded 240pt band (greedy column)':
          'Bounded 240pt band — the column fills it',
    },
  );

  group('FeedbackHeader preview specifics', () {
    testWidgets('the audience switch changes the subtitle and nothing else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackHeaderClientAudience);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_subtitleJeeber), findsOneWidget);
      expect(
        find.text(_subtitleClient),
        findsNothing,
        reason: 'a client must be asked to evaluate the DELIVERY MAN — showing '
            'the other subtitle here is the wrong-audience bug '
            'test/feedback_screen_test.dart guards at the screen level',
      );

      await pumpPreview(tester, feedbackHeaderJeeberAudience);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_subtitleClient), findsOneWidget);
      expect(find.text(_subtitleJeeber), findsNothing);
    });

    testWidgets('holds the title 12pt above the subtitle, both centred', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackHeaderClientAudience);

      final Rect header = tester.getRect(find.byType(FeedbackHeader));
      final Rect title = tester.getRect(find.text(_title));
      final Rect subtitle = tester.getRect(find.text(_subtitleJeeber));

      expect(subtitle.top - title.bottom, _titleToSubtitle);
      expect(
        title.top,
        header.top,
        reason: 'the header adds no padding of its own — its callers own the '
            'spacing above it',
      );
      expect(subtitle.bottom, header.bottom);

      // The block is centred on the content column, which is what makes it read
      expect((title.center.dx - header.center.dx).abs(), lessThan(0.5));
      expect((subtitle.center.dx - header.center.dx).abs(), lessThan(0.5));
    });

    testWidgets('takes the whole content column: 350 on a phone, 280 at 320pt',
        (WidgetTester tester) async {
      await pumpPreview(tester, feedbackHeaderClientAudience);
      expect(
        tester.getSize(find.byType(FeedbackHeader)).width,
        _phoneContentWidth,
      );

      await pumpPreview(tester, feedbackHeaderCompact);
      expect(
        tester.getSize(find.byType(FeedbackHeader)).width,
        _compactContentWidth,
        reason: 'the compact state must really be the 320pt device, not the '
            '800pt test surface — otherwise the state that breaks is not the '
            'state under review',
      );
    });

    testWidgets('wraps rather than clipping at the 200% ceiling on 320pt', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackHeaderCompact);
      expect(tester.takeException(), isNull);
      final int linesAt100 = _lineCount(tester, _subtitleJeeber);
      final double heightAt100 =
          tester.getSize(find.byType(FeedbackHeader)).height;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, feedbackHeaderCompact);

      // Deliberately NOT asserted as an exact line count: `flutter_test`
      final int linesAt200 = _lineCount(tester, _subtitleJeeber);
      expect(linesAt200, greaterThan(linesAt100));
      expect(
        tester.getSize(find.byType(FeedbackHeader)).height,
        greaterThan(heightAt100),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'neither Text sets maxLines/overflow, so the block must grow '
            'and scroll — add either and this becomes an ellipsis through the '
            'only instruction on the screen',
      );
    });

    testWidgets('fills a bounded parent instead of shrink-wrapping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackHeaderClientAudience);
      final double shrinkWrapped =
          tester.getSize(find.byType(FeedbackHeader)).height;
      expect(
        shrinkWrapped,
        lessThan(_bandHeight),
        reason: 'the phone state must be shorter than the band, or the '
            'comparison below proves nothing',
      );

      await pumpPreview(tester, feedbackHeaderBoundedBand);
      final Rect band = tester.getRect(find.byType(FeedbackHeader));
      final Rect title = tester.getRect(find.text(_title));

      // The widget's Column leaves `mainAxisSize` at MainAxisSize.max, so it
      expect(band.height, _bandHeight);
      expect(
        title.top - band.top,
        0,
        reason: 'the block is flush with the top of the band; if it were '
            'centred this would be (240 - content) / 2. Delete this '
            'expectation when the widget grows `mainAxisSize: '
            'MainAxisSize.min` — it is a gap, not a contract.',
      );
      expect(
        band.bottom - title.bottom,
        greaterThan(_bandHeight / 2),
        reason: 'the remainder of the band is dead space the header owns but '
            'does not paint',
      );
    });

    testWidgets('sits 24pt clear of both neighbours in the screen column', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, feedbackHeaderInScreenContext);

      final Rect header = tester.getRect(find.byType(FeedbackHeader));
      final Rect avatar = tester.getRect(find.byKey(const Key(
        'feedback_ratee_avatar',
      )));
      final Rect rateName = tester.getRect(find.text('Rate Sami Fawaz'));

      // `Spacing.xLarge` on both sides, and no margin of the header's own —
      expect(header.top - avatar.bottom, _neighbourGap);
      expect(rateName.top - header.bottom, _neighbourGap);

      // Avatar, header and the "Rate <name>" line share one centre axis.
      expect((header.center.dx - avatar.center.dx).abs(), lessThan(0.5));
      expect((header.center.dx - rateName.center.dx).abs(), lessThan(0.5));
    });

    testWidgets('localizes into Arabic and stays centred', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        feedbackHeaderClientAudience,
        locale: const Locale('ar'),
      );

      // Both strings come from the ARB, so an English leak here would mean the
      expect(find.text(_title), findsNothing);
      expect(find.text(_subtitleJeeber), findsNothing);
      expect(find.text(_titleAr), findsOneWidget);

      // `TextAlign.center` is direction-agnostic, so the block must sit on the
      final Rect header = tester.getRect(find.byType(FeedbackHeader));
      final Rect title = tester.getRect(find.text(_titleAr));
      expect((title.center.dx - header.center.dx).abs(), lessThan(0.5));
    });

    testWidgets('is not announced as a heading', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, feedbackHeaderClientAudience);

      // Documents today's behaviour rather than endorsing it: the title is a
      expect(
        tester.getSemantics(find.text(_title)).flagsCollection.isHeader,
        isFalse,
        reason: 'if this ever fails the widget grew `Semantics(header: true)` — '
            'delete this expectation, it was a gap not a contract',
      );

      handle.dispose();
    });

    test('both ink roles are container roles, and each fails one brightness',
        () {
      final ColorScheme light = AppTheme.light().colorScheme;
      final ColorScheme dark = AppTheme.dark().colorScheme;

      // The title paints with `colorScheme.secondaryContainer` — a container
      expect(
        _contrast(light.secondaryContainer, light.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'the light scheme hard-codes that role to the brand navy, so '
            'navy-on-white clears AA by a mile (17.13:1) — it must not regress',
      );
      expect(
        _contrast(dark.secondaryContainer, dark.surface),
        lessThan(3.0),
        reason: 'measured 1.98:1. The dark scheme is '
            '`ColorScheme.fromSeed(_jeebNavy, dark)`, where the role resolves '
            'to what M3 actually means by a container: a dark fill on a '
            'surface of nearly the same tone. The feedback title is '
            'near-invisible in dark mode; the correct role is `onSurface`. '
            'If this ever passes 3:1 the palette was fixed — delete this '
            'expectation and the note in the preview library doc. '
            '`CustomerProfileSectionHeader` and `JeebVerifiedBadge` pin the '
            'same gap.',
      );

      // The subtitle paints with `colorScheme.onSecondaryContainer`, the ON
      expect(
        _contrast(light.onSecondaryContainer, light.surface),
        lessThan(4.5),
        reason: 'measured 3.76:1. The light scheme hard-codes this role to the '
            'Figma muted purple #777FC0, and the subtitle is 14sp body text, '
            'so 4.5:1 is the floor it has to clear. This is the defect that '
            'ships to the DEFAULT rendering — it reads as intentionally soft '
            'type rather than as a contrast failure. Fix by inking with '
            '`onSurfaceVariant` (the role AppTheme already reserves for '
            'subtitles); when that lands, delete this expectation.',
      );
      expect(
        _contrast(dark.onSecondaryContainer, dark.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'in dark the same role resolves to a tone-90 and measures '
            '14.29:1 — the two defects are mirror images, so neither '
            'brightness shows both',
      );
    });
  });
}
