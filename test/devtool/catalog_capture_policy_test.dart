import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_screen.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';

void main() {
  testWidgets('navigation-only state stays indexed and interactive', (
    tester,
  ) async {
    final defaultState = CatalogState('visual', (_) => const SizedBox());
    expect(defaultState.capturePolicy, CatalogCapturePolicy.visual);

    final entry = kScreenCatalog.singleWhere(
      (entry) => entry.screen == 'KycRejectedScreen',
    );
    final state = entry.states[5];
    expect(state.label, 'Status read failed');
    expect(state.capturePolicy, CatalogCapturePolicy.navigationOnly);

    await tester.pumpWidget(
      MaterialApp(home: CatalogStatesScreen(entry: entry)),
    );
    final row = find.widgetWithText(ListTile, state.label);
    expect(row, findsOneWidget);
    expect(tester.widget<ListTile>(row).onTap, isNotNull);
  });
}
