// Designed states for `DmOnboardingScreen` — the delivery-man onboarding
// wizard (JM-037 / JM-038 / JM-039) — ONE source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_04_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/jeeber_onboarding/presentation/
//     dm_onboarding_screen.dart                         the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog's three states were `const DmOnboardingScreen(initialStep: …)`
// with no cubit at all. That is not inert: with no cubit the screen resolves
// its own collaborators out of GetIt — `sl<DmOnboardingGateway>()`, or a
// `DioDmOnboardingGateway` wrapped round the live `sl<Dio>()` — so inside the
// app the catalog's service-area Continue really did reach for the wire, and
// only `CatalogNetworkGuard` (which rejects mutating verbs, and nothing else)
// stood in the way. Every state below hands the screen a cubit instead, so the
// wizard a designer signs off against and the wizard the canvas draws are the
// same one, and neither can leave the process.
//
// ## Why these are builders, not `DmOnboardingState` constants
//
// [DmOnboardingCubit] has no `seed:` constructor, and three of the seven states
// are not expressible as a starting step at all — `isSubmitting` and BOTH error
// branches exist only as the result of a call:
//
//   * `next()` on the service-area step runs the coverage probe. It is the only
//     route to `isSubmitting`, and the only route to
//     [DmOnboardingError.submitFailed].
//   * `pickFromCamera()` is the only route to
//     [DmOnboardingError.photoPickFailed].
//
// So each builder constructs the cubit with the collaborator that decides how
// the call ends, then makes the call. The emit that matters lands on a
// microtask, which is after the host's `initState` and therefore after
// `DmOnboardingScreen`'s error listener is subscribed — the ordering the two
// error states depend on.
//
// ## Nothing here holds a timer, a subscription, or a socket
//
// [PendingDmOnboardingGateway] is an uncompleted `Completer` (no timer),
// [FakeDmOnboardingGateway] answers from a field, and
// [StubPhotoPickerService] answers from memory — no camera, no gallery, no
// runtime permission prompt. Each builder returns a NEW cubit so two hosts
// never share one; the caller owns closing it.

import 'dart:async';

import '../../../features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import '../../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../../features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../../features/photo_attachment/domain/photo_picker_service.dart';

/// A coverage probe that never lands — holds the wizard in its in-flight frame
/// for as long as the host is open.
///
/// A `Completer` that is never completed holds no timer and no subscription; it
/// simply never settles. [FakeDmOnboardingGateway] cannot express this: its
/// `submit` is an `async` method that always resolves on the next microtask.
class PendingDmOnboardingGateway implements DmOnboardingGateway {
  const PendingDmOnboardingGateway();

  @override
  Future<void> submit(DmOnboardingSubmission submission) =>
      Completer<void>().future;
}

/// The designed states of `DmOnboardingScreen`, as ready-to-mount cubits.
///
/// Pass one to `DmOnboardingScreen(cubit: …)`. The screen wraps a provided
/// cubit in `BlocProvider.value`, so it does NOT close it — whoever builds one
/// of these owns its lifetime.
class DmOnboardingScreenPreviewFixtures {
  const DmOnboardingScreenPreviewFixtures._();

  /// The home base the design is drawn for, once the map-pin screen returns a
  /// resolved place name.
  ///
  /// Same Beirut address the service-area step's own previews and
  /// `test/saved_locations_screen_test.dart` use, so one account runs through
  /// the whole jeeber_onboarding suite.
  static const DmOnboardingHomeBase geocodedBase = DmOnboardingHomeBase(
    lat: 33.8869,
    lng: 35.5131,
    label: 'Sassine Square, Ashrafieh',
  );

  /// The longest label a Lebanese reverse-geocode plausibly returns — a mall
  /// parking level. Shared with the service-area step previews, where it was
  /// first measured pushing the selector row's chevron off the trailing edge.
  static const DmOnboardingHomeBase longLabelBase = DmOnboardingHomeBase(
    lat: 33.8938,
    lng: 35.5018,
    label: 'Beirut Souks — Parking Level B2, Weygand Street',
  );

  /// Step 1 of 3 — the entry state every Jeeber sees first. No photo on file,
  /// so Continue is gated and the progress bar reports zero completed steps.
  static DmOnboardingCubit photoStep() => _cubit();

  /// Step 2 of 3 — the four empty address fields (no vehicle field, D20).
  static DmOnboardingCubit addressStep() =>
      _cubit(step: DmOnboardingStep.address);

  /// Step 3 of 3 — no home base pinned yet, so Continue is gated again.
  static DmOnboardingCubit serviceAreaStep() =>
      _cubit(step: DmOnboardingStep.serviceArea);

  /// Step 3 with a resolved home base and the coverage probe IN FLIGHT.
  ///
  /// The CTA swaps its label for an indeterminate spinner; the probe never
  /// lands, so the frame holds.
  static DmOnboardingCubit checkingCoverage() => _cubit(
        step: DmOnboardingStep.serviceArea,
        base: geocodedBase,
        gateway: const PendingDmOnboardingGateway(),
        confirmCoverage: true,
      );

  /// Step 3 with a coverage probe that THROWS — the JEBV4-13 P1-5 regression.
  ///
  /// The cubit emits a one-shot [DmOnboardingError.submitFailed]. Only
  /// `DmOnboardingScreen` listens for it; the step under it renders nothing.
  static DmOnboardingCubit coverageFailed() => _cubit(
        step: DmOnboardingStep.serviceArea,
        base: geocodedBase,
        gateway: FakeDmOnboardingGateway(shouldFail: true),
        confirmCoverage: true,
      );

  /// Step 1 with the camera permission denied — the other half of the same
  /// one-shot-error contract ([DmOnboardingError.photoPickFailed]).
  ///
  /// `PhotoPickFailure.cancelled` is deliberately NOT used: the cubit swallows
  /// it (backing out of the camera is not a failure), so it produces no state
  /// at all.
  static DmOnboardingCubit photoPickDenied() => _cubit(
        picker: StubPhotoPickerService(
          cameraFailure: PhotoPickFailure.permissionDenied,
        ),
        pickPhoto: true,
      );

  /// Step 3 with the longest home-base label the geocoder plausibly returns —
  /// the layout ceiling, printed twice (map caption + selector row).
  static DmOnboardingCubit longestContent() => _cubit(
        step: DmOnboardingStep.serviceArea,
        base: longLabelBase,
      );

  /// Builds the cubit the way the wizard screen does, minus the network.
  ///
  /// [confirmCoverage] presses Continue for you and [pickPhoto] presses the
  /// camera affordance for you, because those calls are the only routes to the
  /// in-flight and error states (see the library note).
  static DmOnboardingCubit _cubit({
    DmOnboardingStep step = DmOnboardingStep.photo,
    DmOnboardingHomeBase? base,
    DmOnboardingGateway? gateway,
    PhotoPickerService? picker,
    bool confirmCoverage = false,
    bool pickPhoto = false,
  }) {
    final DmOnboardingCubit cubit = DmOnboardingCubit(
      pickerService: picker ?? StubPhotoPickerService(),
      gateway: gateway ?? FakeDmOnboardingGateway(),
      initialStep: step,
    );
    if (base != null) cubit.setHomeBase(base);
    if (confirmCoverage) unawaited(cubit.next());
    if (pickPhoto) unawaited(cubit.pickFromCamera());
    return cubit;
  }
}
