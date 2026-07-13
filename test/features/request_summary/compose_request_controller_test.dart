// iter6 B11 — ComposeRequestController unit tests.
//
// Verifies the controller assembles the `POST /requests` payload correctly from
// the chosen tier + the confirmed location, echoing the live tier UUID
// (`Tier.wireId`) and satisfying the gateway's required-coordinates contract.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/fake_request_submission_service.dart';

// [wireId] maps to the constructor's [Tier.serverId]; the model exposes it back
// via the [Tier.wireId] getter — the exact value the create RPC must echo.
Tier _flash({String? wireId}) => Tier(
      id: TierId.flash,
      serverId: wireId,
      priceLow: 1000,
      priceHigh: 2000,
      currency: 'USD',
      vehicleClass: TierVehicleClass.any,
    );

// JEBV4-176 (Q-060): the "Current Location" choice now carries a REAL resolved
// device-GPS coordinate (Hamra, non-Beirut) instead of the removed
// `33.8886, 35.4955` fallback. Every current-location create test seeds one.
const double _gpsLat = 33.8959;
const double _gpsLng = 35.4797;

LocationSelectState _currentLoaded() => const LocationSelectState(
      status: LocationSelectStatus.loaded,
      choiceKind: LocationChoiceKind.current,
      currentGpsStatus: CurrentGpsStatus.resolved,
      gpsLat: _gpsLat,
      gpsLng: _gpsLng,
    );

