// Designed states for `AddressDetailFormScreen` (JM-050), in ONE place.

import 'dart:async';

import '../../../core/network/auth_token_store.dart';
import '../../../features/location/data/location_repository.dart';
import '../../../features/location/data/map_picker_launcher.dart';
import '../../../features/location/domain/address_form_repository.dart';
import '../../../features/location/domain/saved_location.dart';

/// Inert values the address-detail form can be opened on.
class AddressDetailFormScreenFixtures {
  const AddressDetailFormScreenFixtures._();

  /// The owning user id a host injects to skip the keychain read.
  /// Deliberately NOT `user-client-001`: that mock id is the defect the screen
  static const String userId = 'preview-user-jm050';

  /// The point [AddressDetailFormScreenScriptedPinPicker] hands back — Sassine
  /// Square, Achrafieh. Any real coordinate does; what matters is that it is a
  static const LocationPoint pickedPoint = LocationPoint(
    latitude: 33.8869,
    longitude: 35.5218,
  );

  /// The ordinary edit path: an address saved earlier, opened again from the
  /// JM-049 manager, with every JM-050 field populated and a real pin on file.
  static const SavedLocation savedHome = SavedLocation(
    id: 'addr-home-01',
    label: 'Home',
    latitude: 33.8938,
    longitude: 35.5018,
    category: SavedLocationCategory.home,
    address: 'Rue Gouraud, Gemmayzeh, Beirut',
    isDefault: true,
    building: 'Nassif Building',
    floorApt: '2nd floor, Apt 5',
    deliveryNotes: 'Blue gate behind the pharmacy — call before you ring.',
    codPhone: '+961 3 000 077',
  );

  /// The layout ceiling: every field at the longest a customer plausibly types.
  /// Nothing on this screen caps a field — no `maxLength`, no counter — so this
  static const SavedLocation longestContent = SavedLocation(
    id: 'addr-long-02',
    label: "Grandmother's apartment above the Sunday vegetable market",
    latitude: 33.8547,
    longitude: 35.5015,
    category: SavedLocationCategory.other,
    address: 'Corniche el Mazraa, facing the old municipality building, Beirut',
    building: 'Immeuble Chahine & Fils — the tall sand-coloured one, not the '
        'new glass tower beside it',
    floorApt: 'Mezzanine between the 3rd and 4th floors, Apt 12B (left)',
    deliveryNotes: 'The building has two entrances: use the one on the side '
        'street, the main door is locked after 6pm. Lift is out of service, so '
        'please take the stairs on the right. If nobody answers, leave it with '
        'the concierge and send a photo on the chat.',
    codPhone: '+961 3 000 077 / +961 71 448 902',
  );
}

/// Fails every save the way a dropped connection does.
/// The form's only async surface is the save, and no host can trigger it
/// without a tap — so in a still preview this repository is never called at
class AddressDetailFormScreenOfflineRepository implements AddressFormRepository {
  const AddressDetailFormScreenOfflineRepository();

  @override
  Future<SavedLocation> create({
    required String userId,
    required AddressFormDraft draft,
  }) async =>
      throw const AddressFormException(AddressFormFailure.network);

  @override
  Future<SavedLocation> update({
    required String userId,
    required String id,
    required AddressFormDraft draft,
  }) async =>
      throw const AddressFormException(AddressFormFailure.network);
}

/// Stands in for `GoogleMapPickerLauncher` so "Edit pin" opens nothing.
/// Production builds the real launcher from the tapping context, which pushes
/// the `ofl_geo_capture` map. A host that leaves that seam null gets a live map
class AddressDetailFormScreenScriptedPinPicker implements MapPickerLauncher {
  const AddressDetailFormScreenScriptedPinPicker([
    this.result = AddressDetailFormScreenFixtures.pickedPoint,
  ]);

  /// The point the picker resolves with; `null` models a cancelled pick.
  final LocationPoint? result;

  @override
  Future<LocationPoint?> pickOnMap({LocationPoint? initial}) async => result;
}

/// An [AuthTokenStore] whose reads never resolve.
/// Subclassing rather than reimplementing is deliberate — the real class is
/// concrete, so this cannot drift out of shape — and every read getter is
class AddressDetailFormScreenPendingAuthTokenStore extends AuthTokenStore {
  AddressDetailFormScreenPendingAuthTokenStore([Future<String?>? pending])
      : _pending = pending ?? Completer<String?>().future;

  final Future<String?> _pending;

  @override
  Future<String?> get userId => _pending;

  @override
  Future<String?> get accessToken => _pending;

  @override
  Future<String?> get refreshToken => _pending;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async =>
      throw UnsupportedError('fixtures never write to the keychain');

  @override
  Future<void> clear() async =>
      throw UnsupportedError('fixtures never write to the keychain');
}
