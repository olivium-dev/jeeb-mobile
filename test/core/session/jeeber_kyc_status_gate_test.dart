import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_contract_template.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_form_schema.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';

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
        reason:
            'D38: a registered (KYC-submitted) jeeber must reach the feed '
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

  _liveGateTests();
}

class _Gate implements JeeberKycStatusGate {
  const _Gate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

void _liveGateTests() {
  // JEBV4-267: the release gate must NEVER hardcode `approved`. These lock the
  // live-source branch (forced on via `useLiveSource: true` so the test is
  // deterministic regardless of the harness build mode).
  group('LiveJeeberKycStatusGate (JEBV4-267 release honesty)', () {
    test(
      'conservative non-approved default before the first fetch resolves',
      () {
        // A gateway that never resolves → the gate must report `none` (register
        // prompt), NOT `approved`. This is the core JEBV4-267 invariant.
        final gate = LiveJeeberKycStatusGate(
          _PendingKycGateway(),
          useLiveSource: true,
        );
        expect(gate.status, JeeberKycStatus.none);
        expect(gate.isApproved, isFalse);
      },
    );

    test(
      'maps every live KYC status and notifies listeners on change',
      () async {
        final cases = <KycStatus, JeeberKycStatus>{
          KycStatus.notSubmitted: JeeberKycStatus.none,
          KycStatus.pending: JeeberKycStatus.pending,
          KycStatus.approved: JeeberKycStatus.approved,
          KycStatus.rejected: JeeberKycStatus.rejected,
          // E19 tri-state (JEBV4-214): the coarse gate treats a resubmit-requested
          // submission like `pending` — browse the feed, offering stays gated
          // (isApproved false). The distinct resubmit CTA lives in the status view.
          KycStatus.resubmitRequested: JeeberKycStatus.pending,
        };
        for (final entry in cases.entries) {
          final gateway = _StubKycGateway(entry.key);
          final gate = LiveJeeberKycStatusGate(gateway, useLiveSource: true);
          var notified = false;
          gate.addListener(() => notified = true);
          await gate.refresh();
          expect(
            gate.status,
            entry.value,
            reason: '${entry.key} must map to ${entry.value}',
          );
          expect(gate.isApproved, entry.key == KycStatus.approved);
          // The first successful fetch always transitions the cache off its
          // `null` (unknown) seed, so it notifies — JeeberKycGateBuilder then
          // re-resolves the DELIVERY-tab destination.
          expect(notified, isTrue);
        }
      },
    );

    test(
      'a failed live read holds the conservative default (server backstops)',
      () async {
        final gate = LiveJeeberKycStatusGate(
          _ThrowingKycGateway(),
          useLiveSource: true,
        );
        await gate.refresh();
        expect(gate.status, JeeberKycStatus.none);
        expect(gate.isApproved, isFalse);
      },
    );

    test('is a Listenable so JeeberKycGateBuilder can react', () {
      final gate = LiveJeeberKycStatusGate(
        _PendingKycGateway(),
        useLiveSource: true,
      );
      expect(gate, isA<Listenable>());
    });

    test('debug source delegates to the dev seam (useLiveSource: false)', () {
      // With the live source OFF the gate must defer to SeamJeeberKycStatusGate
      // verbatim — no network — so existing Maestro/widget flows are unchanged.
      final gate = LiveJeeberKycStatusGate(
        _ThrowingKycGateway(),
        useLiveSource: false,
      );
      expect(gate.status, const SeamJeeberKycStatusGate().status);
    });
  });
}

/// A [KycGateway] whose [fetchStatus] never completes — models the pre-fetch
/// window where the release gate must default to `none`.
class _PendingKycGateway extends _UnusedKycGateway {
  @override
  Future<KycSubmission> fetchStatus() => Completer<KycSubmission>().future;
}

/// Returns a submission carrying [_status] from [fetchStatus].
class _StubKycGateway extends _UnusedKycGateway {
  _StubKycGateway(this._status);
  final KycStatus _status;

  @override
  Future<KycSubmission> fetchStatus() async => KycSubmission(status: _status);
}

/// Throws from [fetchStatus] — models a live-read failure.
class _ThrowingKycGateway extends _UnusedKycGateway {
  @override
  Future<KycSubmission> fetchStatus() async => throw Exception('network');
}

/// Base fake that stubs every non-status [KycGateway] member with a throw, so
/// each test overrides only [fetchStatus].
class _UnusedKycGateway implements KycGateway {
  @override
  Future<KycContractTemplate> fetchContractTemplate() =>
      throw UnimplementedError();
  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) =>
      throw UnimplementedError();
  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) => throw UnimplementedError();
  @override
  Future<KycSubmission> submit(KycSubmission draft) =>
      throw UnimplementedError();
  @override
  Future<KycSubmission> fetchStatus() => throw UnimplementedError();
}
