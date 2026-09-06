import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../domain/display_name_repository.dart';

enum DisplayNameStatus {
  idle,
  saving,
  saved,

  /// There is no repository wired, so nothing was sent. Distinct from [saved]:
  /// the step is optional, but the user must never be told it succeeded.
  unavailable,

  failure,
}

class DisplayNameState extends Equatable {
  const DisplayNameState({
    this.status = DisplayNameStatus.idle,
    this.failure,
    this.appFailure,
  });

  final DisplayNameStatus status;

  /// The repository's own classification, when it threw a typed exception.
  final DisplayNameFailure? failure;

  /// The transport classification, for kinds [DisplayNameFailure] cannot say.
  final AppFailure? appFailure;

  bool get isSaving => status == DisplayNameStatus.saving;

  @override
  List<Object?> get props => [status, failure, appFailure];
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
      emit(const DisplayNameState(status: DisplayNameStatus.unavailable));
      return;
    }
    emit(const DisplayNameState(status: DisplayNameStatus.saving));
    try {
      await repo.submitDisplayName(trimmed);
      _refreshSignals?.signalProfileChanged();
      emit(const DisplayNameState(status: DisplayNameStatus.saved));
    } on DisplayNameRepositoryException catch (e) {
      emit(
        DisplayNameState(
          status: DisplayNameStatus.failure,
          failure: e.failure,
        ),
      );
    } catch (e) {
      emit(
        DisplayNameState(
          status: DisplayNameStatus.failure,
          appFailure: AppFailure.of(e),
        ),
      );
    }
  }
}
