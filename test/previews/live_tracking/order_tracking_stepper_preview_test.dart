// Render tests for the OrderTrackingStepper previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One deviation from that template, on purpose, and the same one
// `delivery_confirm_illustration_preview_test.dart` makes. The widget renders
// the SAME four labels at every step — only the third changes, and only at the
// door — so `expectedText` binds to each preview's caption, which is preview
// scaffolding rather than widget output. On its own that would be exactly the
// weak assertion the harness warns about. The per-state contract is therefore
// asserted underneath, from the three things that DO vary: the progress
// fraction handed to the OMDS bar, the done/active/pending icon census, and
// which step carries the `selected` semantics flag.

// `flagsCollection.isSelected` is a tristate, and `Tristate` is only reachable
// from dart:ui — `package:flutter/semantics.dart` imports it without exporting.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/order_tracking_stepper.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Ordered': orderTrackingStepperOrdered,
  'Picked': orderTrackingStepperPicked,
  'In transit': orderTrackingStepperInTransit,
  'At Door': orderTrackingStepperAtDoor,
  'Delivered': orderTrackingStepperDelivered,
  'Delivered on 320pt': orderTrackingStepperCompactPhone,
};

/// The 0-based current step each preview is built with. This is the state the
/// caption claims, restated as the number the widget is actually given.
const Map<String, int> _currentStep = <String, int>{
  'Ordered': 0,
  'Picked': 1,
  'In transit': 2,
  'At Door': 2,
  'Delivered': 3,
  'Delivered on 320pt': 3,
};

/// The four Semantics identifiers, in blueprint order (D70). Coined in
/// 63_W1_TEST_PLAN §2.12 and addressed by Maestro, so they are a contract.
const List<String> _stepIds = <String>[
  'tracking_step_ordered',
  'tracking_step_picked',
  'tracking_step_in_transit',
  'tracking_step_delivered',
];

/// The Arabic step labels, from `app_ar.arb`.
const String _arOrdered = 'تم الطلب';
const String _arPicked = 'تم الاستلام';
const String _arInTransit = 'قيد التوصيل';
const String _arDelivered = 'تم التسليم';

