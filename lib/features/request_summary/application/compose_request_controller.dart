import '../../location/application/location_select_state.dart';
import '../../location/domain/saved_location.dart';
import '../../tier_selection/domain/tier.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

class ComposeRequestController {
  ComposeRequestController(this._submission);

  final RequestSubmissionService _submission;

  Tier? _tier;

  String? _recipientPhone;

  String? _description;

  String? _transcription;
  String? _audioUrl;

  void setTier(Tier tier) {
    _tier = tier;
    _recipientPhone = null;
    _description = null;
    _transcription = null;
    _audioUrl = null;
  }

  void setDescription(String? text) {
    final trimmed = text?.trim();
    _description = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  String? get description => _description;

  void setVoiceNote({String? transcription, String? audioUrl}) {
    final t = transcription?.trim();
    final a = audioUrl?.trim();
    _transcription = (t == null || t.isEmpty) ? null : t;
    _audioUrl = (a == null || a.isEmpty) ? null : a;
  }

  void setRecipientPhone(String? e164) {
    final trimmed = e164?.trim();
    _recipientPhone = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  String? get _tierId => _tier?.wireId;

  Future<String>? _inFlight;

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
    final saved = _selectedSaved(location);
    final lat = saved?.latitude ?? location.pinnedLat ?? location.gpsLat;
    final lng = saved?.longitude ?? location.pinnedLng ?? location.gpsLng;
    if (lat == null || lng == null) {
      throw const RequestSubmissionException(
        RequestSubmissionFailure.invalidInput,
      );
    }
    final address =
        saved?.address ?? saved?.label ?? _currentLocationLabel(lat, lng);

    return RequestDraft(
      description: _description ?? 'Delivery request',
      transcription: _transcription,
      audioUrl: _audioUrl,
      tierId: _tierId,
      tierName: _tier?.id.name,
      pickupLat: lat,
      pickupLng: lng,
      dropoffLat: lat,
      dropoffLng: lng,
      pickupAddress: address,
      dropoffAddress: address,
      recipientPhone: _recipientPhone,
    );
  }

  static String _currentLocationLabel(double lat, double lng) =>
      'Current location (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';

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
