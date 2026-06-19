import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/submitted_offers_repository.dart';
import 'submitted_offers_state.dart';

/// Drives the feed's Pending-Response sub-tab (JM-047/048 AC3): the offers the
/// jeeber has submitted that are awaiting a customer decision, plus the
/// per-row withdraw (D15).
///
/// Lazy by design — [load] is only called when the Pending tab is first
/// selected, so a jeeber who never opens it never hits
/// `GET /offer-service/v1/offers?jeeberId=`.
class SubmittedOffersCubit extends Cubit<SubmittedOffersState> {
  SubmittedOffersCubit({required SubmittedOffersRepository repository})
      : _repository = repository,
        super(const SubmittedOffersState());

  final SubmittedOffersRepository _repository;

  /// Fetch the submitted offers. Shows a spinner only on the first load; a
  /// pull-to-refresh re-fetch keeps the current list on screen.
  Future<void> load() async {
    final isInitial = state.status == SubmittedOffersStatus.initial;
    if (isInitial) {
      emit(state.copyWith(status: SubmittedOffersStatus.loading));
    }
    try {
      final offers = await _repository.listSubmitted();
      emit(state.copyWith(
        status: SubmittedOffersStatus.ready,
        offers: offers,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: state.offers.isEmpty
            ? SubmittedOffersStatus.error
            : SubmittedOffersStatus.ready,
      ));
    }
  }

  /// Withdraw [offerId] (D15). Optimistically marks the row busy; on success it
  /// is removed from the list, on failure the busy flag is cleared so the
  /// jeeber can retry.
  Future<void> withdraw(String offerId) async {
    if (state.isWithdrawing(offerId)) return;
    if (!state.offers.any((o) => o.id == offerId)) return;
    emit(state.copyWith(
      withdrawingIds: {...state.withdrawingIds, offerId},
    ));
    final ok = await _repository.withdraw(offerId);
    final clearedBusy = {...state.withdrawingIds}..remove(offerId);
    if (!ok) {
      emit(state.copyWith(withdrawingIds: clearedBusy));
      return;
    }
    emit(state.copyWith(
      offers: state.offers.where((o) => o.id != offerId).toList(growable: false),
      withdrawingIds: clearedBusy,
    ));
  }
}
