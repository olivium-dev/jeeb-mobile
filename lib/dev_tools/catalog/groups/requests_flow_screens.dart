import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/screens/location_picker_screen.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/application/waiting_cubit.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/data/fake_waiting_repository.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/domain/waiting_request.dart';
import 'package:jeeb_mobile/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';

import '../dev_screen_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Requests & Create Flow" catalog group.
//
// One DevScreenEntry per create-flow screen, one DevScreenState per testWidgets
// case in the matching integration_test/screens/<file>_test.dart (screenshot
// suffix → state id, locale → state locale, the pumped widget → the builder).
//
// Every fake/fixture defined INLINE in a test file is copied here privatised
// (leading underscore, file-local). Fakes that already ship in lib/ (production
// fakes: FakeWaitingRepository, FakeTierRepository, FakeLocationSelectRepository,
// FakeVoice*) are imported directly — the tests rely on the same instances.
//
// All poll/clock/ticker seams get const Stream.empty() so previews leave no
// runaway timers; navigation callbacks stay safe no-ops (the screens' own
// context.go/goNamed calls land on the dev preview host's fallback route).
// ─────────────────────────────────────────────────────────────────────────────

// ── offer-review (Client Offers) ─────────────────────────────────────────────
// Inline fakes ported from client_offers_test.dart (privatised).

/// In-memory [OffersRepository] serving a single fixed snapshot.
class _StaticOffersRepository implements OffersRepository {
  _StaticOffersRepository(this._snapshot);

  final OffersSnapshot _snapshot;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async => _snapshot;

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async =>
      OfferAcceptResult.empty;
}

/// Mirrors the test's `_offer` builder (same defaults).
Offer _offer({
  String id = 'offer-1',
  String jeeberName = 'Karim',
  double fee = 30,
  String currency = 'USD',
  int etaMinutes = 12,
  JeeberVehicle vehicle = JeeberVehicle.scooter,
  double rating = 4.6,
  int ratingCount = 80,
}) {
  return Offer(
    id: id,
    jeeberId: 'jeeber-$id',
    jeeberName: jeeberName,
    fee: fee,
    currency: currency,
    etaMinutes: etaMinutes,
    vehicle: vehicle,
    rating: rating,
    ratingCount: ratingCount,
    submittedAt: DateTime.utc(2026, 5, 17, 12),
  );
}

OffersSnapshot _offersSnapshot(List<Offer> offers) => OffersSnapshot(
      offers: List.unmodifiable(offers),
      windowExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
      requestIsOpen: true,
    );

/// Injects empty poll/clock ticks so the preview has no runaway timers.
ClientOffersCubit _offersCubitFactory(
  OffersRepository repository,
  String requestId,
) {
  return ClientOffersCubit(
    repository: repository,
    requestId: requestId,
    pollTicks: const Stream.empty(),
    clockTicks: const Stream.empty(),
  );
}

Widget _offersScreen(OffersSnapshot snapshot) => ClientOffersScreen(
      requestId: 'req-1',
      repository: _StaticOffersRepository(snapshot),
      cubitFactory: _offersCubitFactory,
    );

// ── waiting-no-coverage (Waiting / No Coverage) ──────────────────────────────
// FakeWaitingRepository ships in lib/; the cubitFactory injects empty ticks and
// a fixed clock (ported from waiting_no_coverage_test.dart).

NoOfferTimeoutScreen _waitingScreen(WaitingRequest seed, {DateTime? now}) {
  final fixedNow = now ?? DateTime.utc(2026, 6, 18, 9, 0, 0);
  return NoOfferTimeoutScreen(
    requestId: seed.requestId,
    repository: FakeWaitingRepository(seed: seed),
    cubitFactory: (repo, requestId) => WaitingCubit(
      repository: repo,
      requestId: requestId,
      now: () => fixedNow,
      pollTicks: const Stream.empty(),
      clockTicks: const Stream.empty(),
    ),
  );
}

WaitingRequest _waitingRequest({int notified = 4, int offers = 0}) =>
    WaitingRequest(
      requestId: 'req-client-001-pending',
      phase: offers > 0
          ? WaitingRequestPhase.offersArrived
          : WaitingRequestPhase.broadcasting,
      notifiedCount: notified,
      offerCount: offers,
      broadcastExpiresAt: DateTime.utc(2026, 6, 18, 9, 4, 30),
      displayId: 'ORD-501001',
      tier: 'express',
      title: 'Pharmacy run',
    );

