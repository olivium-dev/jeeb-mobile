import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../data/super_login_service.dart';
import 'super_login_state.dart';

class SuperLoginCubit extends Cubit<SuperLoginState> {
  SuperLoginCubit({
    required SuperLoginService service,
    required AuthTokenStore tokenStore,
  })  : _service = service,
        _tokenStore = tokenStore,
        super(const SuperLoginState());

  final SuperLoginService _service;
  final AuthTokenStore _tokenStore;

  Future<void> submit({
    required String userId,
    required String passcode,
  }) async {
    if (state.isSubmitting) return;
    if (userId.trim().isEmpty || passcode.isEmpty) {
      emit(state.copyWith(
        status: SuperLoginStatus.error,
        error: SuperLoginError.invalidCredentials,
      ));
      return;
    }

    emit(state.copyWith(status: SuperLoginStatus.submitting, error: null));

    final result = await _service.signIn(
      userId: userId.trim(),
      passcode: passcode,
    );

    if (isClosed) return;

    switch (result) {
      case SuperLoginSuccess(:final session):
        await _tokenStore.save(
          accessToken: session.accessToken,
          refreshToken: session.refreshToken,
          userId: session.userId,
        );
        if (isClosed) return;
        emit(state.copyWith(status: SuperLoginStatus.success, error: null));
      case SuperLoginFailure(:final error):
        emit(state.copyWith(status: SuperLoginStatus.error, error: error));
    }
  }

  void clearError() {
    if (state.status != SuperLoginStatus.error) return;
    emit(state.copyWith(status: SuperLoginStatus.idle, error: null));
  }
}
