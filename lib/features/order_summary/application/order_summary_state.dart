import 'package:equatable/equatable.dart';

import '../domain/order_summary.dart';
import '../domain/order_summary_repository.dart';

enum OrderSummaryStatus { initial, loading, loaded, failed }

class OrderSummaryState extends Equatable {
  const OrderSummaryState({
    this.status = OrderSummaryStatus.initial,
    this.summary,
    this.error,
    this.refreshError,
  });

  final OrderSummaryStatus status;
  final OrderSummary? summary;
  final OrderSummaryFailure? error;

  /// A warm refresh failed while the summary is on screen: a note, not a rung.
  final OrderSummaryFailure? refreshError;

  OrderSummaryState copyWith({
    OrderSummaryStatus? status,
    OrderSummary? summary,
    OrderSummaryFailure? error,
    OrderSummaryFailure? refreshError,
    bool clearError = false,
    bool clearRefreshError = false,
  }) =>
      OrderSummaryState(
        status: status ?? this.status,
        summary: summary ?? this.summary,
        error: clearError ? null : (error ?? this.error),
        refreshError:
            clearRefreshError ? null : (refreshError ?? this.refreshError),
      );

  @override
  List<Object?> get props => [status, summary, error, refreshError];
}
