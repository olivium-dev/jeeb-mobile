import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

/// Shared harness for the CTA tests (kit step 4).
///
/// Deliberately separate from `jeeb_card_test_harness.dart`: the card lane owns
/// that file and both lanes ship concurrently.
Widget wrapCta(Widget child, {TextDirection direction = TextDirection.ltr}) {
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

/// The [BoxDecoration] of the first [DecoratedBox] under [finder]'s subtree.
BoxDecoration ctaDecorationOf(WidgetTester tester, Finder finder) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: finder, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}
