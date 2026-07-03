// sprint-009 scenario matrix #11 (feat/request-scenarios).
//
// PROVES JeeberDeliveryStatus.fromApi resolves EVERY canonical token and every
// legacy alias in the frozen DeliveryStatusAlias table (ADR-002 §3) to the
// correct jeeber-side stage. Pre-fix, the underscore-stripped legacy tokens
// `picked_up` and `heading_off` fell through to the `ordered` default (an
// in-flight delivery re-rendered at step 1), and `disputed` /
// `FailedNeedsEscalation` resurrected an admin-parked delivery as fresh.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';

void main() {
  group('canonical tokens', () {
    test('Ordered/Picked/InTransit/AtDoor/Done map 1:1', () {
      expect(JeeberDeliveryStatusX.fromApi('Ordered'),
          JeeberDeliveryStatus.ordered);
      expect(JeeberDeliveryStatusX.fromApi('Picked'),
          JeeberDeliveryStatus.picked);
      expect(JeeberDeliveryStatusX.fromApi('InTransit'),
          JeeberDeliveryStatus.inTransit);
      expect(JeeberDeliveryStatusX.fromApi('AtDoor'),
          JeeberDeliveryStatus.atDoor);
      expect(
          JeeberDeliveryStatusX.fromApi('Done'), JeeberDeliveryStatus.done);
    });
  });

  group('legacy aliases (DeliveryStatusAlias, ADR-002 §3)', () {
    test('accepted ⇒ ordered (entry edge)', () {
      expect(JeeberDeliveryStatusX.fromApi('accepted'),
          JeeberDeliveryStatus.ordered);
    });

    test('picked_up ⇒ picked (was: fell through to ordered)', () {
      expect(JeeberDeliveryStatusX.fromApi('picked_up'),
          JeeberDeliveryStatus.picked);
    });

    test('heading_off ⇒ inTransit (was: fell through to ordered)', () {
      expect(JeeberDeliveryStatusX.fromApi('heading_off'),
          JeeberDeliveryStatus.inTransit);
    });

    test('at_door ⇒ atDoor', () {
      expect(JeeberDeliveryStatusX.fromApi('at_door'),
          JeeberDeliveryStatus.atDoor);
    });

    test('terminal aliases collapse to done so the in-flight filter drops '
        'them', () {
      for (final token in [
        'delivered',
        'cancelled',
        'canceled',
        'expired',
        'rated',
        'Cancelled',
      ]) {
        expect(JeeberDeliveryStatusX.fromApi(token),
            JeeberDeliveryStatus.done,
            reason: '$token must collapse to done');
      }
    });

    test('disputed / FailedNeedsEscalation collapse to done — the delivery '
        'is admin-parked, never a fresh ordered row', () {
      expect(JeeberDeliveryStatusX.fromApi('disputed'),
          JeeberDeliveryStatus.done);
      expect(JeeberDeliveryStatusX.fromApi('FailedNeedsEscalation'),
          JeeberDeliveryStatus.done);
    });
  });

  test('unknown tokens degrade to ordered (defensive parse)', () {
    expect(JeeberDeliveryStatusX.fromApi('garbage'),
        JeeberDeliveryStatus.ordered);
    expect(JeeberDeliveryStatusX.fromApi(''), JeeberDeliveryStatus.ordered);
  });
}
