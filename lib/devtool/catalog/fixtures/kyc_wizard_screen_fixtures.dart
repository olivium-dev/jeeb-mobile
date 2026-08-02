// Designed states for `KycWizardScreen` (JM-040 `kyc-identity` + JM-042
// `kyc-status`) — ONE source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_05_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/kyc/presentation/kyc_wizard_screen.dart
//                                                       the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog entry owned a private `_kycWizardCubit` factory plus a private
// `_seedKycIdentityReady` drive. Both moved here whole when the screen got a
// preview section, because two copies of the same "designed state" drift and
// the catalog is the one a designer signs off against.
//
// Two things changed in the move, and both are fixes rather than redesigns:
//
//  * **The identity states are SEEDED, not driven.** `_seedKycIdentityReady`
//    fired three real captures fire-and-forget, so the state a reviewer saw
//    depended on how many microtasks had run — and the captured bytes were
//    `StubPhotoPickerService`'s default 1 MB of `0xC0`, which is not a decodable
//    image, so all three tiles fell through `KycCaptureTile`'s `errorBuilder` to
//    the same grey placeholder. [KycWizardScreenPreviewFixtures.identityState]
//    puts real (tiny) PNGs in place synchronously instead, so an ID tile reads
//    as an ID card and the selfie tile as a face.
//  * **"Ready to submit" is now actually ready.** The old drive did captures +
//    ToS and stopped there, but JEBV4-295/E3 made a contract-valid `id_number`
//    a HARD client gate, so the state labelled "ready to submit" rendered a DEAD
//    `kyc_submit_cta`. The seed carries [nationalIdNumber], which is what the
//    label always claimed.
//
// NOTHING here touches the network. Every answer comes from a const value,
// throws, or never completes — the `CatalogNetworkGuard` that both hosts install
// is a net, not the plan. `KycWizardCubit` exposes no `seed:` constructor and a
// captured [PhotoAttachment] can only be put in place by emitting one, so the
// seeded states go through a one-line subclass that emits once from its
// constructor. Nothing else is overridden: `captureIdFront`, `setIdNumber`,
// `setTosAccepted` and `submit` all still run their production implementations,
// which is what keeps the catalog interactive.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../../features/kyc/application/kyc_wizard_state.dart';
import '../../../features/kyc/domain/kyc_form_schema.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../../features/photo_attachment/domain/photo_attachment.dart';

/// [FakeKycGateway] with the two knobs a still frame needs.
///
/// The base fake answers every call immediately, which is right for the Screen
/// Catalog (a designer taps things and expects them to work) and wrong for two
/// of the designed states: a schema load that has not returned, and a status
/// read that never answers. Both are spelled as a [Completer] that is never
/// completed — it holds no timer and no subscription, so the frame is stable
/// for as long as the host is open without arming anything a widget test would
/// report as pending.
///
/// Both knobs default to OFF, so a `KycWizardScreenPreviewGateway()` behaves
/// exactly like the `FakeKycGateway()` the catalog used before.
class KycWizardScreenPreviewGateway extends FakeKycGateway {
  KycWizardScreenPreviewGateway({
    super.decision,
    super.rejectionReason,
    super.initial,
    this.statusReads,
    this.schemaStalls = false,
    this.schemaFails = false,
  });

  /// How many `GET /v1/kyc/status` reads resolve before the gateway goes
  /// silent, or `null` for "always answers" (the catalog's setting).
  ///
  /// This is what makes a PENDING status frame still: `KycStatusView` arms a
  /// real 3 s `Timer` for as long as the decision is pending and
  /// `KycWizardScreen` exposes no seam to shorten it, so the only state in
  /// which the poller holds no timer is "a probe is in flight". Capping the
  /// reads parks it there.
  final int? statusReads;

  /// When true, `fetchFormSchema` never resolves — the wizard's cold-start
  /// `schema` step, held at its spinner.
  final bool schemaStalls;

  /// When true, `fetchFormSchema` throws, which is the only route to
  /// [KycWizardError.schemaLoadFailed].
  final bool schemaFails;

  int _statusReadCount = 0;

