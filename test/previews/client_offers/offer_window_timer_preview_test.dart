// Render tests for the OfferWindowTimer previews.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_window_timer.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// The root [Container] of the widget under test.
const Key _bandKey = Key('offer-window-timer');

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Fresh window · 2:05': offerWindowTimerFreshWindow,
  'Threshold · 0:31': offerWindowTimerJustAboveUrgent,
  'Urgent · 0:30': offerWindowTimerUrgent,
  'Final seconds · 0:04': offerWindowTimerFinalSeconds,
  'Expired · stale 1:12 suppressed': offerWindowTimerExpired,
  'Safe-window fallback · 23:53:18': offerWindowTimerSafeWindowFallback,
};

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

Rect _band(WidgetTester tester) => tester.getRect(find.byKey(_bandKey));

Color _bandColor(WidgetTester tester) =>
    (tester.widget<Container>(find.byKey(_bandKey)).decoration!
            as BoxDecoration)
        .color!;

/// The colour the single [Text] is actually painted in.
Color _labelColor(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(Text).first).text.style!
        .color!;

/// How many lines [text] laid out onto, counted from the glyph boxes.
int _lineCount(WidgetTester tester, String text) {
  final RenderParagraph paragraph =
      tester.renderObject<RenderParagraph>(find.text(text));
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return boxes.map((TextBox b) => b.top.round()).toSet().length;
}

