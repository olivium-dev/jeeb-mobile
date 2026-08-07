import '../../../core/di/injection_container.dart';
import '../data/tier_repository.dart';
import '../domain/tier.dart';

/// The tier BOTH create doors default to. A null [Tier.wireId] is a guaranteed
/// 400 on the create POST, so null here means "ask", never "invent".
Tier? defaultTierOf(Iterable<Tier> tiers) {
  final usable = tiers.where((t) => t.wireId != null).toList(growable: false);
  if (usable.isEmpty) return null;
  return usable.firstWhere((t) => t.recommended, orElse: () => usable.first);
}

/// [defaultTierOf] over the live catalog; every failure collapses to null.
Future<Tier?> resolveDefaultTier() async {
  if (!sl.isRegistered<TierRepository>()) return null;
  try {
    return defaultTierOf(await sl<TierRepository>().fetchTiers());
  } catch (_) {
    return null;
  }
}
