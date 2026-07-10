import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/locale/locale_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_models.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../../features/jeeber_request_feed/presentation/request_feed_screen.dart';
import '../../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../../features/kyc/domain/kyc_contract_template.dart';
import '../../../features/kyc/domain/kyc_form_schema.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/kyc/presentation/kyc_wizard_screen.dart';
import '../../../features/language/presentation/screens/language_settings_screen.dart';
import '../../../features/live_tracking/application/live_tracking_cubit.dart';
import '../../../features/live_tracking/data/demo_live_tracking_repository.dart';
import '../../../features/live_tracking/domain/delivery_tracking_info.dart';
import '../../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../../features/live_tracking/presentation/live_tracking_screen.dart';
import '../../../features/location/cubit/location_picker_cubit.dart';
import '../../../features/location/data/fake_location_select_repository.dart';
import '../../../features/location/data/location_repository.dart';
import '../../../features/location/domain/location_select_repository.dart';
import '../../../features/location/domain/saved_location.dart';
import '../../../features/location/domain/saved_location_repository.dart';
import '../../../features/location/presentation/capture_location_screen.dart';
import '../../../features/location/presentation/client_location_screen.dart';
import '../../../features/location/presentation/location_picker_screen.dart';
import '../../../features/location/presentation/saved_locations_screen.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../catalog_models.dart';

/// Batch 05 — jeeber_request_feed, kyc, language, live_tracking, location,
/// masked_call.
///
/// masked_call has NO `presentation/*_screen.dart` — only `MaskedCallButton`
/// (a small inline widget, not a screen) — so it is intentionally not
/// cataloged here (DoD §6).
List<CatalogEntry> get batch05Entries => <CatalogEntry>[
      // ── jeeber_request_feed ──────────────────────────────────────────────
      const CatalogEntry(
        feature: 'jeeber_request_feed',
        screen: 'RequestFeedScreen',
        states: [
          CatalogState('Incoming request', _feedIncoming),
          CatalogState('Pending offer (awaiting client reply)', _feedPending),
          CatalogState('Accepted deliveries', _feedAccepted),
          CatalogState('Empty feed', _feedEmpty),
          CatalogState('Load error', _feedError),
        ],
      ),

      // ── kyc ───────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'kyc',
        screen: 'KycWizardScreen',
        states: [
          CatalogState('Identity capture (fresh)', _kycIdentity),
          CatalogState('Status — pending', _kycStatusPending),
          CatalogState('Status — approved', _kycStatusApproved),
          CatalogState('Status — rejected', _kycStatusRejected),
          CatalogState('Schema load error', _kycSchemaError),
        ],
      ),

      // ── language ─────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'language',
        screen: 'LanguageSettingsScreen',
        states: [
          CatalogState('English selected', _languageEnglish),
          CatalogState('Arabic selected', _languageArabic),
        ],
      ),

      // ── live_tracking ────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'live_tracking',
        screen: 'LiveTrackingScreen',
        states: [
          CatalogState('In transit', _trackingInTransit),
          CatalogState('At door', _trackingAtDoor),
          CatalogState('GPS / network error', _trackingError),
        ],
      ),

      // ── location ─────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'location',
        screen: 'CaptureLocationScreen',
        states: [
          CatalogState('Idle (map + pin CTA)', _captureLocationIdle),
          CatalogState('Confirming (busy CTA)', _captureLocationConfirming),
        ],
      ),
      const CatalogEntry(
        feature: 'location',
        screen: 'ClientLocationScreen',
        states: [
          CatalogState('With saved addresses', _clientLocationWithSaved),
          CatalogState('No saved addresses', _clientLocationEmpty),
          CatalogState('Saved-addresses load error', _clientLocationError),
        ],
      ),
      const CatalogEntry(
        feature: 'location',
        screen: 'LocationPickerScreen',
        states: [
          CatalogState('Pickup (initial)', _locationPickerPickup),
          CatalogState('Dropoff (pickup confirmed)', _locationPickerDropoff),
        ],
      ),
      const CatalogEntry(
        feature: 'location',
        screen: 'SavedLocationsScreen',
        states: [
          CatalogState('Loaded (Home + Office)', _savedLocationsLoaded),
          CatalogState('Empty', _savedLocationsEmpty),
          CatalogState('Load error', _savedLocationsError),
        ],
      ),
    ];

