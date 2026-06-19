import 'package:equatable/equatable.dart';

import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';

/// Canonical async lifecycle (guardrail §2/§3). `empty` is not a status — a
/// loaded-but-null summary is impossible here (the repo either returns a
/// summary or throws), so the state machine is the three real phases.
enum OrderSummaryStatus { initial, loading, loaded, failed }

class OrderSummaryState extends Equatable {
  const OrderSummaryState({
    this.status = OrderSummaryStatus.initial,
    this.summary,
    this.error,
  });

  final OrderSummaryStatus status;
  final OrderSummary? summary;
  final OrderSummaryFailure? error;

  OrderSummaryState copyWith({
    OrderSummaryStatus? status,
    OrderSummary? summary,
    OrderSummaryFailure? error,
    bool clearError = false,
  }) =>
      OrderSummaryState(
        status: status ?? this.status,
        summary: summary ?? this.summary,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, summary, error];
}