// ── request-summary (Request Summary) ────────────────────────────────────────
// Inline inert submission service ported from request_summary_test.dart.

/// Inert service — the summary is captured before any submit is triggered.
class _NoopSubmissionService implements RequestSubmissionService {
  const _NoopSubmissionService();

  @override
  Future<String> submit(RequestDraft draft) async => 'req-server-1';
}

const _summaryDraft = RequestDraft(
  description: 'Bring me 2 kg of tomatoes and a loaf of bread from the souq',
  transcription: 'كيلو بندورة من السوق',
  photoUrls: ['a.jpg', 'b.jpg'],
  tierName: 'Flash',
  pickupAddress: 'Souq, Hamra Street, Beirut',
  dropoffAddress: 'Verdun 732, Beirut',
);

Widget _summaryScreen() => BlocProvider<RequestSummaryCubit>.value(
      value: RequestSummaryCubit(const _NoopSubmissionService())
        ..setDraft(_summaryDraft),
      child: const RequestSummaryScreen(),
    );

// ── voice-request (Voice Request) ────────────────────────────────────────────
// Voice fakes ship in lib/; empty ticker so no pending timers (ported from
// voice_request_test.dart).

Widget _voiceScreen() => VoiceRecordingScreen(
      cubit: VoiceRecordingCubit(
        recorder: FakeVoiceRecorder(),
        player: FakeVoicePlayer(),
        repository: FakeVoiceRecordingRepository(),
        tickerFactory: (_) => const Stream.empty(),
      ),
    );

// ── client-location (Client Location) ────────────────────────────────────────
// FakeLocationSelectRepository ships in lib/; explicit userId takes the direct
// BlocProvider branch (no AuthTokenStore FutureBuilder).

Widget _clientLocationScreen() => const ClientLocationScreen(
      repository: FakeLocationSelectRepository(),
      userId: 'user-client-001',
    );

