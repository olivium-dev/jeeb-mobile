import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/accessibility/accessibility.dart';

import '../preview_test_harness.dart';

/// The floor the widget promises (AC T-mobile-036).
const double _kFloor = A11y.minTapTargetSize;

/// Phone width, so the stretched state is measured against the same box the
const Size _kPhone = Size(390, 800);

/// [_kPhone] width minus the specimen's 16 dp padding on each side — the width
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

      final Size size = _targetSize(tester);
      expect(size.height, _kFloor);
      expect(size.width, greaterThan(_kFloor));
    });

    testWidgets('a narrow parent silently defeats the floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, minTapTargetNarrowParent);

      expect(_targetSize(tester), const Size(32, 32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a stretching parent blows the target out to full width', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(tester, minTapTargetStretchedParent);

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

      expect(find.text('outer 1 / child 0'), findsOneWidget);
    });

    testWidgets('a bare target is tappable but carries no button role', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, minTapTargetChip);

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

      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, 'Lowest price');

      expect(data.flagsCollection.isButton, isFalse);

      handle.dispose();
    });
  });
}
