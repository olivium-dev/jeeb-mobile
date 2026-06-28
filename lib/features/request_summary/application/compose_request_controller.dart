import '../../location/application/location_select_state.dart';
import '../../location/domain/saved_location.dart';
import '../../tier_selection/domain/tier.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

/// Carries the in-progress compose selection across the create-flow screens and
/// performs the actual `POST /requests` create at the location-confirm step.
///
/// WHY THIS EXISTS (iter6 B11): the create flow used to short-circuit
/// `location-select → order-chat` by handing off the literal placeholder id
/// `'new'` (`client_location_screen.dart` → `chat-detail` id `'new'`). The
/// order-chat compose then broadcast `requestId='new'` WITHOUT ever calling
/// `POST /requests`, so no request was ever created on-device (matching 422 on
/// `'new'`, chat 404 on conversation `'new'`). The backend create endpoint
/// itself works perfectly (`POST /requests` → 201), so the only gap was that
/// the UI never called it. This controller closes that gap: the tier-selection
/// screen records the chosen [Tier] here, and the location-confirm step calls
/// [submitFromLocation] to mint the REAL request id, which then drives the
/// order-chat/broadcast (no more `'new'`).
///
/// Registered as a lazy singleton so the tier step (writer) and the location
/// step (reader/submitter) share one instance even though they own separate
/// cubits with no common ancestor in the widget tree (the tier cubit is gone
/// by the time location-select mounts). This avoids threading a route `extra`
/// through the saved-addresses / capture-location sub-navigations where it
/// would be lost.
class ComposeRequestController {
  ComposeRequestController(this._submission);

  final RequestSubmissionService _submission;

  /// The tier the customer picked on `request-type` (carries the live
  /// gateway UUID on [Tier.wireId] — the exact value request-create echoes,
  /// see iter6 B2 / PR #64). Null until the tier step records a selection.
  Tier? _tier;

  /// The recipient phone (E.164) the customer entered on the location-confirm
  /// step (iter6 OTP-phone v2). Threaded into [RequestDraft.recipientPhone],
  /// which the submission service sends as the gateway `recipientPhone` — the
  /// EXACT value the at-door handover OTP issue/verify reads from the request
  /// store. Null until the location step records one; the submission service
  /// then falls back to the resolver default (the client's own profile phone).
  String? _recipientPhone;

  /// Beirut downtown — the safe non-null fallback when the chosen location
  /// carries no coordinates (the "current location" / freshly-pinned options do
  /// not capture a real lat/lng in the installed build — there is no GPS/map
  /// plugin wired yet). The gateway REQUIRES both `pickupLocation` and
  /// `dropoffLocation` as `{lat,lng}` (verified live: a body without them →
  /// 400 `location-required`), so a non-null pair is mandatory to create at
  /// all. Mirrors the existing `address_detail_form_screen` fallback so we do
  /// not invent a new constant.
  static const double _fallbackLat = 33.8886;
  static const double _fallbackLng = 35.4955;

  /// Records the tier the customer selected on the `request-type` step. Called
  /// by the Continue CTA before navigating to `location-select`. Resets the
  /// per-compose recipient phone so a stale value from a previous (abandoned)
  /// compose session does not leak into this one — the location step re-seeds
  /// it from the profile pre-fill / user entry.
  void setTier(Tier tier) {
    _tier = tier;
    _recipientPhone = null;
  }

