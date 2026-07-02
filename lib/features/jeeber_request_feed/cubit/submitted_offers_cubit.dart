import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../domain/submitted_offer.dart';
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
  SubmittedOffersCubit({
    required SubmittedOffersRepository repository,
    Stream<OfferLifecycleEvent>? lifecycleSignals,
  })  : _repository = repository,
        super(const SubmittedOffersState()) {
    // sprint-009: an `offer_accepted` / `offer_lost` push flips the matching
    // row's badge immediately, then a re-pull reconciles against the server
    // (authoritative). Absent under bare tests / dev seams where DI isn't set up.
    if (lifecycleSignals != null) {
      _lifecycleSub = lifecycleSignals.listen(_onLifecycleEvent);
    }
  }

  final SubmittedOffersRepository _repository;
  StreamSubscription<OfferLifecycleEvent>? _lifecycleSub;

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

  /// Flip [offerId]'s badge to [status] in place (optimistic), then re-pull the
  /// authoritative list. A no-op flip when the row isn't present (the re-pull
  /// still runs so a just-decided offer that isn't in the current list appears).
  Future<void> applyOfferLifecycle(String offerId, OfferStatus status) async {
    final index = state.offers.indexWhere((o) => o.id == offerId);
    if (index != -1) {
      final flipped = [...state.offers];
      flipped[index] = flipped[index].copyWith(status: status);
      if (!isClosed) {
        emit(state.copyWith(offers: flipped));
      }
    }
    await load();
  }

  void _onLifecycleEvent(OfferLifecycleEvent event) {
    unawaited(applyOfferLifecycle(
      event.offerId,
      event.accepted ? OfferStatus.accepted : OfferStatus.lost,
    ));
  }

  @override
  Future<void> close() {
    _lifecycleSub?.cancel();
    return super.close();
  }
}
