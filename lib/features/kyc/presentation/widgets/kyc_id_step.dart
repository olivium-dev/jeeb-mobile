import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';
import 'kyc_capture_tile.dart';
import 'kyc_id_alignment_guide.dart';

/// Step 1: capture both sides of the national ID. Advances to the selfie
/// step once both photos are present.
class KycIdStep extends StatelessWidget {
  const KycIdStep({super.key});

  static const Key frontTileKey = Key('kyc-id-front-tile');
  static const Key backTileKey = Key('kyc-id-back-tile');
  static const Key nextButtonKey = Key('kyc-id-next');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
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
                        l10n.kycIdStepTitle,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.kycIdStepSubtitle,
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: Spacing.medium),
                      KycIdAlignmentGuide(
                        title: l10n.kycIdAlignmentGuideTitle,
                        caption: l10n.kycIdAlignmentGuideCaption,
                      ),
                      const SizedBox(height: Spacing.large),
                      KycCaptureTile(
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
                      const SizedBox(height: Spacing.medium),
                      KycCaptureTile(
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.medium),
              OmdsPrimaryButton(
                key: nextButtonKey,
                text: l10n.kycWizardNext,
                isEnabled: state.canAdvanceFromId,
                onTap:
                    state.canAdvanceFromId ? cubit.goToSelfie : () {},
              ),
            ],
          ),
        );
      },
    );
  }
}
