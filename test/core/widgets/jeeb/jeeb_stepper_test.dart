import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_stepper.dart';

/// The four frozen `tracking_step_*` identifiers, spelled exactly as
/// `order_tracking_stepper.dart:34-37` and `63_W1_TEST_PLAN §2.12` have them.
const List<String> _trackingIds = <String>[
  'tracking_step_ordered',
  'tracking_step_picked',
  'tracking_step_in_transit',
  'tracking_step_delivered',
];

const List<String> _trackingLabels = <String>[
  'Ordered',
  'Picked',
  'In transit',
  'Delivered',
];

Widget _wrap(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(child: SizedBox(width: 340, child: child)),
          ),
        ),
      ),
    ),
  );
}

/// Every [BoxDecoration] painted anywhere under the stepper.
Iterable<BoxDecoration> _decorations(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((DecoratedBox box) => box.decoration as BoxDecoration);

Iterable<BoxDecoration> _circles(WidgetTester tester) =>
    _decorations(tester).where((BoxDecoration d) => d.shape == BoxShape.circle);

/// Connectors and bar segments: rounded rectangles, never circles.
Iterable<BoxDecoration> _rules(WidgetTester tester) => _decorations(tester)
    .where((BoxDecoration d) => d.shape == BoxShape.rectangle)
    .where((BoxDecoration d) => d.borderRadius != null);

ColorScheme get _scheme => AppTheme.midnight().colorScheme;

JeebColorRoles get _roles =>
    AppTheme.midnight().extension<JeebColorRoles>() ??
    JeebColorRoles.midnight();

JeebSemanticColors get _semantics =>
    AppTheme.midnight().extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

Color get _accent => _roles.accent;

Color get _mutedText => _semantics.mutedText;

/// Token sheet §1/§3 — the expected Midnight values, spelled out rather than
/// read back off the implementation.
const Color _periwinkle = Color(0xFF8A93D8);
const Color _pageNavy = Color(0xFF070C33);
const Color _orange = Color(0xFFD73B00);
const Color _glassFillPressed = Color(0x24FFFFFF);
const Color _glassBorderStrong = Color(0x29FFFFFF);

TextStyle _labelStyleOf(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!;

void main() {
  group('JeebStepper — node form (screen 12)', () {
    testWidgets('renders one node per label and n-1 connectors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      for (final String label in _trackingLabels) {
        expect(find.text(label), findsOneWidget);
      }
      // 4 nodes + the active node's white core = 5 circles.
      expect(_circles(tester).length, 5);
      expect(_rules(tester).length, 3);
    });

    testWidgets('per-step Semantics carries identifier, value and selected — '
        'the frozen tracking_lifecycle_bodies_test contract', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      for (var i = 0; i < _trackingIds.length; i++) {
        final Finder finder = find.bySemanticsIdentifier(_trackingIds[i]);
        expect(finder, findsOneWidget, reason: _trackingIds[i]);
        final SemanticsNode node = tester.getSemantics(finder);
        expect(node.identifier, _trackingIds[i]);
        expect(node.value, _trackingLabels[i]);
        expect(
          node.flagsCollection.isSelected,
          i == 2 ? Tristate.isTrue : Tristate.isFalse,
          reason: 'selected is reported in BOTH polarities, never omitted',
        );
      }

      handle.dispose();
    });

    testWidgets('the P6/A5 relabel travels on value, not on the identifier', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            // Screen 12 swaps the third LABEL for "At Door" while the third
            // IDENTIFIER stays `tracking_step_in_transit`.
            labels: <String>['Ordered', 'Picked', 'At Door', 'Delivered'],
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('tracking_step_in_transit'),
      );
      expect(node.value, 'At Door');
      expect(find.bySemanticsIdentifier('tracking_step_at_door'), findsNothing);

      handle.dispose();
    });

    testWidgets('done nodes are periwinkle discs with a 14px navy check', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      final List<BoxDecoration> done = _circles(tester)
          .where((BoxDecoration d) => d.color == _scheme.secondary)
          .toList();
      expect(done.length, 2);
      expect(done.first.color, _periwinkle);
      expect(done.first.border, isNull);

      expect(find.byIcon(Icons.check), findsNWidgets(2));
      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.check).first);
      expect(icon.size, JeebStepper.checkSize);
      expect(icon.color, _scheme.onSecondary);
      expect(icon.color, _pageNavy);
      expect(
        tester.getSize(find.byIcon(Icons.check).first),
        const Size.square(JeebStepper.nodeSize),
      );
    });

    testWidgets('the active node is accent + glowRest + a Ø8 white core', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      final List<BoxDecoration> active = _circles(tester)
          .where((BoxDecoration d) => d.color == _accent)
          .toList();
      expect(active.length, 1);
      expect(active.single.color, _orange);
      // Resting (pulseActive defaults to false) it is byte-identical to the
      // Midnight token — the kit never restates `rgba(215,59,0,.18) 0 0 30`.
      expect(active.single.boxShadow, JeebShadows.glowRest);

      final List<BoxDecoration> cores = _circles(tester)
          .where((BoxDecoration d) => d.color == _roles.onAccent)
          .toList();
      expect(cores.length, 1, reason: 'the Ø8 core is the only white circle');
    });

    testWidgets('pending nodes are a 2px glassBorderStrong ring, no fill',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      final List<BoxDecoration> pending = _circles(tester)
          .where((BoxDecoration d) => d.border != null)
          .toList();
      expect(pending.length, 1);
      expect(pending.single.color, isNull);
      final BorderSide side = (pending.single.border! as Border).top;
      expect(side.color, _semantics.glassBorderStrong);
      expect(side.color, _glassBorderStrong);
      expect(side.width, JeebStepper.pendingRingWidth);
    });

    testWidgets('connector i is periwinkle exactly while step i-1 is done', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      final List<BoxDecoration> rules = _rules(tester).toList();
      expect(rules.length, 3);
      expect(rules[0].color, _scheme.secondary);
      expect(rules[1].color, _periwinkle);
      expect(rules[2].color, _glassFillPressed);
      expect(
        rules.first.borderRadius,
        BorderRadius.circular(JeebStepper.connectorRadius),
      );
    });

    testWidgets('label ink and weight differ per state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );

      // Board: only the ACTIVE label is orange; done/pending both read #8A93D8
      // and separate on weight alone.
      final TextStyle done = _labelStyleOf(tester, 'Ordered');
      expect(done.color, _scheme.secondary);
      expect(done.color, _periwinkle);
      expect(done.fontWeight, FontWeight.w700);
      expect(done.fontSize, 10.5);

      final TextStyle active = _labelStyleOf(tester, 'In transit');
      expect(active.color, _accent);
      expect(active.color, _orange);
      expect(active.fontWeight, FontWeight.w800);

      final TextStyle pending = _labelStyleOf(tester, 'Delivered');
      expect(pending.color, _mutedText);
      expect(pending.color, _periwinkle);
      expect(pending.fontWeight, FontWeight.w600);
    });

    testWidgets('out-of-range currentIndex degrades to all-pending / all-done',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: -1,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );
      expect(
        _circles(tester).where((BoxDecoration d) => d.border != null).length,
        4,
      );
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 4,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );
      expect(find.byIcon(Icons.check), findsNWidgets(4));
      expect(
        _rules(tester).where((BoxDecoration d) => d.color == _scheme.secondary)
            .length,
        3,
      );
    });

    testWidgets('adds no root Semantics node unless asked', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 0,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
        ),
      );
      // Screen 12 owns `tracking_stepper` at its own call site; the kit must
      // not slip an extra node between it and the per-step nodes.
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 0,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
            identifier: 'tracking_stepper',
          ),
        ),
      );
      expect(find.bySemanticsIdentifier('tracking_stepper'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('tracking_step_delivered'),
        findsOneWidget,
        reason: 'explicitChildNodes must keep the per-step ids addressable',
      );

      handle.dispose();
    });

    testWidgets('survives 200% text without an overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('JeebStepper — pulse', () {
    testWidgets('pulseActive swells the glow and then settles back on the token',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
            pulseActive: true,
          ),
        ),
      );

      double spread() => _circles(tester)
          .firstWhere((BoxDecoration d) => d.color == _accent)
          .boxShadow!
          .single
          .spreadRadius;

      final double resting = JeebShadows.glowRest.first.spreadRadius;
      await tester.pump(JeebStepper.pulsePeriod ~/ 2);
      expect(spread(), greaterThan(resting));

      // Bounded on purpose: an endless ticker would deadlock every
      // `pumpAndSettle` in the app.
      await tester.pumpAndSettle();
      expect(spread(), resting);
    });

    testWidgets('reduce-motion skips the pulse entirely', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
            pulseActive: true,
          ),
          disableAnimations: true,
        ),
      );

      for (var i = 0; i < 4; i++) {
        expect(
          _circles(tester)
              .firstWhere((BoxDecoration d) => d.color == _accent)
              .boxShadow,
          JeebShadows.glowRest,
        );
        await tester.pump(JeebStepper.pulsePeriod ~/ 3);
      }
    });

    testWidgets('advancing a step replays the pulse on the new active node', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 1,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
            pulseActive: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
            pulseActive: true,
          ),
        ),
      );
      await tester.pump(JeebStepper.pulsePeriod ~/ 2);

      expect(
        _circles(tester)
            .firstWhere((BoxDecoration d) => d.color == _accent)
            .boxShadow!
            .single
            .spreadRadius,
        greaterThan(JeebShadows.glowRest.first.spreadRadius),
      );
      await tester.pumpAndSettle();
    });
  });

  group('JeebStepper.bars — bar form (screen 18)', () {
    testWidgets('renders stepCount segments with passed/active/pending fills', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const JeebStepper.bars(stepCount: 5, currentIndex: 3)),
      );

      final List<BoxDecoration> bars = _rules(tester).toList();
      expect(bars.length, 5);
      expect(bars[0].color, _scheme.secondary);
      expect(bars[1].color, _periwinkle);
      expect(bars[2].color, _periwinkle);
      expect(bars[3].color, _orange);
      expect(bars[4].color, _semantics.glassFillPressed);
      expect(bars[4].color, _glassFillPressed);
      expect(
        bars.first.borderRadius,
        BorderRadius.circular(JeebStepper.barRadius),
      );
    });

    testWidgets('doneInk defaults to periwinkle — 18\'s fill, unchanged', (
      WidgetTester tester,
    ) async {
      const JeebStepper bars = JeebStepper.bars(stepCount: 4, currentIndex: 2);
      expect(bars.doneInk, JeebStepperDoneInk.periwinkle);

      await tester.pumpWidget(_wrap(bars));
      final List<BoxDecoration> rules = _rules(tester).toList();
      expect(rules[0].color, _periwinkle);
      expect(rules[1].color, _periwinkle);
      expect(rules[2].color, _orange);
      expect(rules[3].color, _glassFillPressed);
    });

    testWidgets('doneInk.accent runs R3\'s orange fill through the active bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper.bars(
            stepCount: 4,
            currentIndex: 2,
            doneInk: JeebStepperDoneInk.accent,
          ),
        ),
      );

      final List<BoxDecoration> rules = _rules(tester).toList();
      // R3: every segment up to AND INCLUDING the active one is orange…
      expect(rules[0].color, _orange);
      expect(rules[1].color, _orange);
      expect(rules[2].color, _orange);
      expect(rules[0].color, _roles.accent);
      expect(rules[3].color, _glassFillPressed);
      // …and the active one alone still carries the glow.
      expect(rules[0].boxShadow, isNull);
      expect(rules[1].boxShadow, isNull);
      expect(rules[2].boxShadow, JeebStepper.barGlow);
      expect(rules[3].boxShadow, isNull);
    });

    testWidgets('doneInk leaves the node form\'s connectors periwinkle', (
      WidgetTester tester,
    ) async {
      const JeebStepper nodes = JeebStepper(
        currentIndex: 2,
        labels: _trackingLabels,
        stepIdentifiers: _trackingIds,
      );
      expect(nodes.doneInk, JeebStepperDoneInk.periwinkle);

      await tester.pumpWidget(_wrap(nodes));
      final List<BoxDecoration> rules = _rules(tester).toList();
      expect(rules[0].color, _scheme.secondary);
      expect(rules[1].color, _scheme.secondary);
      expect(rules[2].color, _glassFillPressed);
    });

    testWidgets('the active segment carries glowDot, not the node halo',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const JeebStepper.bars(stepCount: 4, currentIndex: 3)),
      );

      final BoxDecoration active =
          _rules(tester).firstWhere((BoxDecoration d) => d.color == _accent);
      // Board `0 0 14px rgba(215,59,0,.7)` snaps to the live-dot glow.
      expect(active.boxShadow, JeebShadows.glowDot);
      expect(active.boxShadow, JeebStepper.barGlow);
      expect(active.boxShadow, isNot(JeebShadows.glowRest));

      final List<BoxDecoration> quiet =
          _rules(tester).where((BoxDecoration d) => d.color != _accent).toList();
      expect(quiet.every((BoxDecoration d) => d.boxShadow == null), isTrue);
    });

    testWidgets('segments are 5px tall with a 6px gap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const JeebStepper.bars(stepCount: 4, currentIndex: 1)),
      );
      expect(
        tester.getSize(find.byType(JeebStepper)).height,
        JeebStepper.barHeight,
      );
      expect(
        tester.widgetList<SizedBox>(find.byType(SizedBox)).where(
              (SizedBox box) => box.width == JeebStepper.barGap,
            ).length,
        3,
      );
    });

    testWidgets('segmentKeys re-home 18\'s frozen ValueKeys onto the segments',
        (WidgetTester tester) async {
      const List<Key> keys = <Key>[
        ValueKey<String>('active_delivery_stage_ordered_completed'),
        ValueKey<String>('active_delivery_stage_picked_completed'),
        ValueKey<String>('active_delivery_stage_intransit_current'),
        ValueKey<String>('active_delivery_stage_atdoor_upcoming'),
      ];
      await tester.pumpWidget(
        _wrap(
          const JeebStepper.bars(
            stepCount: 4,
            currentIndex: 2,
            segmentKeys: keys,
          ),
        ),
      );

      for (final Key key in keys) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(
        tester.getSize(find.byKey(keys.first)).height,
        JeebStepper.barHeight,
      );
    });

    testWidgets('bars emit no semantics — 18 owns its labels feature-side', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          const JeebStepper.bars(
            stepCount: 4,
            currentIndex: 2,
            identifier: 'active_delivery_progress',
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(JeebStepper),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('active_delivery_progress'),
      );
      expect(node.childrenCount, 0);

      handle.dispose();
    });
  });

  group('JeebStepper — Midnight metrics', () {
    test('radii and segment geometry are the board values', () {
      expect(JeebStepper.barRadius, JeebRadii.sm);
      expect(JeebStepper.connectorRadius, JeebRadii.sm);
      expect(JeebRadii.sm, 9);
      expect(JeebStepper.barHeight, 5);
      expect(JeebStepper.barGap, 6);
      expect(JeebStepper.nodeSize, 26);
    });
  });

  group('JeebStepper — RTL', () {
    testWidgets('node progress reads start→end in both directions', (
      WidgetTester tester,
    ) async {
      Future<List<double>> centres(TextDirection direction) async {
        await tester.pumpWidget(
          _wrap(
            const JeebStepper(
              currentIndex: 2,
              labels: _trackingLabels,
              stepIdentifiers: _trackingIds,
            ),
            direction: direction,
          ),
        );
        return <double>[
          for (final String label in _trackingLabels)
            tester.getCenter(find.text(label)).dx,
        ];
      }

      final List<double> ltr = await centres(TextDirection.ltr);
      expect(ltr[0], lessThan(ltr[1]));
      expect(ltr[1], lessThan(ltr[2]));
      expect(ltr[2], lessThan(ltr[3]));

      final List<double> rtl = await centres(TextDirection.rtl);
      expect(rtl[0], greaterThan(rtl[1]));
      expect(rtl[1], greaterThan(rtl[2]));
      expect(rtl[2], greaterThan(rtl[3]));

      // A true mirror, not a re-layout: step 0 in RTL sits where step 3 sat.
      expect(rtl[0], moreOrLessEquals(ltr[3], epsilon: 0.01));
      expect(rtl[3], moreOrLessEquals(ltr[0], epsilon: 0.01));
    });

    testWidgets('the passed connectors stay on the START side under RTL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
          direction: TextDirection.rtl,
        ),
      );

      // Painted order is still index order; geometry is what mirrors.
      final List<BoxDecoration> rules = _rules(tester).toList();
      expect(rules[0].color, _scheme.secondary);
      expect(rules[2].color, _semantics.glassFillPressed);

      final Rect first = tester.getRect(find.text('Ordered'));
      final Rect last = tester.getRect(find.text('Delivered'));
      expect(
        first.center.dx,
        greaterThan(last.center.dx),
        reason: 'Ordered must sit at the RTL start edge',
      );
    });

    testWidgets('the active node keeps its Ø26 geometry under RTL', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const JeebStepper(
            currentIndex: 2,
            labels: _trackingLabels,
            stepIdentifiers: _trackingIds,
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(_circles(tester).where((BoxDecoration d) => d.color == _accent)
          .length, 1);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('bar progress mirrors too', (WidgetTester tester) async {
      const List<Key> keys = <Key>[
        ValueKey<String>('seg_0'),
        ValueKey<String>('seg_1'),
        ValueKey<String>('seg_2'),
        ValueKey<String>('seg_3'),
      ];
      const Widget bars = JeebStepper.bars(
        stepCount: 4,
        currentIndex: 2,
        segmentKeys: keys,
      );

      await tester.pumpWidget(_wrap(bars));
      final double ltrFirst = tester.getCenter(find.byKey(keys.first)).dx;
      final double ltrLast = tester.getCenter(find.byKey(keys.last)).dx;
      expect(ltrFirst, lessThan(ltrLast));

      await tester.pumpWidget(_wrap(bars, direction: TextDirection.rtl));
      final double rtlFirst = tester.getCenter(find.byKey(keys.first)).dx;
      final double rtlLast = tester.getCenter(find.byKey(keys.last)).dx;
      expect(rtlFirst, greaterThan(rtlLast));
      expect(rtlFirst, moreOrLessEquals(ltrLast, epsilon: 0.01));
    });
  });
}
