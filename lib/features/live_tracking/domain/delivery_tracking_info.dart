import 'package:equatable/equatable.dart';

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

  @override
  List<Object?> get props => [
        deliveryId,
        currentStage,
        stageTimestamps,
        distanceLabel,
        etaMinutes,
        jeeberPosition,
        polyline,
      ];
}
