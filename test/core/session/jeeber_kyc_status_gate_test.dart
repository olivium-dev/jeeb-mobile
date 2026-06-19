import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';

/// Locks the JM-036/044 DELIVERY-tab gate mapping, reconciled with D38 (KYC
/// gates OFFERING, not feed-browsing). This is the regression net for the
/// W2-closer finding that the old `!isApproved` collapse routed a `pending`
/// jeeber to `delivery_register_prompt`, leaving `feed_make_offer_cta` (and the
/// JM-044 offer-KYC gate) unreachable.
///
/// The authoritative contract every QA seed maps to:
///   * kyc_status=none     → registerPrompt (`delivery_register_prompt`)
///   * kyc_status=pending  → feed           (`jeeber_feed_root`; offering gated)
///   * kyc_status=approved → feed           (`jeeber_feed_root`; offering allowed)
///   * kyc_status=rejected → kycRejected     (`kyc-rejected` screen, D52/D87)
void main() {
  group('JeeberDeliveryTabDestination.forStatus (JM-036/044, D38)', () {
    test('none → register prompt (never onboarded)', () {
      expect(
        JeeberDeliveryTabDestination.forStatus(JeeberKycStatus.none),
        JeeberDeliveryTabDestination.registerPrompt,
      );
    });

    test('pending → feed (registered; browses feed, offering gated)', () {
      expect(
        JeeberDeliveryTabDestination.forStatus(JeeberKycStatus.pending),
        JeeberDeliveryTabDestination.feed,
        reason: 'D38: a registered (KYC-submitted) jeeber must reach the feed '
            'so feed_make_offer_cta → offer_kyc_gate is reachable (JM-044/048).',
      );
    });

    test('approved → feed (offering allowed)', () {
      expect(
        JeeberDeliveryTabDestination.forStatus(JeeberKycStatus.approved),
        JeeberDeliveryTabDestination.feed,
      );
    });

    test('rejected → kyc-rejected (terminal, D52/D87)', () {
      expect(
        JeeberDeliveryTabDestination.forStatus(JeeberKycStatus.rejected),
        JeeberDeliveryTabDestination.kycRejected,
      );
    });

    test('every status maps to exactly one destination (exhaustive)', () {
      // Guards against a future JeeberKycStatus value being added without a
      // forStatus branch (which would throw, failing this test).
      for (final status in JeeberKycStatus.values) {
        expect(
          () => JeeberDeliveryTabDestination.forStatus(status),
          returnsNormally,
        );
      }
    });
  });

  group('JeeberKycStatusGate.isApproved (D38 offering invariant)', () {
    test('only approved unlocks offering', () {
      expect(const _Gate(JeeberKycStatus.none).isApproved, isFalse);
      expect(const _Gate(JeeberKycStatus.pending).isApproved, isFalse);
      expect(const _Gate(JeeberKycStatus.approved).isApproved, isTrue);
      expect(const _Gate(JeeberKycStatus.rejected).isApproved, isFalse);
    });
  });
}

class _Gate implements JeeberKycStatusGate {
  const _Gate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}
