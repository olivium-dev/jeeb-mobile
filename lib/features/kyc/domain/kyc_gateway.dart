import 'kyc_submission.dart';

/// Side-channel for the cubit to submit and re-fetch KYC state.
///
/// The MVP cubit ships with [FakeKycGateway] so the wizard can run without a
/// backend; real wiring lands with the auth-service KYC endpoint. Implementing
/// classes only need to satisfy this contract.
abstract class KycGateway {
  /// Sends the user's captured photos and vehicle details to the back-office.
  /// Returns the post-submit snapshot — typically [KycStatus.pending].
  Future<KycSubmission> submit(KycSubmission draft);

  /// Re-reads the most recent decision (used by the status screen on cold
  /// start). Returns a submission with [KycStatus.notSubmitted] if the user
  /// hasn't kicked off the flow yet.
  Future<KycSubmission> fetchStatus();
}

/// In-memory gateway used during the UI-only milestone. Honours an optional
/// scripted decision so widget tests can drive the status branches without
/// fakery in the test bodies.
class FakeKycGateway implements KycGateway {
  FakeKycGateway({
    this.decision = KycStatus.pending,
    this.rejectionReason = KycRejectionReason.idUnreadable,
    KycSubmission? initial,
  }) : _stored = initial ??
            const KycSubmission(status: KycStatus.notSubmitted);

  /// What [submit] echoes back as the new status. Defaults to pending — the
  /// realistic path the back-office takes before triaging.
  final KycStatus decision;

  /// Reason returned when [decision] is [KycStatus.rejected]. Ignored
  /// otherwise so callers can leave this at its default.
  final KycRejectionReason rejectionReason;

  KycSubmission _stored;

  @override
  Future<KycSubmission> submit(KycSubmission draft) async {
    final updated = draft.copyWith(
      status: decision,
      submittedAt: DateTime.now(),
      rejectionReason:
          decision == KycStatus.rejected ? rejectionReason : null,
      clearRejectionReason: decision != KycStatus.rejected,
    );
    _stored = updated;
    return updated;
  }

  @override
  Future<KycSubmission> fetchStatus() async => _stored;
}
