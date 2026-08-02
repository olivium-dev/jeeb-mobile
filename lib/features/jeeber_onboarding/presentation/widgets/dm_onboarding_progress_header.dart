import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

class DmOnboardingProgressHeader extends StatelessWidget {
  const DmOnboardingProgressHeader({super.key});

  static const Key rootKey = Key('dm-onboarding-progress');

  static const double barHeight = Spacing.small;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DmOnboardingCubit, DmOnboardingState>(
      buildWhen: _stepChanged,
      builder: (context, state) => _ProgressBar(state: state),
    );
  }

  bool _stepChanged(DmOnboardingState prev, DmOnboardingState curr) =>
      prev.step != curr.step || prev.isSubmitted != curr.isSubmitted;
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.state});

  final DmOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'dm_onboarding_progress',
      value: l10n.dmOnboardingStepProgressLabel(
        current: state.currentStepNumber,
        total: DmOnboardingState.totalSteps,
      ),
      child: _ProgressBarTrack(completedSteps: state.completedSteps),
    );
  }
}

class _ProgressBarTrack extends StatelessWidget {
  const _ProgressBarTrack({required this.completedSteps});

  final int completedSteps;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: DmOnboardingProgressHeader.rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.small,
        Spacing.xLarge,
        Spacing.xSmall,
      ),
      child: OMDSStepperProgress(
        totalSteps: DmOnboardingState.totalSteps,
        completedSteps: completedSteps,
        height: DmOnboardingProgressHeader.barHeight,
        borderRadius: DmOnboardingProgressHeader.barHeight / 2,
      ),
    );
  }
}
