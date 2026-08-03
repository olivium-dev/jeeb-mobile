import '../domain/address_form_repository.dart';
import '../domain/saved_location.dart';

class FakeAddressFormRepository implements AddressFormRepository {
  const FakeAddressFormRepository({this.failWith});

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
