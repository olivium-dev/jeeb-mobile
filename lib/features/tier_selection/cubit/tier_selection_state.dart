import 'package:equatable/equatable.dart';

import '../data/tier_repository.dart';
import '../domain/tier.dart';

/// Lifecycle the screen renders against. `initial` is the pre-fetch state so
/// the view doesn't have to special-case "empty list + not loading".
enum TierSelectionStatus { initial, loading, loaded, error }

class TierSelectionState extends Equatable {
  const TierSelectionState({
    this.status = TierSelectionStatus.initial,
    this.tiers = const [],
    this.selectedTierId,
    this.failure,
    this.confirmedTierId,
    this.usingCachedFallback = false,
  });

  final TierSelectionStatus status;
  final List<Tier> tiers;

  /// Id of the tier the user has tapped in the list. The confirm button is
  /// disabled until this is set.
  final TierId? selectedTierId;

  /// Non-null when [status] is [TierSelectionStatus.error] so the retry banner
  /// can render the right copy.
  final TierLoadFailure? failure;

  /// Set by [TierSelectionCubit.confirm] once the user commits a choice. The
  /// host listens for this and navigates to the request-summary step.
  final TierId? confirmedTierId;

  /// True when the network failed and the screen is showing bundled defaults
  /// (AC3 — 'showing cached options' soft warning).
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

  TierSelectionState copyWith({
    TierSelectionStatus? status,
    List<Tier>? tiers,
    TierId? selectedTierId,
    bool clearSelectedTier = false,
    TierLoadFailure? failure,
    bool clearFailure = false,
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
        confirmedTierId,
        usingCachedFallback,
      ];
}
