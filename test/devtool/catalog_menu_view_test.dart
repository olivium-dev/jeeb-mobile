import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_menu_view.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_models.dart';

CatalogEntry _entry(
  String feature,
  String screen, [
  List<String> states = const ['default'],
]) => CatalogEntry(
  feature: feature,
  screen: screen,
  states: [
    for (final label in states)
      CatalogState(label, (_) => const SizedBox.shrink()),
  ],
);

final List<CatalogEntry> _entries = [
  _entry('active_delivery_jeeber', 'ActiveDeliveryJeeberScreen'),
  _entry('addresses', 'Saved Addresses', ['loaded', 'empty']),
  _entry('order_tracking', 'Order Tracking'),
  _entry('chat', 'ChatDetailScreen'),
];

Future<void> _pumpMenu(
  WidgetTester tester, {
  List<CatalogEntry>? opened,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CatalogMenuView(
        entries: _entries,
        onOpen: (entry) => opened?.add(entry),
      ),
    ),
  );
}

void main() {
  testWidgets('lists every screen before anything is typed', (tester) async {
    await _pumpMenu(tester);

    for (final entry in _entries) {
      expect(find.text(entry.screen), findsOneWidget);
    }
    expect(find.textContaining('4 screens'), findsOneWidget);
  });

  testWidgets('"Delivery Active" narrows to ActiveDeliveryJeeberScreen', (
    tester,
  ) async {
    await _pumpMenu(tester);

    await tester.enterText(find.byType(TextField), 'Delivery Active');
    await tester.pump();

    expect(find.text('ActiveDeliveryJeeberScreen'), findsOneWidget);
    expect(find.text('Saved Addresses'), findsNothing);
    expect(find.text('Order Tracking'), findsNothing);
    expect(find.text('ChatDetailScreen'), findsNothing);
    expect(find.text('1 of 4 screens match'), findsOneWidget);
  });

  testWidgets('lowercase typing matches a PascalCase screen name', (
    tester,
  ) async {
    await _pumpMenu(tester);

    await tester.enterText(find.byType(TextField), 'chatdetail');
    await tester.pump();

    expect(find.text('ChatDetailScreen'), findsOneWidget);
    expect(find.text('1 of 4 screens match'), findsOneWidget);
  });

  testWidgets('a query nothing matches shows the empty message', (
    tester,
  ) async {
    await _pumpMenu(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();

    expect(find.text('No screen matches "zzzz".'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('the clear button restores the full list', (tester) async {
    await _pumpMenu(tester);

    await tester.enterText(find.byType(TextField), 'Delivery Active');
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(find.byType(ListTile), findsNWidgets(_entries.length));
    expect(find.textContaining('Cataloged'), findsOneWidget);
  });

  testWidgets('the clear button only exists while searching', (tester) async {
    await _pumpMenu(tester);
    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.enterText(find.byType(TextField), 'chat');
    await tester.pump();
    expect(find.byIcon(Icons.clear), findsOneWidget);
  });

  testWidgets('a row matched only by a state label says which one', (
    tester,
  ) async {
    await _pumpMenu(tester);

    await tester.enterText(find.byType(TextField), 'empty');
    await tester.pump();

    expect(find.text('Saved Addresses'), findsOneWidget);
    expect(find.text('matched state: empty'), findsOneWidget);
  });

  testWidgets('a row matched by its own name carries no explanation', (
    tester,
  ) async {
    await _pumpMenu(tester);

    await tester.enterText(find.byType(TextField), 'saved addresses');
    await tester.pump();

    expect(find.text('Saved Addresses'), findsOneWidget);
    expect(find.textContaining('matched state:'), findsNothing);
  });

  testWidgets('tapping a filtered row opens that entry', (tester) async {
    final opened = <CatalogEntry>[];
    await _pumpMenu(tester, opened: opened);

    await tester.enterText(find.byType(TextField), 'delivery active');
    await tester.pump();
    await tester.tap(find.text('ActiveDeliveryJeeberScreen'));
    await tester.pump();

    expect(opened.single.screen, 'ActiveDeliveryJeeberScreen');
  });
}
