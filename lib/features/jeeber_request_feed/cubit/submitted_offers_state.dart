import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/submitted_offer.dart';

enum SubmittedOffersStatus { initial, loading, ready, error }

/// A one-shot outcome the list acknowledges with `clearEffect()`.
class SubmittedOffersEffect extends Equatable {
  const SubmittedOffersEffect.withdrawFailed(this.offerId, this.failure);

  final String offerId;

  /// Null when the repository answered a clean `false` rather than throwing.
  final AppFailure? failure;

  @override
  List<Object?> get props => [offerId, failure];
}

class SubmittedOffersState extends Equatable {
  const SubmittedOffersState({
    this.status = SubmittedOffersStatus.initial,
    this.offers = const [],
    this.withdrawingIds = const {},
    this.lastEffect,
    this.error,
    this.refreshError,
  });

  final SubmittedOffersStatus status;

  final List<SubmittedOffer> offers;

  final Set<String> withdrawingIds;

  final SubmittedOffersEffect? lastEffect;

  /// Cold failure: the read failed with no rows to keep.
  final AppFailure? error;

  /// Warm failure: rows are on screen and a refresh failed.
  final AppFailure? refreshError;

  bool isWithdrawing(String id) => withdrawingIds.contains(id);

  SubmittedOffersState copyWith({
    SubmittedOffersStatus? status,
    List<SubmittedOffer>? offers,
    Set<String>? withdrawingIds,
    Object? lastEffect = _sentinel,
    Object? error = _sentinel,
    Object? refreshError = _sentinel,
  }) {
    return SubmittedOffersState(
      status: status ?? this.status,
      offers: offers ?? this.offers,
      withdrawingIds: withdrawingIds ?? this.withdrawingIds,
      lastEffect: identical(lastEffect, _sentinel)
          ? this.lastEffect
          : lastEffect as SubmittedOffersEffect?,
      error: identical(error, _sentinel) ? this.error : error as AppFailure?,
      refreshError: identical(refreshError, _sentinel)
          ? this.refreshError
          : refreshError as AppFailure?,
    );
  }

  @override
  List<Object?> get props => [
        status,
        offers,
        withdrawingIds,
        lastEffect,
        error,
        refreshError,
      ];
}

const Object _sentinel = Object();
