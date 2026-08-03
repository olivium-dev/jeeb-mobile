class CourierPositionFix {
  const CourierPositionFix({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.timestamp,
    this.jeeberId,
  });

  final double lat;
  final double lng;

  final double? accuracy;

  final DateTime? timestamp;

  final String? jeeberId;

  @override
  String toString() => 'CourierPositionFix($lat, $lng)';
}

abstract class CourierPositionChannel {
  Future<Stream<CourierPositionFix>?> open({required String deliveryId});
}