  @override
  Future<KycSubmission> fetchStatus() {
    final int? cap = statusReads;
    _statusReadCount++;
    if (cap != null && _statusReadCount > cap) {
      return Completer<KycSubmission>().future;
    }
    return super.fetchStatus();
  }

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) {
    if (schemaStalls) return Completer<KycFormSchema>().future;
    if (schemaFails) {
      return Future<KycFormSchema>.error(
        StateError('KYC form schema unavailable (designed state)'),
      );
    }
    return super.fetchFormSchema(variant: variant);
  }
}

/// The designed states of `KycWizardScreen`, as seeded cubit states plus the
/// two cubits that are described by a real load instead.
class KycWizardScreenPreviewFixtures {
  const KycWizardScreenPreviewFixtures._();

  /// A contract-valid national ID (`^\d{12}$`, the shape the live BFF
  /// enforces). This is the value that makes `kyc_submit_cta` live.
  static const String nationalIdNumber = '123456789012';

  /// A passport number at the field's full 24-character cap — the widest single
  /// line of user content this screen can hold.
  static const String passportNumber = 'AB1234567890123456789012';

  /// A 120 × 76 landscape PNG in the ISO/IEC 7810 ID-1 proportion the alignment
  /// guide teaches — a navy header band, a portrait box and three text lines —
  /// so a captured gov-ID tile reads as a card under `BoxFit.cover`.
  ///
  /// Byte-identical to the fixture the `KycIdentityStep` previews use, so the
  /// step reviewed on its own and the step reviewed inside the wizard show the
  /// same capture.
  static const String _idCardPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAHgAAABMCAIAAAAp7eQ+AAAAv0lEQVR42u3boQ2AMBRF0a7C'
      'JkzDDGg2wKDRGBIGYB4EqhMwAa75QDnJdXXH9KVJU9N2CighAA1aoEGDpgAatECDBk0BNGiB'
      'Bg1aEdDHmRUQaNCgBRo06LuDaV6LBxo0aNCgQYMG/Sx0P4zVBxo0aNCgQYM27+xo0KBBgwYN'
      'GjTowtDLtlcfaNCgQYMGbXWABg0aNGjQoEF763hDoEGDBv13aJchaNCgQYMGDRq0L8qgBRo0'
      'aIEGLdCgQQv0p7oAE7AkXoytNNIAAAAASUVORK5CYII=';

  /// A 60 × 76 portrait PNG — a face and shoulders on a warm ground — so the
  /// selfie tile is visibly a DIFFERENT capture from the two ID tiles rather
  /// than the same block three times.
  static const String _selfiePngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAADwAAABMCAIAAAC+vEPkAAAA8UlEQVR42u3XsRHCMBBE0auK'
      'WiiIGqiFaggJSWgAZpx4MJItaaU77D9z8d8XSvZ6Pv7uDDRo0KBBgw6Ovt+uqYuIznDldBvG'
      'FdJtvLjdbS7iRrd5iVvc5iiudh8GLRTXuY+Blosr3KBjojuJS92gQYMGDRq0M5q3B2h+LjHQ'
      'p/Plc0LxFOyIngZ6oIvclWiVex7sgp4PSNzLoBi9HGh0p4Ij0HXuTE2GzmyU0rekBOgtM6v6'
      '0shotOSa0C7iVffu0I7ivBu0O9pdnHGD9kUHEafcoB3RocQ/3aBB7x0dULx0gwYNGrQAHVb8'
      '5QYNGnQA9BuWuuxNxw9fDgAAAABJRU5ErkJggg==';

  /// The two fixture payloads, decoded once. Both are far under the 2 MB
  /// ceiling, so `HalvingPhotoCompressor` returns them UNCHANGED — a capture
  /// tapped in the catalog fills the tile with a real image rather than the
  /// stride-copied blob the 1 MB default payload compresses down to.
  static final Uint8List idCardBytes = base64Decode(_idCardPngBase64);
  static final Uint8List selfieBytes = base64Decode(_selfiePngBase64);

  static PhotoAttachment _photo(String slot, Uint8List bytes) =>
      PhotoAttachment(
        id: 'kyc-wizard-preview-$slot',
        bytes: bytes,
        // A real capture arrives an order of magnitude larger and is compressed
        // on the way in; the ratio is what a tile's "compressed from" hint will
        // read off when it lands.
        originalSizeBytes: bytes.length * 8,
        source: PhotoSource.camera,
      );

