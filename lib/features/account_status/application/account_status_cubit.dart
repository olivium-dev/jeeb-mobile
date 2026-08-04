import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/account_status_repository.dart';
import 'account_status_state.dart';

class AccountStatusCubit extends Cubit<AccountStatusState> {
  AccountStatusCubit({required AccountStatusRepository repository})
      : _repository = repository,
        super(const AccountStatusState());

  final AccountStatusRepository _repository;

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
