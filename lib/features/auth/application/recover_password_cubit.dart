import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import 'recover_password_state.dart';

/// Drives the recover-password screen (JM-020). Owns the email text and the
/// single `POST /v1/auth/recovery/request` action; maps a thrown
/// [AuthRepositoryException] to a typed [AuthFailure] for the screen to render.
///
/// The recovery request is non-enumerating (W-1 FLOOR): the mock returns 200 for
/// any email, so a `succeeded` here means "a code was sent IF the email exists"
/// — the UX deliberately does not branch on existence.
class RecoverPasswordCubit extends Cubit<RecoverPasswordState> {
  RecoverPasswordCubit({required AuthRepository repository})
      : _repository = repository,
        super(const RecoverPasswordState());

  final AuthRepository _repository;

  /// Live edit from `recover_email_field`. Clears any stale error so the
  /// inline banner doesn't linger while the user retypes.
  void emailChanged(String value) {
    emit(state.copyWith(
      email: value,
      status: state.status == RecoverPasswordStatus.failed
          ? RecoverPasswordStatus.idle
          : state.status,
      clearError: true,
    ));
  }

  /// Requests a recovery code for the current email. Guards re-entry while a
  /// request is in flight. On success → `succeeded` (the screen navigates and
  /// passes [RecoverPasswordState.email] to `/recover/verify`).
  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(
      status: RecoverPasswordStatus.submitting,
      clearError: true,
    ));
    try {
      await _repository.requestRecovery(email: state.email.trim());
      emit(state.copyWith(status: RecoverPasswordStatus.succeeded));
    } on AuthRepositoryException catch (e) {
      emit(state.copyWith(
        status: RecoverPasswordStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: RecoverPasswordStatus.failed,
        error: AuthFailure.unknown,
      ));
    }
  }

  /// One-shot acknowledgement so a re-shown error banner doesn't loop.
  void acknowledgeError() => emit(state.copyWith(clearError: true));
}