// ═══════════════════════════════════════════════════════════════════════════
// jeeber_request_feed
// ═══════════════════════════════════════════════════════════════════════════

Widget _feedIncoming(BuildContext _) => RequestFeedScreen(
      cubit: RequestFeedCubit(
        repository: SeededRequestFeedRepository(DevJeeberFeedFixtures.incoming()),
      )..start(),
    );

Widget _feedPending(BuildContext _) => RequestFeedScreen(
      cubit: RequestFeedCubit(
        repository: SeededRequestFeedRepository(DevJeeberFeedFixtures.pending()),
      )..start(),
    );

Widget _feedAccepted(BuildContext _) => RequestFeedScreen(
      cubit: RequestFeedCubit(
        repository: SeededRequestFeedRepository(DevJeeberFeedFixtures.replies()),
      )..start(),
    );

Widget _feedEmpty(BuildContext _) => RequestFeedScreen(
      cubit: RequestFeedCubit(
        repository: SeededRequestFeedRepository(const []),
      )..start(),
    );

Widget _feedError(BuildContext _) => RequestFeedScreen(
      cubit: RequestFeedCubit(
        repository: const _ErrorRequestFeedRepository(),
      )..start(),
    );

/// Local fake: `refresh()` always throws so the cubit lands on
/// [RequestFeedStatus.error] with an empty feed (DoD §2 — no network).
class _ErrorRequestFeedRepository implements RequestFeedRepository {
  const _ErrorRequestFeedRepository();

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<String> get cancellations => const Stream<String>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async {
    throw StateError('dev-catalog: simulated feed load failure');
  }

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<void> dispose() async {}
}

// ═══════════════════════════════════════════════════════════════════════════
// kyc
// ═══════════════════════════════════════════════════════════════════════════

Widget _kycIdentity(BuildContext _) => KycWizardScreen(
      cubit: KycWizardCubit(
        pickerService: StubPhotoPickerService(),
        gateway: FakeKycGateway(),
      )..loadStatus(),
    );

Widget _kycStatusPending(BuildContext _) => KycWizardScreen(
      cubit: KycWizardCubit(
        pickerService: StubPhotoPickerService(),
        gateway: FakeKycGateway(
          initial: const KycSubmission(status: KycStatus.pending),
        ),
      )..loadStatus(),
    );

Widget _kycStatusApproved(BuildContext _) => KycWizardScreen(
      cubit: KycWizardCubit(
        pickerService: StubPhotoPickerService(),
        gateway: FakeKycGateway(
          initial: const KycSubmission(status: KycStatus.approved),
        ),
      )..loadStatus(),
    );

Widget _kycStatusRejected(BuildContext _) => KycWizardScreen(
      cubit: KycWizardCubit(
        pickerService: StubPhotoPickerService(),
        gateway: FakeKycGateway(
          initial: const KycSubmission(
            status: KycStatus.rejected,
            rejectionReason: KycRejectionReason.idUnreadable,
          ),
        ),
      )..loadStatus(),
    );

Widget _kycSchemaError(BuildContext _) => KycWizardScreen(
      cubit: KycWizardCubit(
        pickerService: StubPhotoPickerService(),
        gateway: const _SchemaFailingKycGateway(),
      )..loadStatus(),
    );

