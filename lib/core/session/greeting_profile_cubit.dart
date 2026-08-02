import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../features/customer_profile/domain/customer_profile_view_data.dart';









class GreetingProfileState extends Equatable {
  const GreetingProfileState({this.name, this.avatarUrl});

  
  
  final String? name;

  
  final String? avatarUrl;

  GreetingProfileState copyWith({String? name, String? avatarUrl}) {
    return GreetingProfileState(
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [name, avatarUrl];
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
    try {
      final profile = await repo.fetchProfile();
      _emitFrom(profile);
    } on CustomerProfileRepositoryException {
      
      
    } catch (_) {
      
    }
  }

  void _emitFrom(CustomerProfileViewData profile) {
    final name = profile.name?.trim();
    final avatar = profile.avatarUrl?.trim();
    emit(GreetingProfileState(
      name: (name == null || name.isEmpty) ? null : name,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
    ));
  }

  @override
  Future<void> close() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    return super.close();
  }
}
