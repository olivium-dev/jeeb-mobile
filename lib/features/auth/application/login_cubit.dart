import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';
import 'login_state.dart';

/// Drives the email/password login submit (JM-007). Constructor takes the
/// abstract [AuthRepository] (40_GUARDRAILS_ARCH §2.2) — the data impl posts the
/// VERIFIED `POST /v1/auth/login` contract (42_GUARDRAILS_MOCK W-1 FLOOR) and
/// persists the JWT pair + `user.userId` before this cubit ever sees the
/// [AuthSession]. On success the screen's listener refreshes [SessionCubit] and
/// routes to the Requests tab.
class LoginCubit extends Cubit<LoginState> {
  LoginCubit({required AuthRepository repository})
      : _repository = repository,
        super(const LoginState());

  final AuthRepository _repository;

  void emailChanged(String value) {
    // A live edit clears a stale failure so the inline error doesn't linger
    // while the user retypes.
    emit(state.copyWith(
      email: value,
      status: state.status == LoginStatus.failed
          ? LoginStatus.initial
          : state.status,
      clearError: state.status == LoginStatus.failed,
    ));
  }

  void passwordChanged(String value) {
    emit(state.copyWith(
      password: value,
      status: state.status == LoginStatus.failed
          ? LoginStatus.initial
          : state.status,
      clearError: state.status == LoginStatus.failed,
    ));
  }

  /// Submits the current credentials. Guards re-entry while a submit is in
  /// flight and ignores empty input. Maps every failure to a typed
  /// [AuthFailure]; the DioException stays inside the repository (§4).
  Future<void> submit() async {
    if (!state.canSubmit) return;
    emit(state.copyWith(
      status: LoginStatus.submitting,
      clearError: true,
      clearSession: true,
    ));
    try {
      final session = await _repository.login(
        email: state.email.trim(),
        password: state.password,
      );
      emit(state.copyWith(status: LoginStatus.succeeded, session: session));
    } on AuthRepositoryException catch (e) {
      emit(state.copyWith(status: LoginStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: LoginStatus.failed,
        error: AuthFailure.unknown,
      ));
    }
  }

  /// One-shot error acknowledgement so a re-shown banner doesn't loop
  /// (40_GUARDRAILS_ARCH §2.2). Returns the form to the editable state.
  void acknowledgeError() {
    if (state.status != LoginStatus.failed) return;
    emit(state.copyWith(status: LoginStatus.initial, clearError: true));
  }
}
