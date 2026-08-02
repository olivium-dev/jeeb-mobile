import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/offer.dart';
import '../domain/offers_repository.dart';
import 'client_offers_state.dart';

/// Drives offer list; accepts and handles push-triggered re-reads.
class ClientOffersCubit extends Cubit<ClientOffersState> {
  ClientOffersCubit({
    required OffersRepository repository,
    required String requestId,
    DateTime Function()? now,
    Duration tickInterval = const Duration(seconds: 1),
    Stream<void>? clockTicks,
    Stream<void>? refreshSignals,
    Future<void> Function(Duration)? retryDelay,
  }) : _repository = repository,
       _requestId = requestId,
       _now = now ?? DateTime.now,
       _tickInterval = tickInterval,
       _externalClockTicks = clockTicks,
       _refreshSignals = refreshSignals,
       _retryDelay = retryDelay ?? _wallClockDelay,
       super(const ClientOffersState());

  static Future<void> _wallClockDelay(Duration d) => Future<void>.delayed(d);

  final OffersRepository _repository;
  final String _requestId;
  final DateTime Function() _now;
  final Duration _tickInterval;
  final Stream<void>? _externalClockTicks;

  final Stream<void>? _refreshSignals;

  final Future<void> Function(Duration) _retryDelay;

  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _clockSubscription;

  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  bool _pollInFlight = false;

  Future<void> load() async {
    if (state.status != OffersScreenStatus.initial &&
        state.status != OffersScreenStatus.failed) {
      return;
    }
    emit(
      state.copyWith(
        status: OffersScreenStatus.loading,
        now: _now(),
        clearError: true,
      ),
    );
    await _attemptColdLoad();
  }

