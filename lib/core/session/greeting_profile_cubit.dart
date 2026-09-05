import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../features/customer_profile/domain/customer_profile_view_data.dart';

/// Where the `getMe` behind the greeting stands. `resolved` is terminal for
/// BOTH outcomes: a failed read has ended, so it must not read as in flight.
enum GreetingProfileStatus { idle, loading, resolved }

class GreetingProfileState extends Equatable {
  const GreetingProfileState({
    this.name,
    this.avatarUrl,
    this.status = GreetingProfileStatus.idle,
  });

  final String? name;

  final String? avatarUrl;

  final GreetingProfileStatus status;

  bool get isLoading => status == GreetingProfileStatus.loading;

  GreetingProfileState copyWith({
    String? name,
    String? avatarUrl,
    GreetingProfileStatus? status,
  }) {
    return GreetingProfileState(
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [name, avatarUrl, status];
}

class GreetingProfileCubit extends Cubit<GreetingProfileState> {
  GreetingProfileCubit({
    CustomerProfileRepository? repository,
    GreetingProfileState seed = const GreetingProfileState(),
    Stream<void>? refreshSignals,
  })  : _repository = repository,
        super(seed) {

    _refreshSubscription = refreshSignals?.listen((_) => load());
  }

  final CustomerProfileRepository? _repository;
  StreamSubscription<void>? _refreshSubscription;

  Future<void> load() async {
    final repo = _repository;
    if (repo == null) return;
    // Only the cold read blanks the band; a refresh keeps the person on screen.
    if (state.status == GreetingProfileStatus.idle) {
      emit(state.copyWith(status: GreetingProfileStatus.loading));
    }
    CustomerProfileViewData? profile;
    try {
      profile = await repo.fetchProfile();
    } on Object {
      profile = null;
    }
    // Greeting is decorative; a failure keeps what was emitted — but the read
    // HAS ended, so the band must leave `loading` either way.
    if (profile == null) {
      emit(state.copyWith(status: GreetingProfileStatus.resolved));
      return;
    }
    _emitFrom(profile);
  }

  void _emitFrom(CustomerProfileViewData profile) {
    final name = profile.name?.trim();
    final avatar = profile.avatarUrl?.trim();
    emit(GreetingProfileState(
      name: (name == null || name.isEmpty) ? null : name,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
      status: GreetingProfileStatus.resolved,
    ));
  }

  @override
  Future<void> close() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    return super.close();
  }
}