/// Local fake: `fetchStatus` reports a fresh (not-submitted) user so the
/// cubit proceeds to `loadSchema`, which always throws — landing the wizard
/// on [KycWizardStep.schema] with `KycWizardError.schemaLoadFailed`.
class _SchemaFailingKycGateway implements KycGateway {
  const _SchemaFailingKycGateway();

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) async {
    throw StateError('dev-catalog: simulated schema load failure');
  }

  @override
  Future<KycContractTemplate> fetchContractTemplate() async {
    throw UnimplementedError('not exercised by this catalog state');
  }

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) async {
    throw UnimplementedError('not exercised by this catalog state');
  }

  @override
  Future<KycSubmission> submit(KycSubmission draft) async {
    throw UnimplementedError('not exercised by this catalog state');
  }

  @override
  Future<KycSubmission> fetchStatus() async =>
      const KycSubmission(status: KycStatus.notSubmitted);
}

// ═══════════════════════════════════════════════════════════════════════════
// language
// ═══════════════════════════════════════════════════════════════════════════

Widget _languageEnglish(BuildContext _) => BlocProvider<LocaleCubit>(
      create: (_) => LocaleCubit(prefs: sl<SharedPreferences>())
        ..setLocale(const Locale('en')),
      child: const LanguageSettingsScreen(),
    );

Widget _languageArabic(BuildContext _) => BlocProvider<LocaleCubit>(
      create: (_) => LocaleCubit(prefs: sl<SharedPreferences>())
        ..setLocale(const Locale('ar')),
      child: const LanguageSettingsScreen(),
    );

// ═══════════════════════════════════════════════════════════════════════════
// live_tracking
// ═══════════════════════════════════════════════════════════════════════════

const String _demoDeliveryId = 'demo-delivery-001';

Widget _trackingInTransit(BuildContext _) => BlocProvider<LiveTrackingCubit>(
      create: (_) => LiveTrackingCubit(
        repository: const DemoLiveTrackingRepository(),
        deliveryId: _demoDeliveryId,
      ),
      child: const LiveTrackingScreen(deliveryId: _demoDeliveryId),
    );

Widget _trackingAtDoor(BuildContext _) => BlocProvider<LiveTrackingCubit>(
      create: (_) => LiveTrackingCubit(
        repository: const _AtDoorLiveTrackingRepository(),
        deliveryId: _demoDeliveryId,
      ),
      child: const LiveTrackingScreen(deliveryId: _demoDeliveryId),
    );

Widget _trackingError(BuildContext _) => BlocProvider<LiveTrackingCubit>(
      create: (_) => LiveTrackingCubit(
        repository: const _ErrorLiveTrackingRepository(),
        deliveryId: _demoDeliveryId,
      ),
      child: const LiveTrackingScreen(deliveryId: _demoDeliveryId),
    );

/// Local fake: deterministic "courier at the door" snapshot — the screen
/// swaps the bottom panel for [OtpAtDoorCard] in this stage.
class _AtDoorLiveTrackingRepository implements LiveTrackingRepository {
  const _AtDoorLiveTrackingRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    final now = DateTime.now();
    return DeliveryTrackingInfo(
      deliveryId: deliveryId,
      currentStage: TrackingStage.atDoor,
      stageTimestamps: {
        TrackingStage.ordered: now.subtract(const Duration(minutes: 22)),
        TrackingStage.picked: now.subtract(const Duration(minutes: 12)),
        TrackingStage.inTransit: now.subtract(const Duration(minutes: 6)),
        TrackingStage.atDoor: now.subtract(const Duration(seconds: 30)),
      },
      distanceLabel: '0.1 km',
      etaMinutes: 1,
      requestId: deliveryId,
      price: 12.5,
      currency: 'USD',
      jeeberName: 'Kamal Hajj',
      tier: 'express',
      itemSummary: 'Pharmacy order',
    );
  }
}