  /// One identity-step state, described by what the jeeber has done so far.
  /// Defaults describe a cold entry: nothing captured, nothing typed, ToS
  /// unticked.
  static KycWizardState identityState({
    KycIdType idType = KycIdType.nationalId,
    String? idNumber,
    bool govIdCaptured = false,
    bool selfieCaptured = false,
    bool tosAccepted = false,
    KycSubmitFieldError? submitFieldError,
  }) {
    return KycWizardState(
      step: KycWizardStep.identity,
      tosAccepted: tosAccepted,
      submitFieldError: submitFieldError,
      submission: KycSubmission(
        status: KycStatus.notSubmitted,
        idType: idType,
        idNumber: idNumber,
        idFront: govIdCaptured ? _photo('id-front', idCardBytes) : null,
        idBack: govIdCaptured ? _photo('id-back', idCardBytes) : null,
        selfie: selfieCaptured ? _photo('selfie', selfieBytes) : null,
      ),
    );
  }

  /// The wizard parked on the submit spinner — `POST /v1/kyc/submit` is in
  /// flight and `KycSubmittingView` owns the body.
  static const KycWizardState submittingState = KycWizardState(
    step: KycWizardStep.submitting,
  );

  /// The `schema` step AFTER `KycWizardCubit.loadSchema` caught a failure.
  ///
  /// Seeded rather than produced by a failing load on purpose: the host screen
  /// listens for `error` changes and calls `acknowledgeError()` in the same
  /// turn, which clears the flag this view is keyed off. See the preview
  /// section in `kyc_wizard_screen.dart` for what that means.
  static const KycWizardState schemaLoadFailedState = KycWizardState(
    step: KycWizardStep.schema,
    error: KycWizardError.schemaLoadFailed,
  );

  /// A real [KycWizardCubit] parked on [seed], with every production transition
  /// still live.
  static KycWizardCubit seededCubit(
    KycWizardState seed, {
    KycGateway? gateway,
  }) {
    return _SeededKycWizardCubit(
      seed,
      gateway ?? KycWizardScreenPreviewGateway(),
    );
  }

  /// The cold-start STATUS path: a cubit hydrated by the real
  /// `KycWizardCubit.loadStatus()` against a canned decision, exactly as
  /// re-entering `/profile/kyc` on an already-submitted KYC does.
  ///
  /// [statusReads] caps how many reads answer; leave it null (the catalog's
  /// setting) for a gateway that always answers.
  static KycWizardCubit statusCubit({
    KycStatus status = KycStatus.notSubmitted,
    KycRejectionReason? rejectionReason,
    List<KycResubmitStep> resubmitSteps = const <KycResubmitStep>[],
    int? statusReads,
  }) {
    final KycWizardCubit cubit = KycWizardCubit(
      pickerService: StubPhotoPickerService(cameraPayload: idCardBytes),
      gateway: KycWizardScreenPreviewGateway(
        initial: KycSubmission(
          status: status,
          rejectionReason: rejectionReason,
          resubmitSteps: resubmitSteps,
        ),
        statusReads: statusReads,
      ),
    );
    unawaited(cubit.loadStatus());
    return cubit;
  }

  /// The cold-start SCHEMA path, held at the moment `GET
  /// /v1/kyc/jeeb/form-schema` has been asked for and has not answered.
  static KycWizardCubit schemaLoadingCubit() {
    final KycWizardCubit cubit = KycWizardCubit(
      pickerService: StubPhotoPickerService(cameraPayload: idCardBytes),
      gateway: KycWizardScreenPreviewGateway(schemaStalls: true),
    );
    unawaited(cubit.loadSchema());
    return cubit;
  }
}

/// The real cubit over inert collaborators, parked on `seed`.
///
/// Emitting once from the constructor is the whole implementation, and it is
/// the only way to put a captured [PhotoAttachment], a submit-scoped field
/// error or a held `schemaLoadFailed` in place — the cubit exposes no seed seam
/// and all three are otherwise reachable only through a camera round-trip, a
/// server 400, or a race with the host screen's own error listener.
class _SeededKycWizardCubit extends KycWizardCubit {
  _SeededKycWizardCubit(KycWizardState seed, KycGateway gateway)
      : super(
          // Canned bytes, so a capture tapped in the catalog fills with the ID
          // fixture instead of reaching for a camera that is not there.
          pickerService: StubPhotoPickerService(
            cameraPayload: KycWizardScreenPreviewFixtures.idCardBytes,
          ),
          gateway: gateway,
        ) {
    emit(seed);
  }
}
