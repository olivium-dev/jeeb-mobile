/// b02 chat-header redesign — the MEASURED contrast gate for both chat headers.
///
/// The owner's verdict on the original headers was "does not comply with
/// material design system concepts neither accessibility neither contrast".
/// This file is the contrast half, and it is deliberately built in two layers,
/// because either layer alone is an instrument that can lie:
///
///  1. **Binding.** Pump the real widgets in the real [AppTheme] and read the
///     colours the widgets ACTUALLY paint out of the rendered tree. Without
///     this, the table below is a table about a design document.
///  2. **Measurement.** Compute the WCAG 2.2 ratio for every text and icon
///     element and every component boundary, and fail below threshold. Without
///     this, the binding is just "it uses some role".
///
/// ---------------------------------------------------------------------------
/// MIDNIGHT RE-CUT (M6, Q-022). READ THIS BEFORE CHANGING A ROW.
///
/// This file was 5-red for the whole engagement. It was a **pass-1 instrument
/// measuring a pre-Midnight palette**, and the failure was in the instrument,
/// not the UI. Two things had moved underneath it:
///
///  * `colorScheme.primary` used to be the NAVY card. Under Midnight it is the
///    brand ORANGE `#D73B00` (token sheet §1). Every row that wrote
///    `background = cs.primary` silently started measuring ink on orange.
///  * The strip stopped being a `primary` slab at all. It is
///    [JeebNavySurfaceCard] — `glassFillEmphasis` (white 10 %) over the screen's
///    [JeebMidnightField], with a 1px `glassBorderStrong` stroke (sheet §4).
///
/// **Q-022 is therefore settled as: NEITHER a token defect NOR a large-text
/// pass — the 3.87:1 pair does not exist.** The old rows computed
/// `blend(onPrimary, primary, .14)` = white-14 %-over-`#D73B00` = `#DD5624`,
/// a colour nothing in the app paints. What the chip really composites is
/// `JeebSurfaceTone.chipFill` (`glassFillPressed`, white 14 %) over the
/// emphasis-glass strip over the field, and its white label measures
/// **8.03 – 9.48:1** depending on which rung of the field gradient sits behind
/// it. Recorded for the avoidance of doubt: the large-text escape was never
/// available either — the chip label is `jeebText.caption`, 11.5 px / w600,
/// nowhere near AA-large (≥18.66 px bold or ≥24 px), so had the pair been real
/// it would have been a genuine defect.
///
/// The instrument now composites the strip the way the screen does, and
/// gates it against **every navy rung the field can put behind it** — the
/// lightest rung (`surfaceContainerHigh`) is the worst case for white ink, so
/// the table's floor is a real floor, not a lucky sample.
/// ---------------------------------------------------------------------------
///
/// Thresholds (WCAG 2.2 AA): 4.5:1 body text, 3:1 large text (≥18.66 px bold or
/// ≥24 px) and non-text — icons and UI component boundaries (SC 1.4.11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_system_chip.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_accepted_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_pinned_summary.dart';
import 'package:omds/omds.dart';

import 'chat_header_support.dart';

/// Composites a token that already CARRIES its own alpha (`glassFillEmphasis`,
/// `glassFillPressed`) over an opaque background.
///
/// `blend()` in the shared harness takes a separate alpha, which is the wrong
/// shape for the Midnight glass tokens — passing one of them to `blend` would
/// silently apply the alpha twice. Local to this file: it is the Midnight
/// idiom, and the harness is shared with the pass-1 overflow/budget tests.
Color blendToken(Color token, Color background) =>
    Color.alphaBlend(token, background);

/// One measured row of the report.
class _Row {
  _Row(this.element, this.fg, this.bg, this.threshold);
  final String element;
  final Color fg;
  final Color bg;
  final double threshold;
  double get ratio => contrastRatio(fg, bg);
  bool get pass => ratio >= threshold;
}

