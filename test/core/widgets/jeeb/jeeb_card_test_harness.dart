import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

/// Shared harness for the card-primitive tests (kit step 1).
///
/// Kept out of the widget files so nothing test-only ships in `lib/`.
Widget wrapCard(Widget child, {TextDirection direction = TextDirection.ltr}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Center(
          child: SizedBox(width: 320, child: child),
        ),
      ),
    ),
  );
}

/// Captures the [JeebSurfaceToneData] visible at its position so tests can
/// prove the re-tone is inherited rather than passed by hand.
class ToneProbe extends StatelessWidget {
  const ToneProbe({super.key, required this.onTone});

  final ValueChanged<JeebSurfaceToneData> onTone;

  @override
  Widget build(BuildContext context) {
    onTone(JeebSurfaceTone.of(context));
    return const SizedBox(height: 20, width: 20);
  }
}

/// The [BoxDecoration] of the first [DecoratedBox] under [finder]'s subtree.
BoxDecoration decorationOf(WidgetTester tester, Finder finder) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: finder, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}
