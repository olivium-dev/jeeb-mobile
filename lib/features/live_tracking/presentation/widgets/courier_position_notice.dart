import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

/// The honest half of the phantom-pin fix: says OUT LOUD that the courier's
/// position can no longer be vouched for, and how old it is.
///
/// ## Why hiding the marker is not enough on its own
///
/// [DeliveryTrackingInfo.markerIsLive] already stops the map drawing a pin once
/// the gateway reports `stale` or `lost`, and that half is correct — a pin at a
/// corner the courier left ten minutes ago is worse than no pin, because the
/// customer walks to it. But from the customer's seat a marker that VANISHES
/// and a marker that was never there look exactly alike, and neither says why.
/// The hardware capture that opened this defect showed 76 s of a stale pin with
/// no staleness affordance at all; removing the pin and adding nothing would
/// trade a lie for a silence.
///
/// So the marker goes, and this takes its place — anchored on the map surface,
/// where the pin was, rather than buried in the panel below.
///
/// ## What it renders, and what it deliberately does not
///
///  * [PositionFreshness.stale] — the gateway still publishes coordinates, they
///    are merely aging. The route stays drawn; the notice reports the age. The
///    customer's correct action is to wait: the uploader reports on a 10 m
///    `distanceFilter`, so a stationary courier legitimately goes quiet for
///    minutes.
///  * [PositionFreshness.lost] — the gateway publishes no coordinates at all
///    any more. Distinct, louder copy, because the customer's correct action is
///    different: call, or take the no-show path.
///  * [PositionFreshness.live] and [PositionFreshness.awaitingFirstFix] —
///    NOTHING. There is no news in "the courier is fine", and pre-first-fix
///    there is genuinely nothing to report; a notice there would train the
///    customer to ignore this row exactly when it starts to matter.
///  * A null [DeliveryTrackingInfo.positionStatus] — NOTHING. That means the
///    gateway sent no verdict, and inventing one client-side is the second
///    source of truth this whole change exists to avoid.
class CourierPositionNotice extends StatelessWidget {
  const CourierPositionNotice({super.key, required this.info});

  final DeliveryTrackingInfo info;

  /// Stable id for Maestro / widget-test targeting.
  static const String semanticsId = 'tracking_position_notice';

  /// Whether this row has anything to say about [info].
  static bool shows(DeliveryTrackingInfo info) =>
      info.positionStatus?.isUnvouched ?? false;

  @override
  Widget build(BuildContext context) {
    if (!shows(info)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final lost = info.positionLost;
    return Semantics(
      identifier: semanticsId,
      container: true,
      child: OmdsChip(
        label: _label(context),
        isSelected: true,
        icon: Icon(
          lost ? Icons.location_off_outlined : Icons.schedule_outlined,
          size: Sizes.small,
          color: lost ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
        selectedColor: lost ? scheme.errorContainer : scheme.secondaryContainer,
        selectedTextColor:
            lost ? scheme.onErrorContainer : scheme.onSecondaryContainer,
      ),
    );
  }

  /// The copy. `lost` with an age below one minute falls back to the ageless
  /// wording rather than rendering "last seen 0 min ago", which reads as a
  /// glitch and undercuts the one row the customer has to trust.
  String _label(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final minutes = _ageMinutes;
    if (info.positionLost) {
      return minutes == null
          ? l10n.positionLostNoticeNoAge
          : l10n.positionLostNotice(minutes);
    }
    return l10n.positionStaleNotice(minutes ?? 0);
  }

  /// Floor of the reported age in whole minutes; null when the gateway sent no
  /// age, or an age under one minute.
  int? get _ageMinutes {
    final seconds = info.positionAgeSeconds;
    if (seconds == null) return null;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    return minutes < 1 ? null : minutes;
  }
}
