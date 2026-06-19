import 'package:equatable/equatable.dart';

/// Categories a saved location can belong to.
enum SavedLocationCategory { home, work, other }

/// A user-saved delivery/pickup location returned by
/// `GET /users/:userId/saved-locations` (T-MOB-012 / JM-049 / JM-050).
///
/// [isDefault] marks the address the manager flags with the
/// `saved_address_default_badge` (JM-049 AC; the `has_saved_addresses` seam
/// seeds `Home` with `isDefault:true`, `Office` with `isDefault:false` —
/// 63_W1_TEST_PLAN §4.1). The mock surfaces it as both `isDefault` and
/// `is_default`; the repository tolerates either (40_GUARDRAILS_ARCH §4).
///
/// JM-050 adds the address-detail-form fields ([building] / [floorApt] /
/// [deliveryNotes] / [codPhone]). All are **optional with safe defaults**, so
/// every existing construction site (`fake_location_select_repository.dart`,
/// the JM-024 location-select parse, the JM-049 CRUD repo + its tests) compiles
/// unchanged — only the form reads/writes them. Wire-field names mirror the
/// mock seed (`journey-seed.ts seedHasSavedAddresses`: `building`, `floorApt`,
/// `deliveryNotes`, `codPhone`).
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

  /// True for the user's default delivery address (JM-049 default badge).
  /// Defaults to `false` so every existing call site stays source-compatible.
  final bool isDefault;

  /// JM-050 address-detail-form fields (all optional).
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
