import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/profile_refresh_signals.dart';
import '../domain/display_name_repository.dart';

/// Save lifecycle for the post-OTP display-name step.
enum DisplayNameStatus { idle, saving, saved, failure }

class DisplayNameState extends Equatable {
  const DisplayNameState({this.status = DisplayNameStatus.idle});

  final DisplayNameStatus status;

  bool get isSaving => status == DisplayNameStatus.saving;

  @override
  List<Object?> get props => [status];
}

/// Submits the user's chosen display name through [DisplayNameRepository]
/// (`PUT /api/User/profile` `{username}`) and signals profile-derived display
/// state (greetings / headers) to re-pull getMe on success.
///
/// Fail-soft by design: the name step is optional-but-encouraged, so a failed
/// PUT emits [DisplayNameStatus.failure] (the screen shows a retryable error
/// and keeps the skip exit) — it must NEVER block registration. A `null`
/// repository (bare widget test / fixture mode, mirroring
/// [GreetingProfileCubit]) resolves the submit as saved without a network
/// round-trip.
class DisplayNameCubit extends Cubit<DisplayNameState> {
  DisplayNameCubit({
    DisplayNameRepository? repository,
    ProfileRefreshSignals? refreshSignals,
  })  : _repository = repository,
        _refreshSignals = refreshSignals,
        super(const DisplayNameState());

  final DisplayNameRepository? _repository;
  final ProfileRefreshSignals? _refreshSignals;

  /// Submits [name] (trimmed). Blank input and re-entrant calls are no-ops —
  /// the UI gates the CTA on a non-empty field, and skip is a separate exit.
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
      // Fail-soft: surface a retryable failure, never a crash or a block.
      emit(const DisplayNameState(status: DisplayNameStatus.failure));
    }
  }
}
