import 'package:equatable/equatable.dart';

import '../domain/offer.dart';
import '../domain/offers_repository.dart';

/// How the client wants to sort the offer list.
///
/// Defaults to [byPrice] (low → high) per AC. [byRating] sorts descending —
/// best Jeebers first — with submission time as a stable tie-break.
enum OfferSortMode { byPrice, byRating }

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
    this.sortMode = OfferSortMode.byPrice,
    this.windowExpiresAt,
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

  bool get hasOffers => offers.isNotEmpty;

  ClientOffersState copyWith({
    OffersScreenStatus? status,
    List<Offer>? offers,
    OfferSortMode? sortMode,
    DateTime? windowExpiresAt,
    bool clearWindowExpiresAt = false,
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
