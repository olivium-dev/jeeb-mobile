import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/notifications/application/offer_lifecycle_signals.dart';
import '../domain/submitted_offer.dart';
import '../domain/submitted_offers_repository.dart';
import 'submitted_offers_state.dart';

class SubmittedOffersCubit extends Cubit<SubmittedOffersState> {
  SubmittedOffersCubit({
    required SubmittedOffersRepository repository,
    Stream<OfferLifecycleEvent>? lifecycleSignals,
  })  : _repository = repository,
        super(const SubmittedOffersState()) {

    if (lifecycleSignals != null) {
      _lifecycleSub = lifecycleSignals.listen(_onLifecycleEvent);
    }
  }

  final SubmittedOffersRepository _repository;
  StreamSubscription<OfferLifecycleEvent>? _lifecycleSub;

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
