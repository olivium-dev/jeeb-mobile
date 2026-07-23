import '../../features/tier_selection/data/tier_repository.dart';
import '../../features/tier_selection/domain/tier.dart';

/// Network-free tier catalog for DevTool previews.
///
/// The delivery-service contract currently exposes only Flash, Express, and
/// Standard. The wider fake repository retains legacy tiers for older widget
/// scenarios, so catalog previews filter it through this contract-specific
/// fixture instead of presenting unsupported choices.
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
