import 'package:equatable/equatable.dart';

import '../../../core/formatting/server_time.dart';
import '../../delivery_status/domain/jeeber_summary.dart';

enum TrackingStage { ordered, picked, inTransit, atDoor, delivered }

/// Lifecycle axis ORTHOGONAL to the forward stage (sprint-009 scenario matrix
/// #9). The canonical delivery SM (ADR-002) has terminal/side states that are
/// NOT steps on the Ordered→Done ladder: `Cancelled` (and the request-lifecycle
/// `Expired`) end the delivery, and `FailedNeedsEscalation` parks it with
/// admin. Pre-fix these all defaulted to `TrackingStage.ordered`, so a
/// cancelled delivery rendered a live "Ordered" stepper forever.
enum TrackingLifecycle {
  /// The delivery is progressing through the forward stages.
  active,

  /// Terminal: `Cancelled` / `cancelled` / `canceled`. The tracking screen
  /// renders a graceful terminal state and stops polling.
  cancelled,

  /// Terminal: `Expired` is a reserved *request*-lifecycle token that only
  /// reaches this screen through the gateway's legacy-mirror fallback. Cancel
  /// and expire carry different fee/strike semantics, so they must not share
  /// copy (P6/A3).
  expired,

  /// `FailedNeedsEscalation` / `disputed`: admin-resolvable side state. NOT
  /// terminal — SM edges 12/13 can still resolve the row to Done or cancel it,
  /// so the screen renders an explicit "under review" body and KEEPS polling
  /// (P6/A1).
  failed,
}

extension TrackingStageLabel on TrackingStage {
  String get label {
    switch (this) {
      case TrackingStage.ordered:
        return 'Ordered';
      case TrackingStage.picked:
        return 'Picked Up';
      case TrackingStage.inTransit:
        return 'In Transit';
      case TrackingStage.atDoor:
        return 'At Door';
      case TrackingStage.delivered:
        return 'Delivered';
    }
  }

  int get order => index;
  bool isAtOrBefore(TrackingStage other) => order <= other.order;
}

/// T-MOB-017: GPS coordinate pair from the Mockoon TrackingPolylineDto.
class GpsPoint extends Equatable {
  const GpsPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  List<Object?> get props => [lat, lng];
}

/// How much the GATEWAY can vouch for the courier's last known position — the
/// client mirror of `JeebGateway.Tracking.PositionFreshness`
/// (`jeeb-gateway/src/JeebGateway/Tracking/PositionFreshness.cs`), read off the
/// `positionStatus` string on `TrackingPolylineDto`
/// (`.../Tracking/TrackingDtos.cs:143`, serialized camelCase by
/// `JsonSerializerDefaults.Web` at `Controllers/LocationController.cs:47`).
///
/// ## Why a four-state enum and not the `stale` boolean
///
/// The boolean cannot separate the two states that matter most to a map:
/// "this courier has not started reporting" and "we HAD this courier and lost
/// them". Before gateway #342 (`d430706f`) both serialized byte-identically as
/// `position:null, stale:false, secondsSinceUpdate:null`, so a screen holding a
/// previously-rendered marker was told "everything is fine" about a courier it
/// had lost, and left the pin up as though it were live. That is the phantom
/// pin, and it is the whole reason this type exists.
///
/// The four states are ordered by decreasing confidence and are a pure function
/// of one fix's age, so the ladder is monotonic: a position ages
/// [live] → [stale] → [lost] and never moves back up without a fresh fix.
enum PositionFreshness {
  /// No fix has ever been recorded for this courier. There is nothing to show
  /// and — crucially — nothing has been LOST. Wire: `"awaitingFirstFix"`.
  awaitingFirstFix,

  /// The last fix is younger than the gateway's `Tracking:StaleThreshold`
  /// (default 2 min). The marker may be drawn normally. Wire: `"live"`.
  live,

  /// The last fix is older than `StaleThreshold` but still within
  /// `Tracking:PositionTtl`. The gateway STILL publishes the coordinates — a
  /// stationary courier legitimately uploads nothing for minutes, because the
  /// uploader uses `distanceFilter: 10` — but the client must degrade the
  /// marker rather than present it as live. Wire: `"stale"`.
  stale,

  /// The last fix is older than `PositionTtl`. The gateway had a courier and no
  /// longer knows where they are, so it publishes NO coordinates — but it does
  /// publish `secondsSinceUpdate`. That non-null age beside a null position is
  /// the entire signal distinguishing this from [awaitingFirstFix].
  /// Wire: `"lost"`.
  lost,
}

