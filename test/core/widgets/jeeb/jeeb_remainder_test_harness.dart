import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

/// Shared harness for the "remainder" kit widgets (§5.1 step 12:
/// `JeebTierRow`, `JeebAccentFrameCard`, `JeebSegmentedToggle`, `JeebPageDots`,
/// `JeebStepperPill`).
///
/// Kept out of the widget files so nothing test-only ships in `lib/`, and kept
/// separate from `jeeb_card_test_harness.dart` so the two kit lanes never race
/// on one file.
Widget wrapRemainder(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );
}

/// A harness themed with a bare `ThemeData.light()` — no `JeebColorRoles`, no
/// `JeebSemanticColors`, no `JeebTextStyles`.
///
/// This is what `wrapForTest` gives a feature test, and a bare `!` read of any
/// of those extensions crashes under it. Every kit widget must survive it.
Widget wrapUnthemed(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    ),
  );
}

/// Captures the [JeebSurfaceToneData] visible at its position, so a test can
/// prove a card re-tones its subtree rather than relying on the consumer.
class RemainderToneProbe extends StatelessWidget {
  const RemainderToneProbe({super.key, required this.onTone});

  final ValueChanged<JeebSurfaceToneData> onTone;

  @override
  Widget build(BuildContext context) {
    onTone(JeebSurfaceTone.of(context));
    return const SizedBox(height: 20, width: 20);
  }
}

/// The [BoxDecoration] of the first [DecoratedBox] under [finder]'s subtree.
BoxDecoration remainderDecorationOf(WidgetTester tester, Finder finder) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: finder, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}
