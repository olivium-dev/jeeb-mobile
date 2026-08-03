import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

/// Shared harness for the code group (kit step 12: #12 `JeebCodeCells`,
/// #13 `JeebNumericKeypad`).
///
/// [width] defaults to 392 — the board's 440 pt frame inside its 24 pt gutters
/// — so the design-exact `flex:1` cell widths and the 335 pt display row are
/// measured at the size they were drawn at.
Widget wrapCode(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double width = 392,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      ),
    ),
  );
}

/// A harness themed with bare `ThemeData.light()` — i.e. **without** the Jeeb
/// theme extensions registered.
///
/// `wrapForTest` in the feature suites does exactly this, so every kit widget
/// has to survive a missing `JeebTextStyles`/`JeebColorRoles`. The accessors
/// fall back internally; this proves it rather than assuming it.
Widget wrapCodeUnthemed(Widget child) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(body: Center(child: SizedBox(width: 392, child: child))),
    ),
  );
}

/// The [BoxDecoration] of every [DecoratedBox] under [finder], in paint order.
Iterable<BoxDecoration> decorationsUnder(WidgetTester tester, Finder finder) =>
    tester
        .widgetList<DecoratedBox>(
          find.descendant(of: finder, matching: find.byType(DecoratedBox)),
        )
        .map((DecoratedBox box) => box.decoration as BoxDecoration);
