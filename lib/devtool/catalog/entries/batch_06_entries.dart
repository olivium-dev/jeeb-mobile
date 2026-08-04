// DT-04 / F2 — Screen Catalog entries, batch 06 (language, live_tracking,

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';

import '../fixtures/language_settings_screen_fixtures.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';

import '../fixtures/live_tracking_screen_fixtures.dart';

import 'package:jeeb_mobile/features/location/data/location_repository.dart'
    show LocationPoint;
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/map_capture_controller.dart';

import '../fixtures/capture_location_screen_fixtures.dart';
import '../fixtures/client_location_screen_fixtures.dart';

import 'package:jeeb_mobile/features/masked_call/application/masked_call_cubit.dart';
import 'package:jeeb_mobile/features/masked_call/presentation/masked_call_button.dart';

import 'package:jeeb_mobile/features/mixed_direction/presentation/mixed_direction_text.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../fixtures/no_offer_timeout_screen_fixtures.dart';

import '../catalog_models.dart';
import '../fixtures/saved_locations_screen_fixtures.dart';

List<CatalogEntry> get batch06Entries => <CatalogEntry>[
      _languageEntry,
      _liveTrackingEntry,
      _savedLocationsEntry,
      _clientLocationEntry,
      _captureLocationEntry,
      _maskedCallEntry,
      _mixedDirectionEntry,
      _noOfferTimeoutEntry,
    ];

/// Uses IN-MEMORY prefs (not persisted device storage) to render designed states.
Widget _languageSettingsPreview(LanguageSettingsScreenCubitFactory create) =>
    LanguageSettingsScreenPreviewHost(
      create: create,
      child: const LanguageSettingsScreen(),
    );

final CatalogEntry _languageEntry = CatalogEntry(
  feature: 'language',
  screen: 'Language Settings',
  states: [
    CatalogState(
      'English selected',
      (_) => _languageSettingsPreview(
        LanguageSettingsScreenPreviewFixtures.englishSaved,
      ),
    ),
    CatalogState(
      'Arabic selected',
      (_) => _languageSettingsPreview(
        LanguageSettingsScreenPreviewFixtures.arabicSaved,
      ),
    ),
  ],
);

/// No refresh source wired (eliminates timer leaks in preview).
Widget _liveTrackingPreview(LiveTrackingRepository repository) {
  return BlocProvider<LiveTrackingCubit>.value(
    value: LiveTrackingScreenFixtures.cubit(
      repository,
      // The board draws the door code, so the catalog must know one.
      code: LiveTrackingScreenFixtures.handoverCode,
    ),
    // MIDNIGHT: the deterministic R3 map frame, not a platform view — a live
    // GoogleMap cannot render under `flutter test` (the two capture crashes).
    child: const LiveTrackingScreen(
      deliveryId: LiveTrackingScreenFixtures.deliveryId,
      useLiveMap: false,
    ),
  );
}

final CatalogEntry _liveTrackingEntry = CatalogEntry(
  feature: 'live_tracking',
  screen: 'Order Tracking',
  states: [
    CatalogState(
      'In transit',
      (_) => _liveTrackingPreview(
        const LiveTrackingScreenStaticRepository(
          LiveTrackingScreenFixtures.inTransitInfo,
        ),
      ),
    ),
    CatalogState(
      'At the door (OTP)',
      (_) => _liveTrackingPreview(
        const LiveTrackingScreenStaticRepository(
          LiveTrackingScreenFixtures.atDoorInfo,
        ),
      ),
    ),
    CatalogState(
      'Cancelled (terminal)',
      (_) => _liveTrackingPreview(
        const LiveTrackingScreenStaticRepository(
          LiveTrackingScreenFixtures.cancelledInfo,
        ),
      ),
    ),
    CatalogState(
      'Error (not found)',
      (_) => _liveTrackingPreview(
        const LiveTrackingScreenFailingRepository(
          LiveTrackingErrorKind.notFound,
        ),
      ),
    ),
  ],
);

final CatalogEntry _savedLocationsEntry = CatalogEntry(
  feature: 'location',
  screen: 'Saved Addresses',
  states: [
    CatalogState(
      'Loaded (Home + Office)',
      (_) => const SavedLocationsScreen(
        repository: SavedLocationsScreenFakeRepository(
          savedLocationsScreenHomeAndOffice,
        ),
      ),
    ),
    CatalogState(
      'Empty',
      (_) => const SavedLocationsScreen(
        repository: SavedLocationsScreenFakeRepository([]),
      ),
    ),
    CatalogState(
      'Error',
      (_) => const SavedLocationsScreen(
        repository: SavedLocationsScreenFakeRepository([], failFetch: true),
      ),
    ),
  ],
);

