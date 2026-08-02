/// Widget previews for [KycIdentityStep] — run with
/// `flutter widget-preview start`.
///
/// [KycIdentityStep] is the whole of JM-040 `kyc-identity` on one scrollable
/// screen: gov-ID front/back, the ratified id-type picker
/// (national_id | passport | residency), the id-number field, the selfie, ToS
/// acceptance and the single submit CTA. Every state below is the real widget
/// over the real [KycWizardCubit], parked on a seeded [KycWizardState] — the
/// same seed-by-emit approach the DM-onboarding previews use, because the
/// production cubit exposes no `seed:` constructor and a captured photo can
/// only be put in place by emitting one.
///
/// **Network-free by construction.** The cubit is built over
/// [StubPhotoPickerService] (canned in-memory bytes, no `image_picker`, no
/// permissions) and [FakeKycGateway] (canned in-memory responses, no [Dio], no
/// DI). Tapping a capture tile or the submit CTA in the canvas therefore runs
/// the REAL cubit paths against fixtures; the guard in [jeebPreviewHost] is the
/// net, not the plan.
///
/// **What to look at.**
///  * The `kyc_scroll_hint` pill (JEBV4-295) is a `Row(mainAxisSize: min)`
///    holding a `Text` with no `Flexible`, no `maxLines` and no ellipsis. It is
///    the one thing on this screen that cannot scroll its way out of trouble,
///    and when it does run out of width it is CLIPPED rather than shortened —
///    silently cutting the cue that exists to stop the selfie section being
///    missed. Read it in the AR RTL and 200% renderings; the shape is pinned in
///    `test/previews/kyc/kyc_identity_step_preview_test.dart`.
///  * The submit CTA is gated on `hasSelfie && hasValidIdNumber` only (JEBV4-295)
///    — gov-ID front/back and the ToS tick do NOT disable it, so
///    [kycIdentityStepReadyToSubmit] and [kycIdentityStepSelfieMissing] differ by
///    a single field and yet only one of them can submit. Note what a jeeber
///    parked on the dead CTA is told: nothing. The inline id-number errors are
///    submit-scoped, and the gate is what stops a submit happening.
///  * The two inline rejection surfaces (`id_number`, `id_type`) are the only
///    error UI this widget owns; every other failure is a snackbar the HOST
///    screen raises, so it is invisible here by design.
///
/// Two things you will NOT see in this canvas, both deliberate:
///  * The `kycWizardSubmitting` label on the CTA. This widget switches to it on
///    `step == submitting`, but `KycWizardScreen._buildBody` swaps the whole
///    body for `KycSubmittingView` at exactly that step — so the branch is
///    unreachable in the app and there is no honest state to preview it from.
///  * The as-you-type validation. It lives in `OmdsTextField`'s own state and
///    fires from `onChanged`, so a seeded preview can never show it — and the
///    `isRequired: true` this step passes is inert for the same reason (the
///    supplied `validator` bypasses the branch that reads it, and the field
///    renders no required marker of any kind).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../features/kyc/application/kyc_wizard_state.dart';
import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/kyc/domain/kyc_submission.dart';
import '../../features/kyc/presentation/widgets/kyc_identity_step.dart';
import '../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../features/photo_attachment/domain/photo_attachment.dart';
import '../harness/jeeb_preview.dart';

/// The real body box this step gets on a 844 dp phone: 390 dp wide, and as tall
/// as `KycWizardScreen` leaves once the status bar, its AppBar, the `ID | Selfie`
/// progress header and the home indicator are taken out.
///
/// Sizing the canvas to the real body is deliberate. This step scrolls, so a
/// taller box would not "fix" anything vertically — but a WIDER one would hide
/// the horizontal ceilings (the scroll-hint pill, the radio-tile titles) that are
/// the only things here that cannot scroll their way out of trouble.
const Size _formBox = Size(390, 670);

/// A 120 × 76 landscape PNG in the ISO/IEC 7810 ID-1 proportion the alignment
/// guide teaches — a navy header band, a portrait box and three text lines — so
/// a captured gov-ID tile reads as a card and `BoxFit.cover` has the aspect
/// ratio it was designed for.
const String _idCardPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAHgAAABMCAIAAAAp7eQ+AAAAv0lEQVR42u3boQ2AMBRF0a7C'
    'JkzDDGg2wKDRGBIGYB4EqhMwAa75QDnJdXXH9KVJU9N2CighAA1aoEGDpgAatECDBk0BNGiB'
    'Bg1aEdDHmRUQaNCgBRo06LuDaV6LBxo0aNCgQYMG/Sx0P4zVBxo0aNCgQYM27+xo0KBBgwYN'
    'GjTowtDLtlcfaNCgQYMGbXWABg0aNGjQoEF763hDoEGDBv13aJchaNCgQYMGDRq0L8qgBRo0'
    'aIEGLdCgQQv0p7oAE7AkXoytNNIAAAAASUVORK5CYII=';

