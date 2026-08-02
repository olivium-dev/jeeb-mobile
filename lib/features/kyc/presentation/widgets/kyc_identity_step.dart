import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/text/digit_normalization.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';
import '../../domain/kyc_submission.dart';
import 'kyc_capture_tile.dart';
import 'kyc_id_alignment_guide.dart';
import 'kyc_liveness_prompt_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
// `Uint8List` already arrives with `package:flutter/services.dart` above.
import 'dart:convert';
import '../../../../core/previews/jeeb_preview.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../../photo_attachment/domain/photo_attachment.dart';
import '../../domain/kyc_gateway.dart';

/// JM-040 `kyc-identity` — the single identity-capture screen of the KYC
/// wizard, after the Vehicle step removal (D20).
class KycIdentityStep extends StatefulWidget {
  const KycIdentityStep({super.key});

  static const Key frontTileKey = Key('kyc-id-front-tile');
  static const Key backTileKey = Key('kyc-id-back-tile');
  static const Key idNumberFieldKey = Key('kyc-id-number-field');
  static const Key idTypeNationalIdKey = Key('kyc-id-type-national_id');
  static const Key idTypePassportKey = Key('kyc-id-type-passport');
  static const Key idTypeResidencyKey = Key('kyc-id-type-residency');
  static const Key selfieTileKey = Key('kyc-selfie-tile');
  static const Key livenessPromptKey = Key('kyc-selfie-liveness-prompt');
  static const Key tosCheckboxKey = Key('kyc-tos-accept-checkbox');
  static const Key submitButtonKey = Key('kyc-submit-cta');

  static const Key scrollHintKey = Key('kyc-scroll-hint');

  static const int _nationalIdLength = 12;

  static const int _documentNumberMaxLength = 24;

  static String? _idNumberError(
    AppLocalizations l10n,
    KycIdType type,
    String? value,
  ) {
    final trimmed = normalizeArabicIndicDigits(value ?? '').trim();
    if (trimmed.isEmpty) return l10n.kycIdNumberRequired;
    if (type == KycIdType.nationalId &&
        !KycSubmission.nationalIdPattern.hasMatch(trimmed)) {
      return l10n.kycIdNumberInvalid;
    }
    return null;
  }

  @override
  State<KycIdentityStep> createState() => _KycIdentityStepState();
}

