// DT-04 / F2 — Screen Catalog entries, batch 06.
//
// Features covered: language, live_tracking, location, masked_call,
// mixed_direction, no_offer_timeout.
//
// Every builder below renders the REAL feature screen/widget seeded with a
// LOCAL fake/stub (or a shipped in-memory double) — no network, no GetIt
// gateway resolution. Repositories that already ship an injectable seam
// (constructor `repository:`/`cubit:` params) are used as-is; two features
// (masked_call, and reusing the existing `repository`/`userId`/`cubitFactory`
// seams elsewhere) needed no new code at all. `masked_call_button.dart` picked
// up one minimal additive seam (see `seamsAdded` in the batch manifest).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';

import '../fixtures/language_settings_screen_fixtures.dart';

import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';

import '../fixtures/live_tracking_screen_fixtures.dart';

import 'package:jeeb_mobile/features/location/cubit/location_picker_cubit.dart';
import 'package:jeeb_mobile/features/location/presentation/location_picker_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';

import '../fixtures/client_location_screen_fixtures.dart';
import '../fixtures/location_picker_screen_fixtures.dart';

import 'package:jeeb_mobile/features/masked_call/application/masked_call_cubit.dart';
import 'package:jeeb_mobile/features/masked_call/presentation/masked_call_button.dart';

import 'package:jeeb_mobile/features/mixed_direction/presentation/mixed_direction_text.dart';

import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';

import '../catalog_models.dart';
import '../fixtures/saved_locations_screen_fixtures.dart';

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

// ─────────────────────────────────────────────────────────────────────────
// language — LanguageSettingsScreen
// ─────────────────────────────────────────────────────────────────────────

/// Seats the real screen on a `LocaleCubit` built over IN-MEMORY prefs seeded
/// with a saved choice, so the two designed rows (English / Arabic selected)
/// render deterministically.
///
/// This used to build the cubit over the app's real, already-bootstrapped
/// `sl<SharedPreferences>()`, which did not deliver that: `_resolveInitial`
/// reads the persisted `app.locale.languageCode` BEFORE it consults
/// `deviceLocaleProvider`, so on a device where anyone had ever picked Arabic
/// both states rendered Arabic — and because every row here is tappable and
/// `setLocale` persists, browsing this entry could rewrite the real user's
/// language for the next cold start. Both are gone with the prefs; see
/// `../fixtures/language_settings_screen_fixtures.dart`, which the preview
/// section at the bottom of the screen file shares with this entry.
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

// ─────────────────────────────────────────────────────────────────────────
// live_tracking — LiveTrackingScreen
// ─────────────────────────────────────────────────────────────────────────

// The seeds moved to `../fixtures/live_tracking_screen_fixtures.dart`, shared
// verbatim with the JEEB PREVIEWS section at the bottom of
// `live_tracking_screen.dart`, so the catalog state a designer signs off and the
// canvas state an engineer edits cannot drift apart. The private
// `_StaticTrackingRepository` / `_FailingTrackingRepository` doubles and the two
// inline `DeliveryTrackingInfo` literals that used to live here are the same
// objects under new, public names.
//
// One thing changed with the move: `In transit` no longer runs on
// `DemoLiveTrackingRepository`. That double stamps `DateTime.now()` offsets into
// `stageTimestamps`, so the state was a function of the wall clock; the fixture
// carries the SAME rendered fields (3 km, 20 min, Kamal Hajj, express,
// "Groceries from Spinneys", $9.00 COD) with an empty timestamp map, which
// nothing on this screen reads. Same four states, same labels, same rendering.

