import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../diagnostics/diag.dart';
import '../network/app_failure.dart';
import '../network/app_failure_mapper.dart';
import '../network/network_reachability_signals.dart';

/// A resolved read landed, named or not; a failed cold read threw.
enum GreetingProfileStatus { idle, loading, resolved, failed }

class GreetingProfileState extends Equatable {
  const GreetingProfileState({
    this.name,
    this.avatarUrl,
    this.status = GreetingProfileStatus.idle,
    this.failure,
  });

  final String? name;

  final String? avatarUrl;

  final GreetingProfileStatus status;
  final AppFailure? failure;

  bool get isLoading => status == GreetingProfileStatus.loading;
  bool get isFailed => status == GreetingProfileStatus.failed;

  GreetingProfileState copyWith({
    String? name,
    String? avatarUrl,
    GreetingProfileStatus? status,
    AppFailure? failure,
    bool clearFailure = false,
  }) {
    return GreetingProfileState(
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [name, avatarUrl, status, failure];
}

class GreetingProfileCubit extends Cubit<GreetingProfileState> {
  GreetingProfileCubit({
    CustomerProfileRepository? repository,
    GreetingProfileState seed = const GreetingProfileState(),
    Stream<void>? refreshSignals,
    Stream<void>? reconnectSignals,
    Stream<void>? resumeSignals,
  }) : _repository = repository,
       super(seed) {
    _refreshSubscription = refreshSignals?.listen((_) {
      if (_inFlight) {
        _profileChangedDuringRead = true;
      } else {
        unawaited(load());
      }
    });
    _reconnectSubscription = reconnectSignals?.listen(
      (_) => _retryIfFailed(reason: 'reconnect', connectivityOnly: true),
    );
    _resumeSubscription = resumeSignals?.listen(
      (_) => _retryIfFailed(reason: 'resume'),
    );
  }

  final CustomerProfileRepository? _repository;
  StreamSubscription<void>? _refreshSubscription;
  StreamSubscription<void>? _reconnectSubscription;
  StreamSubscription<void>? _resumeSubscription;
  bool _inFlight = false;
  bool _profileChangedDuringRead = false;
  bool _closing = false;

  Future<void> load() async {
    final repo = _repository;
    if (repo == null || _inFlight || _closing || isClosed) return;
    _inFlight = true;
    // Cold reads and failed retries blank the band; warm reads keep it.
    if (state.status == GreetingProfileStatus.idle || state.isFailed) {
      emit(
        state.copyWith(
          status: GreetingProfileStatus.loading,
          clearFailure: true,
        ),
      );
    }
    try {
      final profile = await repo.fetchProfile();
      if (!_closing && !isClosed) _emitFrom(profile);
    } on Object catch (error) {
      if (!_closing && !isClosed) _emitFailure(_classify(error));
    } finally {
      _inFlight = false;
      if (_profileChangedDuringRead) {
        _profileChangedDuringRead = false;
        await load();
      }
    }
  }

  void _emitFailure(AppFailure failure) {
    // Warm means a person is on screen; a nameless read is not a person.
    final warm = state.name != null;
    Diag.event('greeting_profile_read_failed', {
      'kind': failure.kind.name,
      'warm': warm,
    });
    if (warm) {
      if (state.status != GreetingProfileStatus.resolved) {
        emit(
          state.copyWith(
            status: GreetingProfileStatus.resolved,
            clearFailure: true,
          ),
        );
      }
      return;
    }
    emit(
      state.copyWith(status: GreetingProfileStatus.failed, failure: failure),
    );
  }

  AppFailure _classify(Object error) {
    if (error is CustomerProfileRepositoryException) {
      return error.appFailure ??
          switch (error.failure) {
            CustomerProfileFailure.network => networkFailureFromReachability(
              cause: error,
            ),
            CustomerProfileFailure.unauthorized => const UnauthorizedFailure(),
            CustomerProfileFailure.unknown => UnknownFailure(cause: error),
          };
    }
    return AppFailure.of(error);
  }

  Future<void> retryIfFailed() => _retryIfFailed(reason: 'dashboard_retry');

  Future<void> _retryIfFailed({
    required String reason,
    bool connectivityOnly = false,
  }) async {
    if (!state.isFailed) return;
    final failure = state.failure;
    if (connectivityOnly &&
        (failure == null || !failureBlamesConnectivity(failure))) {
      return;
    }
    Diag.event('greeting_profile_reload', {'reason': reason});
    await load();
  }

  void _emitFrom(CustomerProfileViewData profile) {
    final name = profile.name?.trim();
    final avatar = profile.avatarUrl?.trim();
    emit(
      GreetingProfileState(
        name: (name == null || name.isEmpty) ? null : name,
        avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
        status: GreetingProfileStatus.resolved,
      ),
    );
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _refreshSubscription?.cancel();
    await _reconnectSubscription?.cancel();
    await _resumeSubscription?.cancel();
    _refreshSubscription = null;
    _reconnectSubscription = null;
    _resumeSubscription = null;
    return super.close();
  }
}
