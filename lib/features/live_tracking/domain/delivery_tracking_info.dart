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

class DeliveryTrackingInfo extends Equatable {
  const DeliveryTrackingInfo({
    required this.deliveryId,
    required this.currentStage,
    required this.stageTimestamps,
  });

  final String deliveryId;
  final TrackingStage currentStage;
  final Map<TrackingStage, DateTime> stageTimestamps;

  factory DeliveryTrackingInfo.fromJson(
    String deliveryId,
    Map<String, dynamic> json,
  ) {
    final status = json['status'] as String? ?? 'Ordered';
    final currentStage = _parseStage(status);
    final timestamps = <TrackingStage, DateTime>{};

    final history = json['statusHistory'] as List<dynamic>?;
    if (history != null) {
      for (final entry in history) {
        if (entry is Map<String, dynamic>) {
          final stage = _parseStage(entry['status'] as String? ?? '');
          final ts = DateTime.tryParse(entry['timestamp'] as String? ?? '');
          if (ts != null) {
            timestamps[stage] = ts;
          }
        }
      }
    }

    // Ensure current stage has a timestamp
    if (!timestamps.containsKey(currentStage)) {
      final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
      if (updatedAt != null) {
        timestamps[currentStage] = updatedAt;
      }
    }

    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: currentStage,
      stageTimestamps: timestamps,
    );
  }

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

  @override
  List<Object?> get props => [deliveryId, currentStage, stageTimestamps];
}
