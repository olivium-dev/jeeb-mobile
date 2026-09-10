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
    Future<String?> Function()? accountId,
  }) : _repository = repository,
       _accountId = accountId,
       super(CustomerProfileState(data: seed));

  final CustomerProfileRepository? _repository;
  final Future<String?> Function()? _accountId;
  int _generation = 0;
  bool _sessionEnded = false;

  void endSession() {
    if (isClosed) return;
    _sessionEnded = true;
    _generation++;
    emit(
      const CustomerProfileState(
        data: CustomerProfileViewData(),
        status: CustomerProfileStatus.failed,
        error: CustomerProfileFailure.unauthorized,
        appFailure: UnauthorizedFailure(),
      ),
    );
  }

  Future<void> load() async {
    if (isClosed ||
        _sessionEnded ||
        state.status != CustomerProfileStatus.initial) {
      return;
    }
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
    if (repo == null || isClosed || _sessionEnded) return;
    await _fetch(repo);
  }

  /// The cold-error retry: unlike [refresh] it shows the loading rung first,
  /// so a blank profile does not sit on the error block until the response.
  Future<void> retry() async {
    final repo = _repository;
    if (repo == null ||
        isClosed ||
        _sessionEnded ||
        state.status == CustomerProfileStatus.loading) {
      return;
    }
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
    if (isClosed || _sessionEnded) return;
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> _fetch(CustomerProfileRepository repo) async {
    final generation = ++_generation;
    bool current() => !isClosed && !_sessionEnded && generation == _generation;
    Future<String?> readAccount() async {
      try {
        return await _accountId?.call();
      } catch (_) {
        if (current()) endSession();
        rethrow;
      }
    }

    try {
      final account = await readAccount();
      if (!current()) return;
      if (account != null &&
          state.data.userId != null &&
          state.data.userId != account) {
        emit(
          const CustomerProfileState(
            data: CustomerProfileViewData(),
            status: CustomerProfileStatus.loading,
          ),
        );
      }
      final fresh = await repo.fetchProfile();
      if (!current()) return;
      final after = await readAccount();
      if (!current()) return;
      if (_accountId != null &&
          (after != account ||
              (account != null &&
                  fresh.userId != null &&
                  fresh.userId != account))) {
        // An account transition must never apply the previous person's response.
        endSession();
        return;
      }
      emit(
        state.copyWith(
          data: fresh,
          status: CustomerProfileStatus.loaded,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } on CustomerProfileRepositoryException catch (e) {
      if (!current()) return;
      _emitFailure(e.failure, e.appFailure ?? AppFailure.of(e));
    } catch (error) {
      if (!current()) return;
      _emitFailure(CustomerProfileFailure.unknown, AppFailure.of(error));
    }
  }

  @override
  Future<void> close() {
    _generation++;
    return super.close();
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
