/// Widget previews for [TrackingMapSurface] — run with
/// `flutter widget-preview start`.
///
/// ## What is actually under review here
///
/// The surface has two modes and only one of them is previewable. With
/// `useLiveMap: true` it mounts a [TrackingGoogleMap], i.e. a platform view
/// that needs `com.google.android.geo.API_KEY`; mounting it keyless is a native
/// FATAL (sprint-009 P0, see the field doc on [TrackingMapSurface.useLiveMap])
/// and there is no platform view at all on the desktop canvas. So every preview
/// below leaves `useLiveMap` at its shipping default of `false` and reviews the
/// **placeholder chrome**: the themed full-bleed container, the navigation mark,
/// and — the part that carries information — the bottom-anchored
/// [CourierPositionNotice].
///
/// That is not a compromise. The notice is deliberately mounted OUTSIDE the
/// `_showsLiveMap` branch (see the comment in `tracking_map_surface.dart`)
/// precisely so it can be reviewed without a Maps key, and
/// `tool/preview_exclusions.txt` already cites `TrackingMapSurface(useLiveMap:
/// false)` as the seam other map widgets lack.
///
/// ## Where the states come from
///
/// Every fixture is the literal `GET /deliveries/{id}/tracking` body from
/// `test/features/live_tracking/tracking_position_status_test.dart` — the
/// phantom-pin suite — parsed through the shipping
/// [DeliveryTrackingInfo.fromTrackingJson]. Nothing is invented and nothing
/// touches the wire: the parse is a pure function of a map literal, so these
/// previews are network-free by construction rather than by [jeebPreviewHost]'s
/// guard.
///
/// The axis the states walk is [PositionFreshness], because that is the axis
/// that produced a real defect: a marker rendered as live at a corner the
/// courier had left, 76 s of it on the hardware capture. Two rungs of the ladder
/// must SAY something ([PositionFreshness.stale], [PositionFreshness.lost]) and
/// two must say nothing ([PositionFreshness.live],
/// [PositionFreshness.awaitingFirstFix]) — "renders nothing" is a state with a
/// contract here, so it gets previews too.
///
/// ## About the captions
///
/// The surface itself renders no text: its own output is an [Icon] plus a
/// [Semantics] label, and four of the six states below render no notice copy
/// either (three of them render nothing at all by design). `find.text` on the
/// widget's own output therefore cannot tell those states apart, and a render
/// test bound to it would pass while every preview drew the same box. Each
/// preview carries a one-line caption naming its state, used by the test only to
/// address a state; the assertions that prove the states really differ are in
/// `test/previews/live_tracking/tracking_map_surface_preview_test.dart`. This
/// mirrors `capture_map_viewport_preview.dart`, which has the same problem.
///
/// ## What these previews surface in the widget
///
///  * **The notice overflows the surface at phone width.** Every state that
///    shows a chip except the shortest one does, in BOTH locales — the ordinary
///    3-minute stale notice included. `OmdsChip` lays its label out in a `Row`
///    with `mainAxisSize: MainAxisSize.min` and no `Flexible`, `maxLines` or
///    `overflow`, so a non-flex child is measured with an unbounded main axis
///    and the chip grows past the 390 − 32 pt band `_MapBody._stacked` gives
///    it — unwrapped, unellipsized and unclipped. It looks perfect on the
///    800 pt surface the existing suite pumps, which is why the existing suite
///    never saw it.
///  * The same chip overflows at the 200% text ceiling even on a wide surface,
///    so this is not only a narrow-phone problem.
///  * Nothing mirrors under RTL: `_MapBody._stacked` already uses
///    `PositionedDirectional`, and its `start`/`end` insets are equal, so the
///    Arabic rendering differs only in the copy. That is the good news of the
///    set, and the render test pins it so a later `EdgeInsets.only(left:)`
///    cannot creep in unnoticed.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/live_tracking/domain/delivery_tracking_info.dart';
import '../../features/live_tracking/presentation/widgets/tracking_map_surface.dart';
import '../harness/jeeb_preview.dart';

/// Phone width, and the height an `Expanded(flex: 2)` map gives on a 390 × 844
/// phone once `LiveTrackingScreen` has taken its app bar, stepper and panel.
const Size _mapBox = Size(390, 320);

/// The delivery the phantom-pin suite tracks.
const String _deliveryId = 'DLV-PHANTOM';

