import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';
import '../../domain/delivery_stage.dart';

/// Vertical milestone list with stepper. Each row shows stage label, reached-at
/// timestamp, and status dot. Active stage pulses via AnimationController.
class DeliveryStageIndicator extends StatelessWidget {
  const DeliveryStageIndicator({
    super.key,
    required this.snapshot,
  });

  static const Key listKey = Key('delivery-status-stage-list');

  final DeliverySnapshot snapshot;

  Key _rowKeyFor(DeliveryStage stage) =>
      Key('delivery-stage-row-${stage.name}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cancelled = snapshot.lifecycle == DeliveryLifecycle.cancelled;
    return Column(
      key: listKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OMDSLabeledStepperProgress(
          totalSteps: kDeliveryStageCount,
          completedSteps: cancelled
              ? 0
              : (snapshot.stage.order + 1).clamp(0, kDeliveryStageCount),
          showStepNumbers: false,
          stepLabels: [
            l10n.deliveryStageMatched,
            l10n.deliveryStagePickedUp,
            l10n.deliveryStageInTransit,
            l10n.deliveryStageDelivered,
          ],
        ),
        const SizedBox(height: Spacing.large),
        for (final stage in DeliveryStage.values)
          Padding(
            key: _rowKeyFor(stage),
            padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
            child: _StageRow(
              stage: stage,
              snapshot: snapshot,
            ),
          ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.snapshot});

  final DeliveryStage stage;
  final DeliverySnapshot snapshot;

  bool get _isReached =>
      snapshot.lifecycle != DeliveryLifecycle.cancelled &&
      stage.isAtOrBefore(snapshot.stage);

  bool get _isActive =>
      snapshot.lifecycle == DeliveryLifecycle.active && stage == snapshot.stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timestamp = snapshot.stageTimestamps[stage];
    final reachedColor =
        _isReached ? colorScheme.primary : colorScheme.onSurfaceVariant;
    final caption = timestamp != null
        ? l10n.deliveryStageReachedAt(_formatTime(context, timestamp))
        : l10n.deliveryStageTimestampPending;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StageDot(isReached: _isReached, isActive: _isActive),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _labelFor(l10n, stage),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: reachedColor,
                  fontWeight: _isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: Sizes.threeXSmall),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _labelFor(AppLocalizations l10n, DeliveryStage stage) {
    switch (stage) {
      case DeliveryStage.matched:
        return l10n.deliveryStageMatched;
      case DeliveryStage.pickedUp:
        return l10n.deliveryStagePickedUp;
      case DeliveryStage.inTransit:
        return l10n.deliveryStageInTransit;
      case DeliveryStage.delivered:
        return l10n.deliveryStageDelivered;
    }
  }

  /// 24-hour format; Arabic locale falls back to Latin digits via intl default.
  String _formatTime(BuildContext context, DateTime when) {
    final tag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Hm(tag).format(when.toLocal());
  }
}

class _StageDot extends StatefulWidget {
  const _StageDot({required this.isReached, required this.isActive});

  final bool isReached;
  final bool isActive;

  @override
  State<_StageDot> createState() => _StageDotState();
}

class _StageDotState extends State<_StageDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Key activeKey = Key('delivery-status-active-dot');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isActive) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _StageDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filled = widget.isReached;
    final color = filled ? colorScheme.primary : colorScheme.outlineVariant;
    return SizedBox(
      width: Sizes.xLarge,
      height: Sizes.xLarge,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pulse = widget.isActive
                ? 1.0 + (_controller.value * 0.6)
                : 1.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isActive)
                  Container(
                    key: _StageDotState.activeKey,
                    width: Sizes.medium * pulse,
                    height: Sizes.medium * pulse,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primary
                          .withValues(alpha: 0.18 * (1 - _controller.value)),
                    ),
                  ),
                Container(
                  width: Sizes.small,
                  height: Sizes.small,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: filled
                        ? null
                        : Border.all(color: color, width: 1.5),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
