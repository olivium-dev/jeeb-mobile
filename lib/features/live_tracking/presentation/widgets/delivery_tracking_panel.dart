import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../mixed_direction/presentation/mixed_direction_text.dart';
import '../../domain/delivery_tracking_info.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, not shipped. Previews are tree-shaken out of release builds.

const Size deliveryTrackingPanelBox = Size(390, 280);

/// A taller box for the states that mount the fourth (deadline) line, which
/// need 404pt at 200% text.
const Size deliveryTrackingPanelTallBox = Size(390, 420);

final DateTime deliveryTrackingPanelLockedDeadline = DateTime(2026, 7, 12, 15, 45);

Widget _deliveryTrackingPanelHosted({
  TrackingStage stage = TrackingStage.inTransit,
  String? distanceLabel,
  int? etaMinutes,
  DateTime? deadline,
}) =>
    DeliveryTrackingPanel(
      info: DeliveryTrackingInfo(
        deliveryId: 'd-1',
        currentStage: stage,
        stageTimestamps: const <TrackingStage, DateTime>{},
        distanceLabel: distanceLabel,
        etaMinutes: etaMinutes,
        deadline: deadline,
      ),
    );

@JeebPreview(group: 'live_tracking', name: 'In transit · live fix', size: deliveryTrackingPanelBox)
Widget deliveryTrackingPanelInTransit() => _deliveryTrackingPanelHosted(
      distanceLabel: '3 km',
      etaMinutes: 20,
    );

@JeebPreview(group: 'live_tracking', name: 'Ordered · awaiting first fix', size: deliveryTrackingPanelBox)
Widget deliveryTrackingPanelAwaitingFix() => _deliveryTrackingPanelHosted(
      stage: TrackingStage.ordered,
    );

@JeebPreview(group: 'live_tracking', name: 'Locked deadline (Q-061/D18)', size: deliveryTrackingPanelTallBox)
Widget deliveryTrackingPanelDeadlineLine() => _deliveryTrackingPanelHosted(
      distanceLabel: '2 km',
      etaMinutes: 12,
      deadline: deliveryTrackingPanelLockedDeadline,
    );

@JeebPreview(group: 'live_tracking', name: 'At the door · 0.0 km', size: deliveryTrackingPanelBox)
Widget deliveryTrackingPanelAtDoor() => _deliveryTrackingPanelHosted(
      stage: TrackingStage.atDoor,
      distanceLabel: '0.0 km',
      etaMinutes: 0,
    );

@JeebPreview(group: 'live_tracking', name: 'Long haul · widest lines', size: deliveryTrackingPanelTallBox)
Widget deliveryTrackingPanelLongHaul() => _deliveryTrackingPanelHosted(
      distanceLabel: '128.6 km',
      etaMinutes: 195,
      deadline: deliveryTrackingPanelLockedDeadline,
    );