/// A 60 × 76 portrait PNG — a face and shoulders on a warm ground — so the
/// selfie tile is visibly a DIFFERENT capture from the two ID tiles rather than
/// the same grey block three times.
const String _selfiePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAADwAAABMCAIAAAC+vEPkAAAA8UlEQVR42u3XsRHCMBBE0auK'
    'WiiIGqiFaggJSWgAZpx4MJItaaU77D9z8d8XSvZ6Pv7uDDRo0KBBgw6Ovt+uqYuIznDldBvG'
    'FdJtvLjdbS7iRrd5iVvc5iiudh8GLRTXuY+Blosr3KBjojuJS92gQYMGDRq0M5q3B2h+LjHQ'
    'p/Plc0LxFOyIngZ6oIvclWiVex7sgp4PSNzLoBi9HGh0p4Ij0HXuTE2GzmyU0rekBOgtM6v6'
    '0shotOSa0C7iVffu0I7ivBu0O9pdnHGD9kUHEafcoB3RocQ/3aBB7x0dULx0gwYNGrQAHVb8'
    '5QYNGnQA9BuWuuxNxw9fDgAAAABJRU5ErkJggg==';

/// The two fixture payloads, decoded once.
final Uint8List _idCardBytes = base64Decode(_idCardPngBase64);
final Uint8List _selfieBytes = base64Decode(_selfiePngBase64);

PhotoAttachment _photo(String slot, Uint8List bytes) => PhotoAttachment(
      id: 'kyc-preview-$slot',
      bytes: bytes,
      // A real capture arrives an order of magnitude larger and is compressed
      // on the way in; the ratio is what the tile's "compressed from" copy will
      // read off when it lands.
      originalSizeBytes: bytes.length * 8,
      source: PhotoSource.camera,
    );

/// The real cubit over inert collaborators, parked on [seed].
///
/// Nothing here overrides a transition: `setIdType`, `setIdNumber`,
/// `setTosAccepted`, `captureIdFront/Back/Selfie` and `submit` all still run
/// their production implementations in the canvas. Emitting once from the
/// constructor is the whole implementation, and it is the only way to put a
/// captured [PhotoAttachment] or a submit-scoped field error in place — the
/// cubit exposes no seed seam and both of those are otherwise reachable only
/// through a camera round-trip or a server 400.
class _SeededKycWizardCubit extends KycWizardCubit {
  _SeededKycWizardCubit(KycWizardState seed)
      : super(
          // Canned bytes, so a capture tapped in the canvas fills with the ID
          // fixture instead of reaching for a camera that is not there.
          pickerService: StubPhotoPickerService(cameraPayload: _idCardBytes),
          // Explicit rather than defaulted: the submit CTA is live in these
          // previews, and this is what makes tapping it in-memory.
          gateway: FakeKycGateway(),
        ) {
    emit(seed);
  }
}

/// Builds an identity-step state. Defaults describe a cold entry: nothing
/// captured, nothing typed, ToS unticked.
KycWizardState _identity({
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
      idFront: govIdCaptured ? _photo('id-front', _idCardBytes) : null,
      idBack: govIdCaptured ? _photo('id-back', _idCardBytes) : null,
      selfie: selfieCaptured ? _photo('selfie', _selfieBytes) : null,
    ),
  );
}

/// Mounts the step over a cubit seeded with [seed].
///
/// The `ValueKey` is load-bearing: these trees are identical apart from the
/// seed, so without it Flutter reconciles element-for-element across a second
/// `pumpWidget` in one test, `create` never re-runs, and — because
/// `KycIdentityStep.initState` copies `idNumber` into its own controller
/// exactly once — the field would keep showing the PREVIOUS preview's digits.
Widget _hosted(String state, KycWizardState seed) {
  return BlocProvider<KycWizardCubit>(
    key: ValueKey<String>(state),
    create: (_) => _SeededKycWizardCubit(seed),
    child: const KycIdentityStep(),
  );
}

