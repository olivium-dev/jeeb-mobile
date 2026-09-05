import '../../../core/network/app_failure.dart';

class DmOnboardingSubmission {
  const DmOnboardingSubmission({
    required this.state,
    required this.country,
    required this.street,
    required this.address,
    required this.homeBaseLat,
    required this.homeBaseLng,
    this.homeBaseLabel = '',
    this.portraitObjectRef,
    this.operationId,
  });

  final String state;
  final String country;
  final String street;
  final String address;

  final double homeBaseLat;
  final double homeBaseLng;
  final String homeBaseLabel;

  /// UX-06: the CDN object ref of the portrait the wizard captured. Null when
  /// no CDN gateway was injected, or the step was skipped.
  final String? portraitObjectRef;

  /// Idempotency scope for the submit; sent as `Idempotency-Key`, not a field.
  final String? operationId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'state': state,
        'country': country,
        'street': street,
        'address': address,
        'home_base_lat': homeBaseLat,
        'home_base_lng': homeBaseLng,
        'home_base_label': homeBaseLabel,
        if (portraitObjectRef != null) 'portrait_object_ref': portraitObjectRef,
      };
}

/// The home base fell outside every served zone — a decision, not a fault:
/// there is nothing to retry in place.
class DmOnboardingOutOfCoverageException implements Exception {
  const DmOnboardingOutOfCoverageException();

  @override
  String toString() => 'DmOnboardingOutOfCoverageException()';
}

/// Any other classified transport failure of the submit.
class DmOnboardingGatewayException implements Exception {
  const DmOnboardingGatewayException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'DmOnboardingGatewayException(${failure.kind.name})';
}

abstract class DmOnboardingGateway {
  /// The documented submit path. NOT deployed on the gateway as of 2026-09-05
  /// — see `stage1/OWNER-CONFIRM.md`; 404/405/501 resolve normally.
  static const String submitPath =
      '/form-builder-service/v1/templates/jeeb_jeeber_v1/submit';

  Future<void> submit(DmOnboardingSubmission submission);
}

class FakeDmOnboardingGateway implements DmOnboardingGateway {
  FakeDmOnboardingGateway({this.shouldFail = false});

  final bool shouldFail;

  DmOnboardingSubmission? lastSubmission;

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {
    if (shouldFail) {
      throw StateError('DM onboarding service-area check failed (fake)');
    }
    lastSubmission = submission;
  }
}
