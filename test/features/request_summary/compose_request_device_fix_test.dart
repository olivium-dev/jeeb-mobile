// SPRINT-003 — the GPS-less "current location" request-create path now uses a
// real device fix for the pickup point instead of silently defaulting to
// Beirut, so a co-located jeeber falls inside the 25 km match radius. The
// Beirut constant is still the last-resort fallback when no fix is available.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/online_location_fix.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/fake_request_submission_service.dart';

Tier _flash() => const Tier(
      id: TierId.flash,
      wireId: 'uuid',
      priceLow: 1000,
      priceHigh: 2000,
      currency: 'USD',
      vehicleClass: TierVehicleClass.any,
    );

class _FakeFix implements OnlineLocationFix {
  const _FakeFix(this._coords);
  final OnlineCoordinates? _coords;
  @override
  Future<OnlineCoordinates?> resolve() async => _coords;
}

// Beirut downtown constant the controller falls back to (mirror of the private
// `_fallbackLat/_fallbackLng`).
const _beirutLat = 33.8886;
const _beirutLng = 35.4955;

void main() {
  group('ComposeRequestController — SPRINT-003 device-fix pickup', () {
    late FakeRequestSubmissionService submission;

    setUp(() => submission = FakeRequestSubmissionService(requestId: 'req-1'));

    test('uses the device fix for the current-location path', () async {
      final controller = ComposeRequestController(
        submission,
        locationFix: const _FakeFix(
          OnlineCoordinates(latitude: 33.8901, longitude: 35.5012),
        ),
      )..setTier(_flash());

      await controller.submitFromLocation(
        const LocationSelectState(status: LocationSelectStatus.loaded),
      );

      final draft = submission.lastDraft!;
      expect(draft.pickupLat, 33.8901);
      expect(draft.pickupLng, 35.5012);
      expect(draft.dropoffLat, 33.8901);
      expect(draft.dropoffLng, 35.5012);
    });

    test('falls back to Beirut when no fix is available', () async {
      final controller = ComposeRequestController(
        submission,
        locationFix: const _FakeFix(null),
      )..setTier(_flash());

      await controller.submitFromLocation(
        const LocationSelectState(status: LocationSelectStatus.loaded),
      );

      final draft = submission.lastDraft!;
      expect(draft.pickupLat, _beirutLat);
      expect(draft.pickupLng, _beirutLng);
    });

    test('a pinned coordinate still wins over the device fix', () async {
      final controller = ComposeRequestController(
        submission,
        locationFix: const _FakeFix(
          OnlineCoordinates(latitude: 1.0, longitude: 2.0),
        ),
      )..setTier(_flash());

      await controller.submitFromLocation(
        const LocationSelectState(
          status: LocationSelectStatus.loaded,
          choiceKind: LocationChoiceKind.pinned,
          pinnedLat: 33.9012,
          pinnedLng: 35.6033,
        ),
      );

      final draft = submission.lastDraft!;
      expect(draft.pickupLat, 33.9012);
      expect(draft.pickupLng, 35.6033);
    });
  });
}