/// Builds the screen with NO refresh source wired (b02 wave C / N7 removed the
/// poll entirely), so a catalog preview reads once and leaks no timers.
Widget _liveTrackingPreview(LiveTrackingRepository repository) {
  return BlocProvider<LiveTrackingCubit>.value(
    value: LiveTrackingScreenFixtures.cubit(repository),
    child: const LiveTrackingScreen(
      deliveryId: LiveTrackingScreenFixtures.deliveryId,
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

// ─────────────────────────────────────────────────────────────────────────
// location — LocationPickerScreen (pickup → dropoff → done)
// ─────────────────────────────────────────────────────────────────────────

// The seeds moved to `../fixtures/location_picker_screen_fixtures.dart`, shared
// verbatim with the JEEB PREVIEWS section at the bottom of
// `location_picker_screen.dart`, so the catalog state a designer signs off and
// the canvas state an engineer edits cannot drift apart.
//
// One thing changed with the move: the seed no longer runs on
// `InMemoryLocationRepository`. That repository answers every call after a
// 60-150 ms delay, so each state used to be "whatever the cubit had reached by
// the time you opened it"; the fixtures drive the cubit through the calls that
// emit SYNCHRONOUSLY, so the screen is in its designed state on the first frame.
// Same three states, same Beirut addresses, same rendering.
//
// `mapPickerLauncher:` stays null here, which is what hides the "Pin on map"
// button and gives "Use current GPS" the full width. That is deliberate and
// shared with the preview section: the two-button Row overflows a 390 pt phone
// by 100 + 29 pt in English and 154 + 168 pt in Arabic, so exactly one surface
// installs [LocationPickerScreenFixtures.mapPicker] — the preview that exists to
// show that overflow (`locationPickerScreenMapPinRow`).

Widget _locationPickerPreview(LocationPickerCubit cubit) {
  return LocationPickerScreen(
    cubit: cubit,
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
        LocationPickerScreenFixtures.pickupNoSelection(),
      ),
    ),
    CatalogState(
      'Dropoff — pickup confirmed',
      (_) => _locationPickerPreview(
        LocationPickerScreenFixtures.dropoffPickupConfirmed(),
      ),
    ),
    CatalogState(
      'Confirmed (done)',
      (_) => _locationPickerPreview(
        LocationPickerScreenFixtures.confirmedPair(),
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────
// location — SavedLocationsScreen (saved-address manager)
// ─────────────────────────────────────────────────────────────────────────
//
// The canned repository and the seeded account moved to
// `../fixtures/saved_locations_screen_fixtures.dart` so this entry and the
// widget-preview section at the bottom of `saved_locations_screen.dart` mock
// the screen from ONE set of fakes. Same three designed states, same data — the
// only change is where the fixture is declared.

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

// ─────────────────────────────────────────────────────────────────────────
// location — ClientLocationScreen (location-select create step)
// ─────────────────────────────────────────────────────────────────────────

// The seeds live in `../fixtures/client_location_screen_fixtures.dart`, shared
// verbatim with the JEEB PREVIEWS section at the bottom of
// `client_location_screen.dart`, so the catalog state a designer reviews and
// the preview an engineer edits cannot drift apart.
//
// `currentLocationResolver:` is now scripted here too. Left null the screen
// builds a real geolocator-backed resolver, so opening this entry on a device
// raised a live permission prompt and then rendered whichever GPS state that
// device happened to be in — the opposite of a designed state.
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

// ─────────────────────────────────────────────────────────────────────────
// masked_call — MaskedCallButton
// ─────────────────────────────────────────────────────────────────────────

/// A [MaskedCallCubit] that emits [seed] one microtask after construction
/// (after `BlocProvider`/`BlocConsumer` have mounted and started listening),
/// so a "calling" designed state renders the same loading affordance the real
/// [MaskedCallCubit.initiateCall] produces — without touching the (nonexistent
/// for this cubit) network path at all.
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

// ─────────────────────────────────────────────────────────────────────────
// mixed_direction — MixedDirectionText
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// no_offer_timeout — NoOfferTimeoutScreen (waiting / no-coverage)
// ─────────────────────────────────────────────────────────────────────────

const String _waitingPreviewRequestId = 'REQ-WAIT-001';

/// Disables the cubit's poll + clock tick streams (empty streams never emit)
/// so no runaway timers leak from the catalog preview.
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
    // P7 — the clean-break failure mode: the gateway answered 200 but omitted
    // `offerDeadlineInSeconds` on a live row. Seeded here so the distinct
    // contract-break copy is visually inspectable without a backend.
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
