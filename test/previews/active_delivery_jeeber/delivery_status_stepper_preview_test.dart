// Render tests for the DeliveryStatusStepper previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Pinning this widget takes one extra step. Its only per-state TEXT is the
// advance CTA, and the CTA exists in exactly two of the seven states — every
// other state paints the same five stage labels and differs only in WHICH
// circle is accented. So `expectedText` pins the two CTA states, and the
// `current stage` group below pins all seven by the key `_StageIcon` stamps on
// the accented circle (`active_delivery_stage_<status>_current`), which is the
// thing that actually distinguishes them. Without that group, six previews of
// the same stepper would all pass while showing the same picture.
//
// Every dimension asserted here is measured on the test fallback font, whose
// glyphs are wider than the bundled Inter, so widths are an upper bound rather
// than a promise about the shipped font.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/widgets/delivery_status_stepper.dart';
import 'package:jeeb_mobile/previews/active_delivery_jeeber/delivery_status_stepper_preview.dart';

import '../preview_test_harness.dart';

/// The inline advance CTA `_AdvanceButton` wraps in `Semantics`.
final Finder _advanceCta = find.bySemanticsIdentifier(
  'mark_delivered_advance_cta',
);

Finder _accentedStage(String status) =>
    find.byKey(ValueKey<String>('active_delivery_stage_${status}_current'));

