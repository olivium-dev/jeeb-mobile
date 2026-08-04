import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/profile_refresh_signals.dart';
import '../domain/display_name_repository.dart';

enum DisplayNameStatus { idle, saving, saved, failure }

class DisplayNameState extends Equatable {
  const DisplayNameState({this.status = DisplayNameStatus.idle});

  final DisplayNameStatus status;

  bool get isSaving => status == DisplayNameStatus.saving;

  @override
  List<Object?> get props => [status];
}

/// Fail-soft: name step optional, failure never blocks registration.
class DisplayNameCubit extends Cubit<DisplayNameState> {
  DisplayNameCubit({
    DisplayNameRepository? repository,
    ProfileRefreshSignals? refreshSignals,
  })  : _repository = repository,
        _refreshSignals = refreshSignals,
        super(const DisplayNameState());

  final DisplayNameRepository? _repository;
  final ProfileRefreshSignals? _refreshSignals;

  Future<void> submit(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || state.isSaving) return;
    final repo = _repository;
    if (repo == null) {
      emit(const DisplayNameState(status: DisplayNameStatus.saved));
      return;
    }
    emit(const DisplayNameState(status: DisplayNameStatus.saving));
    try {
      await repo.submitDisplayName(trimmed);
      _refreshSignals?.signalProfileChanged();
      emit(const DisplayNameState(status: DisplayNameStatus.saved));
    } on Object {
      emit(const DisplayNameState(status: DisplayNameStatus.failure));
    }
  }
}
