import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../data/tier_repository.dart';
import '../domain/tier.dart';

enum TierSelectionStatus { initial, loading, loaded, error }

class TierSelectionState extends Equatable {
  const TierSelectionState({
    this.status = TierSelectionStatus.initial,
    this.tiers = const [],
    this.selectedTierId,
    this.failure,
    this.appFailure,
    this.confirmedTierId,
    this.usingCachedFallback = false,
  });

  final TierSelectionStatus status;
  final List<Tier> tiers;

  final TierId? selectedTierId;

  final TierLoadFailure? failure;

  /// The classified failure the error rung renders. [failure] stays for the
  /// fixtures and tests that seed the legacy enum.
  final AppFailure? appFailure;

  final TierId? confirmedTierId;

  final bool usingCachedFallback;

  Tier? get selectedTier {
    final id = selectedTierId;
    if (id == null) return null;
    for (final tier in tiers) {
      if (tier.id == id) return tier;
    }
    return null;
  }

  bool get canConfirm =>
      status == TierSelectionStatus.loaded && selectedTierId != null;

  /// A completed read that returned no tiers — an empty rung, not an error.
  bool get isEmpty => status == TierSelectionStatus.loaded && tiers.isEmpty;

  TierSelectionState copyWith({
    TierSelectionStatus? status,
    List<Tier>? tiers,
    TierId? selectedTierId,
    bool clearSelectedTier = false,
    TierLoadFailure? failure,
    bool clearFailure = false,
    AppFailure? appFailure,
    bool clearAppFailure = false,
    TierId? confirmedTierId,
    bool clearConfirmedTier = false,
    bool? usingCachedFallback,
  }) {
    return TierSelectionState(
      status: status ?? this.status,
      tiers: tiers ?? this.tiers,
      selectedTierId: clearSelectedTier
          ? null
          : (selectedTierId ?? this.selectedTierId),
      failure: clearFailure ? null : (failure ?? this.failure),
      appFailure: clearAppFailure ? null : (appFailure ?? this.appFailure),
      confirmedTierId: clearConfirmedTier
          ? null
          : (confirmedTierId ?? this.confirmedTierId),
      usingCachedFallback:
          usingCachedFallback ?? this.usingCachedFallback,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tiers,
        selectedTierId,
        failure,
        appFailure,
        confirmedTierId,
        usingCachedFallback,
      ];
}
