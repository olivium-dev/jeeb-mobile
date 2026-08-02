import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class CourierPositionNotice extends StatelessWidget {
  const CourierPositionNotice({super.key, required this.info});

  final DeliveryTrackingInfo info;

  static const String semanticsId = 'tracking_position_notice';

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

  int? get _ageMinutes {
    final seconds = info.positionAgeSeconds;
    if (seconds == null) return null;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    return minutes < 1 ? null : minutes;
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Canvas box for a visible pill: phone width, and only as tall as the row can
/// ever get.
const Size _courierPositionNoticeBox = Size(390, 96);

/// Canvas box for the collapsed state. Deliberately still phone width: the
/// point of that preview is that the row occupies NO height, which only reads
const Size _courierPositionNoticeCollapsedBox = Size(390, 72);

const String _courierPositionNoticeDeliveryId = 'DLV-PHANTOM';

/// One `TrackingPolylineDto` body, varying only along the position axis.
/// `stale` and `secondsSinceUpdate` travel alongside `positionStatus` exactly
Map<String, dynamic> _courierPositionNoticeSnapshot({
  required String positionStatus,
  double? ageSeconds,
  bool stale = true,
  bool hasCoordinates = true,
}) =>
    <String, dynamic>{
      'deliveryId': _courierPositionNoticeDeliveryId,
      'jeeberId': 'JBR-1',
      'position': hasCoordinates
          ? <String, dynamic>{
              'lat': 33.5,
              'lng': 35.5,
              'timestamp': '2026-08-01T10:00:00Z',
            }
          : null,
      'polyline': hasCoordinates
          ? <List<double>>[
              <double>[33.5, 35.5],
              <double>[33.9, 35.6],
            ]
          : <Object?>[],
      'stale': stale,
      'secondsSinceUpdate': ageSeconds,
      'positionStatus': positionStatus,
      'etag': 'cbf29ce484222325',
      'serverTimestamp': '2026-08-01T10:05:12Z',
    };

/// Frames the notice the way its only production caller does.
/// `TrackingMapSurface._stacked` pins the row across the map with
Widget _courierPositionNoticeHosted(Map<String, dynamic> snapshot) => Padding(
      padding: const EdgeInsets.all(16),
      child: Align(
        child: CourierPositionNotice(
          info: DeliveryTrackingInfo.fromTrackingJson(_courierPositionNoticeDeliveryId, snapshot),
        ),
      ),
    );

/// The quiet rung. The gateway STILL publishes coordinates, they are merely
/// older than `Tracking:StaleThreshold` (default 2 min) — so the route stays
@JeebPreview(group: 'live_tracking', name: 'Stale · 3 min old', size: _courierPositionNoticeBox)
Widget courierPositionNoticeStale() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(positionStatus: 'stale', ageSeconds: 187.0),
    );

/// The loud rung, and the state this widget exists for. The gateway had this
/// courier and lost them: no coordinates at all any more, and the non-null age
@JeebPreview(group: 'live_tracking', name: 'Lost · 5 min ago', size: _courierPositionNoticeBox)
Widget courierPositionNoticeLost() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(
        positionStatus: 'lost',
        ageSeconds: 312.5,
        hasCoordinates: false,
      ),
    );

/// Regression guard made visible: an age BELOW one minute drops the number
/// rather than rendering "last seen 0 min ago".
@JeebPreview(group: 'live_tracking', name: 'Lost · under a minute', size: _courierPositionNoticeBox)
Widget courierPositionNoticeLostSubMinute() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(
        positionStatus: 'lost',
        ageSeconds: 41.0,
        hasCoordinates: false,
      ),
    );

/// The same missing-age case on the OTHER rung — which does not get the same
/// treatment.
@JeebPreview(group: 'live_tracking', name: 'Stale · no age reported', size: _courierPositionNoticeBox)
Widget courierPositionNoticeStaleNoAge() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(positionStatus: 'stale'),
    );

/// Layout ceiling: the longest label the widget can emit.
/// The age is a raw minute count with no unit escalation and no upper clamp, so
@JeebPreview(group: 'live_tracking', name: 'Lost · overnight', size: _courierPositionNoticeBox)
Widget courierPositionNoticeLostOvernight() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(
        positionStatus: 'lost',
        ageSeconds: 86400.0,
        hasCoordinates: false,
      ),
    );

/// The courier is fine, and the row says NOTHING.
/// `live` and `awaitingFirstFix` — and a null verdict, which means "this
@JeebPreview(group: 'live_tracking', name: 'Live · nothing to say', size: _courierPositionNoticeCollapsedBox)
Widget courierPositionNoticeLive() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(positionStatus: 'live', ageSeconds: 4.0, stale: false),
    );
