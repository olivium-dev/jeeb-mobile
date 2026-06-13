import 'package:equatable/equatable.dart';

import '../../domain/prohibited_item.dart';

enum ProhibitedAckStatus {
  initial,
  loading,
  loaded,
  acknowledging,
  acknowledged,
  error,
}

class ProhibitedAcknowledgmentState extends Equatable {
  const ProhibitedAcknowledgmentState({
    this.status = ProhibitedAckStatus.initial,
    this.items = const [],
  });

  final ProhibitedAckStatus status;
  final List<ProhibitedItem> items;

  bool get isLoading =>
      status == ProhibitedAckStatus.loading ||
      status == ProhibitedAckStatus.acknowledging;

  bool get isAcknowledged => status == ProhibitedAckStatus.acknowledged;

  ProhibitedAcknowledgmentState copyWith({
    ProhibitedAckStatus? status,
    List<ProhibitedItem>? items,
  }) {
    return ProhibitedAcknowledgmentState(
      status: status ?? this.status,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [status, items];
}
