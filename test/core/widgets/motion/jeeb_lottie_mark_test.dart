// `JeebLottieMark` — the player every Lottie composition in the app goes
// through. These tests pin the three properties that made it necessary, because
// each of them is a real failure mode of a bare `Lottie.asset`:
//
//   1. the loop is BOUNDED, so `pumpAndSettle` terminates (an unbounded
//      `repeat: true` was measured to time it out);
//   2. reduce-motion renders a static frame and schedules NO animation frames;
//   3. only explicitly-directional compositions are mirrored under RTL.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/motion/jeeb_lottie_mark.dart';

/// A real composition from the shipped set — `broadcasting` loops for 240
/// frames at 60 fps (4 s), so a bounded run is unmistakably longer than a
/// suppressed one.
const _asset = 'assets/animations/broadcasting.json';
const _size = 140.0;

Widget _host({
  bool disableAnimations = false,
  TextDirection direction = TextDirection.ltr,
  bool mirrorInRtl = false,
  int cycles = JeebLottieMark.defaultCycles,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: direction,
      child: Center(
        child: JeebLottieMark(
          asset: _asset,
          width: _size,
          height: _size,
          cycles: cycles,
          mirrorInRtl: mirrorInRtl,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a looping mark settles — the loop is bounded, not infinite', (
    tester,
  ) async {
    await tester.pumpWidget(_host(cycles: 2));
    // Would never return if the mark used `repeat: true`.
    final frames = await tester.pumpAndSettle();
    // Two 4 s plays at the test binding's 100 ms default frame period is well
    // over 50 frames; the point is only that it is MANY and that it ENDS.
    expect(frames, greaterThan(20));
  });

  testWidgets('reduce-motion holds the first frame and schedules no animation', (
    tester,
  ) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    // Let the composition resolve off the asset bundle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final frames = await tester.pumpAndSettle();
    expect(frames, lessThan(5), reason: 'nothing may be ticking');
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(JeebLottieMark), findsOneWidget);
  });

  testWidgets('non-directional marks are never mirrored', (tester) async {
    await tester.pumpWidget(
      _host(direction: TextDirection.rtl, disableAnimations: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Transform), findsNothing);
  });

  testWidgets('directional marks flip under RTL only', (tester) async {
    await tester.pumpWidget(
      _host(
        direction: TextDirection.rtl,
        mirrorInRtl: true,
        disableAnimations: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Transform), findsOneWidget);

    await tester.pumpWidget(
      _host(mirrorInRtl: true, disableAnimations: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Transform), findsNothing);
  });

  testWidgets('the mark is decorative — it adds no semantics node', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(disableAnimations: true));
    await tester.pumpAndSettle();
    expect(find.byType(ExcludeSemantics), findsOneWidget);
    handle.dispose();
  });
}
