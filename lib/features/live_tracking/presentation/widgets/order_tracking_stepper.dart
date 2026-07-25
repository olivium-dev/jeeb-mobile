import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../live_tracking_l10n.dart';

/// JM-032 AC1: the canonical 4-step order-tracking stepper — Ordered → Picked →
/// In Transit → Delivered (D70) — the PRIMARY visual of the tracking screen.
///
/// Carries the signature id `tracking_stepper` (root) and one assertable
/// Semantics node per step (`tracking_step_ordered/_picked/_in_transit/
/// _delivered`, all coined in 63_W1_TEST_PLAN §2.12). The OMDS stepper progress
/// bar drives the visual fill; the per-step nodes carry the labels + a
/// done/active/pending state for QA + a11y.
class OrderTrackingStepper extends StatelessWidget {
  const OrderTrackingStepper({
    super.key,
    required this.currentStep,
    this.atDoor = false,
  });

  /// 0-based index of the CURRENT step (0=Ordered … 3=Delivered).
  final int currentStep;

  /// **Recorded product decision (P6/A5).** Keep the customer's 4-step
  /// blueprint stepper (Ordered → Picked → In Transit → Delivered, D70).
  /// At-Door does NOT get a fifth step. Instead, when the row is at the door
  /// the third step's *label* reads "At Door" — so the state is legible —
  /// while the semantics identifiers stay `tracking_step_in_transit` (no
  /// Maestro/E2E churn). This is an explicit decision, not a side effect of
  /// `trackingStepIndex4`'s collapse.
  final bool atDoor;

  static const _stepIds = <String>[
    'tracking_step_ordered',
    'tracking_step_picked',
    'tracking_step_in_transit',
    'tracking_step_delivered',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final labels = <String>[
      l10n.stepOrdered,
      l10n.stepPicked,
      // P6/A5: the third step reads "At Door" while the jeeber is at the door.
      atDoor ? l10n.stepAtDoor : l10n.stepInTransit,
      l10n.stepDelivered,
    ];
    final theme = Theme.of(context);

    return Semantics(
      identifier: 'tracking_stepper',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // OMDS progress bar (visual fill). `showStepNumbers: false` — the
          // labels are rendered as the assertable per-step nodes below so each
          // step id surfaces as its own Semantics node.
          OMDSStepperProgress(
            totalSteps: _stepIds.length,
            completedSteps: currentStep + 1,
            progressColor: theme.colorScheme.primary,
          ),
          const SizedBox(height: Spacing.medium),
          Row(
            children: [
              for (var i = 0; i < _stepIds.length; i++)
                Expanded(
                  child: _StepNode(
                    identifier: _stepIds[i],
                    label: labels[i],
                    isDone: i < currentStep,
                    isActive: i == currentStep,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.identifier,
    required this.label,
    required this.isDone,
    required this.isActive,
  });

  final String identifier;
  final String label;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = isDone || isActive;
    final color =
        reached ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      identifier: identifier,
      container: true,
      selected: isActive,
      value: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone
                ? Icons.check_circle
                : (isActive
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
            size: Sizes.large,
            color: color,
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: reached ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
