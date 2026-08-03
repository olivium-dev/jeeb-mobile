import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_stepper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_delivery_status.dart';
import '../active_delivery_muted_ink.dart';

/// Horizontal stepper showing the successful delivery stages for the Jeeber.
///
/// redesign-2026-08: the OMDS node/connector indicator is replaced by
/// [JeebStepper.bars] — five `flex:1` h5 segments with the label row beneath
/// (`18-active-delivery-jeeber.html` `tpl 1047-1056`). The kit paints the bars;
/// this layer still owns every stage label, its frozen Semantics identifier and
/// its accessibility state copy.
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
    if (currentStatus.isUnsuccessfulTerminal) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    // JM-051: during the delivering phase (InTransit / AtDoor) the journey to
    // Done is owned by the MarkDeliveredPanel's `mark_delivered_cta` (it needs
    // the proof photo + the done→rating chain), so the stepper suppresses its
    // own advance button there. Earlier stages (Ordered → Picked → InTransit)
    // keep the inline advance button.
    final showAdvance =
        !currentStatus.isTerminal &&
        currentStatus != JeeberDeliveryStatus.inTransit &&
        currentStatus != JeeberDeliveryStatus.atDoor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeliveryProgress(currentStatus: currentStatus, l10n: l10n),
        // The gap is part of the advance block: at InTransit/AtDoor the bars
        // are the last thing in the widget and the drop-off card owns the air
        // beneath them (the board's `margin-top: 16`).
        if (showAdvance) ...[
          const SizedBox(height: Spacing.large),
          _AdvanceButton(
            nextStatus: currentStatus.next!,
            isLoading: isTransitioning,
            onAdvance: onAdvance,
            l10n: l10n,
          ),
        ],
      ],
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.currentStatus, required this.l10n});

  final JeeberDeliveryStatus currentStatus;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final currentIndex = jeeberDeliveryProgressStages.indexOf(currentStatus);
    return Column(
      children: [
        JeebStepper.bars(
          stepCount: jeeberDeliveryProgressStages.length,
          currentIndex: currentIndex,
          // The frozen per-stage ValueKeys are re-homed from the deleted stage
          // icons onto the bar segments, so `find.byKey` keeps resolving.
          segmentKeys: <Key>[
            for (
              var index = 0;
              index < jeeberDeliveryProgressStages.length;
              index++
            )
              ValueKey<String>(
                'active_delivery_stage_'
                '${jeeberDeliveryProgressStages[index].name.toLowerCase()}_'
                '${_stateAt(index, currentIndex).name}',
              ),
          ],
        ),
        // The board's `padding: 7px 24px 0` on the label row; 8 is the rung.
        const SizedBox(height: Spacing.xSmall),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (
              var index = 0;
              index < jeeberDeliveryProgressStages.length;
              index++
            )
              Expanded(
                child: _StageLabel(
                  status: jeeberDeliveryProgressStages[index],
                  state: _stateAt(index, currentIndex),
                  l10n: l10n,
                ),
              ),
          ],
        ),
      ],
    );
  }

  _DeliveryStageState _stateAt(int index, int currentIndex) {
    if (index < currentIndex) return _DeliveryStageState.completed;
    if (index == currentIndex) return _DeliveryStageState.current;
    return _DeliveryStageState.upcoming;
  }
}

enum _DeliveryStageState { completed, current, upcoming }

class _StageLabel extends StatelessWidget {
  const _StageLabel({
    required this.status,
    required this.state,
    required this.l10n,
  });

  final JeeberDeliveryStatus status;
  final _DeliveryStageState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = status.statusLabel(l10n);
    return Semantics(
      identifier: 'active_delivery_stage_${status.name.toLowerCase()}',
      container: true,
      label: '$label, ${_stateLabel(l10n)}',
      child: ExcludeSemantics(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: _textStyle(context),
        ),
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n) => switch (state) {
    _DeliveryStageState.completed => l10n.activeDeliveryStageCompletedState,
    _DeliveryStageState.current => l10n.activeDeliveryStageCurrentState,
    _DeliveryStageState.upcoming => l10n.activeDeliveryStageUpcomingState,
  };

  /// The board draws passed and upcoming labels in the SAME periwinkle
  /// (`tpl 1052-1056`); only the current one is accent + w800. Stage state is
  /// still fully announced — it lives in the Semantics label above, not in a
  /// colour a screen reader cannot see.
  TextStyle _textStyle(BuildContext context) {
    final mutedText = jeebMutedInk(context);
    return switch (state) {
      _DeliveryStageState.current => context.jeebText.label.copyWith(
        fontWeight: FontWeight.w800,
        color: context.jeebRoles.accent,
      ),
      _DeliveryStageState.completed ||
      _DeliveryStageState.upcoming => context.jeebText.label.copyWith(
        color: mutedText,
      ),
    };
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

  String _buttonLabel(JeeberDeliveryStatus status, AppLocalizations l10n) {
    switch (status) {
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
      case JeeberDeliveryStatus.cancelled:
      case JeeberDeliveryStatus.expired:
      case JeeberDeliveryStatus.disputed:
        throw StateError('Terminal deliveries cannot be advanced');
    }
  }
}

extension on JeeberDeliveryStatus {
  String statusLabel(AppLocalizations l10n) {
    switch (this) {
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
      case JeeberDeliveryStatus.cancelled:
      case JeeberDeliveryStatus.expired:
      case JeeberDeliveryStatus.disputed:
        throw StateError('Terminal deliveries are not progress stages');
    }
  }
}
