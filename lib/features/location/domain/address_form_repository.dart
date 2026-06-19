import 'saved_location.dart';

/// JM-050 — address-detail-form persistence contract.
///
/// Deliberately SEPARATE from [SavedLocationRepository] (the JM-049 CRUD
/// manager) so the form can carry the full address-detail field set (building /
/// floor-apt / delivery-notes / COD phone / default flag) WITHOUT changing the
/// JM-049 interface — whose existing `saveLocation`/`updateLocation` signatures
/// are pinned by its widget tests (40_GUARDRAILS_ARCH §1, distinct features).
///
/// Pure Dart — no Flutter / Dio / GetIt (40_GUARDRAILS_ARCH §1).
abstract class AddressFormRepository {
  /// Creates a new saved address.
  /// Endpoint: `POST /users/:userId/saved-locations` (201).
  /// Throws [AddressFormException] on failure.
  Future<SavedLocation> create({
    required String userId,
    required AddressFormDraft draft,
  });

  /// Updates an existing saved address.
  /// Endpoint: `PUT /users/:userId/saved-locations/:id`.
  /// Throws [AddressFormException] on failure.
  Future<SavedLocation> update({
    required String userId,
    required String id,
    required AddressFormDraft draft,
  });
}

/// The full address-detail-form payload (JM-050 AC fields).
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

/// Typed failure surface for the address form (40_GUARDRAILS_ARCH §4).
enum AddressFormFailure {
  /// Connection / timeout transport error.
  network,

  /// Server rejected the save (e.g. 422 cap reached) or any other error.
  unknown,
}

/// Thrown by [AddressFormRepository] implementations; the cubit maps it to copy.
class AddressFormException implements Exception {
  const AddressFormException(this.failure, [this.message]);

  final AddressFormFailure failure;
  final String? message;
}
