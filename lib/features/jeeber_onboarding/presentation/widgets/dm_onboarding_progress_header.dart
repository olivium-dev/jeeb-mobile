import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_meter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/dm_onboarding_cubit.dart';
import '../../application/dm_onboarding_state.dart';

/// The wizard progress band pinned under the top bar across all onboarding
/// steps: a "Step n of N" caption over the kit's segmented meter (one `flex:1`
/// cell per step, h6, gap 8 — the board's screen-22 KYC progress, `tpl
/// 1301-1306`).
///
/// The caption is [ExcludeSemantics]'d because the surrounding
/// `dm_onboarding_progress` node already carries the same localized string as
/// its `value` — rendering it visibly must not make screen readers say it
/// twice.
class DmOnboardingProgressHeader extends StatelessWidget {
  const DmOnboardingProgressHeader({super.key});

  static const Key rootKey = Key('dm-onboarding-progress');

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
    final label = l10n.dmOnboardingStepProgressLabel(
      current: state.currentStepNumber,
      total: DmOnboardingState.totalSteps,
    );
    return Semantics(
      identifier: 'dm_onboarding_progress',
      value: label,
      child: _ProgressBarTrack(
        label: label,
        completedSteps: state.completedSteps,
      ),
    );
  }
}

class _ProgressBarTrack extends StatelessWidget {
  const _ProgressBarTrack({required this.label, required this.completedSteps});

  final String label;
  final int completedSteps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      key: DmOnboardingProgressHeader.rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.large,
        Spacing.xLarge,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(
              label,
              style: context.jeebText.bodySmall.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          JeebMeter.segmented(
            steps: DmOnboardingState.totalSteps,
            filled: completedSteps,
          ),
        ],
      ),
    );
  }
}
