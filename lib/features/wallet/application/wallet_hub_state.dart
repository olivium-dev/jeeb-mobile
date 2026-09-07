import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/wallet_repository.dart';

enum WalletHubStatus { initial, loading, loaded, failed }

class WalletHubState extends Equatable {
  const WalletHubState({
    this.status = WalletHubStatus.initial,
    this.balance,
    this.error,
    this.failure,
    this.refreshError,
  });

  final WalletHubStatus status;
  final WalletBalance? balance;
  final WalletFailure? error;

  /// The classified cold-load failure the error rung renders.
  final AppFailure? failure;

  /// A failed refresh over rows that are still on screen: the note goes above
  /// the balance card, and [status] stays `loaded` (LR-09/UX-18).
  final AppFailure? refreshError;

  bool get hasBalance => balance != null;

  WalletHubState copyWith({
    WalletHubStatus? status,
    WalletBalance? balance,
    WalletFailure? error,
    AppFailure? failure,
    bool clearError = false,
    AppFailure? refreshError,
    bool clearRefreshError = false,
  }) {
    return WalletHubState(
      status: status ?? this.status,
      balance: balance ?? this.balance,
      error: clearError ? null : (error ?? this.error),
      failure: clearError ? null : (failure ?? this.failure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => [status, balance, error, failure, refreshError];
}