final List<DevScreenEntry> requestsFlowScreens = <DevScreenEntry>[
  // Capture Location
  DevScreenEntry(
    id: 'capture-location',
    title: 'Capture Location',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'map',
      'pin',
      'pick location',
      'map picker',
      'viewport',
      'capture-location',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'map-en',
        label: 'Map Picker (EN)',
        locale: const Locale('en'),
        builder: (_) => const CaptureLocationScreen(),
      ),
      DevScreenState(
        id: 'map-ar',
        label: 'Map Picker (AR)',
        locale: const Locale('ar'),
        builder: (_) => const CaptureLocationScreen(),
      ),
    ],
  ),

  // Client Location
  DevScreenEntry(
    id: 'client-location',
    title: 'Client Location',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'address',
      'saved addresses',
      'recipient',
      'pickup',
      'dropoff',
      'what do you need',
      'client-location',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'loaded-en',
        label: 'Loaded Create Step (EN)',
        locale: const Locale('en'),
        builder: (_) => _clientLocationScreen(),
      ),
      DevScreenState(
        id: 'loaded-ar',
        label: 'Loaded Create Step (AR)',
        locale: const Locale('ar'),
        builder: (_) => _clientLocationScreen(),
      ),
    ],
  ),

  // Client Offers
  DevScreenEntry(
    id: 'offer-review',
    title: 'Client Offers',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'offer-review-list',
      'offers',
      'bids',
      'jeeber',
      'accept offer',
      'JM-028',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Populated (EN)',
        locale: const Locale('en'),
        builder: (_) => _offersScreen(
          _offersSnapshot([
            _offer(
              id: 'a',
              jeeberName: 'Karim',
              fee: 30,
              vehicle: JeeberVehicle.scooter,
            ),
            _offer(
              id: 'b',
              jeeberName: 'Hadi',
              fee: 15,
              vehicle: JeeberVehicle.bicycle,
            ),
          ]),
        ),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'Empty / Waiting (EN)',
        locale: const Locale('en'),
        builder: (_) => _offersScreen(_offersSnapshot(const [])),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Populated (AR)',
        locale: const Locale('ar'),
        builder: (_) => _offersScreen(
          _offersSnapshot([
            _offer(id: 'a', jeeberName: 'Karim', fee: 30),
            _offer(id: 'b', jeeberName: 'Hadi', fee: 15),
          ]),
        ),
      ),
    ],
  ),

  // Location Picker
  DevScreenEntry(
    id: 'location-picker',
    title: 'Location Picker',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'coming soon',
      'placeholder',
      'empty state',
      'map',
      'location-picker',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'placeholder-en',
        label: 'Placeholder (EN)',
        locale: const Locale('en'),
        builder: (_) => const LocationPickerScreen(),
      ),
    ],
  ),

  // Request Summary
  DevScreenEntry(
    id: 'request-summary',
    title: 'Request Summary',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'summary',
      'review',
      'draft',
      'confirm',
      'submit request',
      'request-summary',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'filled-en',
        label: 'Assembled Draft (EN)',
        locale: const Locale('en'),
        builder: (_) => _summaryScreen(),
      ),
      DevScreenState(
        id: 'filled-ar',
        label: 'Assembled Draft (AR)',
        locale: const Locale('ar'),
        builder: (_) => _summaryScreen(),
      ),
    ],
  ),

  // Request Type
  DevScreenEntry(
    id: 'request-type',
    title: 'Request Type',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'tier',
      'flash',
      'express',
      'delivery speed',
      'request-type-selection',
      'JM-024',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'loaded-en',
        label: 'Tier Catalog Loaded (EN)',
        locale: const Locale('en'),
        builder: (_) => const RequestTypeScreen(repository: FakeTierRepository()),
      ),
      DevScreenState(
        id: 'loaded-ar',
        label: 'Tier Catalog Loaded (AR)',
        locale: const Locale('ar'),
        builder: (_) => const RequestTypeScreen(repository: FakeTierRepository()),
      ),
    ],
  ),

  // Transcription
  DevScreenEntry(
    id: 'transcription',
    title: 'Transcription',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'voice',
      'transcript',
      'speech to text',
      'transcription-result',
      'review transcript',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'review-en',
        label: 'Transcript Ready (EN)',
        locale: const Locale('en'),
        builder: (_) => const TranscriptionScreen(
          clip: VoiceClip(
            audioPath: 'audio-99',
            durationMs: 4200,
            transcript: 'Bring me bread from the bakery',
          ),
        ),
      ),
      DevScreenState(
        id: 'queued-en',
        label: 'Queued / Empty (EN)',
        locale: const Locale('en'),
        builder: (_) => const TranscriptionScreen(
          clip: VoiceClip(audioPath: 'audio-1', durationMs: 3000),
        ),
      ),
      DevScreenState(
        id: 'review-ar',
        label: 'Transcript Ready (AR)',
        locale: const Locale('ar'),
        builder: (_) => const TranscriptionScreen(
          clip: VoiceClip(
            audioPath: 'audio-99',
            durationMs: 4200,
            transcript: 'كيلو بندورة من السوق',
          ),
        ),
      ),
    ],
  ),

  // Voice Request
  DevScreenEntry(
    id: 'voice-request',
    title: 'Voice Request',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'voice',
      'record',
      'hold to record',
      'audio',
      'microphone',
      'voice-request',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Idle Hold-to-Record (EN)',
        locale: const Locale('en'),
        builder: (_) => _voiceScreen(),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Idle Hold-to-Record (AR)',
        locale: const Locale('ar'),
        builder: (_) => _voiceScreen(),
      ),
    ],
  ),

  // Waiting / No Coverage
  DevScreenEntry(
    id: 'waiting-no-coverage',
    title: 'Waiting / No Coverage',
    group: 'Requests & Create Flow',
    keywords: const <String>[
      'waiting',
      'broadcast',
      'no coverage',
      'countdown',
      'no offers',
      'JM-026',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'broadcast-en',
        label: 'Broadcasting (EN)',
        locale: const Locale('en'),
        builder: (_) => _waitingScreen(_waitingRequest(notified: 4)),
      ),
      DevScreenState(
        id: 'no-coverage-en',
        label: 'No Coverage (EN)',
        locale: const Locale('en'),
        builder: (_) => _waitingScreen(
          _waitingRequest(notified: 0),
          now: DateTime.utc(2026, 6, 18, 9, 4, 30),
        ),
      ),
      DevScreenState(
        id: 'offers-ar',
        label: 'Offers Arrived (AR)',
        locale: const Locale('ar'),
        builder: (_) => _waitingScreen(_waitingRequest(notified: 4, offers: 2)),
      ),
    ],
  ),
];