extension PositionFreshnessWire on PositionFreshness {
  /// The gateway's wire spelling (`TrackingFreshness.ToWireValue`).
  String get wire {
    switch (this) {
      case PositionFreshness.awaitingFirstFix:
        return 'awaitingFirstFix';
      case PositionFreshness.live:
        return 'live';
      case PositionFreshness.stale:
        return 'stale';
      case PositionFreshness.lost:
        return 'lost';
    }
  }

  /// True when the gateway is explicitly telling us it cannot vouch for the
  /// position — the two verdicts that must never render as a live marker.
  bool get isUnvouched =>
      this == PositionFreshness.stale || this == PositionFreshness.lost;

  /// True for the ONE verdict that carries no coordinates yet still demands the
  /// screen act: we had this courier and lost them. An overlay in this state is
  /// EMPTY by coordinates but is emphatically not "nothing to say" — it is the
  /// instruction to stop presenting a pin the screen is already holding.
  bool get isLost => this == PositionFreshness.lost;
}

/// Parses `positionStatus` off the tracking snapshot, falling back to the
/// pre-#342 triple when the field is absent.
///
/// The fallback is a DERIVATION, never an invention, and it is exact for any
/// gateway at or after #342 that happens to omit the field. Against a gateway
/// BEFORE #342 the `lost` state was destroyed server-side (the store deleted
/// the fix on read, so the wire carried `stale:false, secondsSinceUpdate:null`)
/// — no client-side rule can recover information that was never sent, so it
/// derives [PositionFreshness.awaitingFirstFix] and the screen behaves exactly
/// as it did before this change. That is the honest floor, not a regression.
PositionFreshness parsePositionStatus(Map<String, dynamic> json) {
  final raw = json['positionStatus'];
  if (raw is String) {
    switch (raw) {
      case 'live':
        return PositionFreshness.live;
      case 'stale':
        return PositionFreshness.stale;
      case 'lost':
        return PositionFreshness.lost;
      case 'awaitingFirstFix':
        return PositionFreshness.awaitingFirstFix;
    }
    // An UNKNOWN verdict falls through to the derivation below rather than
    // defaulting to a confident state. A future gateway that adds a fifth rung
    // must not be read as "live" by an app that has never heard of it.
  }
  final hasPosition = json['position'] is Map;
  final stale = json['stale'] as bool? ?? false;
  final age = (json['secondsSinceUpdate'] as num?)?.toDouble();
  if (hasPosition) {
    return stale ? PositionFreshness.stale : PositionFreshness.live;
  }
  // No coordinates. An AGE without coordinates is the gateway's own documented
  // signature for `lost` (`TrackingDtos.cs:130-136`).
  if (age != null) return PositionFreshness.lost;
  return PositionFreshness.awaitingFirstFix;
}

class DeliveryTrackingInfo extends Equatable {
  const DeliveryTrackingInfo({
    required this.deliveryId,
    required this.currentStage,
    required this.stageTimestamps,
    this.lifecycle = TrackingLifecycle.active,
    this.distanceLabel,
    this.etaMinutes,
    this.deadline,
    this.jeeberPosition,
    this.polyline = const [],
    this.jeeber,
    this.requestId,
    this.conversationId,
    this.price,
    this.currency,
    this.jeeberName,
    this.tier,
    this.itemSummary,
    this.positionStale = false,
    this.positionAgeSeconds,
    this.positionStatus,
  });

