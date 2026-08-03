// Shared dev-only fixtures for `BiometricPromptScreen`.

import 'package:jeeb_mobile/features/biometric_login/application/biometric_cubit.dart';

/// A [BiometricCubit] that starts in [seed] instead of `BiometricState.initial`.
/// DEV-ONLY. The emit happens in the constructor, before any surface has
/// subscribed, so the screen's `BlocBuilder` simply builds the seeded state on
class BiometricPromptScreenSeededCubit extends BiometricCubit {
  BiometricPromptScreenSeededCubit(BiometricState seed) {
    emit(seed);
  }
}

/// The cold-start state: the widget is mounted and the availability probe has
/// not run yet.
BiometricCubit biometricPromptScreenInitialCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.initial);

/// The availability probe is in flight — the screen's only loading state.
/// Also the catalog's `Checking`. Unreachable on a real device: the two `emit`s
BiometricCubit biometricPromptScreenCheckingCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.checking);

/// Hardware present and enrolled: the `Authenticate` CTA is mounted.
/// Also the catalog's `Available`. The only state in which the screen has an
BiometricCubit biometricPromptScreenAvailableCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.available);

/// No biometric hardware, or nothing enrolled: the screen's error state.
/// Also the catalog's `Unavailable`. The one state that swaps in copy of its
BiometricCubit biometricPromptScreenUnavailableCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.unavailable);

/// The user was rejected by the OS prompt — wrong finger, wrong face, or
/// cancelled.
BiometricCubit biometricPromptScreenFailedCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.failed);

/// The terminal success state.
/// Kept as a fixture even though the catalog never listed it, because it is
BiometricCubit biometricPromptScreenAuthenticatedCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.authenticated);
