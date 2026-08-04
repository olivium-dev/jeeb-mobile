import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import '../domain/set_password_policy.dart';
import 'set_password_state.dart';

/// Drives set-password screen: visibility toggles, validation, submit. Success is screen's listener concern.
class SetPasswordCubit extends Cubit<SetPasswordState> {
  SetPasswordCubit({
    required AuthRepository repository,
    required String email,
    String? resetToken,
    SetPasswordPolicy policy = const SetPasswordPolicy(),
  })  : _repository = repository,
        _email = email,
        _resetToken = resetToken,
        _policy = policy,
        super(const SetPasswordState());

  final AuthRepository _repository;
  final String _email;
  final String? _resetToken;
  final SetPasswordPolicy _policy;

  /// Flips masking on the new-password field.
  void toggleNewObscured() =>
      emit(state.copyWith(newObscured: !state.newObscured));

  /// Flips masking on the confirm-password field.
  void toggleConfirmObscured() =>
      emit(state.copyWith(confirmObscured: !state.confirmObscured));

  /// Clears surfaced error on user edit so validation node doesn't linger.
  void acknowledgeError() {
    if (state.status == SetPasswordStatus.failed) {
      emit(state.copyWith(
        status: SetPasswordStatus.idle,
        clearValidation: true,
        clearFailure: true,
      ));
    }
  }

  /// Validates then submits; client-side failures emit reason without network call.
  Future<void> submit({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state.status == SetPasswordStatus.submitting) return;

    final validation = _policy.validate(
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (validation != SetPasswordValidation.valid) {
      emit(state.copyWith(
        status: SetPasswordStatus.failed,
        validation: validation,
        clearFailure: true,
      ));
      return;
    }

    emit(state.copyWith(
      status: SetPasswordStatus.submitting,
      clearValidation: true,
      clearFailure: true,
    ));
    try {
      final session = await _repository.setPassword(
        email: _email,
        password: newPassword,
        resetToken: _resetToken,
      );
      emit(state.copyWith(
        status: SetPasswordStatus.succeeded,
        session: session,
      ));
    } on AuthRepositoryException catch (e) {
      emit(state.copyWith(
        status: SetPasswordStatus.failed,
        failure: e.failure,
        clearValidation: true,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: SetPasswordStatus.failed,
        failure: AuthFailure.unknown,
        clearValidation: true,
      ));
    }
  }
}
