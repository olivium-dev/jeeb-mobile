import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../mixed_direction/presentation/mixed_direction_text.dart';
import '../../domain/delivery_tracking_info.dart';

class DeliveryTrackingPanel extends StatelessWidget {
  const DeliveryTrackingPanel({super.key, required this.info});

  static const Key rootKey = Key('tracking_status_panel');

  final DeliveryTrackingInfo info;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'tracking_status_panel',
      container: true,
      child: FractionallySizedBox(
        key: rootKey,
        widthFactor: _panelWidthFactor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TrackingStepper(stepIndex: info.trackingStepIndex),
            const SizedBox(height: Spacing.xLarge),
            _TrackingDistanceLine(distanceLabel: info.distanceLabel),
            const SizedBox(height: Spacing.xSmall),
            _TrackingEtaLine(etaMinutes: info.etaMinutes),
            if (info.deadline != null) ...[
              const SizedBox(height: Spacing.xSmall),
              _TrackingDeadlineLine(deadline: info.deadline!),
            ],
          ],
        ),
      ),
    );
  }
}

const double _panelWidthFactor = 0.78;

class _TrackingStepper extends StatelessWidget {
  const _TrackingStepper({required this.stepIndex});

  final int stepIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_progress_stepper',
      container: true,
      value: _stepLabels(l10n)[stepIndex],
      child: OMDSLabeledStepperProgress(
        totalSteps: 3,
        completedSteps: stepIndex + 1,
        progressColor: Theme.of(context).colorScheme.tertiary,
        stepLabels: _stepLabels(l10n),
      ),
    );
  }

  List<String> _stepLabels(AppLocalizations l10n) => [
        l10n.trackingStepOrdered,
        l10n.trackingStepPicked,
        l10n.trackingStepInTransit,
      ];
}

class _TrackingDistanceLine extends StatelessWidget {
  const _TrackingDistanceLine({required this.distanceLabel});

  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = distanceLabel;
    final text = label == null
        ? l10n.trackingDistanceUnknown
        : l10n.trackingDistanceAway(label);
    return _TrackingPanelText(
      identifier: 'tracking_distance_label',
      text: text,
    );
  }
}

class _TrackingEtaLine extends StatelessWidget {
  const _TrackingEtaLine({required this.etaMinutes});

  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = etaMinutes;
    final text = minutes == null
        ? l10n.trackingEtaUnknown
        : l10n.trackingEstimatedTime(minutes);
    return _TrackingPanelText(
      identifier: 'tracking_eta_label',
      text: text,
    );
  }
}

class _TrackingDeadlineLine extends StatelessWidget {
  const _TrackingDeadlineLine({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.jm(localeTag).format(deadline.toLocal());
    return _TrackingPanelText(
      identifier: 'tracking_deadline_label',
      text: l10n.trackingDeadlineLocked(time),
    );
  }
}

class _TrackingPanelText extends StatelessWidget {
  const _TrackingPanelText({required this.identifier, required this.text});

  final String identifier;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: identifier,
      liveRegion: true,
      child: MixedDirectionText(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