class _KycIdentityStepState extends State<KycIdentityStep> {
  late final TextEditingController _idNumberController;

  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _idNumberController = TextEditingController(
      text: context.read<KycWizardCubit>().state.submission.idNumber ?? '',
    );
    _scrollController = ScrollController();
  }

  void _scrollToSelfie() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncIdNumber(BuildContext context, KycWizardState state) {
    final target = state.submission.idNumber ?? '';
    if (_idNumberController.text == target) return;
    _idNumberController.value = TextEditingValue(
      text: target,
      selection: TextSelection.collapsed(offset: target.length),
    );
  }

  String _idTypeLabel(AppLocalizations l10n, KycIdType type) {
    switch (type) {
      case KycIdType.nationalId:
        return l10n.kycIdTypeNationalId;
      case KycIdType.passport:
        return l10n.kycIdTypePassport;
      case KycIdType.residency:
        return l10n.kycIdTypeResidency;
    }
  }

  Key _idTypeKey(KycIdType type) {
    switch (type) {
      case KycIdType.nationalId:
        return KycIdentityStep.idTypeNationalIdKey;
      case KycIdType.passport:
        return KycIdentityStep.idTypePassportKey;
      case KycIdType.residency:
        return KycIdentityStep.idTypeResidencyKey;
    }
  }

  String _idNumberLabel(AppLocalizations l10n, KycIdType type) {
    switch (type) {
      case KycIdType.nationalId:
        return l10n.kycIdNumberLabel;
      case KycIdType.passport:
        return l10n.kycIdNumberLabelPassport;
      case KycIdType.residency:
        return l10n.kycIdNumberLabelResidency;
    }
  }

  String _idNumberHint(AppLocalizations l10n, KycIdType type) {
    return type == KycIdType.nationalId
        ? l10n.kycIdNumberHint
        : l10n.kycIdNumberHintDocument;
  }

  String? _submitScopedIdNumberError(
    AppLocalizations l10n,
    KycWizardState state,
  ) {
    if (state.submitFieldError != KycSubmitFieldError.idNumber) return null;
    return KycIdentityStep._idNumberError(
          l10n,
          state.submission.idType,
          state.submission.idNumber,
        ) ??
        l10n.kycIdNumberRejected;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocConsumer<KycWizardCubit, KycWizardState>(
      listenWhen: (prev, curr) =>
          prev.submission.idNumber != curr.submission.idNumber,
      listener: _syncIdNumber,
      builder: (context, state) {
        final cubit = context.read<KycWizardCubit>();
        final idType = state.submission.idType;
        final isNationalId = idType == KycIdType.nationalId;
        return Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.kycIdStepTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.kycIdStepSubtitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: Spacing.medium),
                      KycIdAlignmentGuide(
                        title: l10n.kycIdAlignmentGuideTitle,
                        caption: l10n.kycIdAlignmentGuideCaption,
                      ),
                      const SizedBox(height: Spacing.large),
                      Semantics(
                        identifier: 'kyc_id_front_upload',
                        button: true,
                        container: true,
                        child: KycCaptureTile(
                          tileKey: KycIdentityStep.frontTileKey,
                          label: l10n.kycIdFrontLabel,
                          photo: state.submission.idFront,
                          isProcessing:
                              state.capturing == KycCaptureSlot.idFront,
                          captureCtaSemantic: state.submission.hasIdFront
                              ? l10n.kycIdRetake
                              : l10n.kycIdCaptureCta,
                          onTap: cubit.captureIdFront,
                        ),
                      ),
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'kyc_id_back_upload',
                        button: true,
                        container: true,
                        child: KycCaptureTile(
                          tileKey: KycIdentityStep.backTileKey,
                          label: l10n.kycIdBackLabel,
                          photo: state.submission.idBack,
                          isProcessing:
                              state.capturing == KycCaptureSlot.idBack,
                          captureCtaSemantic: state.submission.hasIdBack
                              ? l10n.kycIdRetake
                              : l10n.kycIdCaptureCta,
                          onTap: cubit.captureIdBack,
                        ),
                      ),
                      const SizedBox(height: Spacing.large),
                      Text(
                        l10n.kycIdTypeLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: Spacing.xSmall),
                      Semantics(
                        identifier: 'kyc_id_type_picker',
                        container: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final type in KycIdType.values)
                              Semantics(
                                identifier: 'kyc_id_type_${type.wire}',
                                child: OmdsRadioTile<KycIdType>(
                                  key: _idTypeKey(type),
                                  title: _idTypeLabel(l10n, type),
                                  value: type,
                                  groupValue: idType,
                                  onChanged: (t) {
                                    if (t != null) cubit.setIdType(t);
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (state.submitFieldError ==
                          KycSubmitFieldError.idType) ...[
                        const SizedBox(height: Spacing.xSmall),
                        Text(
                          l10n.kycIdTypeInvalid,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'kyc_id_number_input',
                        textField: true,
                        child: OmdsTextField(
                          key: KycIdentityStep.idNumberFieldKey,
                          controller: _idNumberController,
                          labelText: _idNumberLabel(l10n, idType),
                          hintText: _idNumberHint(l10n, idType),
                          isRequired: true,
                          errorText: _submitScopedIdNumberError(l10n, state),
                          keyboardType: isNationalId
                              ? TextInputType.number
                              : TextInputType.text,
                          maxLength: isNationalId
                              ? KycIdentityStep._nationalIdLength
                              : KycIdentityStep._documentNumberMaxLength,
                          inputFormatters: [
                            const ArabicIndicDigitsFormatter(),
                            if (isNationalId)
                              FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: cubit.setIdNumber,
                          validator: (value) => KycIdentityStep._idNumberError(
                            l10n,
                            idType,
                            value,
                          ),
                        ),
                      ),
                      const SizedBox(height: Spacing.xLarge),

                      if (!state.submission.hasSelfie) ...[
                        Center(
                          child: _ScrollForSelfieHint(
                            label: l10n.kycScrollForSelfieHint,
                            onTap: _scrollToSelfie,
                          ),
                        ),
                        const SizedBox(height: Spacing.large),
                      ],

                      Text(
                        l10n.kycSelfieStepTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.kycSelfieStepSubtitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: Spacing.medium),
                      KycLivenessPromptCard(
                        cardKey: KycIdentityStep.livenessPromptKey,
                        title: l10n.kycSelfieLivenessPrompt,
                        prompts: [
                          KycLivenessPrompt(
                            icon: Icons.remove_red_eye_outlined,
                            text: l10n.kycSelfieLivenessBlink,
                          ),
                          KycLivenessPrompt(
                            icon: Icons.sentiment_satisfied_alt_rounded,
                            text: l10n.kycSelfieLivenessSmile,
                          ),
                        ],
                      ),
                      const SizedBox(height: Spacing.large),
                      Semantics(
                        identifier: 'kyc_selfie_upload',
                        button: true,
                        container: true,
                        child: KycCaptureTile(
                          tileKey: KycIdentityStep.selfieTileKey,
                          label: l10n.kycSelfieStepTitle,
                          photo: state.submission.selfie,
                          isProcessing:
                              state.capturing == KycCaptureSlot.selfie,
                          captureCtaSemantic: state.submission.hasSelfie
                              ? l10n.kycSelfieRetake
                              : l10n.kycSelfieCaptureCta,
                          onTap: cubit.captureSelfie,
                        ),
                      ),
                      const SizedBox(height: Spacing.xLarge),

                      _TosAcceptanceCard(
                        l10n: l10n,
                        accepted: state.tosAccepted,
                        documentBody: l10n.kycTosDocumentBody,
                        onChanged: (v) => cubit.setTosAccepted(v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.medium),
              Semantics(
                identifier: 'kyc_submit_cta',
                button: true,
                container: true,
                child: OmdsPrimaryButton(
                  key: KycIdentityStep.submitButtonKey,
                  text: state.step == KycWizardStep.submitting
                      ? l10n.kycWizardSubmitting
                      : l10n.kycWizardSubmit,
                  // (JM-051) let the user fire an incomplete submit whenever
                  isEnabled: state.step != KycWizardStep.submitting &&
                      state.submission.hasSelfie &&
                      state.submission.hasValidIdNumber,
                  onTap: () => cubit.submit(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScrollForSelfieHint extends StatelessWidget {
  const _ScrollForSelfieHint({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      identifier: 'kyc_scroll_hint',
      button: true,
      label: label,
      child: Material(
        color: colorScheme.primaryContainer,
        borderRadius: OmdsBorderRadius.pill,
        child: InkWell(
          key: KycIdentityStep.scrollHintKey,
          borderRadius: OmdsBorderRadius.pill,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.xSmall,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Spacing.xSmall),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TosAcceptanceCard extends StatelessWidget {
  const _TosAcceptanceCard({
    required this.l10n,
    required this.accepted,
    required this.documentBody,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final bool accepted;
  final String documentBody;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OMDSSectionCard(
      title: l10n.kycTosStepTitle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            documentBody,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.small),
          Semantics(
            identifier: 'kyc_tos_accept',
            child: OmdsCheckboxTile(
              key: KycIdentityStep.tosCheckboxKey,
              title: l10n.kycTosSignAndSubmit,
              value: accepted,
              onChanged: onChanged,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/kyc/kyc_identity_step_preview_test.dart
// ===========================================================================
//
// `KycIdentityStep` is the whole of JM-040 `kyc-identity` on one scrollable
// screen: gov-ID front/back, the ratified id-type picker
// (national_id | passport | residency), the id-number field, the selfie, ToS
// acceptance and the single submit CTA. Every state below is the real widget
// over the real `KycWizardCubit`, parked on a seeded `KycWizardState` — the
// same seed-by-emit approach the DM-onboarding previews use, because the
// production cubit exposes no `seed:` constructor and a captured photo can
// only be put in place by emitting one.
//
// **Network-free by construction.** The cubit is built over
// `StubPhotoPickerService` (canned in-memory bytes, no `image_picker`, no
// permissions) and `FakeKycGateway` (canned in-memory responses, no `Dio`, no
// DI). Tapping a capture tile or the submit CTA in the canvas therefore runs
// the REAL cubit paths against fixtures; the guard in `jeebPreviewHost` is the
// net, not the plan.
//
// **What to look at.**
//  * The `kyc_scroll_hint` pill (JEBV4-295) is a `Row(mainAxisSize: min)`
//    holding a `Text` with no `Flexible`, no `maxLines` and no ellipsis. It is
//    the one thing on this screen that cannot scroll its way out of trouble,
//    and when it does run out of width it is CLIPPED rather than shortened —
//    silently cutting the cue that exists to stop the selfie section being
//    missed. Read it in the AR RTL and 200% renderings; the shape is pinned in
//    `test/previews/kyc/kyc_identity_step_preview_test.dart`.
//  * The submit CTA is gated on `hasSelfie && hasValidIdNumber` only (JEBV4-295)
//    — gov-ID front/back and the ToS tick do NOT disable it, so
//    `kycIdentityStepReadyToSubmit` and `kycIdentityStepSelfieMissing` differ by
//    a single field and yet only one of them can submit. Note what a jeeber
//    parked on the dead CTA is told: nothing. The inline id-number errors are
//    submit-scoped, and the gate is what stops a submit happening.
//  * The two inline rejection surfaces (`id_number`, `id_type`) are the only
//    error UI this widget owns; every other failure is a snackbar the HOST
//    screen raises, so it is invisible here by design.
//
// Two things you will NOT see in this canvas, both deliberate:
//  * The `kycWizardSubmitting` label on the CTA. This widget switches to it on
//    `step == submitting`, but `KycWizardScreen._buildBody` swaps the whole
//    body for `KycSubmittingView` at exactly that step — so the branch is
//    unreachable in the app and there is no honest state to preview it from.
//  * The as-you-type validation. It lives in `OmdsTextField`'s own state and
//    fires from `onChanged`, so a seeded preview can never show it — and the
//    `isRequired: true` this step passes is inert for the same reason (the
//    supplied `validator` bypasses the branch that reads it, and the field
//    renders no required marker of any kind).

/// The real body box this step gets on a 844 dp phone: 390 dp wide, and as tall
/// as `KycWizardScreen` leaves once the status bar, its AppBar, the `ID | Selfie`
/// progress header and the home indicator are taken out.
///
/// Sizing the canvas to the real body is deliberate. This step scrolls, so a
/// taller box would not "fix" anything vertically — but a WIDER one would hide
/// the horizontal ceilings (the scroll-hint pill, the radio-tile titles) that are
/// the only things here that cannot scroll their way out of trouble.
const Size _kycIdentityStepFormBox = Size(390, 670);

/// A 120 × 76 landscape PNG in the ISO/IEC 7810 ID-1 proportion the alignment
/// guide teaches — a navy header band, a portrait box and three text lines — so
/// a captured gov-ID tile reads as a card and `BoxFit.cover` has the aspect
/// ratio it was designed for.
const String _kycIdentityStepIdCardPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAHgAAABMCAIAAAAp7eQ+AAAAv0lEQVR42u3boQ2AMBRF0a7C'
    'JkzDDGg2wKDRGBIGYB4EqhMwAa75QDnJdXXH9KVJU9N2CighAA1aoEGDpgAatECDBk0BNGiB'
    'Bg1aEdDHmRUQaNCgBRo06LuDaV6LBxo0aNCgQYMG/Sx0P4zVBxo0aNCgQYM27+xo0KBBgwYN'
    'GjTowtDLtlcfaNCgQYMGbXWABg0aNGjQoEF763hDoEGDBv13aJchaNCgQYMGDRq0L8qgBRo0'
    'aIEGLdCgQQv0p7oAE7AkXoytNNIAAAAASUVORK5CYII=';

/// A 60 × 76 portrait PNG — a face and shoulders on a warm ground — so the
/// selfie tile is visibly a DIFFERENT capture from the two ID tiles rather than
/// the same grey block three times.
const String _kycIdentityStepSelfiePngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAADwAAABMCAIAAAC+vEPkAAAA8UlEQVR42u3XsRHCMBBE0auK'
    'WiiIGqiFaggJSWgAZpx4MJItaaU77D9z8d8XSvZ6Pv7uDDRo0KBBgw6Ovt+uqYuIznDldBvG'
    'FdJtvLjdbS7iRrd5iVvc5iiudh8GLRTXuY+Blosr3KBjojuJS92gQYMGDRq0M5q3B2h+LjHQ'
    'p/Plc0LxFOyIngZ6oIvclWiVex7sgp4PSNzLoBi9HGh0p4Ij0HXuTE2GzmyU0rekBOgtM6v6'
    '0shotOSa0C7iVffu0I7ivBu0O9pdnHGD9kUHEafcoB3RocQ/3aBB7x0dULx0gwYNGrQAHVb8'
    '5QYNGnQA9BuWuuxNxw9fDgAAAABJRU5ErkJggg==';

/// The two fixture payloads, decoded once.
final Uint8List _kycIdentityStepIdCardBytes =
    base64Decode(_kycIdentityStepIdCardPngBase64);
final Uint8List _kycIdentityStepSelfieBytes =
    base64Decode(_kycIdentityStepSelfiePngBase64);

PhotoAttachment _kycIdentityStepPhoto(String slot, Uint8List bytes) =>
    PhotoAttachment(
      id: 'kyc-preview-$slot',
      bytes: bytes,
      // A real capture arrives an order of magnitude larger and is compressed
      // on the way in; the ratio is what the tile's "compressed from" copy will
      // read off when it lands.
      originalSizeBytes: bytes.length * 8,
      source: PhotoSource.camera,
    );

/// The real cubit over inert collaborators, parked on `seed`.
///
/// Nothing here overrides a transition: `setIdType`, `setIdNumber`,
/// `setTosAccepted`, `captureIdFront/Back/Selfie` and `submit` all still run
/// their production implementations in the canvas. Emitting once from the
/// constructor is the whole implementation, and it is the only way to put a
/// captured [PhotoAttachment] or a submit-scoped field error in place — the
/// cubit exposes no seed seam and both of those are otherwise reachable only
/// through a camera round-trip or a server 400.
class _KycIdentityStepSeededCubit extends KycWizardCubit {
  _KycIdentityStepSeededCubit(KycWizardState seed)
      : super(
          // Canned bytes, so a capture tapped in the canvas fills with the ID
          // fixture instead of reaching for a camera that is not there.
          pickerService: StubPhotoPickerService(
            cameraPayload: _kycIdentityStepIdCardBytes,
          ),
          // Explicit rather than defaulted: the submit CTA is live in these
          // previews, and this is what makes tapping it in-memory.
          gateway: FakeKycGateway(),
        ) {
    emit(seed);
  }
}

/// Builds an identity-step state. Defaults describe a cold entry: nothing
/// captured, nothing typed, ToS unticked.
KycWizardState _kycIdentityStepSeed({
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
      idFront: govIdCaptured
          ? _kycIdentityStepPhoto('id-front', _kycIdentityStepIdCardBytes)
          : null,
      idBack: govIdCaptured
          ? _kycIdentityStepPhoto('id-back', _kycIdentityStepIdCardBytes)
          : null,
      selfie: selfieCaptured
          ? _kycIdentityStepPhoto('selfie', _kycIdentityStepSelfieBytes)
          : null,
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
Widget _kycIdentityStepHosted(String state, KycWizardState seed) {
  return BlocProvider<KycWizardCubit>(
    key: ValueKey<String>(state),
    create: (_) => _KycIdentityStepSeededCubit(seed),
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
@JeebPreview(
  group: 'kyc',
  name: 'Cold entry · nothing captured',
  size: _kycIdentityStepFormBox,
)
Widget kycIdentityStepFresh() =>
    _kycIdentityStepHosted('fresh', _kycIdentityStepSeed());

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
@JeebPreview(
  group: 'kyc',
  name: 'Selfie still missing · CTA dead',
  size: _kycIdentityStepFormBox,
)
Widget kycIdentityStepSelfieMissing() => _kycIdentityStepHosted(
      'selfie-missing',
      _kycIdentityStepSeed(
        idNumber: '112233445566',
        govIdCaptured: true,
        tosAccepted: true,
      ),
    );

/// Everything captured, a contract-valid 12-digit national ID, ToS accepted —
/// the only state in this section where `kyc_submit_cta` is live.
///
/// The scroll hint is gone (it is tied to `!hasSelfie`, not to scroll position),
/// so this is also the layout where the fold boundary disappears and the selfie
/// section runs straight on from the ID number field.
@JeebPreview(
  group: 'kyc',
  name: 'Ready to submit',
  size: _kycIdentityStepFormBox,
)
Widget kycIdentityStepReadyToSubmit() => _kycIdentityStepHosted(
      'ready',
      _kycIdentityStepSeed(
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
@JeebPreview(
  group: 'kyc',
  name: 'Server rejected the ID number',
  size: _kycIdentityStepFormBox,
)
Widget kycIdentityStepIdNumberRejected() => _kycIdentityStepHosted(
      'id-number-rejected',
      _kycIdentityStepSeed(
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
@JeebPreview(
  group: 'kyc',
  name: 'Residency rejected on id_type',
  size: _kycIdentityStepFormBox,
)
Widget kycIdentityStepResidencyRejected() => _kycIdentityStepHosted(
      'residency-rejected',
      _kycIdentityStepSeed(
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
@JeebPreview(
  group: 'kyc',
  name: 'Passport · 24-char number',
  size: _kycIdentityStepFormBox,
)
Widget kycIdentityStepPassportLongNumber() => _kycIdentityStepHosted(
      'passport-long',
      _kycIdentityStepSeed(
        idType: KycIdType.passport,
        idNumber: 'AB1234567890123456789012',
        govIdCaptured: true,
        selfieCaptured: true,
        tosAccepted: true,
      ),
    );
