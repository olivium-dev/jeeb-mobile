import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_delivery_status.dart';

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
    final showAdvance =
        !currentStatus.isTerminal &&
        currentStatus != JeeberDeliveryStatus.inTransit &&
        currentStatus != JeeberDeliveryStatus.atDoor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeliveryProgress(currentStatus: currentStatus, l10n: l10n),
        const SizedBox(height: Spacing.large),
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

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.currentStatus, required this.l10n});

  final JeeberDeliveryStatus currentStatus;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final currentIndex = jeeberDeliveryProgressStages.indexOf(currentStatus);
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            OmdsStepIndicator(
              currentStep: currentIndex + 1,
              totalSteps: jeeberDeliveryProgressStages.length,
              completedColor: colors.primary,
                activeColor: colors.tertiary,
              pendingColor: colors.surfaceContainerHighest,
              lineColor: colors.outlineVariant,
              stepSize: Sizes.threeXLarge,
              lineHeight: Sizes.threeXSmall,
              showNumbers: false,
              showCheckmark: false,
            ),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (
                    var index = 0;
                    index < jeeberDeliveryProgressStages.length;
                    index++
                  )
                    _StageIcon(
                      status: jeeberDeliveryProgressStages[index],
                      state: _stateAt(index, currentIndex),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.small),
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

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.status, required this.state});

  final JeeberDeliveryStatus status;
  final _DeliveryStageState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (state) {
      _DeliveryStageState.completed => colors.onPrimary,
      _DeliveryStageState.current => colors.onPrimaryContainer,
      _DeliveryStageState.upcoming => colors.onSurfaceVariant,
    };
    return SizedBox.square(
      key: ValueKey<String>(
        'active_delivery_stage_${status.name.toLowerCase()}_${state.name}',
      ),
      dimension: Sizes.threeXLarge,
      child: Icon(status.stepIcon, size: Sizes.large, color: color),
    );
  }
}

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

  TextStyle? _textStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return switch (state) {
      _DeliveryStageState.completed => theme.textTheme.labelSmall?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w600,
      ),
      _DeliveryStageState.current => theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      _DeliveryStageState.upcoming => theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w400,
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
  IconData get stepIcon {
    switch (this) {
      case JeeberDeliveryStatus.ordered:
        return Icons.receipt_long_outlined;
      case JeeberDeliveryStatus.picked:
        return Icons.inventory_2_outlined;
      case JeeberDeliveryStatus.inTransit:
        return Icons.local_shipping_outlined;
      case JeeberDeliveryStatus.atDoor:
        return Icons.home_outlined;
      case JeeberDeliveryStatus.done:
        return Icons.check_circle_outline;
      case JeeberDeliveryStatus.cancelled:
      case JeeberDeliveryStatus.expired:
      case JeeberDeliveryStatus.disputed:
        throw StateError('Terminal deliveries are not progress stages');
    }
  }

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