/// Local fake: always throws so the cubit lands on
/// [LiveTrackingViewMode.error] (DoD §2 — no network).
class _ErrorLiveTrackingRepository implements LiveTrackingRepository {
  const _ErrorLiveTrackingRepository();

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async {
    throw const LiveTrackingException(LiveTrackingErrorKind.network);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// location — CaptureLocationScreen
// ═══════════════════════════════════════════════════════════════════════════

Widget _captureLocationIdle(BuildContext _) => const CaptureLocationScreen();

Widget _captureLocationConfirming(BuildContext _) => const CaptureLocationScreen(
      isConfirming: true,
    );

// ═══════════════════════════════════════════════════════════════════════════
// location — ClientLocationScreen
// ═══════════════════════════════════════════════════════════════════════════

Widget _clientLocationWithSaved(BuildContext _) => const ClientLocationScreen(
      repository: FakeLocationSelectRepository(),
    );

Widget _clientLocationEmpty(BuildContext _) => const ClientLocationScreen(
      repository: FakeLocationSelectRepository(addresses: []),
    );

Widget _clientLocationError(BuildContext _) => const ClientLocationScreen(
      repository: FakeLocationSelectRepository(
        failWith: LocationSelectFailure.network,
      ),
    );

// ═══════════════════════════════════════════════════════════════════════════
// location — LocationPickerScreen
// ═══════════════════════════════════════════════════════════════════════════

const _pickupPoint = LocationPoint(
  latitude: 33.8938,
  longitude: 35.5018,
  address: 'Downtown, Beirut',
);

Widget _locationPickerPickup(BuildContext _) => LocationPickerScreen(
      cubit: LocationPickerCubit(repository: InMemoryLocationRepository()),
      onCompleted: (_) {},
    );

Widget _locationPickerDropoff(BuildContext _) => LocationPickerScreen(
      cubit: LocationPickerCubit(repository: InMemoryLocationRepository())
        ..onPinDragged(
          latitude: _pickupPoint.latitude,
          longitude: _pickupPoint.longitude,
        )
        ..confirmAndContinue(),
      onCompleted: (_) {},
    );

// ═══════════════════════════════════════════════════════════════════════════
// location — SavedLocationsScreen
// ═══════════════════════════════════════════════════════════════════════════

const List<SavedLocation> _savedLocationsSample = [
  SavedLocation(
    id: 'addr-client-001-home',
    label: 'Home',
    latitude: 33.8886,
    longitude: 35.4955,
    category: SavedLocationCategory.home,
    address: 'Sassine Square, Ashrafieh',
    isDefault: true,
  ),
  SavedLocation(
    id: 'addr-client-001-office',
    label: 'Office',
    latitude: 33.8938,
    longitude: 35.5018,
    category: SavedLocationCategory.work,
    address: 'Beirut Tower, Downtown',
  ),
];

Widget _savedLocationsLoaded(BuildContext _) => const SavedLocationsScreen(
      repository: _FakeSavedLocationRepository(_savedLocationsSample),
    );

Widget _savedLocationsEmpty(BuildContext _) => const SavedLocationsScreen(
      repository: _FakeSavedLocationRepository([]),
    );

Widget _savedLocationsError(BuildContext _) => const SavedLocationsScreen(
      repository: _FakeSavedLocationRepository([], shouldFail: true),
    );

/// Local fake covering the read path only (`fetchSavedLocations`) — the
/// designed states here never exercise create/update/delete.
class _FakeSavedLocationRepository implements SavedLocationRepository {
  const _FakeSavedLocationRepository(this._locations, {this.shouldFail = false});

  final List<SavedLocation> _locations;
  final bool shouldFail;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    if (shouldFail) {
      throw const SavedLocationException('dev-catalog: simulated fetch failure');
    }
    return _locations;
  }

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    throw UnimplementedError('not exercised by this catalog state');
  }

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async {
    throw UnimplementedError('not exercised by this catalog state');
  }

  @override
  Future<void> deleteLocation(String id) async {
    throw UnimplementedError('not exercised by this catalog state');
  }
}
