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

  /// G1 (sprint-009 P0): the free-text "What do you need?" the customer typed
  /// (or dictated) on the compose step. This IS the request content — the exact
  /// string the jeeber feed card / request detail renders and prices against.
  /// Null until the compose step records one.
  String? _description;

  /// Optional voice-note evidence captured when the customer dictated the
  /// description (compose-dictation reuse of the transcription flow). Sent as
  /// the gateway `transcription` / `audioUrl` alongside the description.
  String? _transcription;
  String? _audioUrl;

  /// Records the tier the customer selected on the `request-type` step. Called
  /// by the Continue CTA before navigating to `location-select`. Resets the
  /// per-compose recipient phone AND the description/voice-note so a stale
  /// value from a previous (abandoned) compose session does not leak into this
  /// one — the location step re-seeds them from the user's entry.
  void setTier(Tier tier) {
    _tier = tier;
    _recipientPhone = null;
    _description = null;
    _transcription = null;
    _audioUrl = null;
  }

  /// Records the customer's "What do you need?" free text (G1). Trimmed;
  /// empty/blank is treated as null so the submission fallback applies only
  /// when the UI gate was genuinely bypassed (dev seams / tests).
  void setDescription(String? text) {
    final trimmed = text?.trim();
    _description = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// The recorded compose description, if any (used by the compose step to
  /// re-seed its field when the customer navigates back and forth).
  String? get description => _description;

  /// Records the dictation evidence when the description came through the
  /// voice-transcription flow: the confirmed transcript and, when the recorder
  /// produced one, the uploaded audio reference. Blank values clear.
  void setVoiceNote({String? transcription, String? audioUrl}) {
    final t = transcription?.trim();
    final a = audioUrl?.trim();
    _transcription = (t == null || t.isEmpty) ? null : t;
    _audioUrl = (a == null || a.isEmpty) ? null : a;
  }

  /// Records the recipient phone the customer entered on the location-confirm
  /// step (iter6 OTP-phone v2). [e164] should be a normalised E.164 string
  /// (`+961XXXXXXXX`) or null to clear. Empty/blank is treated as null so the
  /// submission service falls back to the resolved default phone.
  void setRecipientPhone(String? e164) {
    final trimmed = e164?.trim();
    _recipientPhone = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// The wire-side tier id request-create must echo: ONLY the server UUID
  /// preserved on [Tier.wireId] (live gateway shape, PR #64).
  ///
  /// JEBV4-300: we deliberately do NOT fall back to the [TierId] enum slug.
  /// A tier without a [Tier.serverId] comes from the bundled fallback catalog
  /// (offline/fixture), and its enum slug is NOT an id the gateway ever minted —
  /// posting it either 400s `tier-required`-style or, worse, names a tier the
  /// server does not sell. When [wireId] is null we send no `tierId` at all;
  /// the gateway accepts a tier-less create (it only skips the delivery-row
  /// seed). The primary defense is upstream — [TierSelectionCubit] now surfaces
  /// a retry instead of serving the fallback catalog — so in the live flow this
  /// getter is always a real UUID; the null path only guards dev/test seams.
  String? get _tierId => _tier?.wireId;

  /// Tracks the single outstanding `POST /requests` so a re-entrant submit
  /// (B-02b) — e.g. the confirm CTA re-tapped after backing out to the tier
  /// step and returning, where the footer's own `_submitting` guard was reset —
  /// joins the in-flight call instead of firing a second create. Cleared when
  /// the call settles so a legitimate retry after failure still works.
  Future<String>? _inFlight;

  /// Builds the [RequestDraft] from the recorded tier + the confirmed location,
  /// calls `POST /requests`, and returns the server-minted request id.
  ///
  /// Throws [RequestSubmissionException] on failure (the caller surfaces an
  /// error and stays on the location step rather than handing off `'new'`).
  ///
  /// B-02b: re-entrant while a create is in flight → returns the SAME future
  /// (the create fires exactly once).
  Future<String> submitFromLocation(LocationSelectState location) =>
      _inFlight ??= _submitOnce(location);

  Future<String> _submitOnce(LocationSelectState location) async {
    try {
      return await _submission.submit(_buildDraft(location));
    } finally {
      _inFlight = null;
    }
  }

  RequestDraft _buildDraft(LocationSelectState location) {
    // Resolve coordinates from the confirmed location. There is NO Beirut
    // fallback (JEBV4-176 / Q-060) — every pickup coordinate is a REAL point.
    // Coordinate precedence:
    //   1. a selected SAVED address's real gateway coordinates
    //      (`GET /users/:id/saved-locations`);
    //   2. the REAL map-PINNED coordinate the customer dropped on
    //      capture-location (carried on the state);
    //   3. the REAL device-GPS fix resolved for the "Current Location" option
    //      (`LocationSelectState.gpsLat/gpsLng`, set only once the OS returned
    //      a fix — the location-select Confirm CTA is gated on it, so this is
    //      non-null by the time a create is submitted).
    final saved = _selectedSaved(location);
    final lat = saved?.latitude ?? location.pinnedLat ?? location.gpsLat;
    final lng = saved?.longitude ?? location.pinnedLng ?? location.gpsLng;
    // Defensive honesty: if no real coordinate is present we REFUSE to create
    // rather than silently invent one (the gateway also 400s without
    // pickup/dropoff locations). The UI gate (`canConfirm`) makes this
    // unreachable in the live flow; it guards dev seams / misuse.
    if (lat == null || lng == null) {
      throw const RequestSubmissionException(
        RequestSubmissionFailure.invalidInput,
      );
    }
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
      // G1 (sprint-009 P0): the description is the USER'S OWN words — the
      // "What do you need?" text from the compose step. This is the content
      // the jeeber feed/detail renders and prices against. The generic
      // 'Delivery request' fallback exists ONLY because the gateway requires a
      // non-empty description; the compose UI gates Confirm on a non-empty
      // entry, so the fallback is unreachable in the live flow (dev seams /
      // tests without the field may still hit it). The old tier-derived
      // '"{Tier} delivery request"' placeholder is intentionally GONE.
      description: _description ?? 'Delivery request',
      transcription: _transcription,
      audioUrl: _audioUrl,
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
}
