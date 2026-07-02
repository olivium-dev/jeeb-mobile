// Core Flow step 7 — V3 status → delivered/completed final-state mapping.
//
// Proves both client consumers map the V3 `Done` terminal correctly:
//   * Customer tracking (DeliveryTrackingInfo): Done/completed → delivered step
//     (4-step stepper index 3) + isDelivered, driving the receipt/final state.
//   * Jeeber lifecycle (JeeberDeliveryStatus): Done is the terminal stage.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';

void main() {
  group('customer tracking — V3 Done → delivered final state', () {
    DeliveryTrackingInfo parse(String status) =>
        DeliveryTrackingInfo.fromDeliveryJson('dlv-1', {'status': status});

    test('V3 `Done` maps to the delivered terminal stage', () {
      final info = parse('Done');
      expect(info.currentStage, TrackingStage.delivered);
      expect(info.isDelivered, isTrue);
      expect(info.trackingStepIndex4, 3,
          reason: 'delivered is the final (4th) step of the tracking stepper');
    });

    test('the lowercase `delivered` / `completed` aliases also map to delivered',
        () {
      for (final s in ['delivered', 'completed', 'DONE']) {
        final info = parse(s);
        expect(info.currentStage, TrackingStage.delivered, reason: 'status=$s');
        expect(info.isDelivered, isTrue, reason: 'status=$s');
      }
    });

    test('an in-flight V3 state is NOT delivered', () {
      for (final entry in {
        'Ordered': TrackingStage.ordered,
        'Picked': TrackingStage.picked,
        'InTransit': TrackingStage.inTransit,
        'AtDoor': TrackingStage.atDoor,
      }.entries) {
        final info = parse(entry.key);
        expect(info.currentStage, entry.value, reason: entry.key);
        expect(info.isDelivered, isFalse, reason: entry.key);
      }
    });
  });

  group('jeeber lifecycle — V3 Done is terminal', () {
    test('fromApi parses the V3 CapitalCase `Done` to the done stage', () {
      expect(JeeberDeliveryStatusX.fromApi('Done'), JeeberDeliveryStatus.done);
      expect(JeeberDeliveryStatus.done.isTerminal, isTrue);
      expect(JeeberDeliveryStatus.done.next, isNull,
          reason: 'Done has no forward transition');
    });

    test('non-terminal stages report a valid next stage', () {
      expect(JeeberDeliveryStatus.ordered.isTerminal, isFalse);
      expect(JeeberDeliveryStatus.atDoor.next, JeeberDeliveryStatus.done);
      expect(JeeberDeliveryStatus.done.apiValue, 'Done');
    });

    test('all terminal statuses collapse to done so the != done filter drops '
        'them (Lane C)', () {
      for (final raw in const [
        'Done',
        'delivered',
        'Delivered',
        'Cancelled',
        'cancelled',
        'canceled',
        'Expired',
        'expired',
        'Rated',
        'rated',
      ]) {
        expect(JeeberDeliveryStatusX.fromApi(raw), JeeberDeliveryStatus.done,
            reason: raw);
      }
    });

    test('accepted parses to the ordered (pre-pickup) stage (Lane C)', () {
      expect(JeeberDeliveryStatusX.fromApi('accepted'),
          JeeberDeliveryStatus.ordered);
      expect(JeeberDeliveryStatusX.fromApi('Accepted'),
          JeeberDeliveryStatus.ordered);
    });
  });
}
