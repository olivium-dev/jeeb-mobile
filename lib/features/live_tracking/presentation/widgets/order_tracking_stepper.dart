import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_stepper.dart';
import '../live_tracking_l10n.dart';

/// JM-032 AC1: the canonical 4-step order-tracking stepper — Ordered → Picked →
/// In Transit → Delivered (D70) — the PRIMARY visual of the tracking screen.
///
/// Carries the signature id `tracking_stepper` (root) and one assertable
/// Semantics node per step (`tracking_step_ordered/_picked/_in_transit/
/// _delivered`, all coined in 63_W1_TEST_PLAN §2.12).
///
/// redesign-2026-08 §C task 9: the node/connector/label visuals belong to
/// [JeebStepper] now (Ø26 discs, 3px connectors, the orange glowing active
/// node). This widget is the thin wrapper that supplies the labels, the frozen
/// identifiers and the screen's own root Semantics node — deliberately NOT
/// `JeebStepper.identifier`, so `tracking_stepper` keeps living here where the
/// P6/A5 relabel is decided.
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

  /// The terminal step index — the pulse rests once the row is delivered.
  static const int _deliveredIndex = 3;

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

    return Semantics(
      identifier: 'tracking_stepper',
      container: true,
      // Without this the four per-step nodes fold into the root and the frozen
      // `tracking_step_*` identifiers stop being addressable.
      explicitChildNodes: true,
      child: JeebStepper(
        currentIndex: currentStep,
        labels: labels,
        stepIdentifiers: _stepIds,
        // Nothing is still in motion once the delivery is done, so the glow
        // rests there. The kit's pulse is bounded (3 breaths) and skipped under
        // reduce-motion, so `pumpAndSettle` stays safe either way.
        pulseActive: currentStep < _deliveredIndex,
      ),
    );
  }
}
