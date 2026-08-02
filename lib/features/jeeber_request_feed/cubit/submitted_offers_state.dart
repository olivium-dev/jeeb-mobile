import 'package:equatable/equatable.dart';

import '../domain/submitted_offer.dart';




enum SubmittedOffersStatus { initial, loading, ready, error }

class SubmittedOffersState extends Equatable {
  const SubmittedOffersState({
    this.status = SubmittedOffersStatus.initial,
    this.offers = const [],
    this.withdrawingIds = const {},
  });

  
  final SubmittedOffersStatus status;

  
  final List<SubmittedOffer> offers;

  
  
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
