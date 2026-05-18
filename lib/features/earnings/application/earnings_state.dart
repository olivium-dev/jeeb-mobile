import 'package:equatable/equatable.dart';

import '../domain/earnings_summary.dart';

enum EarningsViewMode { loading, ready, error }

class EarningsState extends Equatable {
  const EarningsState({
    this.mode = EarningsViewMode.loading,
    this.summary,
    this.errorMessage,
  });

  final EarningsViewMode mode;
  final EarningsSummary? summary;
  final String? errorMessage;

  EarningsState copyWith({
    EarningsViewMode? mode,
    EarningsSummary? summary,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EarningsState(
      mode: mode ?? this.mode,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [mode, summary, errorMessage];
}