/// A `TrackingPolylineDto` body with a live fix, byte-shaped as gateway #342
/// serializes it (`Tracking/TrackingDtos.cs`, camelCase via
/// `JsonSerializerDefaults.Web`).
Map<String, Object?> _liveWire() => <String, Object?>{
      'deliveryId': _deliveryId,
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
Map<String, Object?> _lostWire(double ageSeconds) => <String, Object?>{
      'deliveryId': _deliveryId,
      'jeeberId': 'JBR-1',
      'position': null,
      'polyline': <Object?>[],
      'stale': true,
      'secondsSinceUpdate': ageSeconds,
      'positionStatus': 'lost',
      'etag': 'def',
      'serverTimestamp': '2026-08-01T10:05:12Z',
    };

DeliveryTrackingInfo _info(Map<String, Object?> wire) =>
    DeliveryTrackingInfo.fromTrackingJson(_deliveryId, wire);

/// Renders the surface the way `LiveTrackingScreen` does — full bleed inside an
/// `Expanded` — with a caption naming the state under review beneath it.
///
/// The caption is preview scaffolding (see the library doc). It is deliberately
/// tiny so the 200%-text rendering of the matrix still shows the surface rather
/// than a wall of label, and it sits OUTSIDE [TrackingMapSurface] so it can
/// never be mistaken for something the widget draws.
Widget _hosted(String caption, DeliveryTrackingInfo? info) => Column(
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
///
/// The one state where the overlay is not merely silent but ABSENT — `_MapBody`
/// takes the no-[Stack] branch, so nothing is layered over the mark at all. It
/// is also the state every caller gets by default, and the reason the surface
/// has a placeholder in the first place.
@JeebPreview(group: 'live_tracking', name: 'No snapshot yet', size: _mapBox)
Widget trackingMapSurfaceAwaitingSnapshot() =>
    _hosted('No snapshot yet: placeholder only, no overlay', null);

/// The happy path, and a NEGATIVE control: a fresh fix, and the notice says
/// nothing.
///
/// [CourierPositionNotice] is mounted (the layout always mounts it once `info`
/// is non-null) and collapses itself to a zero-size box. There is no news in
/// "the courier is fine", and a chip here would train the customer to ignore the
/// row exactly when it starts to matter. If this preview ever grows a chip, the
/// `shows()` predicate has inverted.
@JeebPreview(group: 'live_tracking', name: 'Live fix, no notice', size: _mapBox)
Widget trackingMapSurfaceLiveFix() => _hosted(
      'Live fix: notice mounted and silent',
      _info(_liveWire()),
    );

/// The quiet rung: the gateway still publishes coordinates, they are merely
/// aging past `Tracking:StaleThreshold` (2 min).
///
/// 187 s floors to "3 min old". The customer's correct action is to WAIT — the
/// uploader reports on a 10 m `distanceFilter`, so a stationary courier
/// legitimately goes quiet for minutes — so the chip is `secondaryContainer`,
/// not an error colour. Reviewing it beside the state below is the point: if
/// these two ever read the same, the copy split (P6) has been undone.
///
/// This is also the state that makes the overflow finding hard to dismiss: it
/// is the ordinary one, and it overflows at 390 pt in both locales.
@JeebPreview(group: 'live_tracking', name: 'Position stale (3 min)', size: _mapBox)
Widget trackingMapSurfaceStale() => _hosted(
      'Stale rung: quiet chip, coordinates still published',
      _info(<String, Object?>{
        ..._liveWire(),
        'stale': true,
        'secondsSinceUpdate': 187.0,
        'positionStatus': 'stale',
      }),
    );

/// The defect state made visible: the gateway had this courier and has lost
/// them.
///
/// 312.5 s floors to "last seen 5 min ago". Louder copy and `errorContainer`,
/// because the customer's next action is different — call, or take the no-show
/// path. This is the affordance that replaced the phantom pin; hiding the marker
/// and adding nothing would have traded a lie for a silence.
///
/// **This state overflows its band at phone width in both locales** — see the
/// library doc.
@JeebPreview(group: 'live_tracking', name: 'Signal lost (5 min)', size: _mapBox)
Widget trackingMapSurfaceLost() => _hosted(
      'Lost rung: loud chip, no coordinates at all',
      _info(_lostWire(312.5)),
    );

/// The sub-minute guard: a `lost` verdict whose age floors to zero.
///
/// 41 s would render "last seen 0 min ago", which reads as a glitch and
/// undercuts the one row the customer has to trust, so the copy drops the number
/// entirely. Pinned by `tracking_position_status_test.dart`; this is what it
/// looks like.
@JeebPreview(group: 'live_tracking', name: 'Signal lost, under a minute', size: _mapBox)
Widget trackingMapSurfaceLostNoAge() => _hosted(
      'Lost, age under a minute: number dropped',
      _info(_lostWire(41.0)),
    );

/// Layout ceiling: the longest copy this surface can plausibly be asked to
/// carry.
///
/// A courier's phone dies mid-delivery and the row stays open for an hour and a
/// half; 6000 s floors to "last seen 100 min ago", the widest label in the set.
/// At the 390 pt phone width the surface actually ships at, the chip has 358 pt
/// to live in and takes more, because `OmdsChip` gives its label an unbounded
/// main axis — so all three renderings of this state paint the overflow stripe.
/// The same widget on the 800 pt surface the existing widget tests pump looks
/// perfectly healthy, which is the whole reason a preview declared at the real
/// phone width was worth writing.
@JeebPreview(group: 'live_tracking', name: 'Signal lost, longest copy', size: _mapBox)
Widget trackingMapSurfaceLostLongAge() => _hosted(
      'Lost, 100 min: longest plausible chip',
      _info(_lostWire(6000.0)),
    );