void main() {
  setUpAll(() async {
    loadPreviewArbs();
    // Geometry, not glyphs, is what several of these states are for — widths
    await loadInterTestFont();
  });

  testPreviewsRender(
    'OfferWindowTimer',
    _previews,
    expectedText: const <String, String>{
      // Pinned on the band's OWN output. The countdown IS the widget, so
      'Fresh window · 2:05': 'Window: 2:05 left',
      'Threshold · 0:31': 'Window: 0:31 left',
      'Urgent · 0:30': 'Window: 0:30 left',
      'Final seconds · 0:04': 'Window: 0:04 left',
      'Expired · stale 1:12 suppressed': 'Offer window expired',
      'Safe-window fallback · 23:53:18': 'Window: 23:53:18 left',
    },
  );

  group('OfferWindowTimer preview specifics', () {
    testWidgets('urgency starts at exactly thirty seconds', (
      WidgetTester tester,
    ) async {
      final JeebColorRoles lightRoles =
          AppTheme.light().extension<JeebColorRoles>()!;
      final ColorScheme light = AppTheme.light().colorScheme;

      await pumpPreview(tester, offerWindowTimerUrgent);
      expect(_bandColor(tester), lightRoles.warningContainer);
      expect(_labelColor(tester), lightRoles.onWarningContainer);

      // One second earlier in the window the band is still neutral. If this
      await pumpPreview(tester, offerWindowTimerJustAboveUrgent);
      expect(_bandColor(tester), light.surfaceContainerHighest);
      expect(_labelColor(tester), light.onSurface);
    });

    testWidgets('urgent uses the WARNING pair, never the error pair', (
      WidgetTester tester,
    ) async {
      final JeebColorRoles roles = AppTheme.light().extension<JeebColorRoles>()!;
      final ColorScheme light = AppTheme.light().colorScheme;

      // The regression named in `offer_window_timer.dart`: "Urgent previously
      await pumpPreview(tester, offerWindowTimerUrgent);
      expect(_bandColor(tester), isNot(light.errorContainer));
      expect(_bandColor(tester), roles.warningContainer);

      // ...and expired, which really IS terminal, keeps the error pair.
      await pumpPreview(tester, offerWindowTimerExpired);
      expect(_bandColor(tester), light.errorContainer);
      expect(_labelColor(tester), light.onErrorContainer);
      expect(_bandColor(tester), isNot(roles.warningContainer));
    });

    testWidgets('the expired flag wins over a live-looking countdown', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerWindowTimerExpired);

      // `requestIsExpired` (gateway) and `windowRemaining` (local clock) come
      expect(find.text('Offer window expired'), findsOneWidget);
      expect(find.textContaining('1:12'), findsNothing);
      expect(find.textContaining('left'), findsNothing);

      // The glyph flips too — a running timer icon on a dead window reads as
      expect(
        tester.widget<Icon>(find.byType(Icon)).icon,
        Icons.timer_off_outlined,
      );
      await pumpPreview(tester, offerWindowTimerFreshWindow);
      expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.timer_outlined);
    });

    testWidgets('single-digit seconds are zero-padded', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerWindowTimerFinalSeconds);

      expect(find.text('Window: 0:04 left'), findsOneWidget);
      expect(find.textContaining('0:4 '), findsNothing);
    });

    testWidgets('a 24 h window is promoted to h:mm:ss, never 1433 minutes', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerWindowTimerSafeWindowFallback);

      // The live-COD regression `CountdownFormat` exists for: the gateway's
      expect(find.text('Window: 23:53:18 left'), findsOneWidget);
      expect(find.textContaining('1433'), findsNothing);
    });

    testWidgets('the copy is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        offerWindowTimerFreshWindow,
        locale: const Locale('ar'),
      );
      expect(find.textContaining('Window:'), findsNothing);
      // The digits survive the Arabic sentence unchanged — `CountdownFormat`
      expect(find.text('المهلة: تبقى 2:05'), findsOneWidget);

      await pumpPreview(
        tester,
        offerWindowTimerExpired,
        locale: const Locale('ar'),
      );
      expect(find.text('Offer window expired'), findsNothing);
      expect(find.text('انتهت مهلة العروض'), findsOneWidget);
    });

    testWidgets('the band mirrors in RTL and spans the whole list width', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerWindowTimerFreshWindow);
      final Rect ltrBand = _band(tester);
      // The root Container carries no width, so under the tight width the
      expect(ltrBand.width, closeTo(358, 0.5));
      final Rect ltrIcon = tester.getRect(find.byType(Icon));
      final Rect ltrLabel = tester.getRect(find.byType(Text).first);
      // English: glyph leading, hard against the left inner edge.
      expect(ltrIcon.left - ltrBand.left, closeTo(12, 0.5));

      await pumpPreview(
        tester,
        offerWindowTimerFreshWindow,
        locale: const Locale('ar'),
      );
      final Rect rtlBand = _band(tester);
      final Rect rtlIcon = tester.getRect(find.byType(Icon));
      final Rect rtlLabel = tester.getRect(find.byType(Text).first);
      // Arabic: the row mirrors unaided — the padding is `EdgeInsets.symmetric`
      expect(rtlBand.width, closeTo(ltrBand.width, 0.5));
      expect(rtlIcon.right, closeTo(rtlBand.right - 12, 0.5));
      // ...and the label really did swap sides, rather than the band merely
      expect(rtlLabel.right, lessThanOrEqualTo(rtlIcon.left));
      expect(ltrLabel.left, greaterThanOrEqualTo(ltrIcon.right));
    });

    testWidgets('the timer glyph is the one part that ignores text scale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerWindowTimerFreshWindow);
      final Size iconAt100 = tester.getSize(find.byType(Icon));
      final double heightAt100 = _band(tester).height;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, offerWindowTimerFreshWindow);

      // The label honours the scaler and the band grows with it...
      expect(_band(tester).height, greaterThan(heightAt100 * 1.3));

      // ...but `Icon(size: Sizes.medium)` does not, because `applyTextScaling`
      expect(tester.getSize(find.byType(Icon)), iconAt100);
      expect(iconAt100, const Size(16, 16));
    });

    testWidgets('the longest countdown survives the 200% ceiling', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, offerWindowTimerSafeWindowFallback);

      // The `Text` sets neither `maxLines` nor `overflow`, so the failure mode
      expect(_lineCount(tester, 'Window: 23:53:18 left'), 1);
      expect(tester.takeException(), isNull);

      // Arabic is the tighter of the two — check it at the same ceiling.
      await pumpPreview(
        tester,
        offerWindowTimerSafeWindowFallback,
        locale: const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
    });

    test('every band pair clears WCAG AA in both schemes', () {
      for (final ThemeData theme in <ThemeData>[
        AppTheme.light(),
        AppTheme.dark(),
      ]) {
        final ColorScheme scheme = theme.colorScheme;
        final JeebColorRoles roles = theme.extension<JeebColorRoles>()!;

        // Urgent and expired are gated by `color_role_contrast_test.dart`;
        expect(
          _contrast(roles.onWarningContainer, roles.warningContainer),
          greaterThan(4.5),
        );
        expect(
          _contrast(scheme.onErrorContainer, scheme.errorContainer),
          greaterThan(4.5),
        );
        // The neutral branch is the one NOT covered by that gate: it pairs the
        expect(
          _contrast(scheme.onSurface, scheme.surfaceContainerHighest),
          greaterThan(4.5),
        );
      }
    });

    test('the escalation to urgent is carried by hue alone', () {
      final ColorScheme light = AppTheme.light().colorScheme;
      final JeebColorRoles lightRoles =
          AppTheme.light().extension<JeebColorRoles>()!;

      // Nothing but the fill changes at T-30s: same copy template, same
      final double neutralToUrgent = _contrast(
        light.surfaceContainerHighest,
        lightRoles.warningContainer,
      );
      expect(
        neutralToUrgent,
        lessThan(1.3),
        reason: 'the neutral -> urgent fill step is a hue shift, not a '
            'luminance one, so it is invisible to anyone who cannot separate '
            'pale grey from pale amber',
      );
      expect(
        _contrast(lightRoles.warningContainer, light.surface),
        lessThan(_contrast(light.surfaceContainerHighest, light.surface)),
      );
    });

    test('expired is a far heavier treatment in light than in dark', () {
      final ColorScheme light = AppTheme.light().colorScheme;
      final ColorScheme dark = AppTheme.dark().colorScheme;

      // `AppTheme.light()` does not carry an M3 tonal `errorContainer`: it is
      expect(_contrast(light.errorContainer, light.surface), greaterThan(6));
      expect(_contrast(dark.errorContainer, dark.surface), lessThan(3));
      expect(light.onErrorContainer, const Color(0xFFFFFFFF));
    });
  });
}
