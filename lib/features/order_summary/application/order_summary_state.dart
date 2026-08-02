import 'package:equatable/equatable.dart';

import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';

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
