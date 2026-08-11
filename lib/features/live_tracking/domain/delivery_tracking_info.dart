import 'package:equatable/equatable.dart';

import '../../../core/formatting/server_time.dart';
import '../../delivery_status/domain/jeeber_summary.dart';

enum TrackingStage { ordered, picked, inTransit, atDoor, delivered }

enum TrackingLifecycle {
  active,

  cancelled,

  expired,

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

class GpsPoint extends Equatable {
  const GpsPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  List<Object?> get props => [lat, lng];
}

enum PositionFreshness {
  awaitingFirstFix,

  live,

  stale,

  lost,
}

extension PositionFreshnessWire on PositionFreshness {
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

  bool get isUnvouched =>
      this == PositionFreshness.stale || this == PositionFreshness.lost;

  bool get isLost => this == PositionFreshness.lost;
}

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
  }
  final hasPosition = json['position'] is Map;
  final stale = json['stale'] as bool? ?? false;
  final age = (json['secondsSinceUpdate'] as num?)?.toDouble();
  if (hasPosition) {
    return stale ? PositionFreshness.stale : PositionFreshness.live;
  }
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
    this.pickupPoint,
    this.dropoffPoint,
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
      positionStale: json['stale'] as bool? ?? false,
      positionAgeSeconds: (json['secondsSinceUpdate'] as num?)?.toDouble(),
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
      pickupPoint:
          _parsePoint(json['pickupLocation'] ?? json['pickup_location']),
      dropoffPoint:
          _parsePoint(json['dropoffLocation'] ?? json['dropoff_location']),
      jeeber: _parseJeeber(json),
      requestId: _str(json['requestId'] ?? json['request_id']),
      conversationId:
          _str(json['conversationId'] ?? json['conversation_id']),
      price: _money(amount),
      currency: _currency(amount),
      jeeberName: _str(json['jeeberName'] ?? json['jeeber_name']),
      tier: _str(json['tierId'] ?? json['tier_id'] ?? json['tier']),
      itemSummary:
          _str(json['title'] ?? json['itemSummary'] ?? json['description']),
    );
  }

  static GpsPoint? _parsePoint(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'] ?? raw['latitude'];
    final lng = raw['lng'] ?? raw['lon'] ?? raw['longitude'];
    if (lat is! num || lng is! num) return null;
    if (lat == 0 && lng == 0) return null;
    return GpsPoint(lat: lat.toDouble(), lng: lng.toDouble());
  }

  static String? _str(Object? raw) {
    if (raw == null) return null;
    final s = raw is String ? raw : raw.toString();
    final trimmed = s.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

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

  final TrackingLifecycle lifecycle;

  bool get isCancelled => lifecycle == TrackingLifecycle.cancelled;

  bool get isExpired => lifecycle == TrackingLifecycle.expired;

  bool get isUnderReview => lifecycle == TrackingLifecycle.failed;

  bool get isPollTerminal => isCancelled || isExpired;

  final String? distanceLabel;

  final int? etaMinutes;

  final DateTime? deadline;

  final GpsPoint? jeeberPosition;

  /// Route endpoints from the delivery record: they seed the map camera before
  /// the courier's first GPS fix exists (D-V2 — map used to open on Beirut).
  final GpsPoint? pickupPoint;

  final GpsPoint? dropoffPoint;

  final List<GpsPoint> polyline;

  final bool positionStale;

  final double? positionAgeSeconds;

  final PositionFreshness? positionStatus;

  bool get markerIsLive =>
      jeeberPosition != null &&
      !positionStale &&
      !(positionStatus?.isUnvouched ?? false);

  bool get positionLost => positionStatus?.isLost ?? false;

  final JeeberSummary? jeeber;

  final String? requestId;

  final String? conversationId;

  final double? price;

  final String? currency;

  final String? jeeberName;

  final String? tier;

  final String? itemSummary;

  bool get hasSummary => price != null && (jeeberName?.isNotEmpty ?? false);

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
      case 'heading_off':
      case 'headingoff':
        return TrackingStage.inTransit;
      case 'atdoor':
      case 'at_door':
      case 'at door':
        return TrackingStage.atDoor;
      case 'delivered':
      case 'done':
      case 'completed':
      case 'rated':
        return TrackingStage.delivered;
      default:
        return TrackingStage.ordered;
    }
  }

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
      pickupPoint: pickupPoint,
      dropoffPoint: dropoffPoint,
      polyline: polyline.isNotEmpty ? polyline : this.polyline,
      jeeber: jeeber,
      requestId: requestId,
      conversationId: conversationId,
      price: price,
      currency: currency,
      jeeberName: jeeberName,
      tier: tier,
      itemSummary: itemSummary,
      positionStale: stale,
      positionAgeSeconds: secondsSinceUpdate ?? positionAgeSeconds,
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
        pickupPoint,
        dropoffPoint,
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
