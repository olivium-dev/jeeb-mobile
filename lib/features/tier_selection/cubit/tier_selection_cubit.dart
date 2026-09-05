import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../data/tier_repository.dart';
import '../domain/tier.dart';
import 'tier_selection_state.dart';

class TierSelectionCubit extends Cubit<TierSelectionState> {
  TierSelectionCubit({required TierRepository repository})
    : _repository = repository,
      super(const TierSelectionState());

  final TierRepository _repository;

  Future<void> load() async {
    if (state.status == TierSelectionStatus.loading) return;
    emit(
      state.copyWith(
        status: TierSelectionStatus.loading,
        clearFailure: true,
        clearAppFailure: true,
        usingCachedFallback: false,
      ),
    );
    try {
      final tiers = await _repository.fetchTiers();
      _emitLoaded(tiers);
    } on AppFailure catch (f) {
      _emitFailure(f);
    } on TierLoadException catch (e) {
      _emitFailure(
        e.failure == TierLoadFailure.network
            ? const NetworkFailure()
            : const ServerFailure(status: 500),
        legacy: e.failure,
      );
    } catch (e) {
      _emitFailure(AppFailure.of(e));
    }
  }

  void _emitLoaded(List<Tier> tiers) {
    final selectedTierId = _retainedSelection(tiers);
    emit(
      state.copyWith(
        status: TierSelectionStatus.loaded,
        tiers: tiers,
        selectedTierId: selectedTierId,
        clearSelectedTier:
            selectedTierId == null && state.selectedTierId != null,
        clearFailure: true,
        clearAppFailure: true,
        usingCachedFallback: false,
      ),
    );
  }

  /// A transient refetch failure must not throw away a valid selection.
  void _emitFailure(AppFailure failure, {TierLoadFailure? legacy}) {
    final bool wipe = state.tiers.isEmpty;
    emit(
      state.copyWith(
        status: TierSelectionStatus.error,
        appFailure: failure,
        failure: legacy ??
            (failure is NetworkFailure || failure is TimeoutFailure
                ? TierLoadFailure.network
                : TierLoadFailure.server),
        clearSelectedTier: wipe,
        clearConfirmedTier: wipe,
        usingCachedFallback: false,
      ),
    );
  }

  void selectTier(TierId id) {
    if (state.status != TierSelectionStatus.loaded) return;
    if (!state.tiers.any((t) => t.id == id)) return;
    if (state.selectedTierId == id) return;
    emit(state.copyWith(selectedTierId: id, clearConfirmedTier: true));
  }

  void confirm() {
    if (!state.canConfirm) return;
    final id = state.selectedTierId;
    if (id == null) return;
    emit(state.copyWith(confirmedTierId: id));
  }

  /// R9 loads with a row already lit (doc-13 P0-4): an existing choice wins,
  /// otherwise the catalog's recommended tier seeds the selection.
  TierId? _retainedSelection(List<Tier> tiers) {
    if (tiers.any((tier) => tier.id == state.selectedTierId)) {
      return state.selectedTierId;
    }
    for (final tier in tiers) {
      if (tier.recommended) return tier.id;
    }
    return null;
  }
}
