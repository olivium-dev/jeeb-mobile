import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../mixed_direction/presentation/mixed_direction_text.dart';
import '../../domain/delivery_tracking_info.dart';

/// The quiet fact strip beneath the door-code row on the order-tracking screen.
///
/// redesign-2026-08 §C task 7: this used to be a 78%-wide block carrying a
/// SECOND (3-step) stepper above a distance/ETA/deadline stack — a duplicate of
/// the 4-step `tracking_stepper` at the top of the screen, painted in the banned
/// `colorScheme.tertiary`. Both steppers are gone from here; the live ETA moved
/// onto the map pill (`tracking_eta_label`), and what is left is two lines of
/// fact.
///
/// The strip is not on the redesign board at all (D-12-3). It ships anyway
/// because D18/Q-061 LOCKS the absolute arrival deadline as something the
/// customer must be able to read — so it renders as the quietest thing on the
/// screen, below the door code, rather than being deleted.
///
/// The `tracking_progress_stepper` node survives with its historical `value`
/// (the current 3-label stage name) even though no stepper is drawn here any
/// more: Maestro `16-order-tracking.yaml` reads it, and the node's contract is
/// the stage name, not the pixels.
class DeliveryTrackingPanel extends StatelessWidget {
  const DeliveryTrackingPanel({super.key, required this.info});

  static const Key rootKey = Key('tracking_status_panel');

  final DeliveryTrackingInfo info;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deadline = info.deadline;
    return Semantics(
      identifier: 'tracking_status_panel',
      container: true,
      // Keeps the stage node and the two fact leaves addressable instead of
      // folding them into the panel root.
      explicitChildNodes: true,
      child: Semantics(
        identifier: 'tracking_progress_stepper',
        container: true,
        explicitChildNodes: true,
        value: _stepLabels(l10n)[info.trackingStepIndex],
        child: Wrap(
          key: rootKey,
          spacing: Spacing.small,
          runSpacing: Spacing.twoXSmall,
          children: [
            _TrackingDistanceLine(distanceLabel: info.distanceLabel),
            // Q-061 / D18: the LOCKED absolute deadline. Only mounts when the
            // delivery row carries one, so pre-fix rows render unchanged.
            if (deadline != null) _TrackingDeadlineLine(deadline: deadline),
          ],
        ),
      ),
    );
  }

  /// The historical 3-label stage vocabulary the `tracking_progress_stepper`
  /// node's `value` has always reported. Unchanged on purpose — it is the
  /// node's contract, and `trackingStepIndex` still collapses onto it.
  List<String> _stepLabels(AppLocalizations l10n) => [
        l10n.trackingStepOrdered,
        l10n.trackingStepPicked,
        l10n.trackingStepInTransit,
      ];
}

class _TrackingDistanceLine extends StatelessWidget {
  const _TrackingDistanceLine({required this.distanceLabel});

  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = distanceLabel;
    final text = label == null
        ? l10n.trackingDistanceUnknown
        : l10n.trackingDistanceAway(label);
    return _TrackingPanelText(
      identifier: 'tracking_distance_label',
      text: text,
    );
  }
}

/// Q-061 / D18: the LOCKED absolute arrival deadline. Distinct from the live
/// ETA on the map pill — this is the fixed wall-clock instant the order must
/// arrive by, frozen at order creation. The time is formatted locale-aware
/// (`jm` — e.g. `3:45 PM` / `٣:٤٥ م`) and normalized to the device wall clock
/// via `toLocal()`.
class _TrackingDeadlineLine extends StatelessWidget {
  const _TrackingDeadlineLine({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.jm(localeTag).format(deadline.toLocal());
    return _TrackingPanelText(
      identifier: 'tracking_deadline_label',
      text: l10n.trackingDeadlineLocked(time),
    );
  }
}

class _TrackingPanelText extends StatelessWidget {
  const _TrackingPanelText({required this.identifier, required this.text});

  final String identifier;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: identifier,
      liveRegion: true,
      child: MixedDirectionText(
        text,
        // Distance and deadline are FACTS, not qualifiers (R4), and the board's
        // periwinkle fails AA on white at this size by the repo's own pinned
        // contrast guard — so this line is `onSurfaceVariant`, not `mutedText`.
        style: context.jeebText.bodySmall
            .copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
