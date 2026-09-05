import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
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

  bool _evaluating = false;

  Future<void> evaluate() async {
    if (state.phase == BiometricLockPhase.unlocked || _evaluating) return;
    _evaluating = true;
    try {
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
    } catch (e) {
      // Fail OPEN: a broken preference/sensor read must never strand the user
      // behind a lock screen they have no way past.
      Diag.event('biometric_evaluate_failed', {
        'kind': AppFailure.of(e).kind.name,
      });
      _emit(state.copyWith(phase: BiometricLockPhase.disabled));
    } finally {
      _evaluating = false;
    }
  }

  Future<void> authenticate() async {
    if (state.isPrompting) return;
    _emit(
      state.copyWith(
        prompt: BiometricPromptStatus.prompting,
        clearFailure: true,
      ),
    );
    try {
      final ok = await _gateway.authenticate(reason: _osPromptReason);
      if (ok) {
        _emit(
          state.copyWith(
            phase: BiometricLockPhase.unlocked,
            prompt: BiometricPromptStatus.idle,
            clearFailure: true,
          ),
        );
      } else {
        _emit(
          state.copyWith(
            prompt: BiometricPromptStatus.failed,
            clearFailure: true,
          ),
        );
      }
    } on BiometricAuthException catch (e) {
      _emit(
        state.copyWith(
          prompt: BiometricPromptStatus.failed,
          failure: e.failure,
        ),
      );
    } catch (e) {
      Diag.event('biometric_authenticate_failed', {
        'kind': AppFailure.of(e).kind.name,
      });
      _emit(
        state.copyWith(
          prompt: BiometricPromptStatus.failed,
          failure: BiometricFailure.unknown,
        ),
      );
    }
  }

  void usePasswordFallback() {
    _emit(
      state.copyWith(
        phase: BiometricLockPhase.unlocked,
        prompt: BiometricPromptStatus.idle,
        clearFailure: true,
      ),
    );
  }

  void _emit(BiometricLockState next) {
    if (!isClosed) emit(next);
  }
}
