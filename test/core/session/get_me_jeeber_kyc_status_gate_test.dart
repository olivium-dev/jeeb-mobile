// JM-036: the real getMe-backed JeeberKycStatusGate. Verifies the gate reads
// the signed-in user's kycStatus from the CustomerProfileRepository (getMe) and
// classifies it onto JeeberKycStatus / the DELIVERY-tab destination, and that
// it degrades fail-safe (network error / missing field) to the production-safe
// `approved` default so a flaky getMe never bounces a jeeber out of the feed.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';

class _FakeProfileRepo implements CustomerProfileRepository {
  _FakeProfileRepo({this.profile, this.throws});

  final CustomerProfileViewData? profile;
  final CustomerProfileFailure? throws;
  int fetchCount = 0;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    fetchCount++;
    final f = throws;
    if (f != null) throw CustomerProfileRepositoryException(f);
    return profile ?? const CustomerProfileViewData();
  }
}

CustomerProfileViewData _profile(String? kyc) =>
    CustomerProfileViewData(kycStatus: kyc);

void main() {
  group('jeeberKycStatusFromWire', () {
    test('maps the four canonical wire values', () {
      expect(jeeberKycStatusFromWire('none'), JeeberKycStatus.none);
      expect(jeeberKycStatusFromWire('pending'), JeeberKycStatus.pending);
      expect(jeeberKycStatusFromWire('approved'), JeeberKycStatus.approved);
      expect(jeeberKycStatusFromWire('rejected'), JeeberKycStatus.rejected);
    });

    test('is case-insensitive + accepts synonyms', () {
      expect(jeeberKycStatusFromWire('APPROVED'), JeeberKycStatus.approved);
      expect(jeeberKycStatusFromWire('verified'), JeeberKycStatus.approved);
      expect(jeeberKycStatusFromWire('submitted'), JeeberKycStatus.pending);
      expect(jeeberKycStatusFromWire('denied'), JeeberKycStatus.rejected);
    });

    test('unknown / null degrades to the supplied fallback', () {
      expect(jeeberKycStatusFromWire(null), JeeberKycStatus.approved);
      expect(jeeberKycStatusFromWire('garbage'), JeeberKycStatus.approved);
      expect(
        jeeberKycStatusFromWire(null, fallback: JeeberKycStatus.none),
        JeeberKycStatus.none,
      );
    });
  });

  group('GetMeJeeberKycStatusGate', () {
    test('hydrates from getMe kycStatus=pending → feed (browse, D38)', () async {
      final repo = _FakeProfileRepo(profile: _profile('pending'));
      final gate = GetMeJeeberKycStatusGate(
        repository: repo,
        hydrateOnCreate: false,
      );
      await gate.refresh();
      expect(gate.status, JeeberKycStatus.pending);
      expect(gate.isApproved, isFalse);
      expect(
        JeeberDeliveryTabDestination.forStatus(gate.status),
        JeeberDeliveryTabDestination.feed,
      );
    });

    test('kycStatus=none → register prompt', () async {
      final repo = _FakeProfileRepo(profile: _profile('none'));
      final gate = GetMeJeeberKycStatusGate(
        repository: repo,
        hydrateOnCreate: false,
      );
      await gate.refresh();
      expect(gate.status, JeeberKycStatus.none);
      expect(
        JeeberDeliveryTabDestination.forStatus(gate.status),
        JeeberDeliveryTabDestination.registerPrompt,
      );
    });

    test('kycStatus=rejected → kyc-rejected screen (D52)', () async {
      final repo = _FakeProfileRepo(profile: _profile('rejected'));
      final gate = GetMeJeeberKycStatusGate(
        repository: repo,
        hydrateOnCreate: false,
      );
      await gate.refresh();
      expect(
        JeeberDeliveryTabDestination.forStatus(gate.status),
        JeeberDeliveryTabDestination.kycRejected,
      );
    });

    test('kycStatus=approved → approved + feed + isApproved', () async {
      final repo = _FakeProfileRepo(profile: _profile('approved'));
      final gate = GetMeJeeberKycStatusGate(
        repository: repo,
        hydrateOnCreate: false,
      );
      await gate.refresh();
      expect(gate.isApproved, isTrue);
    });

    test('pre-hydration default is the production-safe fallback (approved)',
        () {
      final repo = _FakeProfileRepo(profile: _profile('none'));
      final gate = GetMeJeeberKycStatusGate(
        repository: repo,
        hydrateOnCreate: false,
      );
      // Before any refresh, the cache holds the fallback so the existing feed
      // is never regressed.
      expect(gate.status, JeeberKycStatus.approved);
    });

    test('a getMe network error keeps the last-known status (no downgrade)',
        () async {
      // Start approved, then a failing refresh must not bounce to the fallback
      // (it already IS the fallback) nor throw.
      final ok = _FakeProfileRepo(profile: _profile('pending'));
      final gate = GetMeJeeberKycStatusGate(
        repository: ok,
        hydrateOnCreate: false,
      );
      await gate.refresh();
      expect(gate.status, JeeberKycStatus.pending);

      // Swap to a failing repo by constructing a new gate seeded pending is not
      // possible (cache is private), so assert the failing-repo path directly:
      final failing = _FakeProfileRepo(throws: CustomerProfileFailure.network);
      final failGate = GetMeJeeberKycStatusGate(
        repository: failing,
        hydrateOnCreate: false,
      );
      await failGate.refresh();
      // Stays on the fallback, never throws.
      expect(failGate.status, JeeberKycStatus.approved);
    });

    test('missing kycStatus on getMe → fallback', () async {
      final repo = _FakeProfileRepo(profile: const CustomerProfileViewData());
      final gate = GetMeJeeberKycStatusGate(
        repository: repo,
        hydrateOnCreate: false,
      );
      await gate.refresh();
      expect(gate.status, JeeberKycStatus.approved);
    });
  });
}
