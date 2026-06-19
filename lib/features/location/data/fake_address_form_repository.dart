import '../domain/address_form_repository.dart';
import '../domain/saved_location.dart';

/// In-memory [AddressFormRepository] — a constructor test seam ONLY
/// (40_GUARDRAILS_ARCH §6 / DO-NOT: never registered in DI). Lets widget tests
/// + the `address-detail` route render the form end-to-end without a backend
/// (e.g. `w1_routes_resolve_test` mounts with no Dio registered).
class FakeAddressFormRepository implements AddressFormRepository {
  const FakeAddressFormRepository({this.failWith});

  /// When non-null, both ops throw — exercises the cubit's error branch.
  final AddressFormFailure? failWith;

  SavedLocation _echo(String id, AddressFormDraft draft) {
    final failure = failWith;
    if (failure != null) throw AddressFormException(failure);
    return SavedLocation(
      id: id,
      label: draft.label,
      latitude: draft.latitude,
      longitude: draft.longitude,
      category: draft.category,
      address: draft.address,
      isDefault: draft.isDefault,
      building: draft.building,
      floorApt: draft.floorApt,
      deliveryNotes: draft.deliveryNotes,
      codPhone: draft.codPhone,
    );
  }

  @override
  Future<SavedLocation> create({
    required String userId,
    required AddressFormDraft draft,
  }) async {
    return _echo('addr-${draft.label.toLowerCase()}', draft);
  }

  @override
  Future<SavedLocation> update({
    required String userId,
    required String id,
    required AddressFormDraft draft,
  }) async {
    return _echo(id, draft);
  }
}