/// The CustomPaint the OMDS progress bar draws its fill with.
final Finder _progressPainter = find.descendant(
  of: find.byType(OMDSStepperProgress),
  matching: find.byType(CustomPaint),
);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OrderTrackingStepper',
    _previews,
    expectedText: const <String, String>{
      'Ordered': 'Ordered · step 1 of 4',
      'Picked': 'Picked · step 2 of 4',
      'In transit': 'In transit · step 3 of 4',
      'At Door': 'At Door · step 3 of 4, relabelled',
      'Delivered': 'Delivered · step 4 of 4',
      'Delivered on 320pt': 'Delivered · step 4 of 4 on a 320pt phone',
    },
  );

  group('OrderTrackingStepper preview states are distinct', () {
    // The assertion the caption-based `expectedText` above cannot make: six
    // previews of a two-scalar widget are only distinct states if the fill and
    // the icons differ.
    _currentStep.forEach((String state, int step) {
      testWidgets('$state fills the bar to ${step + 1}/4', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        final OMDSStepperProgress bar = tester.widget<OMDSStepperProgress>(
          find.byType(OMDSStepperProgress),
        );
        expect(bar.totalSteps, 4);
        // `completedSteps: currentStep + 1` — the CURRENT step counts as
        // complete, so a brand-new order already shows a quarter-full bar.
        expect(bar.completedSteps, step + 1);
      });

      testWidgets('$state marks ${step + 1} of 4 steps reached', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        expect(find.byIcon(Icons.check_circle), findsNWidgets(step));
        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
        expect(
          find.byIcon(Icons.radio_button_unchecked),
          findsNWidgets(_stepIds.length - 1 - step),
        );
      });

      testWidgets('$state selects only step ${step + 1}', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpPreview(tester, _previews[state]!);

        for (int i = 0; i < _stepIds.length; i++) {
          final SemanticsData data = tester
              .getSemantics(find.bySemanticsIdentifier(_stepIds[i]))
              .getSemanticsData();
          // `selected:` is a tristate on the wire; the widget always passes a
          // bool, so every step is explicitly true or explicitly false.
          expect(
            data.flagsCollection.isSelected == Tristate.isTrue,
            i == step,
            reason: '${_stepIds[i]} should '
                '${i == step ? '' : 'not '}be the active step in $state',
          );
        }

        handle.dispose();
      });
    });
  });

  group('OrderTrackingStepper preview specifics', () {
    testWidgets('the at-door relabel keeps the in-transit identifier (P6/A5)', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, orderTrackingStepperAtDoor);

      expect(find.bySemanticsIdentifier('tracking_stepper'), findsOneWidget);
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('tracking_step_in_transit'),
      );
      // Relabelled…
      expect(node.value, 'At Door');
      expect(find.text('At Door'), findsOneWidget);
      // …but the id a Maestro flow addresses is unchanged, and no fifth step
      // was invented for it.
      expect(node.identifier, 'tracking_step_in_transit');
      expect(find.bySemanticsIdentifier('tracking_step_at_door'), findsNothing);
      expect(find.text('In transit'), findsNothing);

      handle.dispose();
    });

    testWidgets('in transit the same node reads the in-transit label', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, orderTrackingStepperInTransit);

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('tracking_step_in_transit'),
      );
      expect(node.value, 'In transit');
      expect(find.text('At Door'), findsNothing);

      handle.dispose();
    });

    testWidgets('a delivered order still renders its last step as active, '
        'never as done', (WidgetTester tester) async {
      await pumpPreview(tester, orderTrackingStepperDelivered);

      // `isDone` is `i < currentStep`, so the terminal step can never satisfy
      // it. The bar underneath is 100% full while the column above it shows the
      // same ring the in-transit state shows — three ticks and an open circle
      // is what a COMPLETED delivery looks like.
      expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      final OMDSStepperProgress bar = tester.widget<OMDSStepperProgress>(
        find.byType(OMDSStepperProgress),
      );
      expect(bar.completedSteps, bar.totalSteps);
    });

    testWidgets('AR mirrors the step row but NOT the progress fill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        orderTrackingStepperPicked,
        locale: const Locale('ar'),
      );

      // The Row mirrors: step 1 is now on the trailing (right) edge.
      final double ordered = tester.getCenter(find.text(_arOrdered)).dx;
      final double picked = tester.getCenter(find.text(_arPicked)).dx;
      final double inTransit = tester.getCenter(find.text(_arInTransit)).dx;
      final double delivered = tester.getCenter(find.text(_arDelivered)).dx;
      expect(ordered, greaterThan(picked));
      expect(picked, greaterThan(inTransit));
      expect(inTransit, greaterThan(delivered));

      // The bar does not. `_StepperPainter` draws from x=0 to x=width*progress
      // in raw canvas coordinates and never reads Directionality
      // (`omds_stepper_progress.dart`), so the fill still grows from the LEFT
      // edge: 4pt track across the full 390, then half of it inked.
      expect(
        _progressPainter,
        paints
          ..line(p1: const Offset(0, 2), p2: const Offset(390, 2))
          ..line(p1: const Offset(0, 2), p2: const Offset(195, 2)),
      );

      // Which puts the ink under the wrong steps: the two completed ones sit in
      // the BARE half of the track, and the two that have not happened sit on
      // the filled half.
      final Rect bar = tester.getRect(_progressPainter);
      expect(
        ordered - bar.left,
        greaterThan(195),
        reason: 'in Arabic the completed steps sit over unfilled track',
      );
      expect(
        delivered - bar.left,
        lessThan(195),
        reason: 'in Arabic the pending steps sit over filled track',
      );
    });

    testWidgets('at 200% text a 320pt phone truncates "Delivered"', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, orderTrackingStepperCompactPhone);
      expect(tester.takeException(), isNull);

      // 320 / 4 = 80pt per column. "Delivered" is one unbreakable word, so
      // `maxLines: 2` cannot save it — it is ellipsized, silently and with no
      // overflow stripe, on the step that matters most.
      final RenderParagraph label = tester.renderObject<RenderParagraph>(
        find.text('Delivered'),
      );
      expect(label.size.width, lessThanOrEqualTo(80));
      expect(
        label.getMinIntrinsicWidth(double.infinity),
        greaterThan(label.size.width),
        reason: 'the widest unbreakable word no longer fits the column, so the '
            'label is rendered ellipsized',
      );
    });

    testWidgets('at 200% text the phone-width columns lose every label too', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPreview(tester, orderTrackingStepperDelivered);

      // Not a compact-device edge case: at 390pt the columns are 97.5pt and
      // NONE of the four labels fits on one line. Two of them ("Ordered",
      // "Delivered") are single words that `maxLines: 2` cannot rescue.
      //
      // Measured under flutter_test's fixed-advance test font, which is wider
      // than Inter — so the exact numbers overstate a device. What does not
      // depend on the font is the shape of the result: the widest unbreakable
      // word in each column is a multiple of the column, not a few points over.
      for (final String label in const <String>[
        'Ordered',
        'Picked',
        'In transit',
        'Delivered',
      ]) {
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.size.width, lessThanOrEqualTo(97.5));
        expect(
          paragraph.getMinIntrinsicWidth(double.infinity),
          greaterThan(paragraph.size.width),
          reason: '"$label" cannot fit its column at 200% text',
        );
      }
      expect(tester.takeException(), isNull,
          reason: 'and it truncates silently — no overflow stripe says so');
    });
  });
}
