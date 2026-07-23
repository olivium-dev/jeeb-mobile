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
    Future<void> Function(Duration)? retryDelay,
  }) : _repository = repository,
       _requestId = requestId,
       _now = now ?? DateTime.now,
       _pollInterval = pollInterval,
       _tickInterval = tickInterval,
       _externalPollTicks = pollTicks,
       _externalClockTicks = clockTicks,
       _retryDelay = retryDelay ?? _wallClockDelay,
       super(const ClientOffersState());

  static Future<void> _wallClockDelay(Duration d) => Future<void>.delayed(d);

  final OffersRepository _repository;
  final String _requestId;
  final DateTime Function() _now;
  final Duration _pollInterval;
  final Duration _tickInterval;
  final Stream<void>? _externalPollTicks;
  final Stream<void>? _externalClockTicks;

  /// Injected back-off timer for the rate-limited cold-load auto-retry. Real
  /// wall-clock in production; tests pass a deterministic/controllable delay so
  /// the retry fires without a real wait (and no timer leaks into the binding).
  final Future<void> Function(Duration) _retryDelay;

  StreamSubscription<void>? _pollSubscription;
  StreamSubscription<void>? _clockSubscription;

  /// True while a `GET /v1/offers` poll is on the wire — a second poll tick that
  /// overlaps a slow response is dropped so overlapping ticks never fire
  /// duplicate concurrent reads (FIX-A: the shared coalescer would collapse
  /// them anyway, but this stops the wasted work at the source).
  bool _pollInFlight = false;

  /// Cold-load entry-point. Pulls the first snapshot, then wires the poll and
  /// the countdown tick. A failed load may enter this same full path again via
  /// the Retry CTA; calls from any other status are no-ops.
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

  /// One cold-load attempt. On success wires the streams; on a fatal failure
  /// drops to `failed`; on a rate-limit (429 / local suppression) it KEEPS the
  /// screen in `loading` and schedules an auto-retry after Retry-After — the
  /// connection-error page is never shown for transient back-pressure (FIX-A).
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

  /// Re-attempts the cold load after [after] (Retry-After, or a small default),
  /// while the screen stays in its loading state. Guarded so it no-ops once the
  /// cubit closes or the load has already resolved to another status.
  void _scheduleColdRetry(Duration? after) {
    final delay = after ?? const Duration(seconds: 5);
    _retryDelay(delay).then((_) {
      if (isClosed) return;
      // A concurrent success/failure may have moved us off `loading`; only the
      // still-loading cold path should re-attempt.
      if (state.status != OffersScreenStatus.loading) return;
      _attemptColdLoad();
    });
  }

  /// Manual pull-to-refresh trigger. Doesn't change the status flag — the UI
  /// reflects refresh via the pull indicator, not a full-screen spinner.
  Future<void> refresh() async {
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      if (isClosed) return;
      _emitSnapshot(snapshot, clearLoadError: true);
      if (!snapshot.requestIsOpen) await _stopStreams();
    } on OffersRepositoryException catch (e) {
      // A rate-limit during a manual refresh is transient back-pressure: the
      // RateLimitInterceptor has already paused the reads and the next poll
      // resumes once Retry-After clears. Don't flash an error banner for it.
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

  /// Toggles the sort mode and re-orders the in-memory list. Doesn't refetch.
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

  /// B-01: marks [offerId] as the one whose accept-confirm sheet is currently
  /// open / in flight, so every OTHER card's Accept CTA disables (the
  /// accept-exactly-ONE guard). The real `POST /offers/:id/accept` runs inside
  /// the sheet's OfferAcceptCubit — this only drives the LIST's disable state,
  /// wiring the previously-dead `acceptingOfferId` mechanism into the real
  /// (sheet-based) accept path. Cleared by [endAccept] when the sheet closes.
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

  /// B-01: clears the in-flight accept marker when the accept-confirm sheet
  /// closes (cancelled, failed-and-dismissed, or superseded) so the sibling
  /// Accept CTAs re-enable. On a successful accept the list has already
  /// navigated to order-chat, so the `isClosed` guard makes this a no-op.
  void endAccept() {
    if (isClosed || state.acceptStatus != AcceptStatus.inFlight) return;
    emit(
      state.copyWith(
        acceptStatus: AcceptStatus.idle,
        clearAcceptingOfferId: true,
      ),
    );
  }

  /// Accepts [offerId]. Emits in-flight → succeeded states so the card UI can
  /// swap to a spinner without the host route owning that flag.
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

  /// One-shot error acknowledgement so a snackbar / banner replay doesn't loop.
  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  /// Advances the cubit's notion of "now" so the countdown widget rebuilds.
  /// Exposed so widget tests can drive it manually rather than depending on
  /// real wall-clock ticks.
  void tick() {
    if (isClosed || !state.requestIsOpen || state.windowExpiresAt == null) {
      return;
    }
    emit(state.copyWith(now: _now()));
  }

  void _attachStreams() {
    _pollSubscription =
        (_externalPollTicks ?? Stream.periodic(_pollInterval, (_) {})).listen(
          (_) => _poll(),
        );
    _clockSubscription =
        (_externalClockTicks ?? Stream.periodic(_tickInterval, (_) {})).listen(
          (_) => tick(),
        );
  }

  Future<void> _poll() async {
    if (!state.requestIsOpen) return;
    // In-flight guard (FIX-A): behind a slow proxy a `GET /v1/offers` can take
    // longer than the poll cadence; without this a new tick would fire a second
    // concurrent read over the first. Drop the overlapping tick — the next one
    // picks up once the current read settles.
    if (_pollInFlight) return;
    _pollInFlight = true;
    try {
      final snapshot = await _repository.fetchOffers(_requestId);
      if (isClosed) return;
      _emitSnapshot(snapshot);
      if (!snapshot.requestIsOpen) await _stopStreams();
    } on OffersRepositoryException catch (_) {
      // Swallow transient poll failures (including rate-limits) — the foreground
      // refresh and accept paths surface errors. We don't want a flaky network
      // or a 429 back-off to flash an error banner every 5 seconds.
    } catch (_) {
      /* same — swallow */
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
    await _pollSubscription?.cancel();
    await _clockSubscription?.cancel();
    _pollSubscription = null;
    _clockSubscription = null;
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
    await _stopStreams();
    return super.close();
  }
}
