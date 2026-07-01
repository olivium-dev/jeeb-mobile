import 'package:equatable/equatable.dart';

import '../../delivery_status/domain/jeeber_summary.dart';

enum TrackingStage { ordered, picked, inTransit, atDoor, delivered }

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

class DeliveryTrackingInfo extends Equatable {
  const DeliveryTrackingInfo({
    required this.deliveryId,
    required this.currentStage,
    required this.stageTimestamps,
    this.distanceLabel,
    this.etaMinutes,
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
  });

  /// T-MOB-017: Parses the TrackingPolylineDto shape returned by
  /// GET /deliveries/{id}/tracking and GET /v1/geo/jeeb/stream/{id}.
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
      distanceLabel: json['distanceLabel'] as String?,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeberPosition: pos,
      polyline: polyline,
      jeeber: _parseJeeber(json),
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
      distanceLabel: _str(json['distanceLabel']),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      jeeber: _parseJeeber(json),
      requestId: _str(json['requestId'] ?? json['request_id']),
      conversationId:
          _str(json['conversationId'] ?? json['conversation_id']),
      price: _money(amount),
      currency: _currency(amount),
      jeeberName: _str(json['jeeberName'] ?? json['jeeber_name']),
      tier: _str(json['tier']),
      itemSummary: _str(json['title'] ?? json['itemSummary']),
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
          final ts = DateTime.tryParse(entry['timestamp'] as String? ?? '');
          if (ts != null) timestamps[stage] = ts;
        }
      }
    }
    if (!timestamps.containsKey(currentStage)) {
      final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
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

  /// Pre-formatted distance string from the gateway. Null until GPS fix.
  final String? distanceLabel;

  /// Estimated minutes to arrival. Null when unknown.
  final int? etaMinutes;

  /// T-MOB-017: Latest Jeeber GPS position from tracking feed.
  final GpsPoint? jeeberPosition;

  /// T-MOB-017: Route polyline coordinates for the map overlay.
  final List<GpsPoint> polyline;

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
        return TrackingStage.delivered;
      default:
        return TrackingStage.ordered;
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

  @override
  List<Object?> get props => [
        deliveryId,
        currentStage,
        stageTimestamps,
        distanceLabel,
        etaMinutes,
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
      ];
}
