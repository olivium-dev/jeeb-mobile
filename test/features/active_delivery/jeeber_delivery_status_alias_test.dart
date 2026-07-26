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
      expect(
        JeeberDeliveryStatusX.fromApi('Ordered'),
        JeeberDeliveryStatus.ordered,
      );
      expect(
        JeeberDeliveryStatusX.fromApi('Picked'),
        JeeberDeliveryStatus.picked,
      );
      expect(
        JeeberDeliveryStatusX.fromApi('InTransit'),
        JeeberDeliveryStatus.inTransit,
      );
      expect(
        JeeberDeliveryStatusX.fromApi('AtDoor'),
        JeeberDeliveryStatus.atDoor,
      );
      expect(JeeberDeliveryStatusX.fromApi('Done'), JeeberDeliveryStatus.done);
    });
  });

  group('legacy aliases (DeliveryStatusAlias, ADR-002 §3)', () {
    test('accepted ⇒ ordered (entry edge)', () {
      expect(
        JeeberDeliveryStatusX.fromApi('accepted'),
        JeeberDeliveryStatus.ordered,
      );
    });

    test('picked_up ⇒ picked (was: fell through to ordered)', () {
      expect(
        JeeberDeliveryStatusX.fromApi('picked_up'),
        JeeberDeliveryStatus.picked,
      );
    });

    test('heading_off ⇒ inTransit (was: fell through to ordered)', () {
      expect(
        JeeberDeliveryStatusX.fromApi('heading_off'),
        JeeberDeliveryStatus.inTransit,
      );
    });

    test('at_door ⇒ atDoor', () {
      expect(
        JeeberDeliveryStatusX.fromApi('at_door'),
        JeeberDeliveryStatus.atDoor,
      );
    });

    test('successful terminal aliases map to done', () {
      for (final token in ['delivered', 'completed', 'rated']) {
        expect(
          JeeberDeliveryStatusX.fromApi(token),
          JeeberDeliveryStatus.done,
          reason: '$token must map to successful completion',
        );
      }
    });

    test('cancelled and expired terminals remain distinct from done', () {
      for (final token in ['cancelled', 'canceled', 'Cancelled']) {
        expect(
          JeeberDeliveryStatusX.fromApi(token),
          JeeberDeliveryStatus.cancelled,
          reason: '$token must not render as successful completion',
        );
      }
      expect(
        JeeberDeliveryStatusX.fromApi('expired'),
        JeeberDeliveryStatus.expired,
      );
    });

    test('disputed / FailedNeedsEscalation remain disputed — the delivery '
        'is admin-parked, never successful or freshly ordered', () {
      expect(
        JeeberDeliveryStatusX.fromApi('disputed'),
        JeeberDeliveryStatus.disputed,
      );
      expect(
        JeeberDeliveryStatusX.fromApi('FailedNeedsEscalation'),
        JeeberDeliveryStatus.disputed,
      );
    });
  });

  group('P6 — the AtDoor gate + the poll-terminal axis', () {
    test('P6/B2: AtDoor has NO forward `next` — Done is OTP-only (SM edge 10)',
        () {
      expect(JeeberDeliveryStatus.atDoor.next, isNull);
      // The rest of the ladder is unchanged.
      expect(JeeberDeliveryStatus.ordered.next, JeeberDeliveryStatus.picked);
      expect(JeeberDeliveryStatus.picked.next, JeeberDeliveryStatus.inTransit);
      expect(JeeberDeliveryStatus.inTransit.next, JeeberDeliveryStatus.atDoor);
      expect(JeeberDeliveryStatus.done.next, isNull);
    });

    test('P6/A2: disputed is NOT poll-terminal — admin can still resolve it',
        () {
      expect(JeeberDeliveryStatus.disputed.isTerminal, isTrue); // UI terminal
      expect(
        JeeberDeliveryStatus.disputed.isPollTerminal,
        isFalse,
      ); // but keep watching
      for (final s in [
        JeeberDeliveryStatus.done,
        JeeberDeliveryStatus.cancelled,
        JeeberDeliveryStatus.expired,
      ]) {
        expect(s.isPollTerminal, isTrue, reason: '$s must stop the poll');
      }
    });
  });

  test('unknown tokens degrade to ordered (defensive parse)', () {
    expect(
      JeeberDeliveryStatusX.fromApi('garbage'),
      JeeberDeliveryStatus.ordered,
    );
    expect(JeeberDeliveryStatusX.fromApi(''), JeeberDeliveryStatus.ordered);
  });
}
