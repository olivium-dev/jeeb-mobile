import 'package:equatable/equatable.dart';

import '../domain/offer.dart';
import '../domain/offers_repository.dart';

enum OfferSortMode { byPrice, byRating }

enum OffersScreenStatus {
  initial,

  loading,

  loaded,

  failed,
}

enum AcceptStatus { idle, inFlight, succeeded }

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

  final List<Offer> offers;

  final OfferSortMode sortMode;

  final DateTime? windowExpiresAt;

  final DateTime? now;

  final bool requestIsOpen;

  final bool requestIsExpired;

  final String? acceptingOfferId;

  final String? acceptedOfferId;

  final AcceptStatus acceptStatus;

  final OffersFailure? error;

  final OffersErrorSource? errorSource;

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