  Future<void> _attemptColdLoad() async {
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      if (isClosed) return;
      _emitSnapshot(
        snapshot,
        statusOverride: OffersScreenStatus.loaded,
        clearLoadError: true,
      );
      if (snapshot.requestIsOpen) _attachStreams();
    } on OffersRepositoryException catch (e) {
      if (isClosed) return;
      if (e.failure == OffersFailure.rateLimited) {
        _scheduleColdRetry(e.retryAfter);
        return;
      }
      emit(
        state.copyWith(
          status: OffersScreenStatus.failed,
          error: e.failure,
          errorSource: OffersErrorSource.load,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: OffersScreenStatus.failed,
          error: OffersFailure.unknown,
          errorSource: OffersErrorSource.load,
        ),
      );
    }
  }

  void _scheduleColdRetry(Duration? after) {
    final delay = after ?? const Duration(seconds: 5);
    _retryDelay(delay).then((_) {
      if (isClosed) return;
      if (state.status != OffersScreenStatus.loading) return;
      _attemptColdLoad();
    });
  }

  Future<void> refresh() async {
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      if (isClosed) return;
      _emitSnapshot(snapshot, clearLoadError: true);
      if (!snapshot.requestIsOpen) await _stopStreams();
    } on OffersRepositoryException catch (e) {
      if (e.failure == OffersFailure.rateLimited) return;
      emit(
        state.copyWith(error: e.failure, errorSource: OffersErrorSource.load),
      );
    } catch (_) {
      emit(
        state.copyWith(
          error: OffersFailure.unknown,
          errorSource: OffersErrorSource.load,
        ),
      );
    }
  }

  void refreshOnResume() {
    if (isClosed || state.status != OffersScreenStatus.loaded) return;
    unawaited(_refreshFromPush());
  }

  void setSortMode(OfferSortMode mode) {
    if (state.sortMode == mode) return;
    emit(
      state.copyWith(
        sortMode: mode,
        offers: _sortOffers(state.offers, mode),
        clearError: true,
      ),
    );
  }

  void beginAccept(String offerId) {
    if (isClosed ||
        !state.requestIsOpen ||
        state.acceptStatus == AcceptStatus.inFlight) {
      return;
    }
    emit(
      state.copyWith(
        acceptingOfferId: offerId,
        acceptStatus: AcceptStatus.inFlight,
      ),
    );
  }

  void endAccept() {
    if (isClosed || state.acceptStatus != AcceptStatus.inFlight) return;
    emit(
      state.copyWith(
        acceptStatus: AcceptStatus.idle,
        clearAcceptingOfferId: true,
      ),
    );
  }

  Future<void> acceptOffer(String offerId) async {
    if (!state.requestIsOpen || state.acceptStatus == AcceptStatus.inFlight) {
      return;
    }
    emit(
      state.copyWith(
        acceptingOfferId: offerId,
        acceptStatus: AcceptStatus.inFlight,
        clearError: true,
      ),
    );
    try {
      await _repository.acceptOffer(requestId: _requestId, offerId: offerId);
      emit(
        state.copyWith(
          acceptStatus: AcceptStatus.succeeded,
          acceptedOfferId: offerId,
          requestIsOpen: false,
          clearAcceptingOfferId: true,
        ),
      );
      await _stopStreams();
    } on OffersRepositoryException catch (e) {
      emit(
        state.copyWith(
          acceptStatus: AcceptStatus.idle,
          clearAcceptingOfferId: true,
          error: e.failure,
          errorSource: OffersErrorSource.accept,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          acceptStatus: AcceptStatus.idle,
          clearAcceptingOfferId: true,
          error: OffersFailure.unknown,
          errorSource: OffersErrorSource.accept,
        ),
      );
    }
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  void tick() {
    if (isClosed || !state.requestIsOpen || state.windowExpiresAt == null) {
      return;
    }
    emit(state.copyWith(now: _now()));
  }

  void _attachStreams() {
    _refreshSubscription = _refreshSignals?.listen((_) => _refreshFromPush());
    _clockSubscription =
        (_externalClockTicks ?? Stream.periodic(_tickInterval, (_) {})).listen(
          (_) => tick(),
        );
  }

  Future<void> _refreshFromPush() async {
    if (isClosed || !state.requestIsOpen) return;
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      if (isClosed) return;
      _emitSnapshot(snapshot);
      if (!snapshot.requestIsOpen) await _stopStreams();
    } on OffersRepositoryException catch (_) {
    } catch (_) {
    } finally {
      _pollInFlight = false;
    }
  }

  void _emitSnapshot(
    OffersSnapshot snapshot, {
    OffersScreenStatus? statusOverride,
    bool clearLoadError = false,
  }) {
    final sorted = _sortOffers(snapshot.offers, state.sortMode);
    final shouldClearError =
        clearLoadError && state.errorSource == OffersErrorSource.load;
    emit(
      state.copyWith(
        status: statusOverride ?? OffersScreenStatus.loaded,
        offers: sorted,
        windowExpiresAt: snapshot.windowExpiresAt,
        clearWindowExpiresAt: snapshot.windowExpiresAt == null,
        now: _now(),
        requestIsOpen: snapshot.requestIsOpen,
        requestIsExpired: snapshot.requestIsExpired,
        clearError: shouldClearError,
      ),
    );
  }

  Future<void> _stopStreams() async {
    await _refreshSubscription?.cancel();
    await _clockSubscription?.cancel();
    _refreshSubscription = null;
    _clockSubscription = null;
  }

  List<Offer> _sortOffers(List<Offer> input, OfferSortMode mode) {
    final out = List<Offer>.of(input);
    out.sort((a, b) {
      int primary;
      switch (mode) {
        case OfferSortMode.byPrice:
          primary = a.fee.compareTo(b.fee);
          break;
        case OfferSortMode.byRating:
          primary = b.rating.compareTo(a.rating);
          break;
      }
      if (primary != 0) return primary;
      return b.submittedAt.compareTo(a.submittedAt);
    });
    return List<Offer>.unmodifiable(out);
  }

  @override
  Future<void> close() async {
    await _stopStreams();
    return super.close();
  }
}
