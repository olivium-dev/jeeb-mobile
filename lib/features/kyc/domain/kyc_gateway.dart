import 'kyc_contract_template.dart';
import 'kyc_form_schema.dart';
import 'kyc_submission.dart';

/// A field-scoped rejection of the KYC submit by the live BFF.
///
class KycSubmitFieldException implements Exception {
  const KycSubmitFieldException({required this.field, this.detail});

  final String field;

  final String? detail;

  @override
  String toString() =>
      'KycSubmitFieldException(field: $field, detail: $detail)';
}

abstract class KycGateway {
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'});

  Future<KycContractTemplate> fetchContractTemplate();

  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  });

  Future<KycSubmission> submit(KycSubmission draft);

  Future<KycSubmission> fetchStatus();
}

class FakeKycGateway implements KycGateway {
  FakeKycGateway({
    this.decision = KycStatus.pending,
    this.rejectionReason = KycRejectionReason.idUnreadable,
    KycSubmission? initial,
  }) : _stored = initial ??
            const KycSubmission(status: KycStatus.notSubmitted);

  final KycStatus decision;

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
