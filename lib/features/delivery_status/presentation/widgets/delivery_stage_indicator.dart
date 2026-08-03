import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_stepper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_snapshot.dart';
import '../../domain/delivery_stage.dart';

/// The 4-node stepper plus the milestone list carrying each stage's
/// reached-at timestamp.
///
/// redesign-2026-08: the stepper is the kit's node form now — Ø26 discs, the
/// orange active node, the 3px connectors — the same primary visual 12 puts at
/// the top of its tracking surface. The milestone rows underneath moved onto
/// [JeebListRow] inside one grouped [JeebOutlinedCard], which retired the
/// bespoke pulsing dot and its repeating [AnimationController]: the kit's pulse
/// is bounded (3 breaths) and reduce-motion gated, and the board asks for one
/// motion per screen rather than a decorative loop per row.
class DeliveryStageIndicator extends StatelessWidget {
  const DeliveryStageIndicator({
    super.key,
    required this.snapshot,
  });

  static const Key listKey = Key('delivery-status-stage-list');

  /// Coined here (`<screen>_<element>`). This screen owns no frozen
  /// `tracking_step_*` contract — those belong to the live-tracking surface,
  /// and two emitters of one identifier is a defect.
  static const List<String> _stepIdentifiers = <String>[
    'delivery_status_step_matched',
    'delivery_status_step_picked_up',
    'delivery_status_step_in_transit',
    'delivery_status_step_delivered',
  ];

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
        JeebStepper(
          // A cancelled row has no milestone in motion: -1 leaves every node
          // pending, which is exactly what `completedSteps: 0` used to draw.
          currentIndex: cancelled ? -1 : snapshot.stage.order,
          labels: [
            l10n.deliveryStageMatched,
            l10n.deliveryStagePickedUp,
            l10n.deliveryStageInTransit,
            l10n.deliveryStageDelivered,
          ],
          stepIdentifiers: _stepIdentifiers,
          // Nothing is still moving once the delivery is terminal, so the glow
          // rests there.
          pulseActive: snapshot.lifecycle == DeliveryLifecycle.active &&
              snapshot.stage != DeliveryStage.delivered,
        ),
        const SizedBox(height: Spacing.xLarge),
        JeebOutlinedCard.grouped(
          children: [
            for (final stage in DeliveryStage.values)
              _StageRow(
                key: _rowKeyFor(stage),
                stage: stage,
                snapshot: snapshot,
              ),
          ],
        ),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.stage, required this.snapshot, super.key});

  final DeliveryStage stage;
  final DeliverySnapshot snapshot;

  bool get _isReached =>
      snapshot.lifecycle != DeliveryLifecycle.cancelled &&
      stage.isAtOrBefore(snapshot.stage);

  bool get _isActive =>
      snapshot.lifecycle == DeliveryLifecycle.active && stage == snapshot.stage;

  IconData get _glyph {
    if (_isActive) return Icons.radio_button_checked;
    if (_isReached) return Icons.check_circle;
    return Icons.radio_button_unchecked;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final timestamp = snapshot.stageTimestamps[stage];
    final caption = timestamp != null
        ? l10n.deliveryStageReachedAt(_formatTime(context, timestamp))
        : l10n.deliveryStageTimestampPending;
    return JeebListRow(
      icon: _glyph,
      // The stage in motion is this screen's do-it-now moment, so it takes the
      // rationed accent — the same ink the stepper's active node above carries
      // for the same fact. Reached is navy; everything ahead is outline grey.
      iconColor: _isActive
          ? context.jeebRoles.accent
          : (_isReached ? scheme.primary : scheme.outlineVariant),
      title: _labelFor(l10n, stage),
      subtitle: caption,
      showChevron: false,
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

  String _formatTime(BuildContext context, DateTime when) {
    // 24-hour format. Arabic locale falls back to Latin digits via intl's
    // default — matches the rest of the app's time formatting (see KYC).
    final tag = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.Hm(tag).format(when.toLocal());
  }
}
