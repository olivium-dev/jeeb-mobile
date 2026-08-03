import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

/// Width of the test frame, so 78% ceilings and gutter maths are checkable.
const double kChatFrameWidth = 360;

/// Shared harness for the chat-kit tests (kit step 10).
///
/// The frame is pinned with a **physical** `Alignment.topLeft` on purpose: the
/// widgets under test must mirror themselves, so the frame must not move when
/// [direction] flips or the geometry assertions prove nothing.
Widget wrapChat(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double width = kChatFrameWidth,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

/// The [BoxDecoration] of the first [DecoratedBox] under [finder]'s subtree.
BoxDecoration chatDecorationOf(WidgetTester tester, Finder finder) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: finder, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

/// The [ShapeDecoration] of the first decorated node under [finder]'s subtree.
ShapeDecoration chatShapeOf(WidgetTester tester, Finder finder) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: finder, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as ShapeDecoration;
}
