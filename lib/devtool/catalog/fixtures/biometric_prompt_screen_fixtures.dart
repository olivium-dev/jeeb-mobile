// Shared dev-only fixtures for `BiometricPromptScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_01_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/biometric_login/presentation/biometric_prompt_screen.dart`.
//
// The catalog owned a private `_SeededBiometricCubit` and four inline
// `_SeededBiometricCubit(BiometricState.x)` calls. Copying that into the
// preview section would have given the two surfaces two different notions of
// "the checking state", free to drift — and the catalog is the one a designer
// signs off against. Both surfaces now import this file.
//
// ## Why the states are SEEDED rather than driven
//
// `BiometricCubit` has no `seed:` constructor and no injectable gateway: it
// starts in `BiometricState.initial` and the only two ways to leave that state
// are `checkAvailability()` and `authenticate()`. Both are stubs whose bodies
// are two synchronous `emit`s with nothing awaited between them —
//
//     emit(BiometricState.checking);
//     // In production: use local_auth package
//     emit(BiometricState.available);
//
// — so a real caller never gets a frame in the intermediate state, and
// `unavailable` / `failed` are not emitted by any code path at all. Every state
// worth reviewing is therefore unreachable by driving the cubit, and has to be
// seeded.
//
// [BiometricPromptScreenSeededCubit] is a DEV-ONLY subclass that emits one
// fixed state at construction, through the `emit` bloc marks `@protected` (i.e.
// visible to subclasses). It is not a production seam and it adds none: the
// screen still only ever sees a `BiometricCubit` handed to its existing
// `cubit:` parameter.
//
// ## Network-free by construction
//
// `BiometricCubit` takes no repository, resolves nothing out of GetIt and holds
// no `Dio`, so neither surface can reach the gateway even by accident — the
// `CatalogNetworkGuard` that `jeebPreviewHost` and `_CatalogPreview` install is
// a net here, not the plan.
//
// ## Ownership
//
// Each function returns a FRESH cubit, and every caller hands it to
// `BiometricPromptScreen(cubit:)`, which mounts it with
// `BlocProvider<BiometricCubit>.value` — `.value` does NOT close what it is
// given, so a cubit built here is never disposed. That is harmless (a
// `BiometricCubit` owns no subscription, no timer and no socket) and it is why
// these are functions rather than shared constants: a single long-lived
// instance handed to two mounted surfaces would let one of them emit into the
// other.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:jeeb_mobile/features/biometric_login/application/biometric_cubit.dart';

/// A [BiometricCubit] that starts in [seed] instead of `BiometricState.initial`.
///
/// DEV-ONLY. The emit happens in the constructor, before any surface has
/// subscribed, so the screen's `BlocBuilder` simply builds the seeded state on
/// its first frame rather than seeing it as a transition.
///
/// Everything else about the cubit is real: `checkAvailability()` and
/// `authenticate()` still behave exactly as production if something taps the
/// CTA — which, on the `Available` fixture, is the only interaction the screen
/// offers.
class BiometricPromptScreenSeededCubit extends BiometricCubit {
  BiometricPromptScreenSeededCubit(BiometricState seed) {
    emit(seed);
  }
}

/// The cold-start state: the widget is mounted and the availability probe has
/// not run yet.
///
/// In production this is what `BiometricPromptScreen` builds for exactly one
/// frame before `checkAvailability()` runs. `_PromptAction` has no branch for
/// it, so it falls through to `SizedBox.shrink()` — see the preview.
BiometricCubit biometricPromptScreenInitialCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.initial);

/// The availability probe is in flight — the screen's only loading state.
///
/// Also the catalog's `Checking`. Unreachable on a real device: the two `emit`s
/// in `checkAvailability()` are not separated by an `await`, so no frame is
/// ever built between them.
BiometricCubit biometricPromptScreenCheckingCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.checking);

/// Hardware present and enrolled: the `Authenticate` CTA is mounted.
///
/// Also the catalog's `Available`. The only state in which the screen has an
/// affordance at all.
BiometricCubit biometricPromptScreenAvailableCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.available);

/// No biometric hardware, or nothing enrolled: the screen's error state.
///
/// Also the catalog's `Unavailable`. The one state that swaps in copy of its
/// own (`l10n.biometricNotAvailable`).
BiometricCubit biometricPromptScreenUnavailableCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.unavailable);

/// The user was rejected by the OS prompt — wrong finger, wrong face, or
/// cancelled.
///
/// Also the catalog's `Failed`. `_PromptAction` has no branch for it either, so
/// the screen renders the same invitation to authenticate with the button
/// removed and no error — see the preview.
BiometricCubit biometricPromptScreenFailedCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.failed);

/// The terminal success state.
///
/// Kept as a fixture even though the catalog never listed it, because it is
/// what the CTA emits: tapping `Authenticate` runs `authenticate()`, which
/// lands here. Nothing on the screen reacts to it — there is no `BlocListener`
/// and no `onAuthenticated` callback — so the picture below is what a user sees
/// after a SUCCESSFUL sign-in.
BiometricCubit biometricPromptScreenAuthenticatedCubit() =>
    BiometricPromptScreenSeededCubit(BiometricState.authenticated);
