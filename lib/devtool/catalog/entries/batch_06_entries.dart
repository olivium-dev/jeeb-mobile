
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';

import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/data/demo_live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';

import 'package:jeeb_mobile/features/location/cubit/location_picker_cubit.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/location_picker_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';

import 'package:jeeb_mobile/features/masked_call/application/masked_call_cubit.dart';
import 'package:jeeb_mobile/features/masked_call/presentation/masked_call_button.dart';

import 'package:jeeb_mobile/features/mixed_direction/presentation/mixed_direction_text.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../catalog_models.dart';

List<CatalogEntry> get batch06Entries => <CatalogEntry>[
      _languageEntry,
      _liveTrackingEntry,
      _locationPickerEntry,
      _savedLocationsEntry,
      _clientLocationEntry,
      _maskedCallEntry,
      _mixedDirectionEntry,
      _noOfferTimeoutEntry,
    ];


Widget _languageSettingsPreview(Locale deviceLocale) {
  final cubit = LocaleCubit(
    prefs: sl<SharedPreferences>(),
    deviceLocaleProvider: () => deviceLocale,
  );
  return BlocProvider<LocaleCubit>.value(
    value: cubit,
    child: const LanguageSettingsScreen(),
  );
}

final CatalogEntry _languageEntry = CatalogEntry(
  feature: 'language',
  screen: 'Language Settings',
  states: [
    CatalogState(
      'English selected',
      (_) => _languageSettingsPreview(const Locale('en')),
    ),
    CatalogState(
      'Arabic selected',
      (_) => _languageSettingsPreview(const Locale('ar')),
    ),
  ],
);


const String _trackingDeliveryId = 'DLV-990001';

class _StaticTrackingRepository implements LiveTrackingRepository {
  const _StaticTrackingRepository(this._info);
  final DeliveryTrackingInfo _info;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      _info;
}

class _FailingTrackingRepository implements LiveTrackingRepository {
  const _FailingTrackingRepository(this._kind);
  final LiveTrackingErrorKind _kind;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      throw LiveTrackingException(_kind);
}

DeliveryTrackingInfo _atDoorInfo() => const DeliveryTrackingInfo(
      deliveryId: _trackingDeliveryId,
      currentStage: TrackingStage.atDoor,
      stageTimestamps: {},
      distanceLabel: '0.0 km',
      etaMinutes: 0,
      jeeber: JeeberSummary(displayName: 'Rami K.', vehicleLabel: 'Scooter'),
      requestId: 'REQ-9001',
      price: 8.5,
      currency: 'USD',
      jeeberName: 'Rami K.',
      tier: 'standard',
      itemSummary: 'Pharmacy pickup',
    );

DeliveryTrackingInfo _cancelledInfo() => const DeliveryTrackingInfo(
      deliveryId: _trackingDeliveryId,
      currentStage: TrackingStage.ordered,
      stageTimestamps: {},
      lifecycle: TrackingLifecycle.cancelled,
      requestId: 'REQ-9002',
    );

Widget _liveTrackingPreview(LiveTrackingRepository repository) {
  final cubit = LiveTrackingCubit(
    repository: repository,
    deliveryId: _trackingDeliveryId,
    refreshSignals: const Stream<void>.empty(),
  );
  return BlocProvider<LiveTrackingCubit>.value(
    value: cubit,
    child: const LiveTrackingScreen(deliveryId: _trackingDeliveryId),
  );
}

final CatalogEntry _liveTrackingEntry = CatalogEntry(
  feature: 'live_tracking',
  screen: 'Order Tracking',
  states: [
    CatalogState(
      'In transit',
      (_) => _liveTrackingPreview(const DemoLiveTrackingRepository()),
    ),
    CatalogState(
      'At the door (OTP)',
      (_) => _liveTrackingPreview(_StaticTrackingRepository(_atDoorInfo())),
    ),
    CatalogState(
      'Cancelled (terminal)',
      (_) => _liveTrackingPreview(_StaticTrackingRepository(_cancelledInfo())),
    ),
    CatalogState(
      'Error (not found)',
      (_) => _liveTrackingPreview(
        const _FailingTrackingRepository(LiveTrackingErrorKind.notFound),
      ),
    ),
  ],
);


