import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../live_tracking_l10n.dart';

class OrderTrackingStepper extends StatelessWidget {
  const OrderTrackingStepper({
    super.key,
    required this.currentStep,
    this.atDoor = false,
  });

  final int currentStep;

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
