import 'package:flutter_bloc/flutter_bloc.dart';

import '../../settings/data/repositories/biometric_preference_repository_impl.dart';
import '../data/shared_prefs_pin_repository.dart';
import '../domain/biometric_gateway.dart';
import 'biometric_lock_state.dart';

///      `app_router.dart` biometric gate (40_GUARDRAILS_ARCH §5.5). [evaluate]
class BiometricLockCubit extends Cubit<BiometricLockState> {
  BiometricLockCubit({
    required BiometricPreferenceRepositoryImpl preference,
    required BiometricGateway gateway,
    required SharedPrefsPinRepository pinRepository,
  })  : _preference = preference,
        _gateway = gateway,
        _pinRepository = pinRepository,
        super(const BiometricLockState());

  final BiometricPreferenceRepositoryImpl _preference;
  final BiometricGateway _gateway;
  final SharedPrefsPinRepository _pinRepository;

  static const String _osPromptReason = "Confirm it's you to open Jeeb";

  Future<void> evaluate() async {
    if (state.phase == BiometricLockPhase.unlocked) return;
    final enabled = await _preference.isEnabled();
    if (!enabled) {
      _emit(state.copyWith(phase: BiometricLockPhase.disabled));
      return;
    }
    final available = await _gateway.isAvailable();
    final hasPinFallback = await _pinRepository.hasPin();
    final canChallenge = available || hasPinFallback;
    _emit(
      state.copyWith(
        phase: canChallenge
            ? BiometricLockPhase.locked
            : BiometricLockPhase.disabled,
      ),
    );
  }

  Future<void> authenticate() async {
    if (state.isPrompting) return;
    _emit(state.copyWith(prompt: BiometricPromptStatus.prompting));
    bool ok;
    try {
      ok = await _gateway.authenticate(reason: _osPromptReason);
    } catch (_) {
      ok = false;
    }
    if (ok) {
      _emit(
        state.copyWith(
          phase: BiometricLockPhase.unlocked,
          prompt: BiometricPromptStatus.idle,
        ),
      );
    } else {
      _emit(state.copyWith(prompt: BiometricPromptStatus.failed));
    }
  }

  void usePasswordFallback() {
    _emit(
      state.copyWith(
        phase: BiometricLockPhase.unlocked,
        prompt: BiometricPromptStatus.idle,
      ),
    );
  }

  void _emit(BiometricLockState next) {
    if (!isClosed) emit(next);
  }
}
