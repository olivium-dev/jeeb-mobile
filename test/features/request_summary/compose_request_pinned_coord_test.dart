// S0-REQ-03 — stop dropping the map-pinned coordinate.
//
// The compose flow previously discarded the lat/lng the customer pinned on the
// map: `markPinned()` recorded only the choice KIND, never the point, so
// `_buildDraft` had nothing to read and fell back to the Beirut constant. These
// tests lock the carried-not-defaulted contract: a pinned coordinate flows into
// the create draft verbatim; the Beirut fallback is used ONLY when no real
// coordinate was captured.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/fake_request_submission_service.dart';

// serverId is surfaced via the Tier.wireId getter — the value the create RPC
// echoes as tierId.
Tier _flash() => const Tier(
      id: TierId.flash,
      serverId: 'uuid',
      priceLow: 1000,
      priceHigh: 2000,
      currency: 'USD',
      vehicleClass: TierVehicleClass.any,
    );

void main() {
  group('S0-REQ-03 — pinned coordinate is carried, not defaulted', () {
    late FakeRequestSubmissionService submission;
    late ComposeRequestController controller;

    setUp(() {
      submission = FakeRequestSubmissionService(requestId: 'req-1');
      controller = ComposeRequestController(submission);
    });

    test('a pinned point carries its real lat/lng into the create draft',
        () async {
      controller.setTier(_flash());

      await controller.submitFromLocation(
        const LocationSelectState(
          status: LocationSelectStatus.loaded,
          choiceKind: LocationChoiceKind.pinned,
          pinnedLat: 33.9012,
          pinnedLng: 35.6033,
        ),
      );

      final draft = submission.lastDraft!;
      expect(draft.pickupLat, 33.9012,
          reason: 'the map-pinned coordinate must NOT be replaced by Beirut');
      expect(draft.pickupLng, 35.6033);
      // The single confirmed point seeds both ends in this leg.
      expect(draft.dropoffLat, 33.9012);
      expect(draft.dropoffLng, 35.6033);
      // The address label embeds the REAL pinned coordinate (not Beirut), so
      // the jeeber feed parser keeps the row AND the label points at the pin.
      expect(draft.pickupAddress, contains('33.9012'));
      expect(draft.pickupAddress, contains('35.6033'));
      expect(draft.pickupAddress, isNot(contains('33.8886')));
    });

    test(
      'JEBV4-176: a pinned choice WITHOUT a captured coordinate REFUSES to '
      'create — it no longer fabricates a Beirut fallback',
      () async {
        controller.setTier(_flash());

        expect(
          () => controller.submitFromLocation(
            const LocationSelectState(
              status: LocationSelectStatus.loaded,
              choiceKind: LocationChoiceKind.pinned,
            ),
          ),
          throwsA(isA<RequestSubmissionException>()),
        );
        expect(submission.submitCount, 0);
      },
    );
  });
}
