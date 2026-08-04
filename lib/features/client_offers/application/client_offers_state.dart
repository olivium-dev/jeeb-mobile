import 'package:equatable/equatable.dart';

import '../domain/offer.dart';
import '../domain/offer_ranking.dart' as ranking;
import '../domain/offers_repository.dart';

/// How the client wants to sort the offer list.
///
/// Defaults to [best] — the redesign's first sort chip and a deliberate
/// PRODUCT change from the old [byPrice] default: the cheapest bid is not
/// automatically the one to show first when reputation and ETA differ. See
/// `offer_ranking.dart` for the composite. [byPrice] sorts low → high,
/// [byRating] descending — best Jeebers first — both with submission time as a
/// stable tie-break.
enum OfferSortMode { best, byPrice, byRating }

/// Top-level UI status for the screen.
enum OffersScreenStatus {
  /// Cold load — no offers in state yet.
  initial,

  /// First snapshot is on the wire.
  loading,

  /// At least one snapshot has rendered. New polls keep us here.
  loaded,

  /// Cold load failed and we have nothing to show.
  failed,
}

/// Status of the inline accept action so the card can swap to a spinner.
enum AcceptStatus { idle, inFlight, succeeded }

/// Operation that produced [ClientOffersState.error].
///
/// Load/refetch errors are cleared by the next successful foreground fetch.
/// Accept errors remain visible until explicitly acknowledged or superseded by
/// another accept attempt.
enum OffersErrorSource { load, accept }

class ClientOffersState extends Equatable {
  const ClientOffersState({
    this.status = OffersScreenStatus.initial,
    this.offers = const <Offer>[],
    this.sortMode = OfferSortMode.best,
    this.windowExpiresAt,
    this.windowTotal,
    this.requestTitle,
    this.now,
    this.requestIsOpen = true,
    this.requestIsExpired = false,
    this.acceptingOfferId,
    this.acceptedOfferId,
    this.acceptStatus = AcceptStatus.idle,
    this.error,
    this.errorSource,
  });

  final OffersScreenStatus status;

  /// Sorted view of the offer list, already in display order for [sortMode].
  final List<Offer> offers;

  final OfferSortMode sortMode;

  /// Server-stamped display deadline. Null when the latest snapshot omitted it.
  final DateTime? windowExpiresAt;

  /// Denominator for the countdown meter, and a **session observation, not a
  /// server contract**: the gateway sends a deadline, never a window length.
  /// The cubit keeps the largest remaining it has seen for this request, so
  /// 100% means "the most time this session ever had left" and 0 means the real
  /// server deadline. Null until the first deadline lands — the strip then
  /// renders a track with no fill rather than inventing a fraction.
  final Duration? windowTotal;

  /// The request's item title (`/v1/requests/:id` → `title`), or null when the
  /// gateway omits it. Rendered as the top bar's subtitle.
  final String? requestTitle;

  /// Cubit's notion of "now" used to compute [windowRemaining]. Injected so
  /// tests can drive the countdown without real wall-clock waits.
  final DateTime? now;

  /// False once the gateway tells us the request has been matched / cancelled
  /// / expired — used by the view to render the closed banner.
  final bool requestIsOpen;

  /// True only when the latest request snapshot explicitly says `expired`.
  /// Local countdown progress never sets this lifecycle flag.
  final bool requestIsExpired;

  /// Id of the offer the accept call is in-flight on. Lets every card decide
  /// whether to render the Accept CTA, a spinner, or a disabled state.
  final String? acceptingOfferId;

  /// Id of the offer that accept succeeded on. Drives the success banner /
  /// route hand-off.
  final String? acceptedOfferId;

  final AcceptStatus acceptStatus;

  /// One-shot error surface from the last operation (refresh or accept).
  final OffersFailure? error;

  /// Provenance for [error], used to avoid clearing a genuine accept failure
  /// when a later offers refetch succeeds.
  final OffersErrorSource? errorSource;

  /// Time remaining on the offer window — clamped to non-negative.
  Duration get windowRemaining {
    final deadline = windowExpiresAt;
    final reference = now;
    if (deadline == null || reference == null) return Duration.zero;
    final diff = deadline.difference(reference);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Fraction of the observed window still left, or null when there is nothing
  /// honest to divide by (no deadline yet, or a zero-length observation).
  double? get windowProgress {
    final total = windowTotal;
    if (total == null || total.inMilliseconds <= 0) return null;
    final fraction = windowRemaining.inMilliseconds / total.inMilliseconds;
    return fraction.clamp(0.0, 1.0);
  }

  bool get hasOffers => offers.isNotEmpty;

  /// Id of the offer that wears the `Best value` badge — derived, never stored,
  /// so it cannot drift from [offers].
  String? get bestValueOfferId => ranking.bestValueOfferId(offers);

  /// Id of the offer that wears the `Fastest` pill (null unless the minimum ETA
  /// is unique and is not already the best-value card).
  String? get fastestOfferId => ranking.fastestOfferId(offers);

  ClientOffersState copyWith({
    OffersScreenStatus? status,
    List<Offer>? offers,
    OfferSortMode? sortMode,
    DateTime? windowExpiresAt,
    bool clearWindowExpiresAt = false,
    Duration? windowTotal,
    bool clearWindowTotal = false,
    String? requestTitle,
    bool clearRequestTitle = false,
    DateTime? now,
    bool? requestIsOpen,
    bool? requestIsExpired,
    String? acceptingOfferId,
    bool clearAcceptingOfferId = false,
    String? acceptedOfferId,
    bool clearAcceptedOfferId = false,
    AcceptStatus? acceptStatus,
    OffersFailure? error,
    OffersErrorSource? errorSource,
    bool clearError = false,
  }) {
    return ClientOffersState(
      status: status ?? this.status,
      offers: offers ?? this.offers,
      sortMode: sortMode ?? this.sortMode,
      windowExpiresAt: clearWindowExpiresAt
          ? null
          : (windowExpiresAt ?? this.windowExpiresAt),
      windowTotal: clearWindowTotal
          ? null
          : (windowTotal ?? this.windowTotal),
      requestTitle: clearRequestTitle
          ? null
          : (requestTitle ?? this.requestTitle),
      now: now ?? this.now,
      requestIsOpen: requestIsOpen ?? this.requestIsOpen,
      requestIsExpired: requestIsExpired ?? this.requestIsExpired,
      acceptingOfferId: clearAcceptingOfferId
          ? null
          : (acceptingOfferId ?? this.acceptingOfferId),
      acceptedOfferId: clearAcceptedOfferId
          ? null
          : (acceptedOfferId ?? this.acceptedOfferId),
      acceptStatus: acceptStatus ?? this.acceptStatus,
      error: clearError ? null : (error ?? this.error),
      errorSource: clearError ? null : (errorSource ?? this.errorSource),
    );
  }

  @override
  List<Object?> get props => [
    status,
    offers,
    sortMode,
    windowExpiresAt,
    windowTotal,
    requestTitle,
    now,
    requestIsOpen,
    requestIsExpired,
    acceptingOfferId,
    acceptedOfferId,
    acceptStatus,
    error,
    errorSource,
  ];
}
