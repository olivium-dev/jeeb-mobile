/// Persisted payload for a delivery-man onboarding submission. Carries the
/// address/vehicle details and the chosen service area so the gateway can
/// forward them to the KYC/onboarding endpoint via the BFF.
class DmOnboardingSubmission {
  const DmOnboardingSubmission({
    required this.state,
    required this.country,
    required this.street,
    required this.vehicleNumber,
    required this.address,
    required this.primaryLocation,
    required this.distanceKm,
  });

  final String state;
  final String country;
  final String street;
  final String vehicleNumber;
  final String address;
  final String primaryLocation;
  final int distanceKm;
}

/// Side-channel for the wizard to submit the completed onboarding form.
///
/// The MVP cubit ships with [FakeDmOnboardingGateway] so the wizard runs
/// without a backend; real wiring lands against the jeeb-gateway BFF
/// (form-builder-service + geolocation-service) — never a direct service call.
abstract class DmOnboardingGateway {
  /// Submits the completed onboarding form. Throws on failure so the cubit
  /// surfaces a one-shot [DmOnboardingError.submitFailed].
  Future<void> submit(DmOnboardingSubmission submission);
}

/// In-memory gateway used during the UI-only milestone. Records the last
/// submission so widget tests can assert it without network fakery.
class FakeDmOnboardingGateway implements DmOnboardingGateway {
  FakeDmOnboardingGateway({this.shouldFail = false});

  /// When true, [submit] throws so the error branch can be exercised.
  final bool shouldFail;

  DmOnboardingSubmission? lastSubmission;

  @override
  Future<void> submit(DmOnboardingSubmission submission) async {
    if (shouldFail) {
      throw StateError('DM onboarding submit failed (fake)');
    }
    lastSubmission = submission;
  }
}
