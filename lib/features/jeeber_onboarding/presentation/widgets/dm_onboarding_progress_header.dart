import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
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
    final label = l10n.dmOnboardingStepProgressLabelNamed(
      current: state.currentStepNumber,
      total: DmOnboardingState.totalSteps,
      stepName: stepName(l10n, state.step),
    );
    final DmOnboardingStep? next = nextStep(state.step);
    return Semantics(
      identifier: 'dm_onboarding_progress',
      value: label,
      // R23's rule: segment N is filled while the user is ON step N. Passing
      // `completedSteps` drew "Step 3 of 3" over a 2/3 bar.
      child: _ProgressBarTrack(
        label: label,
        nextHint: next == null
            ? null
            : l10n.dmOnboardingNextStepHint(stepName: stepName(l10n, next)),
        filledSteps: state.isSubmitted
            ? DmOnboardingState.totalSteps
            : state.currentStepNumber,
      ),
    );
  }

  static String stepName(AppLocalizations l10n, DmOnboardingStep step) {
    switch (step) {
      case DmOnboardingStep.photo:
        return l10n.dmOnboardingPhotoStepTitle;
      case DmOnboardingStep.address:
        return l10n.dmOnboardingPersonalDetailsTitle;
      case DmOnboardingStep.serviceArea:
        return l10n.dmOnboardingServiceAreaTitle;
    }
  }

  static DmOnboardingStep? nextStep(DmOnboardingStep step) =>
      step.index + 1 < DmOnboardingStep.values.length
          ? DmOnboardingStep.values[step.index + 1]
          : null;
}

class _ProgressBarTrack extends StatelessWidget {
  const _ProgressBarTrack({
    required this.label,
    required this.nextHint,
    required this.filledSteps,
  });

  final String label;
  final String? nextHint;
  final int filledSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
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
            child: Row(
              children: [
                // Expanded (not Spacer) so the label wraps before it collides
                // with the hint under 200% text or a long Arabic step name.
                Expanded(
                  child: Text(
                    label,
                    style: context.jeebText.bodySmall.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (nextHint != null) const SizedBox(width: Spacing.small),
                if (nextHint != null)
                  Text(
                    nextHint!,
                    style: context.jeebText.bodySmall.copyWith(
                      color: semantic.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          // R23's meter exactly: the kit's default track is opaque navy and
          // disappears against the field, so the glass rung carries it.
          JeebMeter.segmented(
            steps: DmOnboardingState.totalSteps,
            filled: filledSteps,
            trackColor: semantic.glassFillPressed,
          ),
        ],
      ),
    );
  }
}
