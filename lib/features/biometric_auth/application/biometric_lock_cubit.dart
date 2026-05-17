import 'package:flutter_bloc/flutter_bloc.dart';

import '../../settings/data/repositories/biometric_preference_repository_impl.dart';
import '../data/shared_prefs_pin_repository.dart';
import '../domain/biometric_gateway.dart';
import 'biometric_lock_state.dart';

/// Stub created by sanity-build pass (2026-05-17).
///
/// Defaults to `phase == disabled` so the router never blocks navigation.
/// `evaluate()` is a no-op so cold start completes immediately. T-mobile-005
/// real behaviour is a follow-up.
class BiometricLockCubit extends Cubit<BiometricLockState> {
  BiometricLockCubit({
    required BiometricPreferenceRepositoryImpl preference,
    required BiometricGateway gateway,
    required SharedPrefsPinRepository pinRepository,
  })  : _preference = preference,
        _gateway = gateway,
        _pinRepository = pinRepository,
        super(const BiometricLockState());

  // Fields kept for the eventual real impl. ignore: unused_field
  // ignore: unused_field
  final BiometricPreferenceRepositoryImpl _preference;
  // ignore: unused_field
  final BiometricGateway _gateway;
  // ignore: unused_field
  final SharedPrefsPinRepository _pinRepository;

  void evaluate() {
    // No-op stub. Real impl would: read _preference, query _gateway, gate on
    // _pinRepository.hasPin(), then emit locked/unlocked/disabled.
    if (!isClosed) emit(state.copyWith(phase: BiometricLockPhase.disabled));
  }
}
