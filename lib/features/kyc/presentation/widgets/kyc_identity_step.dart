import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/jeeb_commission.dart';
import '../../../../core/text/digit_normalization.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';
import '../../domain/kyc_submission.dart';
import 'kyc_capture_tile.dart';
import 'kyc_liveness_prompt_card.dart';

/// JM-040 `kyc-identity` — the single identity-capture screen of the KYC
/// wizard, after the Vehicle step removal (D20).
///
/// Collects, on one scrollable screen:
///   • gov-ID front  (`kyc_id_front_upload`)
///   • gov-ID back   (`kyc_id_back_upload`)
///   • ID type       (`kyc_id_type_picker` — E3/Q-042 ratified set
///     national_id | passport | residency)
///   • ID number     (`kyc_id_number_input` — E3: REQUIRED for every type;
///     12-digit shape for national_id only)
///   • selfie        (`kyc_selfie_upload`)
///   • ToS acceptance (inline checkbox over the contract document)
///   • a single submit CTA (`kyc_submit_cta`)
///
/// Tapping `kyc_submit_cta` signs the ToS + POSTs the submission via the
/// cubit; on a fresh success the host screen navigates to
/// `onboarding-funding` (JM-041). Gov-ID front/back completeness stays
/// back-office validated (JM-051 convention) and does NOT disable the CTA,
/// but the ID NUMBER and the SELFIE are both hard client gates: the CTA
/// disables until [KycSubmission.hasValidIdNumber] AND
/// [KycSubmission.hasSelfie] hold (JEBV4-295 — submitting without a captured
/// selfie always 400'd server-side on `selfie_with_liveness_url: null`).
///
/// redesign-2026-08 (screen 22): the three 140px capture squares, the two
/// headline/subtitle pairs and the ID alignment guide were replaced by three
/// compact outlined rows, so ID and selfie now read as one checklist. The
/// selfie row stays visually locked until both ID sides exist
/// ([KycWizardState.isSelfieUnlocked]) — a PRESENTATION lock only; the cubit
/// path stays open because neither Maestro nor the widget tests can drive the
/// OS camera. A `kyc_scroll_hint` affordance (JEBV4-295) still marks the fold
/// boundary and can drive the scroll itself.
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

  /// JEBV4-295: tappable "scroll for selfie" affordance shown while the
  /// selfie section is still below the fold and not yet captured.
  static const Key scrollHintKey = Key('kyc-scroll-hint');

  /// Card corner radius of the ID-type / ID-number group — matches the capture
  /// rows so the Step-1 block reads as one family (`22 tpl 1308`).
  static const double groupCardRadius = 18;

  static const int _nationalIdLength = 12;

  /// Sensible cap for passport/residency document numbers. No shape rule is
  /// enforced server-side for these variants, so the client deliberately does
  /// not over-validate — non-empty plus this length cap only.
  static const int _documentNumberMaxLength = 24;

  /// Localized inline validation mirroring exactly what the live contract
  /// enforces (E3/JEBV4-197): `id_number` is required for EVERY [KycIdType];
  /// the `^\d{12}$` shape applies to `national_id` only.
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
  /// Owned controller keeps the visible text in lock-step with the cubit's
  /// [KycSubmission.idNumber] — an uncontrolled field would keep showing the
  /// old digits after [KycWizardCubit.resubmit] wipes the draft (JEBV4-113
  /// review finding 4).
  late final TextEditingController _idNumberController;

  /// JEBV4-295: owns the identity screen's single scroll view so the
  /// "scroll for selfie" affordance (`kyc_scroll_hint`) can drive it.
  late final ScrollController _scrollController;

  /// Anchor the scroll hint aims at. The selfie row is no longer the last
  /// thing on the page (the review note and the terms sit below it), so
  /// scrolling to `maxScrollExtent` would push the row the hint is advertising
  /// almost off the top.
  final GlobalKey _selfieAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _idNumberController = TextEditingController(
      text: context.read<KycWizardCubit>().state.submission.idNumber ?? '',
    );
    _scrollController = ScrollController();
  }

  void _scrollToSelfie() {
    const duration = Duration(milliseconds: 400);
    final anchor = _selfieAnchorKey.currentContext;
    if (anchor != null) {
      Scrollable.ensureVisible(
        anchor,
        alignment: 0.12,
        duration: duration,
        curve: Curves.easeOut,
      );
      return;
    }
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: duration,
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

  /// The inline error forced onto the number field by a submit-time failure —
  /// the client-side gate or the BFF's field-scoped RFC-7807 400
  /// (`field: "id_number"`). Falls back to a neutral "not accepted" message
  /// when the server rejected a value the local rules considered fine.
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

  /// The signed contract must stay readable BEFORE the user signs it
  /// (`kyc_wizard_cubit.dart` signs on submit), so the terms line carries a
  /// text CTA onto this sheet.
  ///
  // TODO(redesign-24): render contractTemplate.documentUrl once the template
  // is fetched eagerly — today it loads lazily at submit
  // (kyc_wizard_cubit.dart:288-289), so the bundled body is all we can show.
  Future<void> _openTosSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Semantics(
        identifier: 'kyc_tos_document_sheet',
        container: true,
        explicitChildNodes: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.kycTosStepTitle, style: sheetContext.jeebText.h2),
                  const SizedBox(height: Spacing.small),
                  Text(
                    l10n.kycTosDocumentBody,
                    style: sheetContext.jeebText.body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        final submission = state.submission;
        final idType = submission.idType;
        final isNationalId = idType == KycIdType.nationalId;
        // Presentation-only: the cubit path stays open (see the class doc).
        final isSelfieLocked = !state.isSelfieUnlocked && !submission.hasSelfie;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: Spacing.xLarge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Spacing.large),
                    // ── Gov-ID rows ─────────────────────────────────────────
                    Semantics(
                      identifier: 'kyc_id_front_upload',
                      button: true,
                      container: true,
                      child: KycCaptureTile(
                        tileKey: KycIdentityStep.frontTileKey,
                        label: l10n.kycIdFrontLabel,
                        photo: submission.idFront,
                        hint: l10n.kycIdCaptureHint,
                        trailingLabel: submission.hasIdFront
                            ? l10n.kycIdRetake
                            : l10n.kycIdCaptureCta,
                        isProcessing:
                            state.capturing == KycCaptureSlot.idFront,
                        captureCtaSemantic: submission.hasIdFront
                            ? l10n.kycIdRetake
                            : l10n.kycIdCaptureCta,
                        onTap: cubit.captureIdFront,
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    Semantics(
                      identifier: 'kyc_id_back_upload',
                      button: true,
                      container: true,
                      child: KycCaptureTile(
                        tileKey: KycIdentityStep.backTileKey,
                        label: l10n.kycIdBackLabel,
                        photo: submission.idBack,
                        hint: l10n.kycIdCaptureHint,
                        trailingLabel: submission.hasIdBack
                            ? l10n.kycIdRetake
                            : l10n.kycIdCaptureCta,
                        isProcessing: state.capturing == KycCaptureSlot.idBack,
                        captureCtaSemantic: submission.hasIdBack
                            ? l10n.kycIdRetake
                            : l10n.kycIdCaptureCta,
                        onTap: cubit.captureIdBack,
                      ),
                    ),
                    const SizedBox(height: Spacing.large),
                    // ── ID type + number (E3/Q-042: national_id | passport |
                    //    residency — exactly the ratified pilot set). The
                    //    board drew neither control; both are CONTRACT
                    //    REQUIRED (`id_number` 400s when absent), so they stay
                    //    and are grouped into one card inside "Step 1". ─────
                    JeebSectionLabel(l10n.kycIdTypeLabel),
                    const SizedBox(height: Spacing.xSmall),
                    JeebOutlinedCard(
                      radius: KycIdentityStep.groupCardRadius,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                              style: context.jeebText.caption.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: Spacing.small),
                          // ── ID number (E3/JEBV4-197: REQUIRED for every
                          //    type; ^\d{12}$ for national_id only) ─────────
                          Semantics(
                            identifier: 'kyc_id_number_input',
                            textField: true,
                            child: OmdsTextField(
                              key: KycIdentityStep.idNumberFieldKey,
                              controller: _idNumberController,
                              labelText: _idNumberLabel(l10n, idType),
                              hintText: _idNumberHint(l10n, idType),
                              isRequired: true,
                              errorText:
                                  _submitScopedIdNumberError(l10n, state),
                              keyboardType: isNationalId
                                  ? TextInputType.number
                                  : TextInputType.text,
                              maxLength: isNationalId
                                  ? KycIdentityStep._nationalIdLength
                                  : KycIdentityStep._documentNumberMaxLength,
                              inputFormatters: [
                                // Map Eastern Arabic-Indic digits to ASCII
                                // BEFORE any digit filter, so Arabic-keyboard
                                // keystrokes are normalized, not swallowed.
                                const ArabicIndicDigitsFormatter(),
                                if (isNationalId)
                                  FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: cubit.setIdNumber,
                              validator: (value) =>
                                  KycIdentityStep._idNumberError(
                                l10n,
                                idType,
                                value,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.large),

                    // JEBV4-295: the selfie row sits below the fold on this
                    // single-scroll screen — an automated driver and a
                    // first-time user can both miss it. Show a tappable
                    // "scroll for selfie" cue right at this fold boundary
                    // until the selfie is captured; tapping it animates the
                    // scroll the rest of the way for the user.
                    if (!submission.hasSelfie) ...[
                      Center(
                        child: _ScrollForSelfieHint(
                          label: l10n.kycScrollForSelfieHint,
                          onTap: _scrollToSelfie,
                        ),
                      ),
                      const SizedBox(height: Spacing.large),
                    ],

                    // ── Selfie row (step 2) ─────────────────────────────────
                    Semantics(
                      key: _selfieAnchorKey,
                      identifier: 'kyc_selfie_upload',
                      button: true,
                      container: true,
                      child: KycCaptureTile(
                        tileKey: KycIdentityStep.selfieTileKey,
                        label: l10n.kycSelfieStepTitle,
                        photo: submission.selfie,
                        isSelfie: true,
                        isLocked: isSelfieLocked,
                        hint: isSelfieLocked ? l10n.kycSelfieLockedHint : null,
                        trailingLabel: submission.hasSelfie
                            ? l10n.kycSelfieRetake
                            : (isSelfieLocked
                                ? null
                                : l10n.kycSelfieCaptureCta),
                        isProcessing: state.capturing == KycCaptureSlot.selfie,
                        captureCtaSemantic: submission.hasSelfie
                            ? l10n.kycSelfieRetake
                            : l10n.kycSelfieCaptureCta,
                        onTap: cubit.captureSelfie,
                      ),
                    ),
                    // Coaching arrives at the moment step 2 actually opens.
                    if (state.isSelfieUnlocked && !submission.hasSelfie) ...[
                      const SizedBox(height: Spacing.small),
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
                    ],
                    const SizedBox(height: Spacing.medium),
                    // C4 hold: the board also promised "encrypted at rest".
                    // The app can verify the read-audience claim, not storage
                    // encryption — an unverified security promise inside a
                    // signed-terms flow is a legal risk, so it is omitted
                    // until legal ratifies it.
                    JeebInfoNote.muted(
                      identifier: 'kyc_review_note',
                      icon: Icons.access_time_filled,
                      title: l10n.kycReviewTimeTitle,
                      text: l10n.kycReviewPrivacyNote,
                    ),
                    const SizedBox(height: Spacing.medium),
                    _TosAgreementRow(
                      accepted: state.tosAccepted,
                      onChanged: (v) => cubit.setTosAccepted(v ?? false),
                      onReadTerms: () => _openTosSheet(context),
                    ),
                    const SizedBox(height: Spacing.medium),
                  ],
                ),
              ),
            ),
            JeebCtaFooter.single(
              child: Semantics(
                identifier: 'kyc_submit_cta',
                button: true,
                container: true,
                child: JeebCtaButton.primary(
                  key: KycIdentityStep.submitButtonKey,
                  label: state.step == KycWizardStep.submitting
                      ? l10n.kycWizardSubmitting
                      : l10n.kycWizardSubmit,
                  // JEBV4-295: the selfie IS now a hard client gate
                  // alongside the ID number — the previous "photo
                  // completeness stays back-office validated" convention
                  // (JM-051) let the user fire an incomplete submit whenever
                  // the ID number alone was valid, which always 400'd
                  // server-side (`selfie_with_liveness_url: null`). Gov-ID
                  // front/back completeness is unchanged (still back-office
                  // validated, does NOT disable the CTA) — only the selfie
                  // and the ID number block the tap so it can never reach
                  // the network (the cubit guard is the backstop).
                  isEnabled: state.step != KycWizardStep.submitting &&
                      submission.hasSelfie &&
                      submission.hasValidIdNumber,
                  onTap: () => cubit.submit(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// JEBV4-295: a tappable pill cueing that more content (the selfie row) sits
/// below the fold, and driving the scroll there on tap. Purely a visual
/// affordance — it never blocks or replaces manual scrolling.
///
/// R5: it is deliberately NOT orange. `primaryContainer` became the brand
/// orange `#FFDBD1` in the redesign, and orange marks decay/urgency on this
/// product, never navigation.
class _ScrollForSelfieHint extends StatelessWidget {
  const _ScrollForSelfieHint({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'kyc_scroll_hint',
      button: true,
      label: label,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.pill,
        child: InkWell(
          key: KycIdentityStep.scrollHintKey,
          borderRadius: OmdsBorderRadius.pill,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.xSmall,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.jeebText.bodySmall.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Spacing.xSmall),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The plain-words terms line the user signs on submit, plus the way into the
/// full document. The fee ALWAYS interpolates [kJeebCommissionPercent] — a
/// literal `10` here or in the ARB is the second-copy class
/// `jeeb_commission_test.dart` exists to prevent, and the framing stays
/// "fee", never "commission".
class _TosAgreementRow extends StatelessWidget {
  const _TosAgreementRow({
    required this.accepted,
    required this.onChanged,
    required this.onReadTerms,
  });

  final bool accepted;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onReadTerms;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          identifier: 'kyc_tos_accept',
          child: OmdsCheckboxTile(
            key: KycIdentityStep.tosCheckboxKey,
            title: l10n.kycTosAgreeLine(percent: kJeebCommissionPercent),
            value: accepted,
            onChanged: onChanged,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        JeebCtaButton.text(
          label: l10n.kycTosReadFullCta,
          identifier: 'kyc_tos_read_cta',
          expand: false,
          contentPadding: EdgeInsetsDirectional.zero,
          onTap: onReadTerms,
        ),
      ],
    );
  }
}
