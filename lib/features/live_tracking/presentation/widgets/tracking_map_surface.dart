import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/delivery_tracking_info.dart';
import 'courier_position_notice.dart';
import 'tracking_google_map.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class TrackingMapSurface extends StatelessWidget {
  const TrackingMapSurface({
    super.key,
    this.info,
    this.useLiveMap = false,
  });

  final DeliveryTrackingInfo? info;

  final bool useLiveMap;

  static const Key rootKey = Key('tracking_map');

  bool get _showsLiveMap => useLiveMap && info != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'tracking_map',
      image: true,
      label: l10n.trackingMapSemanticLabel,
      child: _MapBody(
        rootKey: rootKey,
        overlay: info == null ? null : CourierPositionNotice(info: info!),
        child: _showsLiveMap
            ? TrackingGoogleMap(info: info!)
            : const _MapPlaceholderMark(),
      ),
    );
  }
}

class _MapBody extends StatelessWidget {
  const _MapBody({required this.rootKey, required this.child, this.overlay});

  final Key rootKey;
  final Widget child;

  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: rootKey,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: overlay == null ? child : _stacked(child, overlay!),
    );
  }

  static Widget _stacked(Widget child, Widget overlay) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: Center(child: child)),
          PositionedDirectional(
            start: Spacing.medium,
            end: Spacing.medium,
            bottom: Spacing.medium,
            child: Align(child: overlay),
          ),
        ],
      );
}

class _MapPlaceholderMark extends StatelessWidget {
  const _MapPlaceholderMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor =
        scheme.onSurfaceVariant.withValues(alpha: UIConstants.opacityMedium);
    return Icon(
      Icons.navigation_outlined,
      size: Sizes.fiveXLarge,
      color: iconColor,
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width, and the height an `Expanded(flex: 2)` map gives on a 390 × 844
/// phone once `LiveTrackingScreen` has taken its app bar, stepper and panel.
const Size _trackingMapSurfaceBox = Size(390, 320);

/// The delivery the phantom-pin suite tracks.
const String _trackingMapSurfaceDeliveryId = 'DLV-PHANTOM';

/// A `TrackingPolylineDto` body with a live fix, byte-shaped as gateway #342
/// serializes it (`Tracking/TrackingDtos.cs`, camelCase via
Map<String, Object?> _trackingMapSurfaceLiveWire() => <String, Object?>{
      'deliveryId': _trackingMapSurfaceDeliveryId,
      'jeeberId': 'JBR-1',
      'position': <String, Object?>{
        'lat': 33.5,
        'lng': 35.5,
        'timestamp': '2026-08-01T10:00:00Z',
      },
      'polyline': <List<double>>[
        <double>[33.5, 35.5],
        <double>[33.9, 35.6],
      ],
      'stale': false,
      'secondsSinceUpdate': 4.0,
      'positionStatus': 'live',
      'etag': 'abc',
      'serverTimestamp': '2026-08-01T10:00:04Z',
    };

/// The `lost` body: NO coordinates, NO polyline, `stale:true`, and — the whole
/// signal — a non-null age.
Map<String, Object?> _trackingMapSurfaceLostWire(double ageSeconds) => <String, Object?>{
      'deliveryId': _trackingMapSurfaceDeliveryId,
      'jeeberId': 'JBR-1',
      'position': null,
      'polyline': <Object?>[],
      'stale': true,
      'secondsSinceUpdate': ageSeconds,
      'positionStatus': 'lost',
      'etag': 'def',
      'serverTimestamp': '2026-08-01T10:05:12Z',
    };

DeliveryTrackingInfo _trackingMapSurfaceInfo(Map<String, Object?> wire) =>
    DeliveryTrackingInfo.fromTrackingJson(_trackingMapSurfaceDeliveryId, wire);

/// Renders the surface the way `LiveTrackingScreen` does — full bleed inside an
/// `Expanded` — with a caption naming the state under review beneath it.
Widget _trackingMapSurfaceHosted(String caption, DeliveryTrackingInfo? info) => Column(
      children: <Widget>[
        Expanded(child: TrackingMapSurface(info: info)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );

/// Cold start: the screen is mounted, `GET /deliveries/{id}/tracking` has not
/// answered, so `info` is null.
@JeebPreview(group: 'live_tracking', name: 'No snapshot yet', size: _trackingMapSurfaceBox)
Widget trackingMapSurfaceAwaitingSnapshot() =>
    _trackingMapSurfaceHosted('No snapshot yet: placeholder only, no overlay', null);

/// The happy path, and a NEGATIVE control: a fresh fix, and the notice says
/// nothing.
@JeebPreview(group: 'live_tracking', name: 'Live fix, no notice', size: _trackingMapSurfaceBox)
Widget trackingMapSurfaceLiveFix() => _trackingMapSurfaceHosted(
      'Live fix: notice mounted and silent',
      _trackingMapSurfaceInfo(_trackingMapSurfaceLiveWire()),
    );

/// The quiet rung: the gateway still publishes coordinates, they are merely
/// aging past `Tracking:StaleThreshold` (2 min).
@JeebPreview(group: 'live_tracking', name: 'Position stale (3 min)', size: _trackingMapSurfaceBox)
Widget trackingMapSurfaceStale() => _trackingMapSurfaceHosted(
      'Stale rung: quiet chip, coordinates still published',
      _trackingMapSurfaceInfo(<String, Object?>{
        ..._trackingMapSurfaceLiveWire(),
        'stale': true,
        'secondsSinceUpdate': 187.0,
        'positionStatus': 'stale',
      }),
    );

/// The defect state made visible: the gateway had this courier and has lost
/// them.
@JeebPreview(group: 'live_tracking', name: 'Signal lost (5 min)', size: _trackingMapSurfaceBox)
Widget trackingMapSurfaceLost() => _trackingMapSurfaceHosted(
      'Lost rung: loud chip, no coordinates at all',
      _trackingMapSurfaceInfo(_trackingMapSurfaceLostWire(312.5)),
    );

/// The sub-minute guard: a `lost` verdict whose age floors to zero.
/// 41 s would render "last seen 0 min ago", which reads as a glitch and
@JeebPreview(group: 'live_tracking', name: 'Signal lost, under a minute', size: _trackingMapSurfaceBox)
Widget trackingMapSurfaceLostNoAge() => _trackingMapSurfaceHosted(
      'Lost, age under a minute: number dropped',
      _trackingMapSurfaceInfo(_trackingMapSurfaceLostWire(41.0)),
    );

/// Layout ceiling: the longest copy this surface can plausibly be asked to
/// carry.
@JeebPreview(group: 'live_tracking', name: 'Signal lost, longest copy', size: _trackingMapSurfaceBox)
Widget trackingMapSurfaceLostLongAge() => _trackingMapSurfaceHosted(
      'Lost, 100 min: longest plausible chip',
      _trackingMapSurfaceInfo(_trackingMapSurfaceLostWire(6000.0)),
    );
