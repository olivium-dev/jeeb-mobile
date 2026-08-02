import 'package:equatable/equatable.dart';

import '../domain/wallet_repository.dart';

enum WalletHubStatus { initial, loading, loaded, failed }

class WalletHubState extends Equatable {
  const WalletHubState({
    this.status = WalletHubStatus.initial,
    this.balance,
    this.error,
  });

  final WalletHubStatus status;
  final WalletBalance? balance;
  final WalletFailure? error;

  bool get hasBalance => balance != null;

  WalletHubState copyWith({
    WalletHubStatus? status,
    WalletBalance? balance,
    WalletFailure? error,
    bool clearError = false,
  }) {
    return WalletHubState(
      status: status ?? this.status,
      balance: balance ?? this.balance,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, balance, error];
}
