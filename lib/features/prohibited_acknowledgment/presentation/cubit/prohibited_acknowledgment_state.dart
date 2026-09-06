import 'package:equatable/equatable.dart';

import '../../../../core/network/app_failure.dart';
import '../../domain/prohibited_item.dart';

enum ProhibitedAckStatus {
  initial,
  loading,
  loaded,
  acknowledging,
  acknowledged,
  error,

  /// The server refused the acknowledgement: nothing is latched locally and
  /// the dialog stays open so the user can retry.
  acknowledgeFailed,
}

class ProhibitedAcknowledgmentState extends Equatable {
  const ProhibitedAcknowledgmentState({
    this.status = ProhibitedAckStatus.initial,
    this.items = const [],
    this.failure,
    this.matches = const <String>[],
  });

  final ProhibitedAckStatus status;
  final List<ProhibitedItem> items;

  /// The classified read/acknowledge failure. Copy comes from `failureCopy`.
  final AppFailure? failure;

  /// Keywords the gateway flagged on this request (AE-01), if any.
  final List<String> matches;

  bool get isLoading =>
      status == ProhibitedAckStatus.loading ||
      status == ProhibitedAckStatus.acknowledging;

  bool get isAcknowledged => status == ProhibitedAckStatus.acknowledged;

  ProhibitedAcknowledgmentState copyWith({
    ProhibitedAckStatus? status,
    List<ProhibitedItem>? items,
    AppFailure? failure,
    bool clearFailure = false,
    List<String>? matches,
  }) {
    return ProhibitedAcknowledgmentState(
      status: status ?? this.status,
      items: items ?? this.items,
      failure: clearFailure ? null : (failure ?? this.failure),
      matches: matches ?? this.matches,
    );
  }

  @override
  List<Object?> get props => [status, items, failure, matches];
}
