import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../domain/wallet_repository.dart';
import 'wallet_hub_state.dart';

class WalletHubCubit extends Cubit<WalletHubState> {
  WalletHubCubit({required WalletRepository repository})
    : _repository = repository,
      super(const WalletHubState());

  final WalletRepository _repository;

  /// A double pull-to-refresh must not fire two reads (§7-13b).
  bool _refreshing = false;

  /// Re-entrant from `failed` so the error rung's Retry actually retries; the
  /// in-flight guard is what stops a double tap.
  Future<void> load() async {
    if (state.status == WalletHubStatus.loading ||
        state.status == WalletHubStatus.loaded) {
      return;
    }
    emit(state.copyWith(status: WalletHubStatus.loading, clearError: true));
    try {
      final balance = await _repository.fetchBalance();
      emit(
        state.copyWith(
          status: WalletHubStatus.loaded,
          balance: balance,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } catch (e) {
      final failure = classifyWalletFailure(e);
      emit(
        state.copyWith(
          status: WalletHubStatus.failed,
          error: legacyWalletFailure(failure),
          failure: failure,
        ),
      );
    }
  }

  /// Never flips [WalletHubStatus]: a failed refresh keeps the balance the
  /// Jeeber is reading and raises a dismissible note instead.
  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final balance = await _repository.fetchBalance();
      emit(
        state.copyWith(
          status: WalletHubStatus.loaded,
          balance: balance,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(refreshError: classifyWalletFailure(e)));
    } finally {
      _refreshing = false;
    }
  }

  void clearRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }
}

/// Unwraps the repository's own classification so the kind survives the
/// feature exception; anything else is classified from scratch.
AppFailure classifyWalletFailure(Object error) {
  if (error is WalletRepositoryException) {
    return error.cause ??
        switch (error.failure) {
          WalletFailure.network => networkFailureFromReachability(),
          WalletFailure.unauthorized => const UnauthorizedFailure(),
          WalletFailure.unknown => const UnknownFailure(),
        };
  }
  return AppFailure.of(error);
}

/// The legacy enum stays on the state so no outside reader breaks.
WalletFailure legacyWalletFailure(AppFailure f) => switch (f) {
  NetworkFailure() || TimeoutFailure() => WalletFailure.network,
  UnauthorizedFailure() || ForbiddenFailure() => WalletFailure.unauthorized,
  _ => WalletFailure.unknown,
};
