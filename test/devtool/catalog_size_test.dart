// The Screen Catalog must not shrink.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';

void main() {
  test('the Screen Catalog has not shrunk', () {
    final int states =
        kScreenCatalog.fold<int>(0, (int s, CatalogEntry e) => s + e.states.length);

    // Floors 89/288 → 87/282: the settlement pair (4+2 states) was deleted as a
    // ratified orphan (02-STUDY-NOTES §ORPHAN, M3-15/16), not lost coverage.
    expect(kScreenCatalog.length, greaterThanOrEqualTo(87),
        reason: 'screens dropped — a designer-facing tool lost coverage');
    expect(states, greaterThanOrEqualTo(282),
        reason: 'states dropped — a designer-facing tool lost coverage');
  });
}
