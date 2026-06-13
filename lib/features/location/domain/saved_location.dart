import 'package:equatable/equatable.dart';

/// Categories a saved location can belong to.
enum SavedLocationCategory { home, work, other }

/// A user-saved delivery/pickup location returned by
/// `GET /v1/users/me/saved-locations` (T-MOB-012).
class SavedLocation extends Equatable {
  const SavedLocation({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.address,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final SavedLocationCategory category;
  final String? address;

  @override
  List<Object?> get props => [id, label, latitude, longitude, category];
}
