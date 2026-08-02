import 'saved_location.dart';

abstract class AddressFormRepository {
  Future<SavedLocation> create({
    required String userId,
    required AddressFormDraft draft,
  });

  Future<SavedLocation> update({
    required String userId,
    required String id,
    required AddressFormDraft draft,
  });
}

class AddressFormDraft {
  const AddressFormDraft({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.address,
    this.building,
    this.floorApt,
    this.deliveryNotes,
    this.codPhone,
    this.isDefault = false,
  });

  final String label;
  final double latitude;
  final double longitude;
  final SavedLocationCategory category;
  final String? address;
  final String? building;
  final String? floorApt;
  final String? deliveryNotes;
  final String? codPhone;
  final bool isDefault;
}

enum AddressFormFailure {
  network,

  unknown,
}

class AddressFormException implements Exception {
  const AddressFormException(this.failure, [this.message]);

  final AddressFormFailure failure;
  final String? message;
}
