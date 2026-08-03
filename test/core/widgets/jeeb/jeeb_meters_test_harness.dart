import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

/// Shared harness for the meters group (kit step 7: #10, #20, #21).
///
/// Separate from `jeeb_card_test_harness.dart` because these widgets need the
/// ambient **locale** under their feet — `JeebSectionLabel` gates its case
/// transform on it — and the card harness installs none.
Widget wrapMeter(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  double width = 320,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
    // Without the global delegates an `ar` pump logs a "locale not supported"
    // FlutterError that `tester.takeException()` then reports as a failure.
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Directionality(
      textDirection: direction,
      child: Scaffold(
        // A LOOSE cap, not a `SizedBox`: these widgets self-size (the bar is
        // 70 wide, the price meter hugs its dots) and a tight width would hide
        // that. `double.infinity` still resolves to [width] here.
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width),
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// The [BoxDecoration] of the widget [finder] resolves to.
BoxDecoration boxOf(WidgetTester tester, Finder finder) =>
    tester.widget<DecoratedBox>(finder).decoration as BoxDecoration;

/// Every [DecoratedBox] under [finder], in paint order.
Iterable<BoxDecoration> boxesUnder(WidgetTester tester, Finder finder) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: finder, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration as BoxDecoration);