  /// T-MOB-017: Parses the TrackingPolylineDto shape returned by
  /// GET /deliveries/{id}/tracking.
  ///
  /// It used to name a second producer, the SSE `geo` alias. That route is
  /// deleted (`jeeb-gateway` #333 `b6fe888`, guard `Sse_Alias_Route_Is_Gone`),
  /// so listing it here was stale — and worse than stale, because a reader
  /// looking for "which routes feed this parser" would have gone looking for a
  /// 404.
  ///
  /// Verified contract (d6-tracking-geo, s09-live-tracking):
  ///   { deliveryId, jeeberId, polyline: [[lat,lng], …], position: {lat,lng},
  ///     etag, serverTimestamp }
  factory DeliveryTrackingInfo.fromTrackingJson(
    String deliveryId,
    Map<String, dynamic> json,
  ) {
    final stage = _parseStage(json['status'] as String? ?? '');
    final posObj = json['position'] as Map<String, dynamic>?;
    final GpsPoint? pos = posObj == null
        ? null
        : GpsPoint(
            lat: (posObj['lat'] as num).toDouble(),
            lng: (posObj['lng'] as num).toDouble(),
          );
    final rawPoly = json['polyline'] as List<dynamic>? ?? [];
    final polyline = _decodePolyline(rawPoly);
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: stage,
      stageTimestamps: const {},
      lifecycle: _parseLifecycle(json['status'] as String? ?? ''),
      distanceLabel: json['distanceLabel'] as String?,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberPosition: pos,
      polyline: polyline,
      jeeber: _parseJeeber(json),
      // `stale` + `secondsSinceUpdate` moved onto this DTO when jeeb-gateway
      // #333 deleted the SSE stream whose `last-seen` EVENT NAME used to carry
      // the same verdict. Defaulting `stale` to false is deliberate: a gateway
      // old enough to omit the field is also old enough to have no staleness
      // opinion, and inventing one client-side would be a second source of
      // truth for freshness.
      positionStale: json['stale'] as bool? ?? false,
      positionAgeSeconds: (json['secondsSinceUpdate'] as num?)?.toDouble(),
      // The explicit verdict added by gateway #342 (`d430706f`). Reading it is
      // what lets this client tell "hasn't started" apart from "we lost them"
      // — the two states the `stale` boolean above collapses into one.
      positionStatus: parsePositionStatus(json),
    );
  }

  factory DeliveryTrackingInfo.fromJson(
    String deliveryId,
    Map<String, dynamic> json,
  ) {
    final status = json['status'] as String? ?? 'Ordered';
    final currentStage = _parseStage(status);
    final timestamps = <TrackingStage, DateTime>{};
    _populateTimestamps(timestamps, json, currentStage);
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: currentStage,
      stageTimestamps: timestamps,
      lifecycle: _parseLifecycle(status),
      distanceLabel: json['distanceLabel'] as String?,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
    );
  }

  /// JM-032 / BUG-8: parses the `GET /v1/deliveries/:deliveryId` delivery row the
  /// order-tracking screen polls on the live origin gateway (the same
  /// materialized aggregate the jeeber side reads; the legacy `:4010` mock alias
  /// `GET /v1/delivery/:id` returns the identical shape) (`delivery-service`
  /// getDelivery, mock shape:
  /// `{ id, requestId, jeeberId, tier, status, title, amount:{value,currency},
  ///    jeeberName, conversationId, evidenceUrl, proofPhotoUrl, … }`).
  ///
  /// Drives BOTH the 4-step `tracking_stepper` (via [currentStage] — the
  /// delivery lifecycle status `Ordered/Picked/InTransit/AtDoor/Done`) and the
  /// `order_summary_pinned` header (price/tier/jeeber/item — D11/D71). Defensive
  /// throughout: tolerates snake_case + camelCase, the `{value,minorUnits,
  /// currency}` money object or a bare number, and null-coalesces every field so
  /// a malformed body degrades a field gracefully instead of crashing.
  factory DeliveryTrackingInfo.fromDeliveryJson(
    String deliveryId,
    Map<String, dynamic> json,
  ) {
    final status = (json['status'] as String?) ??
        (json['deliveryStatus'] as String?) ??
        'Ordered';
    final currentStage = _parseStage(status);
    final timestamps = <TrackingStage, DateTime>{};
    _populateTimestamps(timestamps, json, currentStage);
    final amount = json['amount'] ?? json['price'];
    return DeliveryTrackingInfo(
      deliveryId: _str(json['id']) ?? deliveryId,
      currentStage: currentStage,
      stageTimestamps: timestamps,
      lifecycle: _parseLifecycle(status),
      distanceLabel: _str(json['distanceLabel']),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      deadline: _parseDeadline(json),
      jeeber: _parseJeeber(json),
      requestId: _str(json['requestId'] ?? json['request_id']),
      conversationId:
          _str(json['conversationId'] ?? json['conversation_id']),
      price: _money(amount),
      currency: _currency(amount),
      jeeberName: _str(json['jeeberName'] ?? json['jeeber_name']),
      // WIRE KEY: `tierId` FIRST. `GET /v1/deliveries/{id}` answers with the
      // gateway's `DeliveryRequestDto`, whose `TierId` member serializes to
      // `tierId`; it never emits `tier`. Reading only `tier` left this null on
      // every real response, and the tracking header hides the tier row when it
      // is null — so the row was invisible on device while the gateway had the
      // value all along. `tier` is retained as the legacy `:4010` mock alias.
      tier: _str(json['tierId'] ?? json['tier_id'] ?? json['tier']),
      // G1: `description` fallback — the request content the customer typed
      // in compose; delivery rows minted from a request may carry it instead
      // of a dedicated title, and the tracking header should echo it.
      itemSummary:
          _str(json['title'] ?? json['itemSummary'] ?? json['description']),
    );
  }

  static String? _str(Object? raw) {
    if (raw == null) return null;
    final s = raw is String ? raw : raw.toString();
    final trimmed = s.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Pulls a numeric amount from a bare number or the `{ value, minorUnits,
  /// currency }` money object the seed emits.
  static double? _money(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is Map) {
      final value = raw['value'] ?? raw['amount'];
      if (value is num) return value.toDouble();
      final minor = raw['minorUnits'] ?? raw['minor_units'];
      if (minor is num) return minor.toDouble() / 100.0;
    }
    return null;
  }

  static String? _currency(Object? raw) {
    if (raw is Map) return _str(raw['currency']);
    return null;
  }

  /// Q-061 / D18: the LOCKED absolute delivery deadline — the fixed wall-clock
  /// instant the order must arrive by, frozen at order creation (NOT a sliding
  /// ETA). Parsed defensively from any of the aliases the delivery row may
  /// carry, normalized to a UTC instant via [ServerTime] so the panel renders
  /// the true local wall clock. Null when the row omits a deadline (the panel
  /// then simply hides the line).
  static DateTime? _parseDeadline(Map<String, dynamic> json) {
    final raw = _str(json['deadline'] ??
        json['deliveryDeadline'] ??
        json['delivery_deadline'] ??
        json['deadlineAt'] ??
        json['deadline_at'] ??
        json['slaDeadline'] ??
        json['sla_deadline'] ??
        json['dueBy'] ??
        json['due_by'] ??
        json['etaDeadline'] ??
        json['eta_deadline']);
    return ServerTime.parse(raw);
  }

  static void _populateTimestamps(
    Map<TrackingStage, DateTime> timestamps,
    Map<String, dynamic> json,
    TrackingStage currentStage,
  ) {
    final history = json['statusHistory'] as List<dynamic>?;
    if (history != null) {
      for (final entry in history) {
        if (entry is Map<String, dynamic>) {
          final stage = _parseStage(entry['status'] as String? ?? '');
          // T11 / SW-03 family: tracking-event instants are UTC; normalize so
          // the stepper's `toLocal()` shows the real reached-at wall clock.
          final ts = ServerTime.parse(entry['timestamp'] as String?);
          if (ts != null) timestamps[stage] = ts;
        }
      }
    }
    if (!timestamps.containsKey(currentStage)) {
      final updatedAt = ServerTime.parse(json['updatedAt'] as String?);
      if (updatedAt != null) timestamps[currentStage] = updatedAt;
    }
  }

  static List<GpsPoint> _decodePolyline(List<dynamic> raw) {
    final result = <GpsPoint>[];
    for (final item in raw) {
      if (item is List && item.length >= 2) {
        result.add(GpsPoint(
          lat: (item[0] as num).toDouble(),
          lng: (item[1] as num).toDouble(),
        ));
      }
    }
    return result;
  }

  /// Parses the PUBLIC matched-Jeeber slice the gateway is allowed to surface
  /// while a delivery is in flight: display name (first name + initial),
  /// vehicle label, and avatar URL.
  ///
  /// Mirrors the real jeeb-gateway public shape — `UserProfileResponse.Name` /
  /// `AvatarUrl` and `MatchedJeeberDto.VehicleType`
  /// (`jeeb-gateway/src/JeebGateway/Users/UsersDtos.cs`,
  /// `Matching/MatchingDtos.cs`). The blind-reveal rule
  /// (`Ratings/BlindRevealPolicy.cs`) only withholds the post-delivery mutual
  /// rating, NOT the jeeber's public profile — so name/avatar/vehicle are fair
  /// to show once a jeeber is assigned.
  ///
  /// Privacy guards enforced here, not at the call site:
  ///   * `phoneE164` is NEVER read — the in-flight surface withholds it.
  ///   * `rating` is NEVER read — no pre-completion ratings in-flight.
  /// Returns null while the delivery is still matching (no jeeber object), so
  /// the card is only mounted once a jeeber is genuinely assigned.
  static JeeberSummary? _parseJeeber(Map<String, dynamic> json) {
    final raw = json['jeeber'];
    if (raw is! Map<String, dynamic>) return null;
    final displayName = (raw['displayName'] as String?)?.trim();
    final vehicleLabel = (raw['vehicleLabel'] as String?)?.trim();
    if (displayName == null ||
        displayName.isEmpty ||
        vehicleLabel == null ||
        vehicleLabel.isEmpty) {
      return null;
    }
    final avatar = (raw['avatarUrl'] as String?)?.trim();
    return JeeberSummary(
      displayName: displayName,
      vehicleLabel: vehicleLabel,
      avatarUrl: (avatar == null || avatar.isEmpty) ? null : avatar,
    );
  }

  final String deliveryId;
  final TrackingStage currentStage;
  final Map<TrackingStage, DateTime> stageTimestamps;

  /// Terminal/side lifecycle axis parsed from the raw status token (sprint-009
  /// scenario matrix #9). `cancelled` drives the graceful terminal state on
  /// the tracking screen; `failed` keeps the active layout (dispute CTA).
  final TrackingLifecycle lifecycle;

  /// True only for a CANCELLED row (no longer collapses `expired` — P6/A3).
  bool get isCancelled => lifecycle == TrackingLifecycle.cancelled;

  /// True for a request that EXPIRED before it could complete. Distinct copy
  /// from cancelled: the two carry different fee/strike semantics (P6/A3).
  bool get isExpired => lifecycle == TrackingLifecycle.expired;

  /// `FailedNeedsEscalation` / `disputed`: parked with admin, NON-terminal —
  /// SM edges 12/13 can still resolve it to Done or cancel it, so the screen
  /// must keep polling (P6/A1).
  bool get isUnderReview => lifecycle == TrackingLifecycle.failed;

  /// Terminal for POLLING purposes: nothing can move this row again.
  /// Deliberately EXCLUDES [isUnderReview].
  bool get isPollTerminal => isCancelled || isExpired;

  /// Pre-formatted distance string from the gateway. Null until GPS fix.
  final String? distanceLabel;

  /// Estimated minutes to arrival. Null when unknown.
  final int? etaMinutes;

  /// Q-061 / D18: the LOCKED absolute delivery deadline (UTC instant) the order
  /// must arrive by — fixed at order creation, distinct from the live [etaMinutes]
  /// countdown. Null when the delivery row omits one. Rendered by the tracking
  /// panel as an "Arrives by {time}" line.
  final DateTime? deadline;

  /// T-MOB-017: Latest Jeeber GPS position from tracking feed.
  final GpsPoint? jeeberPosition;

  /// T-MOB-017: Route polyline coordinates for the map overlay.
  final List<GpsPoint> polyline;

  /// The gateway's verdict that [jeeberPosition] is older than
  /// `Tracking:StaleThreshold` (default 2 min) — the `stale` field on
  /// `TrackingPolylineDto`
  /// (`jeeb-gateway/src/JeebGateway/Controllers/LocationController.cs:316`).
  ///
  /// The NEGATIVE control of the courier-marker P0 rides on this: a marker
  /// pinned where the jeeber was ten minutes ago is worse than no marker,
  /// because it reads as live. [markerIsLive] is what the map asks.
  final bool positionStale;

  /// Age of [jeeberPosition] in seconds (`secondsSinceUpdate`,
  /// `LocationController.cs:317`). Null when the gateway holds no fix at all —
  /// which is a DIFFERENT state from "holds a stale one", and the screen is
  /// allowed to say so.
  final double? positionAgeSeconds;

  /// The gateway's EXPLICIT freshness verdict (`positionStatus`), or null when
  /// the response carried none.
  ///
  /// Null means "this gateway did not tell us", not "everything is fine": every
  /// read that goes through [DeliveryTrackingInfo.fromTrackingJson] fills it in
  /// (deriving it when the field is absent), so in practice only hand-built
  /// snapshots — tests, the demo repo, devtool seams — leave it null, and those
  /// keep the legacy [positionStale] behaviour unchanged.
  final PositionFreshness? positionStatus;

  /// Whether the map may draw a courier marker: there is a fix AND the gateway
  /// says it is fresh. Everything that renders a marker must go through this,
  /// so "no phantom marker" is one predicate rather than a convention.
  ///
  /// Two clauses, and the second is not redundant with the first. The gateway
  /// sets `stale:true` for BOTH `stale` and `lost`, so today [positionStale]
  /// alone would already answer correctly — but that is a property of one
  /// server's current arithmetic, not a contract. Asking the verdict DIRECTLY
  /// means a snapshot that ever arrives with `positionStatus:"lost"` and a
  /// stray `stale:false` still cannot paint a live pin.
  bool get markerIsLive =>
      jeeberPosition != null &&
      !positionStale &&
      !(positionStatus?.isUnvouched ?? false);

  /// True when the gateway has told us, in so many words, that it lost this
  /// courier: an age with no coordinates. The screen owes the customer an
  /// explanation in this state — it is the one case where the marker vanishes
  /// for a reason the customer cannot infer from anything else on screen.
  bool get positionLost => positionStatus?.isLost ?? false;

  /// The PUBLIC matched-Jeeber slice (display name, vehicle, avatar) surfaced
  /// once a jeeber is assigned. Null while the delivery is still matching — the
  /// tracking screen only mounts the Jeeber card when this is non-null, so the
  /// misleading "looking for a Jeeber…" placeholder never shows on an already
  /// GPS-streaming delivery.
  final JeeberSummary? jeeber;

  /// JM-032 / JM-031 pinned-summary fields, parsed from the delivery row by
  /// [DeliveryTrackingInfo.fromDeliveryJson]. Null on the legacy tracking-feed
  /// shape (the pinned header simply hides absent fields).

  /// The originating request id (drives `order_summary_open_chat` fallback).
  final String? requestId;

  /// The 1:1 conversation id for the accepted order (chat CTA target).
  final String? conversationId;

  /// Accepted COD price the customer pays in cash on delivery (D11).
  final double? price;

  /// ISO currency code for [price] (e.g. `USD`).
  final String? currency;

  /// Display name of the matched Jeeber on the pinned summary.
  final String? jeeberName;

  /// Tier id/label of the accepted order (e.g. `express`).
  final String? tier;

  /// One-line summary of what was ordered (the delivery/request title).
  final String? itemSummary;

  /// True once the row carries enough to render the `order_summary_pinned`
  /// header (price + jeeber name). Avoids mounting an empty summary strip.
  bool get hasSummary => price != null && (jeeberName?.isNotEmpty ?? false);

  /// True when the delivery has reached its terminal delivered state, so the
  /// tracking screen auto-advances to `delivered-receipt-confirm` (JM-033, D70).
  bool get isDelivered => currentStage == TrackingStage.delivered;

  static TrackingStage _parseStage(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
      case 'pending':
      case 'matched':
        return TrackingStage.ordered;
      case 'picked':
      case 'picked_up':
      case 'pickedup':
        return TrackingStage.picked;
      case 'intransit':
      case 'in_transit':
      case 'in transit':
      // DeliveryStatusAlias: legacy `heading_off` ⇒ InTransit (ADR-002 §3).
      case 'heading_off':
      case 'headingoff':
        return TrackingStage.inTransit;
      case 'atdoor':
      case 'at_door':
      case 'at door':
        return TrackingStage.atDoor;
      case 'delivered':
      // Mock SM-1 terminal status is `Done` (delivery-service SM1_TRANSITIONS);
      // both map to the delivered step + auto-advance to the receipt prompt.
      case 'done':
      case 'completed':
      // DeliveryStatusAlias: `rated` is a ratings-context concern that reads
      // as Done for delivery-status purposes (ADR-002 §3).
      case 'rated':
        return TrackingStage.delivered;
      default:
        return TrackingStage.ordered;
    }
  }

  /// Parses the terminal/side lifecycle axis from the same raw token as
  /// [_parseStage]. Canonical `Cancelled` + legacy `cancelled`/`canceled` are
  /// terminal cancelled; the request-lifecycle `Expired` is its OWN terminal
  /// arm (P6/A3 — cancel and expire carry different fee/strike semantics);
  /// `FailedNeedsEscalation` + legacy `disputed` are the admin-parked side
  /// state. Everything else — including unknown tokens — is an active forward
  /// stage (defensive parse, 40_GUARDRAILS_ARCH §4).
  static TrackingLifecycle _parseLifecycle(String status) {
    switch (status.toLowerCase().replaceAll('_', '')) {
      case 'cancelled':
      case 'canceled':
        return TrackingLifecycle.cancelled;
      case 'expired':
        return TrackingLifecycle.expired;
      case 'failedneedsescalation':
      case 'disputed':
        return TrackingLifecycle.failed;
      default:
        return TrackingLifecycle.active;
    }
  }

  /// Maps the 5-stage internal lifecycle onto the 3-stage Figma stepper
  /// (Ordered / Picked / In transit). `atDoor` and `delivered` both land on
  /// the third stage so the panel reads "In transit" through arrival.
  int get trackingStepIndex {
    switch (currentStage) {
      case TrackingStage.ordered:
        return 0;
      case TrackingStage.picked:
        return 1;
      case TrackingStage.inTransit:
      case TrackingStage.atDoor:
      case TrackingStage.delivered:
        return 2;
    }
  }

  /// JM-032: maps the lifecycle onto the canonical 4-step blueprint stepper
  /// (Ordered → Picked → In Transit → Delivered, D70). `atDoor` lands on the
  /// In-Transit step (the courier is en route to the door); `delivered` lands on
  /// the final step. Returned as the index of the CURRENT step (0-based).
  ///
  /// **Recorded product decision (P6/A5).** At-Door does NOT get a fifth step —
  /// the customer keeps the 4-step blueprint. Instead, when the row is at the
  /// door `OrderTrackingStepper` relabels the third step "At Door" while its
  /// Semantics identifier stays `tracking_step_in_transit` (no Maestro/E2E
  /// churn). The collapse below is therefore deliberate, not an oversight.
  int get trackingStepIndex4 {
    switch (currentStage) {
      case TrackingStage.ordered:
        return 0;
      case TrackingStage.picked:
        return 1;
      case TrackingStage.inTransit:
      case TrackingStage.atDoor:
        return 2;
      case TrackingStage.delivered:
        return 3;
    }
  }

  /// JEBV4-269: overlays the live Jeeber position + route [polyline] (read from
  /// the gateway's `GET /deliveries/{id}/tracking` snapshot) onto the
  /// stage-driving snapshot the tracking screen polls from the delivery row.
  /// Every other field is preserved verbatim — this is the merge that feeds the
  /// live map marker without disturbing the stepper / pinned-summary fields the
  /// delivery-row read already populated. Returns an identical instance
  /// (Equatable-equal, so no rebuild) when the overlay carries no new position.
  DeliveryTrackingInfo withLivePosition({
    GpsPoint? jeeberPosition,
    List<GpsPoint> polyline = const [],
    bool stale = false,
    double? secondsSinceUpdate,
    PositionFreshness? status,
  }) {
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: currentStage,
      stageTimestamps: stageTimestamps,
      lifecycle: lifecycle,
      distanceLabel: distanceLabel,
      etaMinutes: etaMinutes,
      deadline: deadline,
      jeeberPosition: jeeberPosition ?? this.jeeberPosition,
      polyline: polyline.isNotEmpty ? polyline : this.polyline,
      jeeber: jeeber,
      requestId: requestId,
      conversationId: conversationId,
      price: price,
      currency: currency,
      jeeberName: jeeberName,
      tier: tier,
      itemSummary: itemSummary,
      // Freshness comes from the overlay, NOT from `this`: the whole point of
      // re-reading is that the previous verdict is out of date. A merge that
      // kept the old `false` would let a marker that has since gone stale keep
      // rendering as live — the exact phantom the negative control forbids.
      positionStale: stale,
      positionAgeSeconds: secondsSinceUpdate ?? positionAgeSeconds,
      // Same rule as `stale` directly above, and for the same reason: the
      // verdict belongs to the SNAPSHOT that just arrived, never to `this`.
      // A merge that kept the previous `live` would be the phantom pin
      // rebuilt one layer up.
      positionStatus: status,
    );
  }

  @override
  List<Object?> get props => [
        deliveryId,
        currentStage,
        stageTimestamps,
        lifecycle,
        distanceLabel,
        etaMinutes,
        deadline,
        jeeberPosition,
        polyline,
        jeeber,
        requestId,
        conversationId,
        price,
        currency,
        jeeberName,
        tier,
        itemSummary,
        positionStale,
        positionAgeSeconds,
        positionStatus,
      ];
}
