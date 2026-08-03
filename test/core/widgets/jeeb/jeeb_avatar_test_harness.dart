import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:omds/omds.dart';

/// Harness for the avatar kit (#9). Kept beside the tests so nothing test-only
/// ships in `lib/`, and separate from the card harness so the two lanes do not
/// serialise on one file.
Widget wrapAvatar(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Captures the [BuildContext] below the theme so a test can compare painted
/// colors against the real `ColorScheme` instead of hardcoding hexes.
class ContextProbe extends StatelessWidget {
  const ContextProbe({super.key, required this.onContext, required this.child});

  final ValueChanged<BuildContext> onContext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onContext(context);
    return child;
  }
}

/// The single [OmdsProfileAvatar] inside [finder]'s subtree.
OmdsProfileAvatar composedAvatar(WidgetTester tester, Finder finder) =>
    tester.widget<OmdsProfileAvatar>(
      find.descendant(of: finder, matching: find.byType(OmdsProfileAvatar)),
    );