LocationPickerCubit _seededLocationPickerCubit({
  required bool advanceToDropoff,
  required bool advanceToDone,
}) {
  final cubit = LocationPickerCubit(repository: InMemoryLocationRepository());
  if (advanceToDropoff || advanceToDone) {
    unawaited(() async {
      await cubit.detectCurrentLocation();
      await cubit.confirmAndContinue(); // pickup -> dropoff
      if (advanceToDone) {
        await cubit.detectCurrentLocation();
        await cubit.confirmAndContinue(); // dropoff -> done (saved)
      }
    }());
  }
  return cubit;
}

Widget _locationPickerPreview({
  required bool advanceToDropoff,
  required bool advanceToDone,
}) {
  return LocationPickerScreen(
    cubit: _seededLocationPickerCubit(
      advanceToDropoff: advanceToDropoff,
      advanceToDone: advanceToDone,
    ),
    onCompleted: (_) {}, // safe no-op — never pops the catalog preview route.
  );
}

final CatalogEntry _locationPickerEntry = CatalogEntry(
  feature: 'location',
  screen: 'Location Picker (pickup/dropoff)',
  states: [
    CatalogState(
      'Pickup — no selection',
      (_) => _locationPickerPreview(
        advanceToDropoff: false,
        advanceToDone: false,
      ),
    ),
    CatalogState(
      'Dropoff — pickup confirmed',
      (_) => _locationPickerPreview(
        advanceToDropoff: true,
        advanceToDone: false,
      ),
    ),
    CatalogState(
      'Confirmed (done)',
      (_) => _locationPickerPreview(
        advanceToDropoff: true,
        advanceToDone: true,
      ),
    ),
  ],
);


class _StaticSavedLocationRepository implements SavedLocationRepository {
  const _StaticSavedLocationRepository(this._locations, {this.failFetch = false});

  final List<SavedLocation> _locations;
  final bool failFetch;

  static const List<SavedLocation> seeded = [
    SavedLocation(
      id: 'addr-home',
      label: 'Home',
      latitude: 33.8886,
      longitude: 35.4955,
      category: SavedLocationCategory.home,
      address: 'Sassine Square, Ashrafieh',
      isDefault: true,
    ),
    SavedLocation(
      id: 'addr-office',
      label: 'Office',
      latitude: 33.8938,
      longitude: 35.5018,
      category: SavedLocationCategory.work,
      address: 'Beirut Tower, Downtown',
    ),
  ];

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    if (failFetch) throw const SavedLocationException('fetch_failed');
    return _locations;
  }

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      SavedLocation(
        id: 'new-$label',
        label: label,
        latitude: latitude,
        longitude: longitude,
        category: category,
        address: address,
      );

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      SavedLocation(
        id: id,
        label: label,
        latitude: latitude,
        longitude: longitude,
        category: category,
        address: address,
      );

  @override
  Future<void> deleteLocation(String id) async {}
}

final CatalogEntry _savedLocationsEntry = CatalogEntry(
  feature: 'location',
  screen: 'Saved Addresses',
  states: [
    CatalogState(
      'Loaded (Home + Office)',
      (_) => const SavedLocationsScreen(
        repository: _StaticSavedLocationRepository(
          _StaticSavedLocationRepository.seeded,
        ),
      ),
    ),
    CatalogState(
      'Empty',
      (_) => const SavedLocationsScreen(
        repository: _StaticSavedLocationRepository([]),
      ),
    ),
    CatalogState(
      'Error',
      (_) => const SavedLocationsScreen(
        repository: _StaticSavedLocationRepository([], failFetch: true),
      ),
    ),
  ],
);


const String _clientLocationPreviewUserId = 'preview-user-001';

final CatalogEntry _clientLocationEntry = CatalogEntry(
  feature: 'location',
  screen: 'Location Select (create flow)',
  states: [
    CatalogState(
      'Current location + saved addresses',
      (_) => const ClientLocationScreen(
        userId: _clientLocationPreviewUserId,
        repository: FakeLocationSelectRepository(),
      ),
    ),
    CatalogState(
      'Saved-addresses load error',
      (_) => const ClientLocationScreen(
        userId: _clientLocationPreviewUserId,
        repository: FakeLocationSelectRepository(
          failWith: LocationSelectFailure.network,
        ),
      ),
    ),
  ],
);


class _SeededMaskedCallCubit extends MaskedCallCubit {
  _SeededMaskedCallCubit(MaskedCallState seed) {
    scheduleMicrotask(() {
      if (!isClosed) emit(seed);
    });
  }
}

