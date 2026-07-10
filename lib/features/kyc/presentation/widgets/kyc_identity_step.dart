import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';
import '../../domain/kyc_submission.dart';
import 'kyc_capture_tile.dart';
import 'kyc_id_alignment_guide.dart';
import 'kyc_liveness_prompt_card.dart';

/// JM-040 `kyc-identity` — the single identity-capture screen of the KYC
/// wizard, after the Vehicle step removal (D20).
///
/// Collects, on one scrollable screen:
///   • gov-ID front  (`kyc_id_front_upload`)
///   • gov-ID back   (`kyc_id_back_upload`)
///   • selfie        (`kyc_selfie_upload`)
///   • ToS acceptance (inline checkbox over the contract document)
///   • a single submit CTA (`kyc_submit_cta`)
///
/// Tapping `kyc_submit_cta` signs the ToS + POSTs the submission via the cubit;
/// on a fresh success the host screen navigates to `onboarding-funding`
/// (JM-041). The submit CTA is always enabled — the back-office validates KYC
/// completeness (mirrors the JM-051 mark-delivered convention) — but the screen
/// still surfaces a "complete every step" hint until all captures + the ToS
/// tick are present.
class KycIdentityStep extends StatelessWidget {
  const KycIdentityStep({super.key});

  static const Key frontTileKey = Key('kyc-id-front-tile');
  static const Key backTileKey = Key('kyc-id-back-tile');
  static const Key idNumberFieldKey = Key('kyc-id-number-field');
  static const Key selfieTileKey = Key('kyc-selfie-tile');
  static const Key livenessPromptKey = Key('kyc-selfie-liveness-prompt');
  static const Key tosCheckboxKey = Key('kyc-tos-accept-checkbox');
  static const Key submitButtonKey = Key('kyc-submit-cta');

  static const int _nationalIdLength = 12;

  /// Localized inline validation for the national-ID number, mirroring the live
  /// BFF rule (`^\d{12}$` for `national_id`) so the user sees the requirement
  /// rather than a round-trip 400 (E3/JEBV4-197).
  static String? _idNumberError(AppLocalizations l10n, String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return l10n.kycIdNumberRequired;
    if (!KycSubmission.nationalIdPattern.hasMatch(trimmed)) {
      return l10n.kycIdNumberInvalid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<KycWizardCubit, KycWizardState>(
      builder: (context, state) {
        final cubit = context.read<KycWizardCubit>();
        return Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Gov-ID section ──────────────────────────────────
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
                          tileKey: frontTileKey,
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
                          tileKey: backTileKey,
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
                      // ── National-ID number (E3/JEBV4-197: REQUIRED id_number)
                      Semantics(
                        identifier: 'kyc_id_number_input',
                        textField: true,
                        child: OmdsTextField(
                          key: idNumberFieldKey,
                          labelText: l10n.kycIdNumberLabel,
                          hintText: l10n.kycIdNumberHint,
                          isRequired: true,
                          keyboardType: TextInputType.number,
                          maxLength: _nationalIdLength,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: cubit.setIdNumber,
                          validator: (value) => _idNumberError(l10n, value),
                        ),
                      ),
                      const SizedBox(height: Spacing.xLarge),

                      // ── Selfie section ──────────────────────────────────
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
                        cardKey: livenessPromptKey,
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
                          tileKey: selfieTileKey,
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

                      // ── ToS acceptance ──────────────────────────────────
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
                  key: submitButtonKey,
                  text: state.step == KycWizardStep.submitting
                      ? l10n.kycWizardSubmitting
                      : l10n.kycWizardSubmit,
                  isEnabled: state.step != KycWizardStep.submitting,
                  // The submit CTA stays enabled regardless of capture state:
                  // the back-office validates completeness (JM-051 convention).
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
