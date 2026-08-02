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

  final double homeBaseLat;
  final double homeBaseLng;
  final String homeBaseLabel;
}

abstract class DmOnboardingGateway {
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