/// currentLocationResolver scripted to avoid live permission prompts.
final CatalogEntry _clientLocationEntry = CatalogEntry(
  feature: 'location',
  screen: 'Location Select (create flow)',
  states: [
    CatalogState(
      'Current location + saved addresses',
      (_) => const ClientLocationScreen(
        userId: ClientLocationScreenFixtures.userId,
        repository: ClientLocationScreenFixtures.savedAddresses,
        currentLocationResolver: ClientLocationScreenFixtures.gpsResolved,
      ),
    ),
    CatalogState(
      'Saved-addresses load error',
      (_) => const ClientLocationScreen(
        userId: ClientLocationScreenFixtures.userId,
        repository: ClientLocationScreenFixtures.savedAddressesUnavailable,
        currentLocationResolver: ClientLocationScreenFixtures.gpsResolved,
      ),
    ),
  ],
);

/// R11's map leg. The live `GoogleMapCaptureView` is a platform view the
/// harness cannot render, so every state drives the screen's `mapBuilder` seam.
final CatalogEntry _captureLocationEntry = CatalogEntry(
  feature: 'location',
  screen: 'Capture Location (map pin)',
  states: [
    CatalogState(
      'Map pinned',
      (_) => CaptureLocationScreen(
        controller: _captureCentre(),
        mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
      ),
    ),
    CatalogState(
      'Confirming the pin',
      (_) => CaptureLocationScreen(
        controller: _captureCentre(),
        isConfirming: true,
        mapBuilder: CaptureLocationScreenPreviewFixtures.liveMap(),
      ),
    ),
    CatalogState(
      'Location permission denied',
      (_) => CaptureLocationScreen(
        showCentrePin: false,
        mapBuilder: CaptureLocationScreenPreviewFixtures.permissionDenied(),
      ),
    ),
  ],
);

MapCaptureController _captureCentre() => MapCaptureController(
      initial: const LocationPoint(
        latitude: CaptureLocationScreenPreviewFixtures.beirutLatitude,
        longitude: CaptureLocationScreenPreviewFixtures.beirutLongitude,
      ),
    );

/// Emits [seed] on microtask (after mount) to avoid network calls.
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

/// Frozen clock (countdown reads exactly 4:30, not variable).
Widget _waitingPreview(WaitingRepository repository) => NoOfferTimeoutScreen(
      requestId: NoOfferTimeoutScreenPreviewFixtures.requestId,
      repository: repository,
      cubitFactory: NoOfferTimeoutScreenPreviewFixtures.inertCubit,
    );

final CatalogEntry _noOfferTimeoutEntry = CatalogEntry(
  feature: 'no_offer_timeout',
  screen: 'Waiting / No Coverage',
  states: [
    CatalogState(
      'Broadcasting (counting down)',
      (_) => _waitingPreview(
        NoOfferTimeoutScreenPreviewFixtures.broadcasting(),
      ),
    ),
    CatalogState(
      'Offers arrived',
      (_) => _waitingPreview(
        NoOfferTimeoutScreenPreviewFixtures.offersArrived(),
      ),
    ),
    CatalogState(
      'No offers yet (window elapsed)',
      (_) => _waitingPreview(
        NoOfferTimeoutScreenPreviewFixtures.noOffersYet(),
      ),
    ),
    CatalogState(
      'Error',
      (_) => _waitingPreview(
        NoOfferTimeoutScreenPreviewFixtures.failingLoad(),
      ),
    ),
    CatalogState(
      'Contract violation',
      (_) => _waitingPreview(
        NoOfferTimeoutScreenPreviewFixtures.contractViolation(),
      ),
    ),
    // Appended, never inserted: the capture file names carry the state INDEX.
    CatalogState(
      'Loading (cold read in flight)',
      (_) => _waitingPreview(NoOfferTimeoutScreenPreviewFixtures.stalledLoad()),
    ),
    CatalogState(
      'Terminal (expired)',
      (_) =>
          _waitingPreview(NoOfferTimeoutScreenPreviewFixtures.terminalExpired()),
    ),
  ],
);
