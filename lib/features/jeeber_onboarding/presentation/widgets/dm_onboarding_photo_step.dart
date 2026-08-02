import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';
import 'dm_onboarding_photo_upload_card.dart';
import 'dm_onboarding_step_header.dart';
import 'dm_onboarding_step_layout.dart';

class DmOnboardingPhotoStep extends StatelessWidget {
  const DmOnboardingPhotoStep({super.key});

  static const Key rootKey = Key('dm-onboarding-photo-step');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: (prev, curr) => prev.hasPhoto != curr.hasPhoto,
      builder: (context, state) => DmOnboardingStepLayout(
        key: rootKey,
        continueIdentifier: 'dm_onboarding_continue',
        enabled: state.hasPhoto,
        content: _PhotoStepContent(l10n: l10n),
      ),
    );
  }
}

class _PhotoStepContent extends StatelessWidget {
  const _PhotoStepContent({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DmOnboardingStepHeader(
          title: l10n.dmOnboardingPhotoUploadTitle,
          subtitle: l10n.dmOnboardingPhotoUploadSubtitle,
        ),
        const SizedBox(height: Spacing.xLarge),
        const DmOnboardingPhotoUploadCard(),
      ],
    );
  }
}
