// NET-12 — ONE Idempotency-Key spans a draft's whole retry chain, including
// the moderation acknowledge-then-resubmit. Without it a retried create whose
// first POST actually landed mints a SECOND request.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/fake_request_submission_service.dart';

const Tier _tier = Tier(
  id: TierId.flash,
  serverId: 'tier-flash',
  priceLow: 1,
  priceHigh: 2,
  currency: 'USD',
  vehicleClass: TierVehicleClass.bikeOrScooter,
);

const LocationSelectState _loaded = LocationSelectState(
  status: LocationSelectStatus.loaded,
  choiceKind: LocationChoiceKind.pinned,
  pinnedLat: 33.8869,
  pinnedLng: 35.5131,
);

/// Records every draft it is handed, so the key can be compared across a
/// failure and the retry that follows it.
class _RecordingService implements RequestSubmissionService {
  _RecordingService({this.failFirst = false});

  final bool failFirst;
  final List<String?> keys = <String?>[];
  int calls = 0;

  @override
  Future<String> submit(RequestDraft draft) async {
    calls++;
    keys.add(draft.operationId);
    if (failFirst && calls == 1) {
      throw const RequestSubmissionException.classified(
        RequestSubmissionFailure.network,
        appFailure: NetworkFailure(),
      );
    }
    return 'req-$calls';
  }
}

Future<void> _submit(ComposeRequestController c) => c.submitFromLocation(
      _loaded,
      defaultDescription: 'Delivery request',
      currentLocationLabel: 'Current location',
    );

void main() {
  group('ComposeRequestController · Idempotency-Key lifetime', () {
    test('a retry after a failure reuses the SAME key', () async {
      final service = _RecordingService(failFirst: true);
      final controller = ComposeRequestController(service)..setTier(_tier);

      await expectLater(_submit(controller), throwsA(isA<Exception>()));
      await _submit(controller);

      expect(service.calls, 2);
      expect(service.keys.first, isNotNull);
      expect(service.keys[1], service.keys.first);
    });

    test('startSession mints a NEW key', () async {
      final service = _RecordingService();
      final controller = ComposeRequestController(service)..setTier(_tier);

      await _submit(controller);
      final String? first = service.keys.first;

      controller
        ..startSession()
        ..setTier(_tier);
      await _submit(controller);

      expect(service.keys[1], isNotNull);
      expect(service.keys[1], isNot(first));
    });

    test('a SUCCESSFUL submit ends the key: the next create is a new request',
        () async {
      final service = _RecordingService();
      final controller = ComposeRequestController(service)..setTier(_tier);

      await _submit(controller);
      await _submit(controller);

      expect(service.keys[1], isNot(service.keys.first));
    });

    test('setTier starts a fresh session, so it mints a fresh key', () {
      final controller = ComposeRequestController(
        FakeRequestSubmissionService(),
      )..setTier(_tier);
      final String first = controller.operationId;

      controller.setTier(_tier);

      expect(controller.operationId, isNot(first));
    });

    test('the key reaches the draft the service is handed', () async {
      final service = _RecordingService();
      final controller = ComposeRequestController(service)..setTier(_tier);

      final String expected = controller.operationId;
      await _submit(controller);

      expect(service.keys.single, expected);
    });
  });
}
