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
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
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

      // Header surface + boundary.
      final box = tester.widget<DecoratedBox>(find
          .descendant(
            of: find.byType(OrderChatPinnedSummary),
            matching: find.byType(DecoratedBox),
          )
          .first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, cs.surfaceContainerHigh,
          reason: 'the header must be a tonal surface, not a chroma slab');
      expect((decoration.border! as Border).bottom.color, cs.outline);

      // The reference heading.
      expect(
        tester.widget<Text>(find.text('ORD-23470')).style!.color,
        cs.onSurface,
      );

      // The single accent: the status chip.
      final statusDecoration = tester
          .widget<Container>(find.ancestor(
            of: find.text('In transit'),
            matching: find.byType(Container),
          ).first)
          .decoration! as BoxDecoration;
      expect(statusDecoration.color, cs.primaryContainer);
      expect(
        (statusDecoration.border! as Border).top.color,
        cs.onPrimaryContainer,
      );
      expect(
        tester.widget<Text>(find.text('In transit')).style!.color,
        cs.onPrimaryContainer,
      );

      // The amount is emphasis in the on-surface role, not a second accent.
      expect(
        tester.widget<Text>(find.text(r'$12.00')).style!.color,
        cs.onSurface,
      );

      // The disclosure control's icon.
      expect(
        tester
            .widget<Icon>(find.descendant(
              of: find.bySemanticsIdentifier('order_chat_summary_expand'),
              matching: find.byType(Icon),
            ))
            .color,
        cs.onSurfaceVariant,
      );

      // Expanded content: the cash reminder — the element the owner reported
      // as unreadable. Full-strength role, no alpha.
      await tester.tap(find.bySemanticsIdentifier('order_chat_summary_expand'));
      await tester.pump();
      expect(
        tester.widget<Text>(find.text('Pay cash on delivery')).style!.color,
        cs.onSurfaceVariant,
      );
      expect(
        tester.widget<Text>(find.text('View summary')).style!.color,
        cs.primary,
      );
      expect(
        tester.widget<Text>(find.text('Kamal Hajj')).style!.color,
        cs.onSurfaceVariant,
      );

      // A NEUTRAL chip (disclosed by the expand): surfaceContainerLowest under
      // an `outline` hairline.
      final tierDecoration = tester
          .widget<Container>(find.ancestor(
            of: find.text('Pending'),
            matching: find.byType(Container),
          ).first)
          .decoration! as BoxDecoration;
      expect(tierDecoration.color, cs.surfaceContainerLowest);
      expect((tierDecoration.border! as Border).top.color, cs.outline);
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

    testWidgets('offer-accepted banner', (tester) async {
      await tester.pumpWidget(themedHost(Scaffold(
        body: OfferAcceptedBanner(
          jeeberName: 'Kamal Hajj',
          onDismiss: () {},
          onStartActiveDelivery: () {},
        ),
      )));
      await tester.pump();
      final theme = AppTheme.light();
      final roles = theme.extension<JeebColorRoles>()!;

      final box = tester.widget<DecoratedBox>(find
          .descendant(
            of: find.byType(OfferAcceptedBanner),
            matching: find.byType(DecoratedBox),
          )
          .first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, roles.successContainer,
          reason: 'the banner is a SUCCESS surface, not the brand navy slab');
      expect((decoration.border! as Border).bottom.color, roles.success);
      expect(
        tester.widget<Text>(find.text('Offer accepted!')).style!.color,
        roles.onSuccessContainer,
      );
      expect(
        tester
            .widget<Icon>(find.descendant(
              of: find.bySemanticsIdentifier('offer_accepted_dismiss_cta'),
              matching: find.byType(Icon),
            ))
            .color,
        roles.onSuccessContainer,
      );
      // The CTA keeps the OMDS primary treatment (primary / onPrimary).
      expect(
        tester
            .widget<OmdsPrimaryButton>(
                find.byKey(const Key('chat-start-active-delivery-cta')))
            .variant,
        OmdsButtonVariant.primary,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Layer 2 — MEASUREMENT.
  // -------------------------------------------------------------------------
  group('measured WCAG 2.2 AA contrast', () {
    List<_Row> rowsFor(ThemeData theme) {
      final cs = theme.colorScheme;
      final roles = theme.extension<JeebColorRoles>()!;
      final header = cs.surfaceContainerHigh;
      final chip = cs.surfaceContainerLowest;
      final accentChip = cs.primaryContainer;
      final banner = roles.successContainer;
      final list = cs.surface;
      return <_Row>[
        // ── HEADER 1 · pinned order summary ─────────────────────────────────
        _Row('H1 order reference (titleSmall bold)', cs.onSurface, header,
            kAaBodyText),
        _Row('H1 status chip label', cs.onPrimaryContainer, accentChip,
            kAaBodyText),
        _Row('H1 status chip icon', cs.onPrimaryContainer, accentChip,
            kAaLargeTextAndNonText),
        _Row('H1 status chip border vs header', cs.onPrimaryContainer, header,
            kAaLargeTextAndNonText),
        _Row('H1 price chip label', cs.onSurface, chip, kAaBodyText),
        _Row('H1 price chip icon', cs.onSurface, chip, kAaLargeTextAndNonText),
        _Row('H1 neutral chip border vs header', cs.outline, header,
            kAaLargeTextAndNonText),
        _Row('H1 neutral chip border vs chip fill', cs.outline, chip,
            kAaLargeTextAndNonText),
        _Row('H1 expand/collapse icon', cs.onSurfaceVariant, header,
            kAaLargeTextAndNonText),
        _Row('H1 party name (bodyMedium)', cs.onSurfaceVariant, header,
            kAaBodyText),
        _Row('H1 view-summary link (labelLarge)', cs.primary, header,
            kAaBodyText),
        _Row('H1 request description (bodyMedium)', cs.onSurface, header,
            kAaBodyText),
        _Row('H1 request icon', cs.onSurfaceVariant, header,
            kAaLargeTextAndNonText),
        _Row('H1 ETA chip label', cs.onSurface, chip, kAaBodyText),
        _Row('H1 tier chip label', cs.onSurface, chip, kAaBodyText),
        _Row('H1 cash-on-delivery label (labelMedium)', cs.onSurfaceVariant,
            header, kAaBodyText),
        _Row('H1 cash-on-delivery icon', cs.onSurfaceVariant, header,
            kAaLargeTextAndNonText),
        _Row('H1 bottom divider vs message list', cs.outline, list,
            kAaLargeTextAndNonText),
        _Row('H1 bottom divider vs header', cs.outline, header,
            kAaLargeTextAndNonText),
        // ── HEADER 2 · offer-accepted banner ────────────────────────────────
        _Row('H2 success icon', roles.onSuccessContainer, banner,
            kAaLargeTextAndNonText),
        _Row('H2 title (labelLarge bold)', roles.onSuccessContainer, banner,
            kAaBodyText),
        _Row('H2 body sentence (bodySmall)', roles.onSuccessContainer, banner,
            kAaBodyText),
        _Row('H2 dismiss icon', roles.onSuccessContainer, banner,
            kAaLargeTextAndNonText),
        _Row('H2 CTA label on CTA fill', cs.onPrimary, cs.primary, kAaBodyText),
        _Row('H2 CTA fill vs banner (component boundary)', cs.primary, banner,
            kAaLargeTextAndNonText),
        _Row('H2 bottom divider vs banner', roles.success, banner,
            kAaLargeTextAndNonText),
        _Row('H2 bottom divider vs message list', roles.success, list,
            kAaLargeTextAndNonText),
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
