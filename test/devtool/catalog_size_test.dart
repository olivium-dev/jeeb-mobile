// The Screen Catalog must not shrink.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';

void main() {
  test('the Screen Catalog has not shrunk', () {
    final int states =
        kScreenCatalog.fold<int>(0, (int s, CatalogEntry e) => s + e.states.length);

    expect(kScreenCatalog.length, greaterThanOrEqualTo(89),
        reason: 'screens dropped — a designer-facing tool lost coverage');
    expect(states, greaterThanOrEqualTo(288),
        reason: 'states dropped — a designer-facing tool lost coverage');
  });
}
