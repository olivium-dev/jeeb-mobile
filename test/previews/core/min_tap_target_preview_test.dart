// Render tests for the MinTapTarget previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT title, because a
// suite that only asked "did something render?" would pass on five copies of
// the same specimen.
//
// MinTapTarget also needs a second kind of test the other preview suites do
// not. It paints nothing: the ONLY thing a reviewer judges in the canvas is
// whether the tinted bounds reach the 48 dp gauge, and that is a measurement,
// not a pixel. The geometry group below measures the same rectangles the canvas
// draws, so the two states that are supposed to show the floor being defeated
// cannot quietly start passing.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/accessibility/accessibility.dart';

import '../preview_test_harness.dart';

/// The floor the widget promises (AC T-mobile-036).
const double _kFloor = A11y.minTapTargetSize;

/// Phone width, so the stretched state is measured against the same box the
/// preview declares (390) instead of the 800 pt default test surface.
const Size _kPhone = Size(390, 800);

/// [_kPhone] width minus the specimen's 16 dp padding on each side — the width
/// a stretching parent hands down.
const double _kStretchedWidth = 390 - 2 * 16;

/// The single [MinTapTarget] in the pumped preview.
Size _targetSize(WidgetTester tester) => tester.getSize(
      find.byType(MinTapTarget),
    );

/// Renders [preview] at [_kPhone] rather than the default test surface.
Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await tester.binding.setSurfaceSize(_kPhone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpPreview(tester, preview);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'MinTapTarget',
    const <String, Widget Function()>{
      'Tiny icon child': minTapTargetTinyIcon,
      'Chip child': minTapTargetChip,
      'Narrow parent': minTapTargetNarrowParent,
      'Stretched parent': minTapTargetStretchedParent,
      'Child owns its own onTap': minTapTargetChildOnTapSwallowed,
    },
    expectedText: const <String, String>{
      'Tiny icon child': 'Tiny icon child',
      'Chip child': 'Chip child',
      'Narrow parent': 'Narrow parent',
      'Stretched parent': 'Stretched parent',
      'Child owns its own onTap': 'Child owns its own onTap',
    },
  );

  group('MinTapTarget preview geometry', () {
    testWidgets('a 16 dp glyph is grown to the full 48 dp square', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, minTapTargetTinyIcon);

      expect(_targetSize(tester), const Size(_kFloor, _kFloor));
    });

    testWidgets('the chip state binds the floor on height only', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, minTapTargetChip);

      // The distinction the preview exists to show: a chip is already wide
      // enough, so the minimum is inert horizontally and load-bearing
      // vertically. If both axes ever read 48 here, the chip stopped rendering.
      final Size size = _targetSize(tester);
      expect(size.height, _kFloor);
      expect(size.width, greaterThan(_kFloor));
    });

    testWidgets('a narrow parent silently defeats the floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, minTapTargetNarrowParent);

      // BoxConstraints.enforce CLAMPS the minimum into the incoming range
      // instead of winning over it, so a 32 dp slot yields a 32 dp tap target —
      // 16 dp under the AC, with no assert and no overflow stripe to say so.
      expect(_targetSize(tester), const Size(32, 32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a stretching parent blows the target out to full width', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(tester, minTapTargetStretchedParent);

      // The same property as `Narrow parent`, in the other direction: a
      // stretching Column hands down a TIGHT width, which is a minimum too, so
      // enforce keeps it. A 16 dp glyph ends up 358 dp wide.
      final Size size = _targetSize(tester);
      expect(size.width, _kStretchedWidth);
      expect(size.height, _kFloor);
      expect(size.width, greaterThan(7 * _kFloor));
    });

    testWidgets('every pixel of the stretched strip is live', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(tester, minTapTargetStretchedParent);
      expect(find.text('taps 0'), findsOneWidget);

      // Not merely wide: HitTestBehavior.opaque means the whole strip takes
      // taps. A tap 24 dp from the trailing edge — nowhere near the glyph —
      // still fires this target's onTap, so a sibling control placed on that
      // line would be unreachable.
      final Rect target = tester.getRect(find.byType(MinTapTarget));
      await tester.tapAt(Offset(target.right - 24, target.center.dy));
      await tester.pumpAndSettle();

      expect(find.text('taps 1'), findsOneWidget);
    });
  });

  group('MinTapTarget preview specifics', () {
    testWidgets("the child's own onTap never fires", (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, minTapTargetChildOnTapSwallowed);
      expect(find.text('outer 0 / child 0'), findsOneWidget);

      await tester.tap(find.byType(MinTapTarget));
      await tester.pumpAndSettle();

      // IgnorePointer swallows it. Deliberate — the outer gesture owns the
      // whole target — but OmdsChip advertises an onTap, so the natural call
      // wires up a handler that is dead on arrival.
      expect(find.text('outer 1 / child 0'), findsOneWidget);
    });

    testWidgets('a bare target is tappable but carries no button role', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than in a tearDown: the end-of-test handle
      // verification runs BEFORE tearDowns and fails on a live handle.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, minTapTargetChip);

      // `.first` is MinTapTarget's own detector: OmdsChip carries a second one
      // deeper in the subtree, which is exactly the pair this test is about.
      final SemanticsData data = tester
          .getSemantics(
            find
                .descendant(
                  of: find.byType(MinTapTarget),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .getSemanticsData();

      // The good news, worth pinning because it is not obvious: the child's
      // label survives the IgnorePointer and lands on the same node as the tap
      // action, so a bare target is not anonymous.
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, 'Lowest price');

      // The gap: no button role. A screen reader announces "Lowest price" with
      // nothing to say it can be activated. That is why every production call
      // site wraps this widget in
      // `Semantics(button: true, …) → ExcludeSemantics(MinTapTarget(…))` — the
      // helper named by AC T-mobile-036 does not satisfy the "semantic labels
      // on all interactive elements" half of it on its own.
      expect(data.flagsCollection.isButton, isFalse);

      handle.dispose();
    });
  });
}
