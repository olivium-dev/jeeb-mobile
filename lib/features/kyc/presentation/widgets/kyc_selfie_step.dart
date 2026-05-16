import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';
import 'kyc_capture_tile.dart';
import 'kyc_liveness_prompt_card.dart';

/// Step 2: selfie capture with an inline liveness prompt. The prompt is a
/// hint, not an automated check — the actual liveness verification happens
/// server-side; the UI's only job is to coach the user through the two
/// required motions (blink + smile) the reviewer expects to see captured.
class KycSelfieStep extends StatelessWidget {
  const KycSelfieStep({super.key});

  static const Key selfieTileKey = Key('kyc-selfie-tile');
  static const Key livenessPromptKey = Key('kyc-selfie-liveness-prompt');
  static const Key nextButtonKey = Key('kyc-selfie-next');

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
                      KycCaptureTile(
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.medium),
              OmdsPrimaryButton(
                key: nextButtonKey,
                text: l10n.kycWizardNext,
                isEnabled: state.canAdvanceFromSelfie,
                onTap: state.canAdvanceFromSelfie
                    ? cubit.goToVehicle
                    : () {},
              ),
            ],
          ),
        );
      },
    );
  }
}
