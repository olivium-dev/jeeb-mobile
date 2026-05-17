import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/offer.dart';
import '../domain/offers_repository.dart';
import 'client_offers_state.dart';

/// Drives the client offer cards screen.
///
/// Responsibilities (T-mobile-015):
///  - Fetch the open offer list for a request id
///  - Poll for new offers so freshly-arrived bids appear without a manual
///    refresh (SSE/WebSocket lands later; polling is the gateway-friendly
///    primitive everything else can replace)
///  - Sort by price (default) or rating
///  - Drive the offer-window countdown
///  - Accept a single offer via the gateway
///
/// The cubit injects its own clock (`now`) and a poll-tick subscription so
/// tests can fast-forward time deterministically.
class ClientOffersCubit extends Cubit<ClientOffersState> {
  ClientOffersCubit({
    required OffersRepository repository,
    required String requestId,
    DateTime Function()? now,
    Duration pollInterval = const Duration(seconds: 5),
    Duration tickInterval = const Duration(seconds: 1),
    Stream<void>? pollTicks,
    Stream<void>? clockTicks,
  })  : _repository = repository,
        _requestId = requestId,
        _now = now ?? DateTime.now,
        _pollInterval = pollInterval,
        _tickInterval = tickInterval,
        _externalPollTicks = pollTicks,
        _externalClockTicks = clockTicks,
        super(const ClientOffersState());

  final OffersRepository _repository;
  final String _requestId;
  final DateTime Function() _now;
  final Duration _pollInterval;
  final Duration _tickInterval;
  final Stream<void>? _externalPollTicks;
  final Stream<void>? _externalClockTicks;

  StreamSubscription<void>? _pollSubscription;
  StreamSubscription<void>? _clockSubscription;

  /// Cold-load entry-point. Pulls the first snapshot, then wires the poll and
  /// the countdown tick. Subsequent calls are no-ops so the host route can
  /// safely re-invoke on remount.
  Future<void> load() async {
    if (state.status != OffersScreenStatus.initial) return;
    emit(state.copyWith(
      status: OffersScreenStatus.loading,
      now: _now(),
      clearError: true,
    ));
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      _emitSnapshot(snapshot, statusOverride: OffersScreenStatus.loaded);
      _attachStreams();
    } on OffersRepositoryException catch (e) {
      emit(state.copyWith(
        status: OffersScreenStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: OffersScreenStatus.failed,
        error: OffersFailure.unknown,
      ));
    }
  }

  /// Manual pull-to-refresh trigger. Doesn't change the status flag — the UI
  /// reflects refresh via the pull indicator, not a full-screen spinner.
  Future<void> refresh() async {
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      _emitSnapshot(snapshot);
    } on OffersRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: OffersFailure.unknown));
    }
  }

  /// Toggles the sort mode and re-orders the in-memory list. Doesn't refetch.
  void setSortMode(OfferSortMode mode) {
    if (state.sortMode == mode) return;
    emit(state.copyWith(
      sortMode: mode,
      offers: _sortOffers(state.offers, mode),
      clearError: true,
    ));
  }

  /// Accepts [offerId]. Emits in-flight → succeeded states so the card UI can
  /// swap to a spinner without the host route owning that flag.
  Future<void> acceptOffer(String offerId) async {
    if (state.acceptStatus == AcceptStatus.inFlight) return;
    emit(state.copyWith(
      acceptingOfferId: offerId,
      acceptStatus: AcceptStatus.inFlight,
      clearError: true,
    ));
    try {
      await _repository.acceptOffer(
        requestId: _requestId,
        offerId: offerId,
      );
      emit(state.copyWith(
        acceptStatus: AcceptStatus.succeeded,
        acceptedOfferId: offerId,
        requestIsOpen: false,
        clearAcceptingOfferId: true,
      ));
      await _pollSubscription?.cancel();
      _pollSubscription = null;
    } on OffersRepositoryException catch (e) {
      emit(state.copyWith(
        acceptStatus: AcceptStatus.idle,
        clearAcceptingOfferId: true,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        acceptStatus: AcceptStatus.idle,
        clearAcceptingOfferId: true,
        error: OffersFailure.unknown,
      ));
    }
  }

  /// One-shot error acknowledgement so a snackbar / banner replay doesn't loop.
  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  /// Advances the cubit's notion of "now" so the countdown widget rebuilds.
  /// Exposed so widget tests can drive it manually rather than depending on
  /// real wall-clock ticks.
  void tick() {
    emit(state.copyWith(now: _now()));
  }

  void _attachStreams() {
    _pollSubscription = (_externalPollTicks ??
            Stream.periodic(_pollInterval, (_) => null))
        .listen((_) => _poll());
    _clockSubscription = (_externalClockTicks ??
            Stream.periodic(_tickInterval, (_) => null))
        .listen((_) => tick());
  }

  Future<void> _poll() async {
    if (!state.requestIsOpen) return;
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      _emitSnapshot(snapshot);
    } on OffersRepositoryException catch (_) {
      // Swallow transient poll failures — the foreground refresh and accept
      // paths surface errors. We don't want a flaky network to flash an error
      // banner every 5 seconds.
    } catch (_) {/* same — swallow */}
  }

  void _emitSnapshot(
    OffersSnapshot snapshot, {
    OffersScreenStatus? statusOverride,
  }) {
    final sorted = _sortOffers(snapshot.offers, state.sortMode);
    emit(state.copyWith(
      status: statusOverride ?? OffersScreenStatus.loaded,
      offers: sorted,
      windowExpiresAt: snapshot.windowExpiresAt,
      now: _now(),
      requestIsOpen: snapshot.requestIsOpen,
    ));
  }

  /// Stable ordering: price asc (then newest first) or rating desc (then
  /// newest first). The newest-first tiebreak prevents two equal-fee offers
  /// from churning their positions every poll.
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
    await _pollSubscription?.cancel();
    await _clockSubscription?.cancel();
    return super.close();
  }
}
