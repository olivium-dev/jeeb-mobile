import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';
import 'customer_profile_state.dart';

class CustomerProfileCubit extends Cubit<CustomerProfileState> {
  CustomerProfileCubit({
    required CustomerProfileViewData seed,
    CustomerProfileRepository? repository,
  }) : _repository = repository,
       super(CustomerProfileState(data: seed));

  final CustomerProfileRepository? _repository;

  Future<void> load() async {
    if (state.status != CustomerProfileStatus.initial) return;
    final repo = _repository;
    if (repo == null) {
      // A route seed is not live account data: in release a DI miss fails
      // rather than presenting the seed as loaded (WP7-N7/GEN-01).
      emit(
        kReleaseMode
            ? state.copyWith(
                status: CustomerProfileStatus.failed,
                error: CustomerProfileFailure.unknown,
                appFailure: const UnknownFailure(),
              )
            : state.copyWith(status: CustomerProfileStatus.loaded),
      );
      return;
    }
    emit(
      state.copyWith(status: CustomerProfileStatus.loading, clearError: true),
    );
    await _fetch(repo);
  }

  Future<void> refresh() async {
    final repo = _repository;
    if (repo == null) return;
    await _fetch(repo);
  }

  /// The cold-error retry: unlike [refresh] it shows the loading rung first,
  /// so a blank profile does not sit on the error block until the response.
  Future<void> retry() async {
    final repo = _repository;
    if (repo == null || state.status == CustomerProfileStatus.loading) return;
    emit(
      state.copyWith(
        status: CustomerProfileStatus.loading,
        clearError: true,
        clearRefreshError: true,
      ),
    );
    await _fetch(repo);
  }

  void acknowledgeRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> _fetch(CustomerProfileRepository repo) async {
    try {
      final fresh = await repo.fetchProfile();
      emit(
        state.copyWith(
          data: fresh,
          status: CustomerProfileStatus.loaded,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } on CustomerProfileRepositoryException catch (e) {
      _emitFailure(e.failure, e.appFailure ?? AppFailure.of(e));
    } catch (error) {
      _emitFailure(CustomerProfileFailure.unknown, AppFailure.of(error));
    }
  }

  /// A cold blank read is a real failure; a warm read over a seeded profile
  /// keeps the identity card and rides the refresh strip (UX-42).
  void _emitFailure(CustomerProfileFailure kind, AppFailure failure) {
    if (state.data.isBlank) {
      emit(
        state.copyWith(
          status: CustomerProfileStatus.failed,
          error: kind,
          appFailure: failure,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: CustomerProfileStatus.loaded,
        error: kind,
        refreshError: failure,
      ),
    );
  }
}
