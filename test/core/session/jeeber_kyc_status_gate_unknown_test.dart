// NET-16: `refresh()`'s `catch (_) {}` left `_cached == null`, so `status`
// reported `none` — an APPROVED jeeber was routed to the register prompt and
// the gate never re-read.
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/lifecycle/app_resume_signals.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';

/// Fails until [failUntil] reads have been served.
class _FlakyGateway extends FakeKycGateway {
  _FlakyGateway({this.failUntil = 1 << 30});

  final int failUntil;
  int reads = 0;

  @override
  Future<KycSubmission> fetchStatus() async {
    reads++;
    if (reads <= failUntil) {
      throw const KycGatewayException(ServerFailure(status: 503));
    }
    return const KycSubmission(status: KycStatus.approved);
  }
}

/// Serves [first] once, then throws — the resume/reconnect re-read shape.
class _ThenThrowsGateway extends FakeKycGateway {
  _ThenThrowsGateway(this.first);

  final KycStatus first;
  int reads = 0;

  @override
  Future<KycSubmission> fetchStatus() async {
    reads++;
    if (reads == 1) return KycSubmission(status: first);
    throw const KycGatewayException(NetworkFailure());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await NetworkReachabilitySignals.debugReset();
    await AppResumeSignals.debugReset();
  });

  test('a failed read is UNKNOWN, never none', () async {
    final gate = LiveJeeberKycStatusGate(_FlakyGateway(), useLiveSource: true);
    addTearDown(gate.dispose);

    await gate.refresh();

    expect(gate.status, JeeberKycStatus.unknown);
    expect(gate.status, isNot(JeeberKycStatus.none));
    expect(gate.lastFailure, isA<ServerFailure>());
    expect(gate.isApproved, isFalse);
  });

  test('unknown routes the delivery tab to the unavailable destination', () {
    expect(
      JeeberDeliveryTabDestination.forStatus(JeeberKycStatus.unknown),
      JeeberDeliveryTabDestination.unavailable,
    );
  });

  test('a later success flips to approved, clears the failure and notifies',
      () async {
    final gateway = _FlakyGateway(failUntil: 1);
    final gate = LiveJeeberKycStatusGate(gateway, useLiveSource: true);
    addTearDown(gate.dispose);
    // The constructor already fired the first (failing) read.
    await Future<void>.delayed(Duration.zero);
    expect(gate.status, JeeberKycStatus.unknown);

    var notified = 0;
    gate.addListener(() => notified++);
    await gate.refresh();

    expect(gate.status, JeeberKycStatus.approved);
    expect(gate.lastFailure, isNull);
    expect(notified, greaterThan(0));
  });

  test('a resume signal triggers exactly one re-read', () async {
    final gateway = _FlakyGateway();
    final gate = LiveJeeberKycStatusGate(gateway, useLiveSource: true);
    addTearDown(gate.dispose);
    await Future<void>.delayed(Duration.zero);
    final int base = gateway.reads;

    AppResumeSignals.instance.debugEmit();
    await Future<void>.delayed(Duration.zero);

    expect(gateway.reads - base, 1);
  });

  test('a reconnect edge triggers exactly one re-read', () async {
    final gateway = _FlakyGateway();
    final gate = LiveJeeberKycStatusGate(gateway, useLiveSource: true);
    addTearDown(gate.dispose);
    await Future<void>.delayed(Duration.zero);
    final int base = gateway.reads;

    NetworkReachabilitySignals.instance.debugObserve(online: false);
    NetworkReachabilitySignals.instance.debugObserve(online: true);
    await Future<void>.delayed(Duration.zero);

    expect(gateway.reads - base, 1);
  });

  test('a failed re-read keeps an approved status — it never downgrades',
      () async {
    final gateway = _ThenThrowsGateway(KycStatus.approved);
    final gate = LiveJeeberKycStatusGate(gateway, useLiveSource: true);
    addTearDown(gate.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(gate.status, JeeberKycStatus.approved);

    await gate.refresh();

    expect(gate.status, JeeberKycStatus.approved);
    expect(gate.isApproved, isTrue);
    expect(gate.lastFailure, isA<NetworkFailure>());
    expect(
      JeeberDeliveryTabDestination.forStatus(gate.status),
      JeeberDeliveryTabDestination.feed,
    );
  });

  test('a failed re-read keeps a pending status too', () async {
    final gate = LiveJeeberKycStatusGate(
      _ThenThrowsGateway(KycStatus.pending),
      useLiveSource: true,
    );
    addTearDown(gate.dispose);
    await Future<void>.delayed(Duration.zero);

    await gate.refresh();

    expect(gate.status, JeeberKycStatus.pending);
    expect(gate.lastFailure, isA<NetworkFailure>());
  });

  test('the debug seam never reports unknown', () {
    final gate = LiveJeeberKycStatusGate(_FlakyGateway(), useLiveSource: false);
    addTearDown(gate.dispose);

    expect(gate.status, isNot(JeeberKycStatus.unknown));
    expect(gate.status, const SeamJeeberKycStatusGate().status);
  });
}
