import 'package:flutter/material.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_stepper.dart';
import '../live_tracking_l10n.dart';

/// JM-032 AC1: the 4-step order-tracking stepper — Ordered → Picked → In
/// Transit → Delivered (D70) — and the owner of `tracking_stepper` + the four
/// frozen `tracking_step_*` identifiers.
///
/// MIDNIGHT R3 draws the kit's BAR form over a `space-between` label row, with
/// [JeebStepperDoneInk.accent] for R3's orange fill-through.
class OrderTrackingStepper extends StatelessWidget {
  const OrderTrackingStepper({
    super.key,
    required this.currentStep,
    this.atDoor = false,
  });

  /// 0-based index of the CURRENT step (0=Ordered … 3=Delivered).
  final int currentStep;

  /// **Recorded product decision (P6/A5).** At-Door does NOT get a fifth step:
  /// the third step's *label* reads "At Door" while its identifier stays
  /// `tracking_step_in_transit` (no Maestro/E2E churn).
  final bool atDoor;

  /// Gap between the bar row and the label row (board 8).
  static const double labelGap = 8;

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

    return Semantics(
      identifier: 'tracking_stepper',
      container: true,
      // Without this the four per-step nodes fold into the root and the frozen
      // `tracking_step_*` identifiers stop being addressable.
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          JeebStepper.bars(
            stepCount: labels.length,
            currentIndex: currentStep,
            doneInk: JeebStepperDoneInk.accent,
          ),
          const SizedBox(height: labelGap),
          _LabelRow(labels: labels, currentStep: currentStep),
        ],
      ),
    );
  }
}

/// The `space-between` label row — and the owner of the frozen per-step ids.
class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.labels, required this.currentStep});

  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final accent = context.jeebRoles.accent;
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final base = context.jeebText.caption;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < labels.length; index++)
          Flexible(
            child: Semantics(
              identifier: OrderTrackingStepper._stepIds[index],
              // `value` + `selected` are the frozen contract read by
              // `tracking_lifecycle_bodies_test.dart` d/e.
              value: labels[index],
              selected: index == currentStep,
              container: true,
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: index == currentStep
                    ? base.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      )
                    : base.copyWith(
                        color: semantics.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
