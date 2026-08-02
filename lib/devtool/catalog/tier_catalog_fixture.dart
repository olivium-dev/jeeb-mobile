import '../../features/tier_selection/data/tier_repository.dart';
import '../../features/tier_selection/domain/tier.dart';

class DevtoolTierRepository implements TierRepository {
  const DevtoolTierRepository({this.failWith});

  static const Set<TierId> supportedTierIds = {
    TierId.flash,
    TierId.express,
    TierId.standard,
  };

  final TierLoadFailure? failWith;

  @override
  Future<List<Tier>> fetchTiers() async {
    final failure = failWith;
    if (failure != null) {
      throw TierLoadException(failure);
    }
    return FakeTierRepository.defaultCatalog
        .where((tier) => supportedTierIds.contains(tier.id))
        .toList(growable: false);
  }
}
