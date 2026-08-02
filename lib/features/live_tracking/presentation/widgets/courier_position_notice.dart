import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/live_tracking/courier_position_notice_preview_test.dart
// ===========================================================================
// Widget previews for [CourierPositionNotice] — run with
// `flutter widget-preview start`.
//
// The notice takes exactly one argument, a [DeliveryTrackingInfo], and reads
// three things off it: the gateway's freshness verdict
// ([DeliveryTrackingInfo.positionStatus]), whether that verdict is `lost`, and
// the reported age. There is no cubit, no repository and no map behind it, so
// these previews are network-free by construction rather than by the guard in
// [jeebPreviewHost] — each one is a value built from a literal snapshot.
//
// Every fixture goes through [DeliveryTrackingInfo.fromTrackingJson] rather
// than the bare constructor, and the snapshot maps are the byte-shapes
// `GET /deliveries/{id}/tracking` actually answers — the same fixtures as
// `test/features/live_tracking/tracking_position_status_test.dart`, so the
// canvas and the regression suite look at the same rows. That matters more
// than usual here: the whole point of this widget is to render the gateway's
// verdict and NEVER to invent one, so a preview that hand-set
// `positionStatus` would be reviewing a state the wire cannot produce.
//
// ## What to look for in the canvas
//
// The failure mode of this row is HORIZONTAL, which is why every box below is
// exactly phone width and none of them is tall. `OmdsChip` lays its label out
// as a bare [Text] inside a `Row` with no `Flexible`, no `maxLines` and no
// `overflow` — and a `Row` hands its non-flex children UNBOUNDED main-axis
// constraints. Measured: the label renders on exactly one line at every width,
// 16 px tall at 1.0× and 32 px at 2.0×, even when that line wants 1225 px. So
// this pill can neither wrap nor ellipsize; past the width it is given it
// simply overflows. Every rendering in the matrix is worth checking against
// that, and the AR RTL and 200 %-text ones especially — the EN light rendering
// is the last one to break.

/// Canvas box for a visible pill: phone width, and only as tall as the row can
/// ever get.
///
/// The pill is a fixed 32 px at 1.0× text (16 px label + 2 × `Spacing.xSmall`)
/// and 48 px at 2.0×, because the label never wraps — so height is not where
/// the interesting information is, and a taller box would just pad the card
/// with empty space. 96 px leaves the 32 px of framing the map surface adds.
const Size _courierPositionNoticeBox = Size(390, 96);

/// Canvas box for the collapsed state. Deliberately still phone width: the
/// point of that preview is that the row occupies NO height, which only reads
/// when the box around it is as wide as the visible ones.
const Size _courierPositionNoticeCollapsedBox = Size(390, 72);

const String _courierPositionNoticeDeliveryId = 'DLV-PHANTOM';

/// One `TrackingPolylineDto` body, varying only along the position axis.
///
/// `stale` and `secondsSinceUpdate` travel alongside `positionStatus` exactly
/// as the gateway serializes them, because [parsePositionStatus] falls back to
/// that older triple whenever the verdict is missing or unrecognized — a
/// fixture that omitted them would exercise a shorter path than the app runs.
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
///
/// `TrackingMapSurface._stacked` pins the row across the map with
/// `PositionedDirectional(start: Spacing.medium, end: Spacing.medium, …)` and
/// an `Align`, so on a 390 px phone the pill has 358 px to live in and is
/// centred in it. Reproducing that here is not decoration: those 32 px of inset
/// are what set the width at which the label starts to overflow, and a preview
/// that handed the chip the whole canvas would review a threshold the app never
/// uses. The `Align` also keeps the pill at its intrinsic size — without it the
/// `Scaffold` body's tight constraints stretch the rounded pill across the
/// entire box, which is not a shape this widget ever has on device.
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
/// drawn and only the marker is withheld, and the customer's correct action is
/// to wait (the uploader reports on a 10 m `distanceFilter`, so a stationary
/// courier legitimately goes quiet for minutes).
///
/// 187 s is the age the regression suite uses; it floors to 3 whole minutes.
/// This is the reading to compare `Lost` against: the two rungs share a shape
/// and must NOT share a colour, an icon or a sentence. Check that in the AR RTL
/// **dark** rendering in particular — `secondaryContainer` and `errorContainer`
/// sit much closer together in the dark scheme than in the light one, and this
/// row is the only thing distinguishing "wait" from "call them".
@JeebPreview(group: 'live_tracking', name: 'Stale · 3 min old', size: _courierPositionNoticeBox)
Widget courierPositionNoticeStale() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(positionStatus: 'stale', ageSeconds: 187.0),
    );

