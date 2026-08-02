// The Screen Catalog must not shrink.
//
// Counted from `kScreenCatalog` at RUNTIME. A grep over `CatalogState(` counts
// source literals and reports a false regression the moment an entry is
// refactored onto a factory — which is exactly what happened in screens wave 06
// (literals 278 -> 276, real states unchanged at 282).
//
// Raise these numbers when the catalog genuinely grows; never lower them
// without saying why in the commit.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';

void main() {
  test('the Screen Catalog has not shrunk', () {
    final int states =
        kScreenCatalog.fold<int>(0, (int s, CatalogEntry e) => s + e.states.length);

    expect(kScreenCatalog.length, greaterThanOrEqualTo(89),
        reason: 'screens dropped — a designer-facing tool lost coverage');
    expect(states, greaterThanOrEqualTo(282),
        reason: 'states dropped — a designer-facing tool lost coverage');
  });
}
