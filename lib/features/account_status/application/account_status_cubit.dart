import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account_status_repository.dart';
import 'account_status_state.dart';

/// Drives `account-status` (JM-066, D5). Imports `domain/` only
/// (40_GUARDRAILS_ARCH §2.2); the abstract [AccountStatusRepository] is
/// constructor-injected (the screen resolves the LIVE
/// `DioAccountStatusRepository` from `sl<AccountStatusRepository>()`).
///
/// Reads the blocked-account status once on entry so the banner + reason copy
/// reflect WHICH blocked state (`suspended` vs `locked`) the account is in. The
/// router gate ([AccountStatusGate]) already forces the screen; the cubit only
/// resolves the display — it never polices reachability (40_GUARDRAILS_ARCH
/// §12: gates live in the central redirect, not the screen).
class AccountStatusCubit extends Cubit<AccountStatusState> {
  AccountStatusCubit({required AccountStatusRepository repository})
      : _repository = repository,
        super(const AccountStatusState());

  final AccountStatusRepository _repository;

  /// Cold-entry load. Guards re-entry so a remount doesn't refetch (§2.2).
  Future<void> load() async {
    if (state.status != AccountStatusScreenStatus.initial) return;
    emit(state.copyWith(
      status: AccountStatusScreenStatus.loading,
      clearError: true,
    ));
    try {
      final info = await _repository.fetchStatus();
      emit(state.copyWith(
        status: AccountStatusScreenStatus.loaded,
        info: info,
      ));
    } on AccountStatusRepositoryException catch (e) {
      emit(state.copyWith(
        status: AccountStatusScreenStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: AccountStatusScreenStatus.failed,
        error: AccountStatusFailure.unknown,
      ));
    }
  }

  /// Retry after a failed status read. Re-runs the fetch and flips back to
  /// loaded/failed (does not strand on `failed`).
  Future<void> refresh() async {
    emit(state.copyWith(
      status: AccountStatusScreenStatus.loading,
      clearError: true,
    ));
    try {
      final info = await _repository.fetchStatus();
      emit(state.copyWith(
        status: AccountStatusScreenStatus.loaded,
        info: info,
      ));
    } on AccountStatusRepositoryException catch (e) {
      emit(state.copyWith(
        status: AccountStatusScreenStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: AccountStatusScreenStatus.failed,
        error: AccountStatusFailure.unknown,
      ));
    }
  }
}
