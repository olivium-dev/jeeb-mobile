import 'package:equatable/equatable.dart';

import '../domain/wallet_repository.dart';

/// Canonical 4-state lifecycle (40_GUARDRAILS_ARCH §2/§3). `loaded` + a healthy
/// snapshot is the content state; the JM-053 engineer adds the D30 variant
/// rendering (low/empty/all-reserved) off [WalletBalance.affordabilityState].
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
