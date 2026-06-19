import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import 'sign_up_state.dart';

/// Drives the email-first sign-up form (JM-008, CTO-D1). Holds field state,
/// derives password strength, and submits to [AuthRepository.signup].
///
/// Navigation is NOT performed here — the screen's `BlocListener` reacts to the
/// terminal [SignUpStatus] (succeeded → phone-OTP; collision → JM-019 sheet)
/// per 40_GUARDRAILS_ARCH §3 ("navigation belongs in the listener").
class SignUpCubit extends Cubit<SignUpState> {
  SignUpCubit({required AuthRepository repository})
      : _repository = repository,
        super(const SignUpState());

  final AuthRepository _repository;

  void nameChanged(String value) =>
      emit(state.copyWith(name: value, status: SignUpStatus.idle, clearError: true));

  void emailChanged(String value) =>
      emit(state.copyWith(email: value, status: SignUpStatus.idle, clearError: true));

  void passwordChanged(String value) =>
      emit(state.copyWith(password: value, status: SignUpStatus.idle, clearError: true));

  void togglePasswordVisibility() =>
      emit(state.copyWith(passwordVisible: !state.passwordVisible));

  /// Submits the form. Guards against double-submit and an incomplete form.
  /// 201 → [SignUpStatus.succeeded]; 409 → [SignUpStatus.collision]; anything
  /// else → [SignUpStatus.failed] with a typed [AuthFailure] the screen maps to
  /// copy. The session minted on 201 is persisted by the repo, but the account
  /// still needs phone-OTP (D21/G8) — the screen handles that routing.
  Future<void> submit() async {
    if (!state.isSubmittable) return;
    emit(state.copyWith(status: SignUpStatus.submitting, clearError: true));
    try {
      await _repository.signup(
        email: state.email.trim(),
        password: state.password,
        name: state.name.trim(),
      );
      emit(state.copyWith(status: SignUpStatus.succeeded));
    } on AuthRepositoryException catch (e) {
      if (e.failure == AuthFailure.emailCollision) {
        emit(state.copyWith(status: SignUpStatus.collision));
      } else {
        emit(state.copyWith(status: SignUpStatus.failed, error: e.failure));
      }
    } catch (_) {
      emit(state.copyWith(
        status: SignUpStatus.failed,
        error: AuthFailure.unknown,
      ));
    }
  }

  /// One-shot acknowledgement after the screen has consumed a terminal status
  /// (routed to OTP, shown the collision sheet, or surfaced the inline error),
  /// so a rebuild does not re-fire the side effect.
  void acknowledge() {
    if (state.status == SignUpStatus.idle) return;
    emit(state.copyWith(status: SignUpStatus.idle, clearError: true));
  }
}