/// Cold entry: the jeeber has just landed on `kyc-identity` and done nothing.
///
/// This is the first frame of the step and the one every jeeber sees. Two
/// things are worth checking here and nowhere else: the `kyc_scroll_hint` pill
/// is present (JEBV4-295 — the selfie section is below the fold behind a STATIC
/// "ID | Selfie" header, and without this cue first-time users and automated
/// drivers both missed it), and the submit CTA is already disabled.
///
/// Note what the disabled CTA does NOT come with: no inline reason, no summary
/// of what is still missing. The two error strings this widget can render are
/// both submit-scoped, so at this point the screen states the requirement only
/// in the field label and the section titles.
@JeebPreview(name: 'Cold entry · nothing captured', size: _formBox)
Widget kycIdentityStepFresh() => _hosted('fresh', _identity());

/// The JEBV4-295 state: gov-ID done, number valid, ToS ticked — selfie missing.
///
/// This is the exact shape that used to 400 server-side on
/// `selfie_with_liveness_url: null`, because the CTA was enabled the moment the
/// ID number alone was valid. It is now the load-bearing NEGATIVE case for the
/// gate: everything on this screen looks finished, the scroll hint is the only
/// thing telling the user otherwise, and the CTA must still be dead.
///
/// It is also the state where the scroll hint matters most, so it is the one to
/// read the AR RTL and 200% renderings against.
@JeebPreview(name: 'Selfie still missing · CTA dead', size: _formBox)
Widget kycIdentityStepSelfieMissing() => _hosted(
      'selfie-missing',
      _identity(
        idNumber: '112233445566',
        govIdCaptured: true,
        tosAccepted: true,
      ),
    );

/// Everything captured, a contract-valid 12-digit national ID, ToS accepted —
/// the only state in this file where `kyc_submit_cta` is live.
///
/// The scroll hint is gone (it is tied to `!hasSelfie`, not to scroll position),
/// so this is also the layout where the fold boundary disappears and the selfie
/// section runs straight on from the ID number field.
@JeebPreview(name: 'Ready to submit', size: _formBox)
Widget kycIdentityStepReadyToSubmit() => _hosted(
      'ready',
      _identity(
        idNumber: '990011223344',
        govIdCaptured: true,
        selfieCaptured: true,
        tosAccepted: true,
      ),
    );

/// The BFF rejected the number itself: a field-scoped RFC-7807 400 with
/// `field: "id_number"` on a value the client's own rules accepted.
///
/// The fallback branch of `_submitScopedIdNumberError` — "This ID number was not
/// accepted. Check it and try again." — is only reachable this way, and it is
/// the longest of the three id-number errors, so it is what decides whether the
/// error line wraps under the field or collides with the ToS card below it.
@JeebPreview(name: 'Server rejected the ID number', size: _formBox)
Widget kycIdentityStepIdNumberRejected() => _hosted(
      'id-number-rejected',
      _identity(
        idNumber: '123456789012',
        govIdCaptured: true,
        selfieCaptured: true,
        tosAccepted: true,
        submitFieldError: KycSubmitFieldError.idNumber,
      ),
    );

/// Residency permit rejected on `id_type` — a live contract mismatch, not a
/// hypothetical.
///
/// E3/Q-042 ratified `residency`, but the deployed BFF still spells the variant
/// `residency_permit`, so picking the third radio and submitting comes back as a
/// field-scoped 400 on `id_type` until JEBV4-197 lands on the gateway side. The
/// inline "Select a supported ID type" line under the picker is the ONLY thing
/// the jeeber is told, on a picker where all three options look equally
/// selectable — which is the state to review, in both locales.
@JeebPreview(name: 'Residency rejected on id_type', size: _formBox)
Widget kycIdentityStepResidencyRejected() => _hosted(
      'residency-rejected',
      _identity(
        idType: KycIdType.residency,
        idNumber: 'RP-2026-004417',
        govIdCaptured: true,
        selfieCaptured: true,
        tosAccepted: true,
        submitFieldError: KycSubmitFieldError.idType,
      ),
    );

/// Content ceiling: a passport at the field's full 24-character cap.
///
/// Switching away from `national_id` changes three things at once — the label
/// ("Passport number"), the hint ("Enter your document number") and the input
/// contract (free text, 24 chars, no digits-only filter, no `^\d{12}$` rule) —
/// and 24 characters is the longest value the field will hold. That makes this
/// the widest single line of user content the step can produce, and the state
/// where the label, the value and the `24/24` counter all compete for one row.
@JeebPreview(name: 'Passport · 24-char number', size: _formBox)
Widget kycIdentityStepPassportLongNumber() => _hosted(
      'passport-long',
      _identity(
        idType: KycIdType.passport,
        idNumber: 'AB1234567890123456789012',
        govIdCaptured: true,
        selfieCaptured: true,
        tosAccepted: true,
      ),
    );
