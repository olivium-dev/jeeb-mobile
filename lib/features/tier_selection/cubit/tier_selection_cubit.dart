import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/tier_repository.dart';
import '../domain/tier.dart';
import 'tier_selection_state.dart';

/// Owns the tier-catalog fetch and the user's selection. Three calls:
///
///   - [load] pulls `GET /api/tiers` on first mount and on retry.
///   - [selectTier] records the user's choice without confirming it.
///   - [confirm] commits the choice; the host listens for [
///     TierSelectionState.confirmedTierId] to drive navigation.
///
/// The cubit pre-selects the recommended tier from the catalog (if any) so the
/// confirm button is reachable on first paint — users can still tap to change.
class TierSelectionCubit extends Cubit<TierSelectionState> {
  TierSelectionCubit({required TierRepository repository})
      : _repository = repository,
        super(const TierSelectionState());

  final TierRepository _repository;

  Future<void> load() async {
    if (state.status == TierSelectionStatus.loading) return;
    emit(state.copyWith(
      status: TierSelectionStatus.loading,
      clearFailure: true,
    ));
    try {
      final tiers = await _repository.fetchTiers();
      final preselected = _recommendedId(tiers) ?? state.selectedTierId;
      emit(state.copyWith(
        status: TierSelectionStatus.loaded,
        tiers: tiers,
        selectedTierId: preselected,
        clearSelectedTier: preselected == null && state.selectedTierId != null,
        clearFailure: true,
      ));
    } on TierLoadException catch (e) {
      emit(state.copyWith(
        status: TierSelectionStatus.error,
        failure: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: TierSelectionStatus.error,
        failure: TierLoadFailure.server,
      ));
    }
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

  TierId? _recommendedId(List<Tier> tiers) {
    for (final tier in tiers) {
      if (tier.recommended) return tier.id;
    }
    return null;
  }
}
