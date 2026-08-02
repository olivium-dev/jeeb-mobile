// Render tests for the ClientHomeTierBadge previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One state deviates from that template, on purpose. `ClientRequestTier.unknown`
// makes the badge render the EMPTY STRING, so there is no text of the widget's
// own for `expectedText` to bind to — that absence is the state. It is addressed
// below by the title of the row hosting it, and the contract that actually
// matters (a zero-width box where the domain enum promises "a neutral chip") is
// measured in the specifics group.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_tier_colors.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/active_request_card.dart';
import 'package:jeeb_mobile/previews/home_client/client_home_tier_badge_preview.dart';

import '../preview_test_harness.dart';

const String _longTitle =
    'Pharmacy run — Ashrafieh to Hamra, ring the second bell';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Flash · in-progress header': clientHomeTierBadgeFlash,
  'Express · pending header': clientHomeTierBadgeExpressPending,
  'Standard · in-progress header': clientHomeTierBadgeStandard,
  'Unknown tier · nothing renders': clientHomeTierBadgeUnknown,
  'Long title · badge holds its place': clientHomeTierBadgeLongTitle,
  'All four tiers · strip': clientHomeTierBadgeStrip,
};

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

/// The badge's own [Text] — the whole of what this widget emits.
Text _badgeText(WidgetTester tester, {int at = 0}) => tester.widget<Text>(
      find
          .descendant(
            of: find.byType(ClientHomeTierBadge),
            matching: find.byType(Text),
          )
          .at(at),
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ClientHomeTierBadge',
    _previews,
    expectedText: const <String, String>{
      // The three real tiers are pinned on the badge's OWN output: the label is
      // the entire widget, so binding to anything else would pass on a badge
      // that had rendered the wrong tier.
      'Flash · in-progress header': 'Flash',
      'Express · pending header': 'Express',
      'Standard · in-progress header': 'Standard',
      // `unknown` emits nothing — see the header note. Addressed by its row.
      'Unknown tier · nothing renders': 'ORD-88213',
      'Long title · badge holds its place': _longTitle,
      'All four tiers · strip': 'Every ClientRequestTier value',
    },
  );

  group('ClientHomeTierBadge preview specifics', () {
    testWidgets('an unknown tier renders NOTHING, not a neutral chip', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeTierBadgeUnknown);

      // `ClientRequestTier`'s own doc says unknown "falls back to a neutral chip
      // so the screen never crashes when the backend introduces a new tier
      // mid-deploy". It does not crash — and it does not render a chip either.
      // `_labelFor` returns '', so the order silently loses its tier.
      expect(_badgeText(tester).data, isEmpty);
      expect(
        tester.getSize(find.byType(ClientHomeTierBadge)).width,
        0.0,
        reason: 'a zero-width badge leaves the row\'s Spacing.xSmall gap as 8pt '
            'of stray trailing air with nothing after it',
      );

      // Not a chip in any sense: no fill, no border, no padding — this is why a
      // new server tier degrades to an invisible badge rather than an unstyled
      // one. Guarding the shape here so "give unknown a real neutral chip"
      // shows up as a failure to update, not a silent no-op.
      expect(
        find.descendant(
          of: find.byType(ClientHomeTierBadge),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );

      for (final String tier in const <String>['Flash', 'Express', 'Standard']) {
        expect(find.text(tier), findsNothing);
      }
    });

    testWidgets('each tier inks its own JeebTierColors token', (
      WidgetTester tester,
    ) async {
      final JeebTierColors tokens = JeebTierColors.standard();

      await pumpPreview(tester, clientHomeTierBadgeFlash);
      expect(_badgeText(tester).style?.color, tokens.flash);

      await pumpPreview(tester, clientHomeTierBadgeExpressPending);
      expect(_badgeText(tester).style?.color, tokens.express);

      await pumpPreview(tester, clientHomeTierBadgeStandard);
      expect(_badgeText(tester).style?.color, tokens.standard);

      // The three previews above must not be one state wearing three labels.
      expect(
        <Color>{tokens.flash, tokens.express, tokens.standard}.length,
        3,
      );

      // Unknown resolves no token and lands on `colorScheme.tertiary` — a
      // carefully chosen colour applied to an empty string.
      await pumpPreview(tester, clientHomeTierBadgeUnknown);
      expect(
        _badgeText(tester).style?.color,
        AppTheme.light().colorScheme.tertiary,
      );
    });

    testWidgets('the label is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        clientHomeTierBadgeFlash,
        locale: const Locale('ar'),
      );

      expect(find.text('Flash'), findsNothing);
      expect(find.text('سريع'), findsOneWidget);
    });

    testWidgets('the two production headers place the badge differently', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeTierBadgeFlash);
      final Rect activeBadge = tester.getRect(find.byType(ClientHomeTierBadge));
      final Rect activeTitle = tester.getRect(find.text('Kamal Hajj'));

      await pumpPreview(tester, clientHomeTierBadgeExpressPending);
      final Rect pendingBadge = tester.getRect(find.byType(ClientHomeTierBadge));
      final Rect pendingTitle = tester.getRect(find.text('ORD-23470'));

      // `_ActiveOrderHeader` leaves `crossAxisAlignment` at its `center`
      // default, so the 11pt label is optically centred on the 22pt title.
      expect(
        (activeBadge.center.dy - activeTitle.center.dy).abs(),
        lessThan(1.0),
      );

      // Both pending headers pass `CrossAxisAlignment.start` instead, which
      // pins the label's TOP to the title's top — riding up against the
      // ascender, several points above where the in-progress tab puts the same
      // badge on the same screen. Nothing in the badge defends against this:
      // it is a bare `Text` with no baseline or alignment of its own.
      expect((pendingBadge.top - pendingTitle.top).abs(), lessThan(1.0));
      expect(
        pendingTitle.center.dy - pendingBadge.center.dy,
        greaterThan(4.0),
        reason: 'if this ever reaches ~0 the pending headers were switched to '
            'centre alignment and the two hosts finally agree',
      );
    });

    testWidgets('a title that cannot fit ellipsizes; the badge keeps its box', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeTierBadgeFlash);
      final Size shortBadge = tester.getSize(find.byType(ClientHomeTierBadge));
      final double shortTitle = tester.getSize(find.text('Kamal Hajj')).width;

      await pumpPreview(tester, clientHomeTierBadgeLongTitle);
      final Rect longBadge = tester.getRect(find.byType(ClientHomeTierBadge));
      final Rect row = tester.getRect(find.byType(Row).first);

      // Same tier, same label, same box: `Flexible` hands the title only the
      // leftovers, so the badge is never the child that gives way.
      expect(longBadge.size, shortBadge);
      expect(longBadge.right, lessThanOrEqualTo(row.right + 0.5));
      expect(longBadge.left, greaterThanOrEqualTo(row.left));

      // And the title really is the one under pressure — otherwise this is the
      // short-title state with a longer string.
      expect(
        tester.getSize(find.text(_longTitle)).width,
        greaterThan(shortTitle),
      );
      final RenderParagraph title =
          tester.renderObject<RenderParagraph>(find.text(_longTitle));
      expect(title.didExceedMaxLines, isTrue);
    });

    testWidgets('the badge grows with text scale and does not break the row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeTierBadgeLongTitle);
      final Size at100 = tester.getSize(find.byType(ClientHomeTierBadge));

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, clientHomeTierBadgeLongTitle);

      // Unlike the fixed-size `JeebVerifiedBadge` seal, this badge is a plain
      // `Text` with no `textScaler` override, so it honours the accessibility
      // ceiling.
      expect(
        tester.getSize(find.byType(ClientHomeTierBadge)).height,
        greaterThan(at100.height * 1.5),
      );
      // At 200% the longest plausible title plus the widest label still fit the
      // 314pt the in-progress row really has — no RenderFlex overflow.
      expect(tester.takeException(), isNull);
    });

    test('one fixed tier palette serves both schemes, and misses AA in light',
        () {
      // Same three hexes in both themes: `AppTheme._build` registers
      // `JeebTierColors.standard()` unconditionally, with no light/dark pair —
      // unlike `JeebSemanticColors` and `JeebColorRoles` right beside it.
      expect(
        AppTheme.light().extension<JeebTierColors>(),
        AppTheme.dark().extension<JeebTierColors>(),
        reason: 'if these ever differ the tier tokens grew a dark variant — '
            'update the notes on the previews',
      );

      // The badge paints these as 11pt text directly on `surface`, so WCAG AA
      // asks 4.5:1. Asserted as the failure it currently is, the way
      // `jeeb_verified_badge_preview_test.dart` does: pinning today's exact
      // ratios would make fixing the palette a test failure, and asserting 4.5
      // would fail today.
      final JeebTierColors tokens = JeebTierColors.standard();
      final Color lightSurface = AppTheme.light().colorScheme.surface;
      for (final MapEntry<String, Color> tier in <String, Color>{
        'flash': tokens.flash, // 4.23:1
        'express': tokens.express, // 2.37:1 — barely half of AA
        'standard': tokens.standard, // 3.68:1
      }.entries) {
        expect(
          _contrast(tier.value, lightSurface),
          lessThan(4.5),
          reason: '${tier.key} now clears AA on the light surface — the palette '
              'was fixed; delete this expectation and the notes on the previews',
        );
      }

      // Dark inverts the ranking (Express 7.81, Standard 5.03) because nothing
      // re-tunes the hexes for a near-black surface. Flash is the one that
      // fails at BOTH ends.
      final Color darkSurface = AppTheme.dark().colorScheme.surface;
      expect(_contrast(tokens.flash, darkSurface), lessThan(4.5));
      expect(
        _contrast(tokens.express, darkSurface),
        greaterThan(_contrast(tokens.express, lightSurface)),
      );
    });
  });
}
