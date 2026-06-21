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

Tier _flash({String? wireId}) => Tier(
      id: TierId.flash,
      wireId: wireId,
      priceLow: 1000,
      priceHigh: 2000,
      currency: 'USD',
      vehicleClass: TierVehicleClass.any,
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
        const LocationSelectState(status: LocationSelectStatus.loaded),
      );

      expect(id, 'req-123');
      expect(submission.submitCount, 1);
    });

    test('echoes the live tier UUID (Tier.wireId) verbatim as tierId', () async {
      controller.setTier(_flash(wireId: '0be308ce-uuid'));

      await controller.submitFromLocation(
        const LocationSelectState(status: LocationSelectStatus.loaded),
      );

      expect(submission.lastDraft!.tierId, '0be308ce-uuid',
          reason: 'the gateway resolves the tier by the exact UUID it minted');
      expect(submission.lastDraft!.tierName, 'flash');
    });

    test('falls back to the enum name when no wireId was captured', () async {
      controller.setTier(_flash());

      await controller.submitFromLocation(
        const LocationSelectState(status: LocationSelectStatus.loaded),
      );

      expect(submission.lastDraft!.tierId, 'flash');
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
      'supplies non-null fallback coordinates for the current-location choice '
      '(the gateway REQUIRES pickup + dropoff lat/lng)',
      () async {
        controller.setTier(_flash(wireId: 'uuid'));

        await controller.submitFromLocation(
          const LocationSelectState(
            status: LocationSelectStatus.loaded,
            choiceKind: LocationChoiceKind.current,
          ),
        );

        final draft = submission.lastDraft!;
        // Must be non-null so the create body carries pickupLocation +
        // dropoffLocation (a body without them is rejected 400 live).
        expect(draft.pickupLat, isNotNull);
        expect(draft.pickupLng, isNotNull);
        expect(draft.dropoffLat, isNotNull);
        expect(draft.dropoffLng, isNotNull);
      },
    );

    test('propagates a RequestSubmissionException on failure', () async {
      submission.error = const RequestSubmissionException(
        RequestSubmissionFailure.invalidInput,
      );
      controller.setTier(_flash(wireId: 'uuid'));

      expect(
        () => controller.submitFromLocation(
          const LocationSelectState(status: LocationSelectStatus.loaded),
        ),
        throwsA(isA<RequestSubmissionException>()),
      );
    });
  });
}
