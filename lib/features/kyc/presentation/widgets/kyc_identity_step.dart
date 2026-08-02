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
