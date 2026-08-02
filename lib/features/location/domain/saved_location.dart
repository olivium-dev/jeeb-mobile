import 'package:equatable/equatable.dart';

enum SavedLocationCategory { home, work, other }

class SavedLocation extends Equatable {
  const SavedLocation({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.address,
    this.isDefault = false,
    this.building,
    this.floorApt,
    this.deliveryNotes,
    this.codPhone,
  });

  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final SavedLocationCategory category;
  final String? address;

  final bool isDefault;

  final String? building;
  final String? floorApt;
  final String? deliveryNotes;
  final String? codPhone;

  @override
  List<Object?> get props => [
        id,
        label,
        latitude,
        longitude,
        category,
        isDefault,
        building,
        floorApt,
        deliveryNotes,
        codPhone,
      ];
}
