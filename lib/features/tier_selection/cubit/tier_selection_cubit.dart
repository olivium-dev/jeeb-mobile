import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/tier_repository.dart';
import '../domain/tier.dart';
import 'tier_selection_state.dart';

/// Owns the tier-catalog fetch and the user's selection. Three calls:
///
///   - [load] pulls `GET /tiers` on first mount and on retry; on failure it
///     surfaces [TierSelectionStatus.error] so the screen blocks Continue and
///     shows a retry banner. It deliberately does NOT fall back to the bundled
///     [FakeTierRepository.defaultCatalog] (JEBV4-300): those tiers carry no
///     gateway [Tier.serverId], so confirming one would put a client-side enum
///     slug on the wire for a tier the gateway never minted (and On-the-Way /
///     Eco are tiers the server does not even sell).
///   - [selectTier] records the user's choice without confirming it.
///   - [confirm] commits the choice; the host listens for
///     [TierSelectionState.confirmedTierId] to drive navigation.
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
      usingCachedFallback: false,
    ));
    try {
      final tiers = await _repository.fetchTiers();
      _emitLoaded(tiers);
    } on TierLoadException catch (e) {
      _emitFailure(e.failure);
    } catch (_) {
      _emitFailure(TierLoadFailure.network);
    }
  }

  void _emitLoaded(List<Tier> tiers) {
    final preselected = _recommendedId(tiers) ?? state.selectedTierId;
    emit(state.copyWith(
      status: TierSelectionStatus.loaded,
      tiers: tiers,
      selectedTierId: preselected,
      clearSelectedTier: preselected == null && state.selectedTierId != null,
      clearFailure: true,
      usingCachedFallback: false,
    ));
  }

  /// JEBV4-300: surface the fetch failure instead of silently serving the
  /// bundled fallback catalog. The screen renders a retry banner and keeps the
  /// Continue CTA hidden, so no fallback tier (serverId == null) can ever reach
  /// `POST /requests`. Retry re-runs [load] → `GET /tiers`.
  void _emitFailure(TierLoadFailure failure) {
    emit(state.copyWith(
      status: TierSelectionStatus.error,
      failure: failure,
      clearSelectedTier: true,
      clearConfirmedTier: true,
      usingCachedFallback: false,
    ));
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
