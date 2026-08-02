// Designed states for `AddressDetailFormScreen` (JM-050), in ONE place.
//
// The Screen Catalog (`lib/devtool/catalog/`) and the widget previews at the
// bottom of
// `lib/features/location/presentation/screens/address_detail_form_screen.dart`
// are two views of the same screen, and they drift the moment each keeps its
// own copy of "a saved address that looks real". This file is the single
// source of truth for both: the previews import it today, and the catalog
// entry imports it on the day someone writes one (there is none yet — this
// screen is one of the 26 with no catalog coverage).
//
// Everything here is a LOCAL fake or an inert value. Nothing reaches GetIt, Dio
// or the keychain, so a host that forgets `CatalogNetworkGuard` still cannot
// touch the wire.

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
  ///
  /// Deliberately NOT `user-client-001`: that mock id is the defect the screen
  /// records as DEFECT A, and a fixture that reuses it would make the bug look
  /// like the intended shape.
  static const String userId = 'preview-user-jm050';

  /// The point [AddressDetailFormScreenScriptedPinPicker] hands back — Sassine
  /// Square, Achrafieh. Any real coordinate does; what matters is that it is a
  /// point the *user* picked, never one the form assumed (JEBV4-176).
  static const LocationPoint pickedPoint = LocationPoint(
    latitude: 33.8869,
    longitude: 35.5218,
  );

  /// The ordinary edit path: an address saved earlier, opened again from the
  /// JM-049 manager, with every JM-050 field populated and a real pin on file.
  ///
  /// No value here may equal an `AddressFormL10n` hint. The hints are full
  /// plausible values ("4th floor, Apt 12", "Ring twice; blue door.") and
  /// `InputDecorator` keeps the hint in the tree whether or not the field is
  /// filled, so a fixture that reused one would be indistinguishable from an
  /// empty field to a reader and would match twice in a render test.
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
  ///
  /// Nothing on this screen caps a field — no `maxLength`, no counter — so this
  /// is not a synthetic worst case, it is what the form allows. The label is
  /// the one that matters most: it is a single-line field whose value is echoed
  /// by the JM-049 manager row.
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
///
/// The form's only async surface is the save, and no host can trigger it
/// without a tap — so in a still preview this repository is never called at
/// all. It exists so that the one place a save CAN start (a designer tapping
/// "Save address" in the live canvas) ends in the screen's real failure copy
/// instead of an unhandled error or, worse, a request.
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
///
/// Production builds the real launcher from the tapping context, which pushes
/// the `ofl_geo_capture` map. A host that leaves that seam null gets a live map
/// screen the moment anyone taps the CTA; this returns [result] instead, so the
/// gate the add path is really about — no Save until a REAL point is dropped —
/// can be opened by hand in the canvas without leaving the preview.
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
///
/// Subclassing rather than reimplementing is deliberate — the real class is
/// concrete, so this cannot drift out of shape — and every read getter is
/// overridden, so nothing here can reach `FlutterSecureStorage`. Both writers
/// throw: a fixture that persisted a token would leak canvas state into a real
/// signed-in session on the same device.
///
/// This is what makes the screen's cold-mount state (`FutureBuilder` on
/// `AuthTokenStore.userId`, still waiting) a state a host can hold still and
/// look at, instead of a few hundred milliseconds nobody ever sees.
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
