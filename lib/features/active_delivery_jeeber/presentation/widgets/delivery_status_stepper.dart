import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_delivery_status.dart';

/// Horizontal stepper showing the 5-stage delivery status for the Jeeber.
///
/// Only the next valid tap is enabled (AC2 — in-order only).
class DeliveryStatusStepper extends StatelessWidget {
  const DeliveryStatusStepper({
    super.key,
    required this.currentStatus,
    required this.isTransitioning,
    required this.onAdvance,
  });

  final JeeberDeliveryStatus currentStatus;
  final bool isTransitioning;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // JM-051: during the delivering phase (InTransit / AtDoor) the journey to
    // Done is owned by the MarkDeliveredPanel's `mark_delivered_cta` (it needs
    // the proof photo + the done→rating chain), so the stepper suppresses its
    // own advance button there. Earlier stages (Ordered → Picked → InTransit)
    // keep the inline advance button.
    final showAdvance = !currentStatus.isTerminal &&
        currentStatus != JeeberDeliveryStatus.inTransit &&
        currentStatus != JeeberDeliveryStatus.atDoor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepsRow(currentStatus: currentStatus),
        const SizedBox(height: Spacing.small),
        if (showAdvance)
          _AdvanceButton(
            nextStatus: currentStatus.next!,
            isLoading: isTransitioning,
            onAdvance: onAdvance,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _StepsRow extends StatelessWidget {
  const _StepsRow({required this.currentStatus});

  final JeeberDeliveryStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    const statuses = JeeberDeliveryStatus.values;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: _semanticsLabel(currentStatus, l10n),
      child: Row(
        children: List.generate(statuses.length * 2 - 1, (i) {
          if (i.isOdd) return const Expanded(child: Divider(height: 2));
          final status = statuses[i ~/ 2];
          return _StepDot(
            status: status,
            isCurrent: status == currentStatus,
            isDone: status.index < currentStatus.index,
          );
        }),
      ),
    );
  }

  String _semanticsLabel(
    JeeberDeliveryStatus current,
    AppLocalizations l10n,
  ) {
    final next = current.next;
    final currentLabel = _statusLabel(current, l10n);
    if (next == null) {
      return l10n.activeDeliveryStepperCurrentDone(currentLabel);
    }
    return l10n.activeDeliveryStepperA11y(
      currentLabel,
      _statusLabel(next, l10n),
    );
  }

  String _statusLabel(JeeberDeliveryStatus s, AppLocalizations l10n) {
    switch (s) {
      case JeeberDeliveryStatus.ordered:
        return l10n.activeDeliveryStatusOrdered;
      case JeeberDeliveryStatus.picked:
        return l10n.activeDeliveryStatusPicked;
      case JeeberDeliveryStatus.inTransit:
        return l10n.activeDeliveryStatusInTransit;
      case JeeberDeliveryStatus.atDoor:
        return l10n.activeDeliveryStatusAtDoor;
      case JeeberDeliveryStatus.done:
        return l10n.activeDeliveryStatusDone;
    }
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.status,
    required this.isCurrent,
    required this.isDone,
  });

  final JeeberDeliveryStatus status;
  final bool isCurrent;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDone || isCurrent
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: isCurrent
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
      ),
      child: isDone
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }
}

class _AdvanceButton extends StatelessWidget {
  const _AdvanceButton({
    required this.nextStatus,
    required this.isLoading,
    required this.l10n,
    required this.onAdvance,
  });

  final JeeberDeliveryStatus nextStatus;
  final bool isLoading;
  final AppLocalizations l10n;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final label = _buttonLabel(nextStatus, l10n);
    // Screen-scoped to the active-delivery / mark-delivered screen (the only
    // host of this stepper), matching its `mark_delivered_*` id family. The
    // element is the status-advance action; the visible label rotates per stage
    // (Mark Picked / In Transit / At Door) so the id is derived from role, not
    // copy.
    return Semantics(
      identifier: 'mark_delivered_advance_cta',
      container: true,
      button: true,
      child: OmdsLoadingButton(
        text: label,
        isLoading: isLoading,
        onTap: onAdvance,
      ),
    );
  }

  String _buttonLabel(JeeberDeliveryStatus s, AppLocalizations l10n) {
    switch (s) {
      case JeeberDeliveryStatus.ordered:
        return l10n.activeDeliveryStatusOrdered;
      case JeeberDeliveryStatus.picked:
        return l10n.activeDeliveryMarkPicked;
      case JeeberDeliveryStatus.inTransit:
        return l10n.activeDeliveryMarkInTransit;
      case JeeberDeliveryStatus.atDoor:
        return l10n.activeDeliveryMarkAtDoor;
      case JeeberDeliveryStatus.done:
        return l10n.activeDeliveryMarkDone;
    }
  }
}