void main() {
  setUpAll(loadArb);
  setUp(ChatHeaderExpansionStore.instance.reset);

  const summary = OrderChatSummary(
    deliveryId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
    orderRef: 'ORD-23470',
    priceLabel: r'$12.00',
    jeeberName: 'Kamal Hajj',
    statusId: 'in_transit',
  ); // no ETA/tier → the disclosed chips read the "Pending" placeholder

  // -------------------------------------------------------------------------
  // Layer 1 — BINDING: the widgets really do paint these roles.
  // -------------------------------------------------------------------------
  group('binding — the rendered widgets use the roles the table measures', () {
    testWidgets('pinned summary', (tester) async {
      await tester.pumpWidget(themedHost(Scaffold(
        body: OrderChatPinnedSummary(
          summary: summary,
          counterpartName: 'Kamal Hajj',
          onViewSummary: () {},
        ),
      )));
      await tester.pump();
      final cs = AppTheme.light().colorScheme;
      final roles = AppTheme.light().extension<JeebColorRoles>()!;
      final semantics = AppTheme.light().extension<JeebSemanticColors>()!;

      // MIDNIGHT: the shell is the kit's emphasis-GLASS card, not a `primary`
      // slab. This is the assertion whose absence let the measurement layer
      // drift onto orange for a whole engagement.
      final box = tester.widget<DecoratedBox>(find
          .descendant(
            of: find.byType(OrderChatPinnedSummary),
            matching: find.byType(DecoratedBox),
          )
          .first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, semantics.glassFillEmphasis,
          reason: 'the strip is emphasis glass (sheet §4), NOT cs.primary — '
              'cs.primary is #D73B00 under Midnight');
      expect(decoration.color, isNot(cs.primary),
          reason: 'Q-022 guard: if this ever fails the strip has gone orange');
      final border = decoration.border! as Border;
      expect(border.top.color, semantics.glassBorderStrong,
          reason: 'every glass surface carries the 1px stroke (sheet §4)');
      expect(decoration.boxShadow, JeebNavySurfaceCard.stripShadow);

      // The ONE accent, and it is a dot rather than a fill.
      final dot = tester
          .widget<Container>(find
              .descendant(
                of: find.byType(OrderChatPinnedSummary),
                matching: find.byType(Container),
              )
              .first)
          .decoration! as BoxDecoration;
      expect(dot.color, roles.accent);
      expect(dot.shape, BoxShape.circle);

      // The three collapsed FACTS are white — the fact ink on the strip.
      for (final label in const ['ORD-23470', 'In transit', r'$12.00']) {
        expect(
          tester.widget<Text>(find.text(label)).style!.color,
          cs.onPrimary,
          reason: '$label is a locked fact and reads at full strength',
        );
      }

      // Every ink on this strip is `onPrimary` — see the ink note at the top of
      // `order_chat_pinned_summary.dart`. That note's REASONING is pass-1 (it
      // argues from a light/dark split that no longer exists) but the ink it
      // lands on is white, which is the highest-contrast choice available on
      // glass-over-navy, so the treatment stands. M6 filed the reasoning gap.
      expect(
        tester
            .widget<Icon>(find.descendant(
              of: find.bySemanticsIdentifier('order_chat_summary_expand'),
              matching: find.byType(Icon),
            ))
            .color,
        cs.onPrimary,
      );

      // Expanded content: the cash reminder — the element the owner reported
      // as unreadable. Full-strength role, no alpha.
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('Pay cash on delivery')).style!.color,
        cs.onPrimary,
      );
      // The view-summary link is a FACT on the strip — white, and still
      // underlined so the affordance survives without a colour cue.
      final link = tester.widget<Text>(find.text('View summary'));
      expect(link.style!.color, cs.onPrimary);
      expect(link.style!.decoration, TextDecoration.underline);
      final party = tester.widget<Text>(find.text('Kamal Hajj'));
      expect(party.style!.color, cs.onPrimary);
      expect(party.style!.fontWeight, isNot(FontWeight.w700),
          reason: 'a qualifier is separated from a fact by WEIGHT, not ink');

      // A summary chip (disclosed by the expand): the fill comes from the
      // card's OWN published tone, never a hand-mixed alpha, and it carries no
      // border — a translucent white capsule on the strip is already an edge.
      final tierDecoration = tester
          .widget<Container>(find.ancestor(
            of: find.text('Pending'),
            matching: find.byType(Container),
          ).first)
          .decoration! as BoxDecoration;
      expect(tierDecoration.color, semantics.glassFillPressed,
          reason: 'the navy tone publishes glassFillPressed (white 14%); the '
              'pass-1 instrument assumed a hand-mixed onPrimary @ .14');
      expect(tierDecoration.border, isNull);
    });

    testWidgets('no foreground in the pinned summary is alpha-faded',
        (tester) async {
      // The 3.85:1 failure was NOT a wrong role — it was a right role faded to
      // `UIConstants.opacityHigh`. Guard the technique, not just the numbers.
      await tester.pumpWidget(themedHost(Scaffold(
        body: OrderChatPinnedSummary(
          summary: summary,
          counterpartName: 'Kamal Hajj',
          onViewSummary: () {},
        ),
      )));
      await tester.pump();
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();

      for (final text
          in tester.widgetList<Text>(find.byType(Text, skipOffstage: false))) {
        final color = text.style?.color;
        if (color == null) continue;
        expect(color.a, 1.0,
            reason: 'faded body text on a container is how this header fell '
                'below AA: "${text.data}" is at alpha ${color.a}');
      }
      for (final icon
          in tester.widgetList<Icon>(find.byType(Icon, skipOffstage: false))) {
        final color = icon.color;
        if (color == null) continue;
        expect(color.a, 1.0, reason: 'faded icon: ${icon.icon}');
      }
    });

    // MIDNIGHT (M2-16): the green success band is DEMOTED to the thread's own
    // quiet timeline chip, so the roles this row used to bind — successContainer
    // / onSuccessContainer / success — are gone by ruling, not by accident.
    testWidgets('offer-accepted banner is the demoted timeline chip',
        (tester) async {
      await tester.pumpWidget(themedHost(Scaffold(
        body: OfferAcceptedBanner(
          jeeberName: 'Kamal Hajj',
          onDismiss: () {},
          onStartActiveDelivery: () {},
        ),
      )));
      await tester.pump();
      final context = tester.element(find.byType(OfferAcceptedBanner));

      // No band: nothing inside the banner paints the success surface or a
      // full-bleed divider any more.
      final roles = AppTheme.light().extension<JeebColorRoles>()!;
      for (final box in tester.widgetList<DecoratedBox>(find.descendant(
        of: find.byType(OfferAcceptedBanner),
        matching: find.byType(DecoratedBox),
      ))) {
        final decoration = box.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.color, isNot(roles.successContainer));
          expect(decoration.border, isNull, reason: 'no divider band');
        }
      }
      expect(find.byType(JeebSystemChip), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Offer accepted!')).style!.color,
        JeebSystemChip.inkOf(context, JeebSystemChipTone.filled),
      );
      expect(
        tester
            .widget<Icon>(find.descendant(
              of: find.bySemanticsIdentifier('offer_accepted_dismiss_cta'),
              matching: find.byType(Icon),
            ))
            .color,
        Theme.of(context).colorScheme.onSecondaryContainer,
      );
      // The CTA is the kit's navy pill — R20 spends no orange here.
      expect(
        tester
            .widget<JeebCtaButton>(
                find.byKey(const Key('chat-start-active-delivery-cta')))
            .variant,
        JeebCtaVariant.primary,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Layer 2 — MEASUREMENT.
  // -------------------------------------------------------------------------
  group('measured WCAG 2.2 AA contrast', () {
    /// The rungs of `JeebMidnightField`'s base wash (sheet §8): the strip is
    /// translucent, so the navy UNDER it is part of the measurement. The
    /// lightest rung is the worst case for white ink, so all three are gated.
    List<MapEntry<String, Color>> fieldRungs(ColorScheme cs) => [
          MapEntry('page', cs.surfaceContainerLowest),
          MapEntry('surface', cs.surface),
          MapEntry('raised', cs.surfaceContainerHigh),
        ];

    List<_Row> rowsFor(ThemeData theme) {
      final cs = theme.colorScheme;
      final semantics = theme.extension<JeebSemanticColors>()!;
      final rows = <_Row>[];

      // ── HEADER 1 · pinned order summary (emphasis glass on the field) ─────
      for (final rung in fieldRungs(cs)) {
        final strip = blendToken(semantics.glassFillEmphasis, rung.value);
        final chip = blendToken(semantics.glassFillPressed, strip);
        final on = '@${rung.key}';
        rows.addAll([
          _Row('H1 order reference (fact) $on', cs.onPrimary, strip,
              kAaBodyText),
          _Row('H1 status label (fact) $on', cs.onPrimary, strip, kAaBodyText),
          _Row('H1 price (fact) $on', cs.onPrimary, strip, kAaBodyText),
          _Row('H1 party name (qualifier) $on', cs.onPrimary, strip,
              kAaBodyText),
          _Row('H1 view-summary link $on', cs.onPrimary, strip, kAaBodyText),
          _Row('H1 request description $on', cs.onPrimary, strip, kAaBodyText),
          _Row('H1 cash-on-delivery label $on', cs.onPrimary, strip,
              kAaBodyText),
          _Row('H1 expand/collapse icon $on', cs.onPrimary, strip,
              kAaLargeTextAndNonText),
          _Row('H1 request icon $on', cs.onPrimary, strip,
              kAaLargeTextAndNonText),
          _Row('H1 cash-on-delivery icon $on', cs.onPrimary, strip,
              kAaLargeTextAndNonText),
          // The chip fill is the card's published tone over the strip — a
          // translucent fill measured as if opaque is exactly the class of
          // instrument error this file exists to prevent.
          _Row('H1 ETA chip label $on', cs.onPrimary, chip, kAaBodyText),
          _Row('H1 tier chip label (Pending placeholder) $on', cs.onPrimary,
              chip, kAaBodyText),
          _Row('H1 Track pill fill vs strip (component boundary) $on',
              cs.onPrimary, strip, kAaLargeTextAndNonText),
          _Row('H1 Track pill label $on', cs.primary, cs.onPrimary,
              kAaBodyText),
        ]);
      }
      // NOT measured, deliberately: the Ø8 accent dot. It is decorative and
      // conveys nothing the status text beside it does not already say, so
      // SC 1.4.11 does not reach it. This exclusion is now an INFORMED one —
      // M6 measured it at 3.18 / 2.82 / 2.62:1 against the three rungs. Adding
      // it as a row would invent a requirement whose only fixes are lowering a
      // threshold or recolouring the board's one accent.
      // NOT measured, deliberately: the chip's own fill against the strip
      // (1.52–1.56:1). It is decoration behind its own label, not a control
      // boundary that conveys state. Its LABEL is measured, and that is the
      // requirement.

      // ── HEADER 2 · offer-accepted banner ─────────────────────────────────
      // MIDNIGHT (M2-16): the banner is DEMOTED to the thread's timeline chip
      // — no success band, no divider, a navy CTA pill.
      final list = cs.surface;
      rows.addAll([
        _Row('H2 chip label', semantics.inkSoft, cs.surfaceContainerHigh,
            kAaBodyText),
        _Row('H2 dismiss icon', cs.onSecondaryContainer, list,
            kAaLargeTextAndNonText),
        _Row('H2 CTA label on CTA fill', cs.onSecondary, cs.secondary,
            kAaBodyText),
        _Row('H2 CTA fill vs message list (component boundary)', cs.secondary,
            list, kAaLargeTextAndNonText),
      ]);
      return rows;
    }

    // Both factories return Midnight (token sheet §1) — the loop is now a
    // REGRESSION GUARD that a stray light path cannot reappear, not two themes.
    for (final entry in <String, ThemeData>{
      'AppTheme.light()': AppTheme.light(),
      'AppTheme.dark()': AppTheme.dark(),
    }.entries) {
      final rows = rowsFor(entry.value);

      test('${entry.key} — full element table, every row at or above its '
          'threshold', () {
        final buffer = StringBuffer()
          ..writeln('')
          ..writeln('CONTRAST TABLE — ${entry.key} (Midnight)')
          ..writeln('| element | foreground | background | ratio | min | '
              'verdict |')
          ..writeln('|---|---|---|---|---|---|');
        for (final r in rows) {
          buffer.writeln('| ${r.element} | ${hex(r.fg)} | ${hex(r.bg)} | '
              '${r.ratio.toStringAsFixed(2)}:1 | ${r.threshold}:1 | '
              '${r.pass ? "PASS" : "**FAIL**"} |');
        }
        // ignore: avoid_print
        print(buffer.toString());

        final failures = rows.where((r) => !r.pass).toList();
        expect(
          failures.map((r) => '${r.element} = '
              '${r.ratio.toStringAsFixed(2)}:1 (needs ${r.threshold}:1)'),
          isEmpty,
        );
      });
    }

    test('the two theme factories are the same Midnight scheme', () {
      expect(AppTheme.light().colorScheme, AppTheme.dark().colorScheme);
      expect(AppTheme.light().extension<JeebSemanticColors>(),
          AppTheme.dark().extension<JeebSemanticColors>());
    });
  });

  // -------------------------------------------------------------------------
  // NEGATIVE CONTROLS — proof the measurement can fail.
  // -------------------------------------------------------------------------
  group('negative controls — the instrument is able to report a FAIL', () {
    // `#D73B00` was `primaryContainer` in pass 1 and is `primary` now. Either
    // way it is the same hex, and it is the surface the unreadable line sat on.
    const shippedContainer = Color(0xFFD73B00);

    test('the pairing that actually shipped is BELOW AA when measured', () {
      // White at `UIConstants.opacityHigh` over the saturated orange — the
      // "Pay cash on delivery" line the owner could not read.
      final faded = blend(
        const Color(0xFFFFFFFF),
        shippedContainer,
        UIConstants.opacityHigh,
      );
      final ratio = contrastRatio(faded, shippedContainer);
      expect(ratio, lessThan(kAaBodyText),
          reason: 'if this ever passes, the measurement changed — not the UI');
      expect(ratio, closeTo(3.85, 0.05));
    });

    test('the unfaded pre-fix pairing was AA by only 0.15', () {
      expect(
        contrastRatio(const Color(0xFFFFFFFF), shippedContainer),
        closeTo(4.65, 0.05),
      );
    });

    test('the Midnight container pair has ~9:1 of headroom, so the same fade '
        'would still pass', () {
      // Re-cut for Midnight: `onPrimaryContainer`/`primaryContainer` are
      // `#FFB499` on `#431505` (sheet §1), which measures 9.08:1 — not the
      // 13:1 of the pass-1 tonal pair. The POINT of the control is unchanged:
      // enough headroom that the fade that broke this header cannot break it
      // again.
      final cs = AppTheme.light().colorScheme;
      expect(contrastRatio(cs.onPrimaryContainer, cs.primaryContainer),
          greaterThan(9));
      final faded = blend(
        cs.onPrimaryContainer,
        cs.primaryContainer,
        UIConstants.opacityHigh,
      );
      expect(contrastRatio(faded, cs.primaryContainer),
          greaterThanOrEqualTo(kAaBodyText));
    });

    test('the pass-1 two-ink refusal was a LIGHT/DARK argument: inkSoft now '
        'clears AA on the strip, mutedText runs out on the lightest rung', () {
      // The strip's file-top note refuses a muted qualifier ink because no role
      // was ≥AA on `primary` in BOTH themes. Midnight has ONE theme and the
      // strip is glass, so that particular constraint is gone — the kit's own
      // navy tone publishes `inkSoft` as the meta ink for exactly this surface.
      // The strip still hard-codes `onPrimary` everywhere; that is an adoption
      // gap M6 filed, not a contrast failure. Measured here so the decision is
      // made on numbers whenever it is revisited.
      final theme = AppTheme.light();
      final cs = theme.colorScheme;
      final semantics = theme.extension<JeebSemanticColors>()!;
      final rungs = <Color>[
        cs.surfaceContainerLowest,
        cs.surface,
        cs.surfaceContainerHigh,
      ];
      for (final rung in rungs) {
        final strip = blendToken(semantics.glassFillEmphasis, rung);
        expect(contrastRatio(semantics.inkSoft, strip),
            greaterThanOrEqualTo(kAaBodyText),
            reason: 'inkSoft on the strip over ${hex(rung)}');
      }
      // The lightest rung is where the muted role runs out — which is exactly
      // why `JeebSurfaceToneData.navy` publishes `inkSoft` and not `mutedText`.
      final raised =
          blendToken(semantics.glassFillEmphasis, cs.surfaceContainerHigh);
      expect(contrastRatio(semantics.mutedText, raised), lessThan(kAaBodyText),
          reason: 'if this ever passes the glass ladder moved — re-open the '
              'two-ink hierarchy on the strip');
    });

    test('the ratio function is calibrated at both ends', () {
      expect(
        contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        contrastRatio(const Color(0xFF123456), const Color(0xFF123456)),
        closeTo(1, 0.001),
      );
    });

    test('the FALSE comment this redesign removed: onSecondaryContainer on '
        'secondaryContainer was never "~3:1"', () {
      // `offer_accepted_banner.dart` carried a comment asserting the muted ink
      // on the navy container "is ~3:1 on navy and fails WCAG 2.2 AA", and used
      // `onPrimary` to work around it. Measured, it passes — 9.08:1 under
      // Midnight (`#B9C0F0` on `#10175E`).
      final cs = AppTheme.light().colorScheme;
      expect(
        contrastRatio(cs.onSecondaryContainer, cs.secondaryContainer),
        greaterThanOrEqualTo(kAaBodyText),
      );
    });

    test('Q-022 guard: the phantom pair the pass-1 instrument measured is not '
        'a colour this app paints', () {
      // `blend(onPrimary, primary, .14)` was the old chip background. Under
      // Midnight it evaluates to white-14%-over-orange = #DD5624 at 3.87:1.
      // Nothing renders it: the chip composites over emphasis glass, not over
      // `primary`. Keep the arithmetic pinned so the number in the M6 ruling
      // stays checkable, and keep the disproof beside it.
      final cs = AppTheme.light().colorScheme;
      final semantics = AppTheme.light().extension<JeebSemanticColors>()!;
      final phantom = blend(cs.onPrimary, cs.primary, 0.14);
      expect(hex(phantom), '#DD5624');
      expect(contrastRatio(cs.onPrimary, phantom), closeTo(3.87, 0.02));

      final real = blendToken(
        semantics.glassFillPressed,
        blendToken(semantics.glassFillEmphasis, cs.surfaceContainerHigh),
      );
      expect(contrastRatio(cs.onPrimary, real),
          greaterThanOrEqualTo(kAaBodyText),
          reason: 'the chip label as the app actually composites it');
    });
  });
}
