import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_models.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_search.dart';

// Deliberately does NOT import screen_catalog.dart: that pulls in every
// cataloged feature screen, so a matcher test would only be as runnable as the
// whole app. The shipped catalog is covered in
// catalog_search_real_catalog_test.dart instead.

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

void main() {
  group('catalogSearchTerms', () {
    test('splits on whitespace and lowercases', () {
      expect(catalogSearchTerms('Delivery Active'), ['delivery', 'active']);
    });

    test('collapses repeated and surrounding separators', () {
      expect(catalogSearchTerms('  Delivery   Active  '), [
        'delivery',
        'active',
      ]);
    });

    test('treats name punctuation as a separator', () {
      expect(catalogSearchTerms('pickup/dropoff'), ['pickup', 'dropoff']);
      expect(catalogSearchTerms('home_client'), ['home', 'client']);
    });

    test('an empty or blank query has no terms', () {
      expect(catalogSearchTerms(''), isEmpty);
      expect(catalogSearchTerms('   '), isEmpty);
    });

    test('keeps non-Latin text as a term instead of erasing it', () {
      expect(catalogSearchTerms('تتبع الطلب'), ['تتبع', 'الطلب']);
    });
  });

  group('filterCatalog', () {
    final entries = [
      _entry('active_delivery_jeeber', 'ActiveDeliveryJeeberScreen'),
      _entry('addresses', 'Saved Addresses', ['loaded', 'empty']),
      _entry('order_tracking', 'Order Tracking'),
      _entry('location', 'Location Picker (pickup/dropoff)'),
    ];

    test('an empty query returns everything, untouched in order', () {
      expect(filterCatalog(entries, ''), entries);
      expect(filterCatalog(entries, '   '), entries);
    });

    test('spaces mean AND, and word order does not matter', () {
      // The example from the request: "Delivery Active" must find
      // ActiveDeliveryJeeberScreen even though the words are reversed and
      // run together in the name.
      expect(filterCatalog(entries, 'Delivery Active').map((e) => e.screen), [
        'ActiveDeliveryJeeberScreen',
      ]);
    });

    test('case is irrelevant', () {
      for (final query in ['saved addresses', 'SAVED ADDRESSES', 'sAvEd']) {
        expect(filterCatalog(entries, query).map((e) => e.screen), [
          'Saved Addresses',
        ], reason: query);
      }
    });

    test('matches partial words, not just whole ones', () {
      expect(filterCatalog(entries, 'deliv jeeb').map((e) => e.screen), [
        'ActiveDeliveryJeeberScreen',
      ]);
    });

    test('matches on the feature name', () {
      expect(filterCatalog(entries, 'order_tracking').map((e) => e.screen), [
        'Order Tracking',
      ]);
    });

    test('matches on a state label', () {
      expect(filterCatalog(entries, 'empty').map((e) => e.screen), [
        'Saved Addresses',
      ]);
    });

    test('matches through punctuation inside a screen name', () {
      expect(filterCatalog(entries, 'pickup dropoff').map((e) => e.screen), [
        'Location Picker (pickup/dropoff)',
      ]);
    });

    test('every term must hit — one miss drops the entry', () {
      expect(filterCatalog(entries, 'delivery nonsense'), isEmpty);
    });
  });
}
