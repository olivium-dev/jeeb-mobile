import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/catalog_search.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';

/// The matcher's own rules are covered in catalog_search_test.dart, which stays
/// free of the catalog so it runs without compiling every feature screen. This
/// file is the other half: the rules applied to the catalog we actually ship,
/// so a screen rename that breaks a documented search shows up here.
void main() {
  test('"Delivery Active" finds ActiveDeliveryJeeberScreen', () {
    final hits = filterCatalog(
      kScreenCatalog,
      'Delivery Active',
    ).map((e) => e.screen);
    expect(hits, contains('ActiveDeliveryJeeberScreen'));
  });

  test('casing never changes the result', () {
    final lower = filterCatalog(kScreenCatalog, 'delivery active');
    final upper = filterCatalog(kScreenCatalog, 'DELIVERY ACTIVE');
    final mixed = filterCatalog(kScreenCatalog, 'Delivery Active');
    expect(lower, upper);
    expect(lower, mixed);
  });

  test('an empty query lists the whole catalog', () {
    expect(filterCatalog(kScreenCatalog, ''), kScreenCatalog);
    expect(filterCatalog(kScreenCatalog, '   '), kScreenCatalog);
  });

  test('every catalog entry is reachable by searching its own name', () {
    for (final entry in kScreenCatalog) {
      expect(
        filterCatalog(kScreenCatalog, entry.screen),
        contains(entry),
        reason: 'searching "${entry.screen}" should find it',
      );
    }
  });
}
