import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../live_tracking_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The phone width the tracking screen is designed against.
const double _orderTrackingStepperPhoneWidth = 390;

/// The narrowest device the app still supports.
const double _orderTrackingStepperCompactPhoneWidth = 320;

/// Canvas box for a phone-width rendering: 4pt bar + 16pt gap + a 20pt icon
/// over one or two lines of label, plus the caption. Deliberately NOT tall
const Size _orderTrackingStepperBox = Size(390, 170);

/// Same, on the compact phone: the columns are 80pt wide there, so the labels
/// take a second line sooner and the block is taller.
const Size _orderTrackingStepperCompactBox = Size(320, 190);

/// Renders the stepper at [width] above a caption naming the state.
/// [width] is fixed rather than left to the canvas so the four step columns are
Widget _orderTrackingStepperHosted(
  String caption, {
  required int currentStep,
  bool atDoor = false,
  double width = _orderTrackingStepperPhoneWidth,
}) =>
    Center(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            OrderTrackingStepper(currentStep: currentStep, atDoor: atDoor),
            const SizedBox(height: Spacing.xSmall),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );

/// Cold start: the order exists and nothing else has happened yet.
/// Worth its own preview because of what the bar already says. The widget
@JeebPreview(group: 'live_tracking', name: 'Ordered', size: _orderTrackingStepperBox)
Widget orderTrackingStepperOrdered() =>
    _orderTrackingStepperHosted('Ordered · step 1 of 4', currentStep: 0);

/// The jeeber has the parcel. One step done, one active, two pending — the only
/// state where all three step icons are on screen at once, which makes it the
@JeebPreview(group: 'live_tracking', name: 'Picked', size: _orderTrackingStepperBox)
Widget orderTrackingStepperPicked() =>
    _orderTrackingStepperHosted('Picked · step 2 of 4', currentStep: 1);

/// En route. The steady state of a live delivery and the one a customer stares
/// at longest.
@JeebPreview(group: 'live_tracking', name: 'In transit', size: _orderTrackingStepperBox)
Widget orderTrackingStepperInTransit() =>
    _orderTrackingStepperHosted('In transit · step 3 of 4', currentStep: 2);

/// P6/A5, made visible: at the door the THIRD step relabels to "At Door" while
/// its Semantics identifier stays `tracking_step_in_transit`.
@JeebPreview(group: 'live_tracking', name: 'At Door', size: _orderTrackingStepperBox)
Widget orderTrackingStepperAtDoor() =>
    _orderTrackingStepperHosted('At Door · step 3 of 4, relabelled', currentStep: 2, atDoor: true);

/// Terminal: the parcel is delivered.
/// The state that reads wrong, and the reason this preview exists. `isDone` is
@JeebPreview(group: 'live_tracking', name: 'Delivered', size: _orderTrackingStepperBox)
Widget orderTrackingStepperDelivered() =>
    _orderTrackingStepperHosted('Delivered · step 4 of 4', currentStep: 3);

/// The layout ceiling: the terminal state on the narrowest supported device.
/// 320pt over four [Expanded] columns is 80pt per label — and the 200%-text
@JeebPreview(group: 'live_tracking', name: 'Delivered on 320pt', size: _orderTrackingStepperCompactBox)
Widget orderTrackingStepperCompactPhone() => _orderTrackingStepperHosted(
      'Delivered · step 4 of 4 on a 320pt phone',
      currentStep: 3,
      width: _orderTrackingStepperCompactPhoneWidth,
    );
