import 'package:equatable/equatable.dart';

/// A pickup or dropoff location displayed on the delivery status screen.
///
/// Kept intentionally minimal — the real geocoding payload (lat/lng,
/// formatted address, place id) lands with the request creation flow in
/// jeeb-gateway. The status screen only needs the human-readable label and
/// an optional sub-label (apartment/floor) for display.
class DeliveryAddress extends Equatable {
  const DeliveryAddress({
    required this.label,
    this.detail,
  });

  /// Primary address line — e.g. "Hamra Main St, Beirut".
  final String label;

  /// Optional second line — floor / apartment / landmark.
  final String? detail;

  @override
  List<Object?> get props => [label, detail];
}