void main() {
  group('ComposeRequestController', () {
    late FakeRequestSubmissionService submission;
    late ComposeRequestController controller;

    setUp(() {
      submission = FakeRequestSubmissionService(requestId: 'req-123');
      controller = ComposeRequestController(submission);
    });

    test('submits POST /requests and returns the server-minted id', () async {
      controller.setTier(_flash(wireId: '0be308ce-uuid'));

      final id = await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(id, 'req-123');
      expect(submission.submitCount, 1);
    });

    test('echoes the live tier UUID (Tier.wireId) verbatim as tierId', () async {
      controller.setTier(_flash(wireId: '0be308ce-uuid'));

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(submission.lastDraft!.tierId, '0be308ce-uuid',
          reason: 'the gateway resolves the tier by the exact UUID it minted');
      expect(submission.lastDraft!.tierName, 'flash');
    });

    test(
        'JEBV4-300: with no wireId the tierId is null (never the enum slug) — '
        'a serverId-less fallback tier must not put a fake id on the wire',
        () async {
      // A tier with no serverId comes from the bundled fallback catalog; its
      // enum slug is NOT an id the gateway ever minted (and On-the-Way / Eco
      // are tiers the server does not sell). Sending null yields a tier-less
      // create (accepted; only the delivery-row seed is skipped) instead.
      controller.setTier(_flash());

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(submission.lastDraft!.tierId, isNull);
    });

    test(
      'uses a selected saved address coordinates for pickup + dropoff',
      () async {
        controller.setTier(_flash(wireId: 'uuid'));
        const saved = SavedLocation(
          id: 'home-1',
          label: 'Home',
          latitude: 33.8959,
          longitude: 35.4797,
          category: SavedLocationCategory.home,
          address: 'Hamra, Beirut',
        );

        await controller.submitFromLocation(
          const LocationSelectState(
            status: LocationSelectStatus.loaded,
            choiceKind: LocationChoiceKind.saved,
            selectedSavedId: 'home-1',
            savedAddresses: [saved],
          ),
        );

        final draft = submission.lastDraft!;
        expect(draft.pickupLat, 33.8959);
        expect(draft.pickupLng, 35.4797);
        expect(draft.dropoffLat, 33.8959);
        expect(draft.dropoffLng, 35.4797);
        expect(draft.pickupAddress, 'Hamra, Beirut');
      },
    );

    test(
      'JEBV4-176: current-location pickup uses the REAL resolved GPS fix '
      '(never the removed 33.8886/35.4955 Beirut fallback)',
      () async {
        controller.setTier(_flash(wireId: 'uuid'));

        await controller.submitFromLocation(_currentLoaded());

        final draft = submission.lastDraft!;
        // The coordinate is the device fix seeded on the state, verbatim.
        expect(draft.pickupLat, _gpsLat);
        expect(draft.pickupLng, _gpsLng);
        expect(draft.dropoffLat, _gpsLat);
        expect(draft.dropoffLng, _gpsLng);
        // The old silent Beirut fallback must NEVER appear.
        expect(draft.pickupLat, isNot(33.8886));
        expect(draft.pickupLng, isNot(35.4955));
      },
    );

    test(
      'JEBV4-176: a current-location choice WITHOUT a resolved fix REFUSES to '
      'create (no fabricated coordinate)',
      () async {
        controller.setTier(_flash(wireId: 'uuid'));

        // A current choice whose GPS never resolved (permission denied / off).
        // The UI gates this out, but the controller must not invent a point.
        expect(
          () => controller.submitFromLocation(
            const LocationSelectState(
              status: LocationSelectStatus.loaded,
              choiceKind: LocationChoiceKind.current,
              currentGpsStatus: CurrentGpsStatus.permissionDenied,
            ),
          ),
          throwsA(isA<RequestSubmissionException>()),
        );
        expect(submission.submitCount, 0);
      },
    );

    // iter6 feed-drop fix — an order created via "Current Location" (no Saved
    // address) must carry a NON-NULL pickup/dropoff address, else the jeeber
    // feed parser (`dio_request_feed_repository._parseLocation`) drops the row
    // and no jeeber can ever see the order. The label must embed the coords so
    // the jeeber can still locate the point until reverse-geocoding lands.
    test(
      'current-location order carries a non-null address embedding the REAL '
      'GPS coords (so the jeeber feed parser keeps the row)',
      () async {
        controller.setTier(_flash(wireId: 'uuid'));

        await controller.submitFromLocation(_currentLoaded());

        final draft = submission.lastDraft!;
        expect(draft.pickupAddress, isNotNull,
            reason: 'a null address makes the jeeber feed drop the order');
        expect(draft.dropoffAddress, isNotNull);
        expect(draft.pickupAddress, isNotEmpty);
        // The label embeds the resolved device coordinates.
        expect(draft.pickupAddress, contains('33.8959'));
        expect(draft.pickupAddress, contains('35.4797'));
      },
    );

    // A freshly-pinned map point (no Saved address) takes the same address-label
    // path as current-location — it must also carry a non-null address.
    test('pinned map-point order also carries a non-null address', () async {
      controller.setTier(_flash(wireId: 'uuid'));

      await controller.submitFromLocation(
        const LocationSelectState(
          status: LocationSelectStatus.loaded,
          choiceKind: LocationChoiceKind.pinned,
          pinnedLat: 33.8869,
          pinnedLng: 35.5131,
        ),
      );

      final draft = submission.lastDraft!;
      expect(draft.pickupLat, 33.8869);
      expect(draft.pickupAddress, isNotNull);
      expect(draft.dropoffAddress, isNotNull);
    });

    test('propagates a RequestSubmissionException on failure', () async {
      submission.error = const RequestSubmissionException(
        RequestSubmissionFailure.invalidInput,
      );
      controller.setTier(_flash(wireId: 'uuid'));

      expect(
        () => controller.submitFromLocation(
          _currentLoaded(),
        ),
        throwsA(isA<RequestSubmissionException>()),
      );
    });

    // iter6 OTP-phone v2 — the recipient phone the customer enters on the
    // location-confirm step must reach the create draft so the gateway
    // request-store row is non-null and the at-door OTP-1234 verify works.
    test('threads the entered recipientPhone into the draft', () async {
      controller.setTier(_flash(wireId: 'uuid'));
      controller.setRecipientPhone('+9613000001');

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(submission.lastDraft!.recipientPhone, '+9613000001');
    });

    test('blank recipientPhone is treated as null (resolver default applies)',
        () async {
      controller.setTier(_flash(wireId: 'uuid'));
      controller.setRecipientPhone('   ');

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(submission.lastDraft!.recipientPhone, isNull);
    });

    test('setTier resets a stale recipientPhone from a prior compose', () async {
      controller.setTier(_flash(wireId: 'uuid'));
      controller.setRecipientPhone('+9613000001');
      // New compose session starts — tier re-selected.
      controller.setTier(_flash(wireId: 'uuid2'));

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(submission.lastDraft!.recipientPhone, isNull);
    });

    // ── G1 (sprint-009 P0) — the description IS the user's own words ────────

    test(
      'G1: the typed "What do you need?" text lands in the POST body '
      'VERBATIM — the hardcoded "{Tier} delivery request" string is GONE',
      () async {
        controller.setTier(_flash(wireId: 'uuid'));
        controller.setDescription('2 shawarma + cola from Barbar');

        await controller.submitFromLocation(
          _currentLoaded(),
        );

        final draft = submission.lastDraft!;
        expect(draft.description, '2 shawarma + cola from Barbar');
        expect(draft.description, isNot(contains('Flash')),
            reason: 'no tier-derived placeholder may leak into user content');
        expect(draft.description.toLowerCase(),
            isNot(contains('delivery request')));
      },
    );

    test('G1: description is trimmed before it reaches the draft', () async {
      controller.setTier(_flash(wireId: 'uuid'));
      controller.setDescription('  a birthday cake  ');

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(submission.lastDraft!.description, 'a birthday cake');
    });

    test(
      'G1: with NO description recorded the draft falls back to the generic '
      'gateway-required default — never the tier-derived string',
      () async {
        controller.setTier(_flash(wireId: 'uuid'));

        await controller.submitFromLocation(
          _currentLoaded(),
        );

        final draft = submission.lastDraft!;
        // The gateway 400s on a blank description, so a non-empty fallback
        // must exist — but it must NOT be the old '"Flash delivery request"'.
        expect(draft.description, isNotEmpty);
        expect(draft.description, 'Delivery request');
        expect(draft.description, isNot('Flash delivery request'));
      },
    );

    test('G1: blank description is treated as unset (fallback applies)',
        () async {
      controller.setTier(_flash(wireId: 'uuid'));
      controller.setDescription('   ');

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      expect(submission.lastDraft!.description, 'Delivery request');
      expect(controller.description, isNull);
    });

    test('G1: dictation voice-note rides the draft as transcription+audioUrl',
        () async {
      controller.setTier(_flash(wireId: 'uuid'));
      controller.setDescription('A birthday cake from Sea Sweet');
      controller.setVoiceNote(
        transcription: 'A birthday cake from Sea Sweet',
        audioUrl: 'clip-42',
      );

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      final draft = submission.lastDraft!;
      expect(draft.transcription, 'A birthday cake from Sea Sweet');
      expect(draft.audioUrl, 'clip-42');
    });

    test('G1: setTier starts a fresh compose — stale description/voice reset',
        () async {
      controller.setTier(_flash(wireId: 'uuid'));
      controller.setDescription('old abandoned order');
      controller.setVoiceNote(transcription: 'old', audioUrl: 'clip-old');
      // New compose session.
      controller.setTier(_flash(wireId: 'uuid2'));

      await controller.submitFromLocation(
        _currentLoaded(),
      );

      final draft = submission.lastDraft!;
      expect(draft.description, 'Delivery request',
          reason: 'the abandoned session\'s text must not leak');
      expect(draft.transcription, isNull);
      expect(draft.audioUrl, isNull);
    });
  });
}
