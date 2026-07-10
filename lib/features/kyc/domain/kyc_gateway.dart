import 'kyc_contract_template.dart';
import 'kyc_form_schema.dart';
import 'kyc_submission.dart';

/// A field-scoped rejection of the KYC submit by the live BFF.
///
/// The gateway answers invalid submissions with an RFC-7807 ProblemDetails
/// carrying a `field` extension (e.g. `{"field": "id_number", "detail":
/// "id_number must be exactly 12 digits (^\d{12}$)."}`). The data layer
/// translates that shape into this domain exception so the wizard can surface
/// the failure INLINE on the offending field instead of collapsing every 400
/// into the generic submit-failed snackbar (JEBV4-113 review finding 1).
class KycSubmitFieldException implements Exception {
  const KycSubmitFieldException({required this.field, this.detail});

  /// The snake_case wire name of the rejected field (e.g. `id_number`).
  final String field;

  /// The server's human-readable detail. English server prose — kept for
  /// diagnostics only; the UI renders its own localized message per field.
  final String? detail;

  @override
  String toString() =>
      'KycSubmitFieldException(field: $field, detail: $detail)';
}

/// Side-channel for the cubit to submit and re-fetch KYC state.
///
/// Implementing classes only need to satisfy this contract.
/// The MVP cubit ships with [FakeKycGateway] so the wizard can run without a
/// backend; real wiring uses [DioKycGateway].
abstract class KycGateway {
  /// Fetches the schema-driven form fields from `/v1/kyc/jeeb/form-schema`.
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'});

  /// Fetches the ToS contract template from `/v1/kyc/contract-template?type=tos`.
  Future<KycContractTemplate> fetchContractTemplate();

  /// Signs the ToS via POST `/v1/kyc/contract-template/sign`.
  /// Returns the sign stamp containing [tosSignedAt] and [tosAcceptedVersion].
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  });

  /// Sends the user's captured photos and vehicle details to the back-office
  /// via POST `/v1/kyc/submit`.
  /// Returns the post-submit snapshot — typically `state: "Submitted"`.
  /// Throws [KycSubmitFieldException] when the BFF rejects the submission
  /// with a field-scoped RFC-7807 400 (e.g. `field: "id_number"`).
  Future<KycSubmission> submit(KycSubmission draft);

  /// Re-reads the most recent decision from GET `/v1/kyc/status`.
  /// Returns a submission with [KycStatus.notSubmitted] if the user
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
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) async {
    return const KycFormSchema(
      templateVersion: 'v1',
      templateName: 'jeeb_jeeber_v1',
      variant: 'national_id',
      fields: [],
    );
  }

  @override
  Future<KycContractTemplate> fetchContractTemplate() async {
    return const KycContractTemplate(
      templateId: 'fake-template-id',
      tosVersion: 'v1',
      documentUrl: 'cdn://jeeb/jeeb_tos_v1.en.md',
      locale: 'en',
      name: 'jeeb_tos_v1',
    );
  }

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) async {
    return KycSignStamp(
      tosSignedAt: DateTime.now(),
      tosAcceptedVersion: tosVersion,
    );
  }

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
