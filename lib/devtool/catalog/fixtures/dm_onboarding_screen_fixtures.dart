// Designed states for `DmOnboardingScreen` — the delivery-man onboarding

import 'dart:async';

import 'dart:typed_data';

import '../../../core/network/app_failure.dart';
import '../../../features/kyc/domain/cdn_asset_gateway.dart';
import '../../../features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import '../../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../../features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../../features/photo_attachment/domain/photo_picker_service.dart';

/// A coverage probe that never lands — holds the wizard in its in-flight frame
/// for as long as the host is open.
/// A `Completer` that is never completed holds no timer and no subscription; it
class PendingDmOnboardingGateway implements DmOnboardingGateway {
  const PendingDmOnboardingGateway();

  @override
  Future<void> submit(DmOnboardingSubmission submission) =>
      Completer<void>().future;
}

/// The designed states of `DmOnboardingScreen`, as ready-to-mount cubits.
/// Pass one to `DmOnboardingScreen(cubit: …)`. The screen wraps a provided
/// cubit in `BlocProvider.value`, so it does NOT close it — whoever builds one
class DmOnboardingScreenPreviewFixtures {
  const DmOnboardingScreenPreviewFixtures._();

  /// The home base the design is drawn for, once the map-pin screen returns a
  /// resolved place name.
  static const DmOnboardingHomeBase geocodedBase = DmOnboardingHomeBase(
    lat: 33.8869,
    lng: 35.5131,
    label: 'Sassine Square, Ashrafieh',
  );

  /// The longest label a Lebanese reverse-geocode plausibly returns — a mall
  /// parking level. Shared with the service-area step previews, where it was
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
  /// The CTA swaps its label for an indeterminate spinner; the probe never
  static DmOnboardingCubit checkingCoverage() => _cubit(
        step: DmOnboardingStep.serviceArea,
        base: geocodedBase,
        gateway: const PendingDmOnboardingGateway(),
        confirmCoverage: true,
      );

  /// Step 3 with a coverage probe that THROWS — the JEBV4-13 P1-5 regression.
  /// The cubit emits a one-shot [DmOnboardingError.submitFailed]. Only
  static DmOnboardingCubit coverageFailed() => _cubit(
        step: DmOnboardingStep.serviceArea,
        base: geocodedBase,
        gateway: FakeDmOnboardingGateway(shouldFail: true),
        confirmCoverage: true,
      );

  /// Step 1 with the camera permission denied — the other half of the same
  /// one-shot-error contract ([DmOnboardingError.photoPickFailed]).
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
  /// [confirmCoverage] presses Continue for you and [pickPhoto] presses the
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

/// UX-40: the home base is outside every served zone — the note stays on the
/// service-area step rather than flashing past as a snack.
class DmOnboardingScreenOutOfCoverageGateway implements DmOnboardingGateway {
  const DmOnboardingScreenOutOfCoverageGateway();

  @override
  Future<void> submit(DmOnboardingSubmission submission) async =>
      throw const DmOnboardingOutOfCoverageException();
}

/// A 5xx on the submit: `dm_onboarding_error_snack` with the server body.
class DmOnboardingScreenServerErrorGateway implements DmOnboardingGateway {
  const DmOnboardingScreenServerErrorGateway();

  @override
  Future<void> submit(DmOnboardingSubmission submission) async => throw const
      DmOnboardingGatewayException(ServerFailure(status: 500));
}

/// UX-06: the portrait upload fails — `photoUploadFailed`, never
/// `submitFailed`.
class DmOnboardingScreenPhotoUploadFailingCdn implements CdnAssetGateway {
  const DmOnboardingScreenPhotoUploadFailingCdn();

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async =>
      throw const CdnUploadException(
        'cdn_signed_put',
        failure: ServerFailure(status: 500),
        status: 500,
      );

  @override
  Future<Uint8List> fetchAsset(String objectRef) async =>
      throw const CdnFetchException('cdn_fetch');
}
