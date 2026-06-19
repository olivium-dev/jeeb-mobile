import 'package:equatable/equatable.dart';

import '../domain/submitted_offer.dart';

/// Load axis for the Pending-Response sub-tab. Orthogonal to "is the list
/// empty" — the view combines [status] and `offers.isEmpty` to choose between
/// spinner / list / empty state (mirrors [RequestFeedStatus]).
enum SubmittedOffersStatus { initial, loading, ready, error }

class SubmittedOffersState extends Equatable {
  const SubmittedOffersState({
    this.status = SubmittedOffersStatus.initial,
    this.offers = const [],
    this.withdrawingIds = const {},
  });

  /// High-level load status — drives spinner vs list vs error.
  final SubmittedOffersStatus status;

  /// The jeeber's submitted offers awaiting a customer decision, render order.
  final List<SubmittedOffer> offers;

  /// Ids of offers with an in-flight withdraw call so the row shows a busy
  /// affordance without locking the whole list.
  final Set<String> withdrawingIds;

  bool isWithdrawing(String id) => withdrawingIds.contains(id);

  SubmittedOffersState copyWith({
    SubmittedOffersStatus? status,
    List<SubmittedOffer>? offers,
    Set<String>? withdrawingIds,
  }) {
    return SubmittedOffersState(
      status: status ?? this.status,
      offers: offers ?? this.offers,
      withdrawingIds: withdrawingIds ?? this.withdrawingIds,
    );
  }

  @override
  List<Object?> get props => [status, offers, withdrawingIds];
}