/// Pumps a preview at [scale] times the base text size — the third rendering
/// every [JeebPreview] produces, which `pumpPreview` alone does not reproduce.
Future<void> pumpScaled(
  WidgetTester tester,
  Widget Function() preview,
  double scale, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Picked · transitioning` — see the dedicated group.
  testPreviewsRender(
    'DeliveryStatusStepper',
    const <String, Widget Function()>{
      'Ordered · step 1 + CTA': deliveryStatusStepperOrdered,
      'Picked · longest CTA': deliveryStatusStepperPicked,
      'In transit · no CTA (JM-051)': deliveryStatusStepperInTransit,
      'At door · next is null': deliveryStatusStepperAtDoor,
      'Done · last step still accented': deliveryStatusStepperDone,
      'Cancelled · paints nothing': deliveryStatusStepperCancelled,
    },
    expectedText: const <String, String>{
      // The CTA names the NEXT status, never the current one.
      'Ordered · step 1 + CTA': 'Mark as Picked',
      'Picked · longest CTA': 'Mark as In Transit',
    },
  );

  // The half of the suite `expectedText` cannot express: each preview renders
  // ITS OWN stage as the accented one, and no other.
  group('DeliveryStatusStepper previews · current stage', () {
    const Map<String, String> accentedStageByPreview = <String, String>{
      'Ordered · step 1 + CTA': 'ordered',
      'Picked · longest CTA': 'picked',
      'In transit · no CTA (JM-051)': 'intransit',
      'At door · next is null': 'atdoor',
      'Done · last step still accented': 'done',
    };
    const Map<String, Widget Function()> previews = <String, Widget Function()>{
      'Ordered · step 1 + CTA': deliveryStatusStepperOrdered,
      'Picked · longest CTA': deliveryStatusStepperPicked,
      'In transit · no CTA (JM-051)': deliveryStatusStepperInTransit,
      'At door · next is null': deliveryStatusStepperAtDoor,
      'Done · last step still accented': deliveryStatusStepperDone,
    };

    accentedStageByPreview.forEach((String name, String status) {
      testWidgets('$name accents only $status', (WidgetTester tester) async {
        await pumpPreview(tester, previews[name]!);

        expect(_accentedStage(status), findsOneWidget);
        for (final String other in accentedStageByPreview.values) {
          if (other == status) continue;
          expect(
            _accentedStage(other),
            findsNothing,
            reason: '$name must not accent $other',
          );
        }
      });
    });
  });

  group('DeliveryStatusStepper preview specifics', () {
    testWidgets('JM-051 — the delivering phase offers no inline advance', (
      WidgetTester tester,
    ) async {
      // From inTransit onward the journey to Done belongs to
      // MarkDeliveredPanel's `mark_delivered_cta`, which carries the proof
      // photo. A second way to finish a delivery would skip that.
      for (final Widget Function() preview in <Widget Function()>[
        deliveryStatusStepperInTransit,
        deliveryStatusStepperAtDoor,
        deliveryStatusStepperDone,
      ]) {
        await pumpPreview(tester, preview);
        expect(_advanceCta, findsNothing);
      }

      // …and the two earlier stages still have theirs.
      await pumpPreview(tester, deliveryStatusStepperOrdered);
      expect(_advanceCta, findsOneWidget);
    });

    testWidgets('cancelled paints nothing and does not throw', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusStepperCancelled);

      // `stepIcon` / `statusLabel` throw StateError for unsuccessful
      // terminals — the shrink is what stands between this state and a crash.
      expect(tester.takeException(), isNull);
      expect(find.byType(OmdsStepIndicator), findsNothing);
      expect(_advanceCta, findsNothing);
      expect(tester.getSize(find.byType(DeliveryStatusStepper)).height, 0);
    });

    testWidgets('every stage carries its state in the semantics label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryStatusStepperInTransit);

      expect(find.bySemanticsLabel('Picked, Completed'), findsOneWidget);
      expect(find.bySemanticsLabel('In Transit, Current'), findsOneWidget);
      expect(find.bySemanticsLabel('At Door, Upcoming'), findsOneWidget);
    });

    testWidgets('AR mirrors the stepper — stage 1 sits on the trailing edge', (
      WidgetTester tester,
    ) async {
      // The icon overlay Row and the OmdsStepIndicator underneath it are two
      // independent Rows stacked on top of each other. If only one of them
      // mirrors, every icon ends up on the wrong circle in Arabic, which no
      // amount of reading the English card would reveal.
      await pumpPreview(tester, deliveryStatusStepperOrdered);
      final double ltrX = tester
          .getCenter(find.byIcon(Icons.receipt_long_outlined))
          .dx;
      final double ltrLeft = tester
          .getTopLeft(find.byType(DeliveryStatusStepper))
          .dx;

      await pumpPreview(
        tester,
        deliveryStatusStepperOrdered,
        locale: const Locale('ar'),
      );
      final double rtlX = tester
          .getCenter(find.byIcon(Icons.receipt_long_outlined))
          .dx;
      final double rtlRight = tester
          .getTopRight(find.byType(DeliveryStatusStepper))
          .dx;

      expect(ltrX - ltrLeft, rtlRight - rtlX);
    });
  });

  // These two pin the layout ceilings the 200% rendering of the matrix exists
  // to surface. Both are upper bounds on the test font — see the header note —
  // but the mechanism (a fixed-height button and a width/5 label column, both
  // holding text that scales) is font-independent. If either stops failing to
  // fit, the widget has grown a real defence and this test should be deleted
  // rather than relaxed.
  group('DeliveryStatusStepper previews · 200% text', () {
    testWidgets('the CTA label outgrows its fixed 48 dp button', (
      WidgetTester tester,
    ) async {
      await pumpScaled(tester, deliveryStatusStepperOrdered, 2.0);

      final Size button = tester.getSize(find.byType(OmdsLoadingButton));
      final RenderParagraph label = tester.renderObject<RenderParagraph>(
        find.text('Mark as Picked'),
      );
      // `OmdsLoadingButton` hard-codes `height: Sizes.fourXLarge` (48) and
      // centres a plain Text in it, so the wrapped label is clipped, not
      // ellipsized and not given more room.
      expect(button.height, 48);
      expect(label.getMaxIntrinsicHeight(label.size.width), greaterThan(48));
    });

    testWidgets('stage labels break mid-word in their 62 dp column', (
      WidgetTester tester,
    ) async {
      await pumpScaled(tester, deliveryStatusStepperInTransit, 2.0);

      final RenderParagraph label = tester.renderObject<RenderParagraph>(
        find.text('In Transit'),
      );
      // 310 dp of content / 5 stages. The column is a bare `Expanded`, so a
      // word wider than it has nowhere to go.
      expect(label.size.width, 62);
      expect(label.getMinIntrinsicWidth(double.infinity), greaterThan(62));
    });
  });

  // `isTransitioning` swaps the CTA label for `OmdsButtonLoading`, i.e. an
  // indeterminate `CircularProgressIndicator`. `pumpAndSettle` (which
  // `pumpPreview` calls) never returns while one is on screen, so this preview
  // gets the same three assertions the shared suite makes — builds in EN,
  // builds in AR, renders its OWN state — driven by fixed pumps instead.
  group('DeliveryStatusStepper previews · Picked · transitioning', () {
    Future<void> pumpTransitioning(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(deliveryStatusStepperPickedTransitioning, locale),
      );
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Picked · transitioning · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpTransitioning(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Picked · transitioning renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpTransitioning(tester);

      // Same stage as `Picked · longest CTA` — the optimistic advance is the
      // server's to confirm, so the circles must NOT have moved on…
      expect(_accentedStage('picked'), findsOneWidget);
      // …but the label is gone, replaced by the spinner. That pair is true of
      // no other preview in this file.
      expect(find.text('Mark as In Transit'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The button must not collapse while it loads — a shrinking CTA makes the
      // whole card jump under the jeeber's thumb.
      expect(tester.getSize(find.byType(OmdsLoadingButton)).height, 48);
    });

    testWidgets('the CTA goes inert while the transition POST is in flight', (
      WidgetTester tester,
    ) async {
      // A live tap target here is how a jeeber fires a second
      // `POST /v1/delivery/status/transition` for the same step.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, deliveryStatusStepperPicked);
      expect(
        tester.getSemantics(_advanceCta),
        isSemantics(isButton: true, hasTapAction: true),
        reason: 'control: the idle CTA is tappable, so a false negative below '
            'would be a broken finder rather than a real guard',
      );

      await pumpTransitioning(tester);
      expect(
        tester.getSemantics(_advanceCta),
        isSemantics(isButton: true, hasTapAction: false),
      );
      handle.dispose();
    });
  });
}
