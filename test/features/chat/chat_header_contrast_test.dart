/// b02 chat-header redesign — the MEASURED contrast gate for both chat headers.
///
/// The owner's verdict on the previous headers was "does not comply with
/// material design system concepts neither accessibility neither contrast".
/// This file is the contrast half, and it is deliberately built in two layers,
/// because either layer alone is an instrument that can lie:
///
///  1. **Binding.** Pump the real widgets in the real [AppTheme] and read the
///     colours the widgets ACTUALLY paint out of the rendered tree. Without
///     this, the table below is a table about a design document.
///  2. **Measurement.** Compute the WCAG 2.2 ratio for every text and icon
///     element and every component boundary, in light AND dark, and fail below
///     threshold. Without this, the binding is just "it uses some role".
///
/// Plus a **negative control** (`contrastRatio` must be able to FAIL): the
/// pairing that actually shipped — white faded to `UIConstants.opacityHigh`
/// over the old saturated `primaryContainer` — is asserted to be BELOW AA. A
/// checker that has never been shown failing is not a checker.
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

      // redesign-2026-08: the shell is the kit's NAVY card. The M3 argument
      // that produced the previous tonal shell has not been reversed, it is
      // satisfied differently — one accent (the Ø8 orange dot), no alpha-faded
      // foreground, and the shadow (not a hairline) as the boundary, which a
      // navy card on a white thread does not need help with.
      final box = tester.widget<DecoratedBox>(find
          .descendant(
            of: find.byType(OrderChatPinnedSummary),
            matching: find.byType(DecoratedBox),
          )
          .first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, cs.primary,
          reason: 'the strip is the board navy card');
      expect(decoration.border, isNull,
          reason: 'R7 — on navy the shadow IS the boundary');
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

      // The three collapsed FACTS are white — the fact ink on navy.
      for (final label in const ['ORD-23470', 'In transit', r'$12.00']) {
        expect(
          tester.widget<Text>(find.text(label)).style!.color,
          cs.onPrimary,
          reason: '$label is a locked fact and reads at full strength',
        );
      }

      // Every ink on the navy card is `onPrimary` — see the ink note at the
      // top of `order_chat_pinned_summary.dart`. Hierarchy is type size and
      // weight, never colour, because no muted role survives BOTH themes.
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
      // The view-summary link is a FACT on navy — white, and still underlined
      // so the affordance survives without a colour cue.
      final link = tester.widget<Text>(find.text('View summary'));
      expect(link.style!.color, cs.onPrimary);
      expect(link.style!.decoration, TextDecoration.underline);
      final party = tester.widget<Text>(find.text('Kamal Hajj'));
      expect(party.style!.color, cs.onPrimary);
      expect(party.style!.fontWeight, isNot(FontWeight.w700),
          reason: 'a qualifier is separated from a fact by WEIGHT, not ink');

      // A summary chip (disclosed by the expand): the fill comes from the navy
      // card's OWN published tone, never a hand-mixed alpha, and it carries no
      // border — a translucent white capsule on navy is already a boundary.
      final tierDecoration = tester
          .widget<Container>(find.ancestor(
            of: find.text('Pending'),
            matching: find.byType(Container),
          ).first)
          .decoration! as BoxDecoration;
      expect(tierDecoration.color, cs.onPrimary.withValues(alpha: 0.14));
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
    List<_Row> rowsFor(ThemeData theme) {
      final cs = theme.colorScheme;
      // redesign-2026-08: HEADER 1 is the navy strip. Its "chip fill" is the
      // kit tone's `onPrimary @ .14` OVER the navy, so the measurement blends
      // it — a translucent fill measured as if opaque is exactly the class of
      // instrument error this file exists to prevent.
      final header = cs.primary;
      final chip = blend(cs.onPrimary, header, 0.14);
      final semantics = theme.extension<JeebSemanticColors>()!;
      final list = cs.surface;
      return <_Row>[
        // ── HEADER 1 · pinned order summary (navy) ──────────────────────────
        _Row('H1 order reference (fact)', cs.onPrimary, header, kAaBodyText),
        _Row('H1 status label (fact)', cs.onPrimary, header, kAaBodyText),
        _Row('H1 price (fact)', cs.onPrimary, header, kAaBodyText),
        _Row('H1 Track pill label', cs.primary, cs.onPrimary, kAaBodyText),
        _Row('H1 Track pill fill vs strip (component boundary)', cs.onPrimary,
            header, kAaLargeTextAndNonText),
        _Row('H1 expand/collapse icon', cs.onPrimary, header,
            kAaLargeTextAndNonText),
        _Row('H1 party name (qualifier)', cs.onPrimary, header, kAaBodyText),
        _Row('H1 view-summary link', cs.onPrimary, header, kAaBodyText),
        _Row('H1 request description', cs.onPrimary, header, kAaBodyText),
        _Row('H1 request icon', cs.onPrimary, header, kAaLargeTextAndNonText),
        _Row('H1 ETA chip label', cs.onPrimary, chip, kAaBodyText),
        _Row('H1 tier chip label (Pending placeholder)', cs.onPrimary, chip,
            kAaBodyText),
        _Row('H1 cash-on-delivery label', cs.onPrimary, header, kAaBodyText),
        _Row('H1 cash-on-delivery icon', cs.onPrimary, header,
            kAaLargeTextAndNonText),
        // The two-ink hierarchy the brief prescribed (qualifiers in
        // `onSecondaryContainer`) is REFUSED and this is the measurement that
        // refuses it: it is 4.55:1 in light and 1.32:1 in DARK, where the navy
        // card inverts to a pale periwinkle. Asserted as a negative control
        // below so the refusal cannot quietly be undone.
        // NOT measured, deliberately: the Ø8 accent dot. It is decorative and
        // conveys nothing the status text beside it does not already say, so
        // SC 1.4.11 does not reach it. Adding it as a row would be inventing a
        // requirement, and the only ways to pass it would be to lower the
        // threshold or to recolour the board's one accent.
        // ── HEADER 2 · offer-accepted banner ────────────────────────────────
        // MIDNIGHT (M2-16): the banner is DEMOTED to the thread's timeline chip
        // — no success band, no divider, a navy CTA pill. The rows below
        // measure what it paints now; the retired ones measured a surface that
        // no longer exists.
        _Row('H2 chip label', semantics.inkSoft, cs.surfaceContainerHigh,
            kAaBodyText),
        // NOT measured, deliberately (same reasoning as the Ø8 accent dot
        // above): the chip's tonal fill is decoration behind its own label,
        // not a control boundary that conveys state, so SC 1.4.11 does not
        // reach it. Its LABEL is measured, and that is the requirement.
        _Row('H2 dismiss icon', cs.onSecondaryContainer, list,
            kAaLargeTextAndNonText),
        _Row('H2 CTA label on CTA fill', cs.onSecondary, cs.secondary,
            kAaBodyText),
        _Row('H2 CTA fill vs message list (component boundary)', cs.secondary,
            list, kAaLargeTextAndNonText),
      ];
    }

    for (final entry in <String, ThemeData>{
      'LIGHT': AppTheme.light(),
      'DARK': AppTheme.dark(),
    }.entries) {
      final rows = rowsFor(entry.value);

      test('${entry.key} — full element table, every row at or above its '
          'threshold', () {
        final buffer = StringBuffer()
          ..writeln('')
          ..writeln('CONTRAST TABLE — ${entry.key} theme')
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
  });

  // -------------------------------------------------------------------------
  // NEGATIVE CONTROLS — proof the measurement can fail.
  // -------------------------------------------------------------------------
  group('negative controls — the instrument is able to report a FAIL', () {
    const oldPrimaryContainer = Color(0xFFD73B00); // the pre-fix role value

    test('the pairing that actually shipped is BELOW AA when measured', () {
      // White at `UIConstants.opacityHigh` over the old saturated container —
      // the "Pay cash on delivery" line the owner could not read.
      final faded = blend(
        const Color(0xFFFFFFFF),
        oldPrimaryContainer,
        UIConstants.opacityHigh,
      );
      final ratio = contrastRatio(faded, oldPrimaryContainer);
      expect(ratio, lessThan(kAaBodyText),
          reason: 'if this ever passes, the measurement changed — not the UI');
      expect(ratio, closeTo(3.85, 0.05));
    });

    test('the unfaded pre-fix pairing was AA by only 0.15', () {
      expect(
        contrastRatio(const Color(0xFFFFFFFF), oldPrimaryContainer),
        closeTo(4.65, 0.05),
      );
    });

    test('the fixed container pair has ~13:1 of headroom, so the same fade '
        'would now still pass', () {
      final cs = AppTheme.light().colorScheme;
      expect(contrastRatio(cs.onPrimaryContainer, cs.primaryContainer),
          greaterThan(13));
      final faded = blend(
        cs.onPrimaryContainer,
        cs.primaryContainer,
        UIConstants.opacityHigh,
      );
      expect(contrastRatio(faded, cs.primaryContainer),
          greaterThanOrEqualTo(kAaBodyText));
    });

    test('the REFUSED two-ink strip hierarchy really is below AA in dark', () {
      // The brief asked for qualifiers in `onSecondaryContainer` on the navy
      // card and quoted 4.59:1. That is the LIGHT reading only.
      final light = AppTheme.light().colorScheme;
      final dark = AppTheme.dark().colorScheme;
      expect(contrastRatio(light.onSecondaryContainer, light.primary),
          greaterThanOrEqualTo(kAaBodyText));
      expect(contrastRatio(dark.onSecondaryContainer, dark.primary),
          lessThan(kAaLargeTextAndNonText),
          reason: 'if this ever passes, re-open the two-ink hierarchy — until '
              'then a single onPrimary ink is the only pairing that holds in '
              'both themes');
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
      // `offer_accepted_banner.dart` carried a comment asserting #777FC0 on the
      // navy container "is ~3:1 on navy and fails WCAG 2.2 AA", and used
      // `onPrimary` to work around it. Measured, it passes.
      final cs = AppTheme.light().colorScheme;
      expect(
        contrastRatio(cs.onSecondaryContainer, cs.secondaryContainer),
        greaterThanOrEqualTo(kAaBodyText),
      );
    });
  });
}