/// The loud rung, and the state this widget exists for. The gateway had this
/// courier and lost them: no coordinates at all any more, and the non-null age
/// beside that null position is the entire signal separating this from
/// `awaitingFirstFix`.
///
/// 312.5 s floors to 5 min — the age from the hardware capture that opened the
/// phantom-pin defect. The map has just REMOVED a pin the customer was
/// watching; this pill is the only thing on screen that explains why. If it is
/// hard to find here, it is invisible over a real map.
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
///
/// 41 s floors to zero whole minutes, and `_ageMinutes` returns null rather
/// than 0 precisely so the copy falls back to the ageless wording. "0 min ago"
/// reads as a glitch, and this is the one row on the screen the customer has to
/// trust. If this preview ever shows a number, that fallback has broken.
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
///
/// A `stale` verdict with no `secondsSinceUpdate` is a shape the wire can
/// produce: [parsePositionStatus] accepts an explicit verdict without requiring
/// an age, so a gateway mid-deploy, or any proxy that drops the field, sends
/// exactly this. `_label` guards the null age on the `lost` branch only and
/// passes `minutes ?? 0` on the stale branch, so this renders **"Jeeber's
/// location is 0 min old"** — the very sentence the ageless fallback one rung
/// over exists to prevent. Kept as a preview because it is the state a reviewer
/// would otherwise never think to open.
@JeebPreview(group: 'live_tracking', name: 'Stale · no age reported', size: _courierPositionNoticeBox)
Widget courierPositionNoticeStaleNoAge() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(positionStatus: 'stale'),
    );

/// Layout ceiling: the longest label the widget can emit.
///
/// The age is a raw minute count with no unit escalation and no upper clamp, so
/// a row parked overnight — a `FailedNeedsEscalation` delivery waiting on admin
/// still mounts this notice, and it is explicitly NOT poll-terminal — renders a
/// four-digit count instead of "a day ago". This is the state the AR RTL and
/// 200 %-text renderings are really for: measured on the test font the label
/// alone wants 625 px at 1.0× and 1225 px at 2.0×, against the 358 px the map
/// surface gives it, and because the chip's `Row` neither wraps nor ellipsizes
/// there is nowhere for that to go but over the edge.
@JeebPreview(group: 'live_tracking', name: 'Lost · overnight', size: _courierPositionNoticeBox)
Widget courierPositionNoticeLostOvernight() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(
        positionStatus: 'lost',
        ageSeconds: 86400.0,
        hasCoordinates: false,
      ),
    );

/// The courier is fine, and the row says NOTHING.
///
/// `live` and `awaitingFirstFix` — and a null verdict, which means "this
/// gateway did not tell us" rather than "everything is fine" — all collapse to
/// a zero-size box. The widget is still MOUNTED (`TrackingMapSurface` builds it
/// unconditionally, outside the live-map branch); it owns the decision to
/// disappear, so the map above it must show no gap, no shadow and no stray
/// inset where the pill would be. That silence is what makes the notice worth
/// reading when it does appear — a row that were always present would be
/// trained away by the time it started to matter.
@JeebPreview(group: 'live_tracking', name: 'Live · nothing to say', size: _courierPositionNoticeCollapsedBox)
Widget courierPositionNoticeLive() => _courierPositionNoticeHosted(
      _courierPositionNoticeSnapshot(positionStatus: 'live', ageSeconds: 4.0, stale: false),
    );