Widget _maskedCallHost(Widget child) => Scaffold(
      appBar: AppBar(title: const Text('Masked Call')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );

final CatalogEntry _maskedCallEntry = CatalogEntry(
  feature: 'masked_call',
  screen: 'Masked Call Button',
  states: [
    CatalogState(
      'Idle',
      (_) => _maskedCallHost(
        const MaskedCallButton(orderId: 'DLV-9001'),
      ),
    ),
    CatalogState(
      'Calling (in progress)',
      (_) => _maskedCallHost(
        MaskedCallButton(
          orderId: 'DLV-9001',
          cubit: _SeededMaskedCallCubit(const MaskedCallState(isLoading: true)),
        ),
      ),
    ),
  ],
);


Widget _mixedDirectionHost(String label, String text) => Scaffold(
      appBar: AppBar(title: const Text('Mixed Direction Text')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            MixedDirectionText(
              text,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );

final CatalogEntry _mixedDirectionEntry = CatalogEntry(
  feature: 'mixed_direction',
  screen: 'Mixed Direction Text',
  states: [
    CatalogState(
      'English (LTR)',
      (_) => _mixedDirectionHost(
        'English (LTR)',
        'Pickup from Spinneys, Hamra',
      ),
    ),
    CatalogState(
      'Arabic (RTL)',
      (_) => _mixedDirectionHost(
        'Arabic (RTL)',
        'توصيل من محل الحلويات في الأشرفية',
      ),
    ),
    CatalogState(
      'Leading digits (LTR fallback)',
      (_) => _mixedDirectionHost(
        'Leading digits (LTR fallback)',
        '2 boxes - توصيل سريع',
      ),
    ),
  ],
);


const String _waitingPreviewRequestId = 'REQ-WAIT-001';

WaitingCubit _staticWaitingCubit(WaitingRepository repository) => WaitingCubit(
      repository: repository,
      requestId: _waitingPreviewRequestId,
      refreshSignals: const Stream<void>.empty(),
      clockTicks: const Stream<void>.empty(),
    );

Widget _waitingPreview(WaitingRepository repository) => NoOfferTimeoutScreen(
      requestId: _waitingPreviewRequestId,
      repository: repository,
      cubitFactory: (repo, id) => _staticWaitingCubit(repo),
    );

final CatalogEntry _noOfferTimeoutEntry = CatalogEntry(
  feature: 'no_offer_timeout',
  screen: 'Waiting / No Coverage',
  states: [
    CatalogState(
      'Broadcasting (counting down)',
      (_) => _waitingPreview(FakeWaitingRepository(
        seed: WaitingRequest(
          requestId: _waitingPreviewRequestId,
          phase: WaitingRequestPhase.broadcasting,
          notifiedCount: 6,
          offerCount: 0,
          receivedAt: DateTime.now(),
          remainingAtReceipt: const Duration(minutes: 4),
          displayId: 'ORD-5001',
          tier: 'express',
          title: '2 grocery bags from Spinneys',
        ),
      )),
    ),
    CatalogState(
      'Offers arrived',
      (_) => _waitingPreview(FakeWaitingRepository(
        seed: WaitingRequest(
          requestId: _waitingPreviewRequestId,
          phase: WaitingRequestPhase.offersArrived,
          notifiedCount: 6,
          offerCount: 3,
          receivedAt: DateTime.now(),
          remainingAtReceipt: const Duration(minutes: 2),
          displayId: 'ORD-5001',
          tier: 'express',
          title: '2 grocery bags from Spinneys',
        ),
      )),
    ),
    CatalogState(
      'No offers yet (window elapsed)',
      (_) => _waitingPreview(FakeWaitingRepository(
        seed: WaitingRequest(
          requestId: _waitingPreviewRequestId,
          phase: WaitingRequestPhase.broadcasting,
          notifiedCount: 0,
          offerCount: 0,
          receivedAt: DateTime.now(),
          remainingAtReceipt: Duration.zero,
          displayId: 'ORD-5002',
          tier: 'standard',
        ),
      )),
    ),
    CatalogState(
      'Error',
      (_) => _waitingPreview(
        FakeWaitingRepository(
          failure: const WaitingException(WaitingFailure.network),
        ),
      ),
    ),
    CatalogState(
      'Contract violation',
      (_) => _waitingPreview(
        FakeWaitingRepository(
          failure: const WaitingException(
            WaitingFailure.contractViolation,
            'offerDeadlineInSeconds absent on a live broadcasting row',
          ),
        ),
      ),
    ),
  ],
);
