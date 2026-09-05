import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/account_status_repository.dart';
import 'account_status_state.dart';

class AccountStatusCubit extends Cubit<AccountStatusState> {
  AccountStatusCubit({required AccountStatusRepository repository})
      : _repository = repository,
        super(const AccountStatusState());

  final AccountStatusRepository _repository;

  /// The cold read. Retryable from `failed` — the old `!= initial` guard made
  /// the error rung's CTA a no-op.
  Future<void> load() async {
    if (state.status == AccountStatusScreenStatus.loading) return;
    emit(state.copyWith(
      status: AccountStatusScreenStatus.loading,
      clearError: true,
      clearRefreshError: true,
    ));
    await _read(warm: false);
  }

  /// The warm read: with a loaded banner on screen it NEVER flips to loading
  /// and never blanks the banner — a second failure sets `refreshError`.
  Future<void> refresh() async {
    if (state.status == AccountStatusScreenStatus.loading) return;
    final bool warm =
        state.info != null && state.status == AccountStatusScreenStatus.loaded;
    if (!warm) {
      emit(state.copyWith(
        status: AccountStatusScreenStatus.loading,
        clearError: true,
        clearRefreshError: true,
      ));
    }
    await _read(warm: warm);
  }

  void dismissRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> _read({required bool warm}) async {
    try {
      final info = await _repository.fetchStatus();
      emit(state.copyWith(
        status: AccountStatusScreenStatus.loaded,
        info: info,
        clearError: true,
        clearRefreshError: true,
      ));
    } catch (e) {
      final AccountStatusFailure failure = e is AccountStatusRepositoryException
          ? e.failure
          : AccountStatusFailure.unknown;
      final AppFailure appFailure = e is AccountStatusRepositoryException
          ? (e.appFailure ?? _appFailureFor(failure))
          : AppFailure.of(e);
      if (warm) {
        emit(state.copyWith(refreshError: appFailure));
        return;
      }
      emit(state.copyWith(
        status: AccountStatusScreenStatus.failed,
        error: failure,
        appFailure: appFailure,
      ));
    }
  }

  /// The repository classifies into its own enum, so re-derive the kind the
  /// copy family reads. Terminal kinds get an exit CTA, never a Retry.
  static AppFailure _appFailureFor(AccountStatusFailure failure) =>
      switch (failure) {
        AccountStatusFailure.network => const NetworkFailure(),
        AccountStatusFailure.unauthorized => const UnauthorizedFailure(),
        AccountStatusFailure.forbidden => const ForbiddenFailure(),
        AccountStatusFailure.serverError => const ServerFailure(status: 500),
        AccountStatusFailure.unknown => const UnknownFailure(),
      };
}