  /// Records the recipient phone the customer entered on the location-confirm
  /// step (iter6 OTP-phone v2). [e164] should be a normalised E.164 string
  /// (`+961XXXXXXXX`) or null to clear. Empty/blank is treated as null so the
  /// submission service falls back to the resolved default phone.
  void setRecipientPhone(String? e164) {
    final trimmed = e164?.trim();
    _recipientPhone = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// The wire-side tier id request-create must echo. Prefers the server UUID
  /// preserved on [Tier.wireId] (live gateway shape, PR #64); falls back to the
  /// enum name only if no wireId was captured (e.g. an offline/fixture catalog)
  /// so we never POST a null tier.
  String? get _tierId => _tier?.wireId ?? _tier?.id.name;

  /// Builds the [RequestDraft] from the recorded tier + the confirmed location,
  /// calls `POST /requests`, and returns the server-minted request id.
  ///
  /// Throws [RequestSubmissionException] on failure (the caller surfaces an
  /// error and stays on the location step rather than handing off `'new'`).
  Future<String> submitFromLocation(LocationSelectState location) {
    final draft = _buildDraft(location);
    return _submission.submit(draft);
  }

  RequestDraft _buildDraft(LocationSelectState location) {
    // Resolve coordinates from the confirmed location. A selected saved address
    // carries real gateway coordinates (`GET /users/:id/saved-locations`); the
    // current-location / pinned options have none captured in the installed
    // build, so we fall back to the Beirut constant to satisfy the gateway's
    // required-coordinates contract.
    // Coordinate precedence (S0-REQ-03):
    //   1. a selected SAVED address's real gateway coordinates;
    //   2. the REAL map-PINNED coordinate the customer dropped on
    //      capture-location (now carried on the state — previously dropped, so
    //      the pin silently became Beirut);
    //   3. the Beirut constant, used ONLY when neither a saved nor a pinned
    //      coordinate exists (e.g. the GPS-less "Current Location" default), so
    //      the gateway's required-coordinates contract is still satisfied.
    final saved = _selectedSaved(location);
    final lat = saved?.latitude ?? location.pinnedLat ?? _fallbackLat;
    final lng = saved?.longitude ?? location.pinnedLng ?? _fallbackLng;
    // ADDRESS (iter6 feed-drop fix): the gateway stores pickup/dropoff `address`
    // and the jeeber feed parser (`dio_request_feed_repository._parseLocation`)
    // DROPS any row whose location has a null `address` — so an order created
    // via "Current Location" / the map pin (no Saved address selected) used to
    // get a null address and vanish from every jeeber's feed (no jeeber could
    // ever see it). A Saved address yields its real label/address; for the
    // current/pinned path we have no reverse-geocode plugin wired, so we carry a
    // sensible human-readable label that embeds the coordinates. This keeps the
    // address non-null so the feed parser retains the row, and the label still
    // tells the jeeber where the point is (lat,lng) until reverse-geocoding
    // lands. NOTE: replace `_currentLocationLabel` with a real reverse-geocoded
    // street address once a maps/geocoding key is available.
    final address =
        saved?.address ?? saved?.label ?? _currentLocationLabel(lat, lng);

    return RequestDraft(
      // The order detail is composed as the first order-chat message after the
      // request exists; seed a non-empty description so the create succeeds
      // (the gateway accepts it and the chat refines it).
      description: _tier == null
          ? 'Delivery request'
          : '${_titleCase(_tier!.id.name)} delivery request',
      tierId: _tierId,
      tierName: _tier?.id.name,
      // Single confirmed point in this step: use it as both pickup and dropoff
      // origin so both required coordinate pairs are present. The dropoff is
      // refined in order-chat / the map step (no dropoff picker in this leg).
      pickupLat: lat,
      pickupLng: lng,
      dropoffLat: lat,
      dropoffLng: lng,
      pickupAddress: address,
      dropoffAddress: address,
      // iter6 OTP-phone v2: the recipient phone the customer entered on the
      // location-confirm step. The submission service sends it as the gateway
      // `recipientPhone` (winning over the resolver default) so the request
      // store row — which the at-door OTP issue/verify reads — is non-null.
      recipientPhone: _recipientPhone,
    );
  }

  /// A non-null, human-readable address label for the current-location / pinned
  /// path (no Saved address selected, no reverse-geocode plugin wired). Embeds
  /// the coordinates so (a) the gateway stores a non-null `address` — the jeeber
  /// feed parser keeps the row instead of dropping it — and (b) the jeeber can
  /// still see where the point is. Coordinates are formatted to 4 dp (~11 m),
  /// enough to identify a pickup without implying false precision.
  static String _currentLocationLabel(double lat, double lng) =>
      'Current location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';

  /// The selected saved address, or null when the choice is current/pinned (or
  /// no saved address matches the selected id).
  SavedLocation? _selectedSaved(LocationSelectState location) {
    if (location.choiceKind != LocationChoiceKind.saved) return null;
    final id = location.selectedSavedId;
    if (id == null) return null;
    for (final a in location.savedAddresses) {
      if (a.id == id) return a;
    }
    return null;
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
