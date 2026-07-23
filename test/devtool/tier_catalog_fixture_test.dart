import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/catalog/tier_catalog_fixture.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

void main() {
  test(
    'DevTool tier fixture mirrors the three-tier delivery contract',
    () async {
      final tiers = await const DevtoolTierRepository().fetchTiers();

      expect(
        tiers.map((tier) => tier.id),
        orderedEquals(const [TierId.flash, TierId.express, TierId.standard]),
      );
    },
  );
}
