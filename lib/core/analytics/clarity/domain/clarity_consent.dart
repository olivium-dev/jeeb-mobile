enum ClarityConsent {
  unknown,
  granted,
  denied;

  bool get isGranted => this == ClarityConsent.granted;
}
