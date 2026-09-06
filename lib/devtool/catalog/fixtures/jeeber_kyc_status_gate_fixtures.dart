// Dev-only fixtures for `LiveJeeberKycStatusGate` (NET-16).

import '../../../core/network/app_failure.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';

/// A status read that THROWS, so the gate reports [JeeberKycStatus.unknown]
/// rather than swallowing the failure and reporting `none` (which routed an
/// approved jeeber to the register prompt).
class JeeberKycGateUnknownGateway extends FakeKycGateway {
  JeeberKycGateUnknownGateway({
    this.failure = const ServerFailure(status: 503),
  });

  final AppFailure failure;

  @override
  Future<KycSubmission> fetchStatus() async =>
      throw KycGatewayException(failure);
}
