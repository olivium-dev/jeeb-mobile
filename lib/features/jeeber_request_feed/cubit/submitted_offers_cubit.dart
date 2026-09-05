import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
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
  bool _loadInFlight = false;

  Future<void> load() async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    final isInitial = state.status == SubmittedOffersStatus.initial;
    if (isInitial) {
      emit(state.copyWith(status: SubmittedOffersStatus.loading, error: null));
    }
    try {
      final offers = await _repository.listSubmitted();
      if (isClosed) return;
      emit(state.copyWith(
        status: SubmittedOffersStatus.ready,
        offers: offers,
        error: null,
        refreshError: null,
      ));
    } catch (e) {
      if (isClosed) return;
      final failure = AppFailure.of(e);
      // A warm failure keeps the rows; only a cold one owns the screen.
      emit(state.offers.isEmpty
          ? state.copyWith(
              status: SubmittedOffersStatus.error,
              error: failure,
              refreshError: null,
            )
          : state.copyWith(
              status: SubmittedOffersStatus.ready,
              refreshError: failure,
            ));
    } finally {
      _loadInFlight = false;
    }
  }

  Future<void> withdraw(String offerId) async {
    if (state.isWithdrawing(offerId)) return;
    if (!state.offers.any((o) => o.id == offerId)) return;
    emit(state.copyWith(
      withdrawingIds: {...state.withdrawingIds, offerId},
    ));
    SubmittedOffersEffect? effect;
    List<SubmittedOffer>? remaining;
    try {
      final ok = await _repository.withdraw(offerId);
      if (ok) {
        remaining =
            state.offers.where((o) => o.id != offerId).toList(growable: false);
      } else {
        effect = SubmittedOffersEffect.withdrawFailed(offerId, null);
      }
    } catch (e) {
      effect = SubmittedOffersEffect.withdrawFailed(offerId, AppFailure.of(e));
    } finally {
      if (!isClosed) {
        // The busy id clears on EVERY path, or the row is dead forever.
        emit(state.copyWith(
          offers: remaining,
          withdrawingIds: {...state.withdrawingIds}..remove(offerId),
          lastEffect: effect,
        ));
      }
    }
  }

  void clearEffect() {
    if (state.lastEffect == null) return;
    emit(state.copyWith(lastEffect: null));
  }

  void clearRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(refreshError: null));
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
