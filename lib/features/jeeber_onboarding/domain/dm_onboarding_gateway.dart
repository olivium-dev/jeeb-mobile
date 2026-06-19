/// Payload for the service-area completion of delivery-man onboarding.
///
/// Carries the address details and the pinned home base so the gateway can
/// confirm coverage (matching find-jeebers) before the wizard chains on to KYC
/// identity (JM-038 AC4).
///
/// No vehicle field — D20 (jeeb is not a vehicle-fleet product); the field was
/// removed across widget, cubit, state, and this DTO under JM-037.
/// No distance/radius field — D51 (the distance slider was removed under
/// JM-038); a single home-base pin replaces the working-radius model.
class DmOnboardingSubmission {
  const DmOnboardingSubmission({
    required this.state,
    required this.country,
    required this.street,
    required this.address,
    required this.homeBaseLat,
    required this.homeBaseLng,
    this.homeBaseLabel = '',
  });

  final String state;
  final String country;
  final String street;
  final String address;

  /// Pinned home-base coordinates (D51). These are forwarded as the matching
  /// `origin` so the mock can confirm the Jeeber's base is serviceable.
  final double homeBaseLat;
  final double homeBaseLng;
  final String homeBaseLabel;
}

/// Side-channel for the service-area step to confirm the chosen home base is
/// serviceable before chaining to KYC identity.
///
/// Real wiring lands against the jeeb-gateway BFF
/// (`POST /v1/matching/find-jeebers`, rewritten to
/// `/matching/v1/matching/find-jeebers`) — never a direct service call. Tests
/// inject [FakeDmOnboardingGateway].
abstract class DmOnboardingGateway {
  /// Confirms the home base is serviceable. Throws on failure so the cubit
  /// surfaces a one-shot [DmOnboardingError.submitFailed] and stays on the step.
  Future<void> submit(DmOnboardingSubmission submission);
}

/// In-memory gateway used in widget/cubit tests. Records the last submission so
/// assertions can inspect it without network fakery.
class FakeDmOnboardingGateway implements DmOnboardingGateway {
  FakeDmOnboardingGateway({this.shouldFail = false});

  /// When true, [submit] throws so the error branch can be exercised.
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
