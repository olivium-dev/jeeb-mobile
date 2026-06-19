import 'package:dio/dio.dart';

import '../domain/kyc_contract_template.dart';
import '../domain/kyc_form_schema.dart';
import '../domain/kyc_gateway.dart';
import '../domain/kyc_submission.dart';

/// Dio-backed [KycGateway].
///
/// Endpoints (useMockPrefixes=false, Mockoon :3055):
///   GET  /v1/kyc/jeeb/form-schema?variant=  → [KycFormSchema]
///   GET  /v1/kyc/contract-template?type=tos → [KycContractTemplate]
///   POST /v1/kyc/contract-template/sign     → [KycSignStamp]
///   POST /v1/kyc/submit                     → [KycSubmission]  (201 first / 200 replay)
///   GET  /v1/kyc/status                     → [KycSubmission]
///
/// All paths verified against Mockoon :3055 scenario s03-kyc-submission.
class DioKycGateway implements KycGateway {
  const DioKycGateway(this._dio);

  final Dio _dio;

  static const String _formSchemaPath = '/v1/kyc/jeeb/form-schema';
  static const String _contractTemplatePath = '/v1/kyc/contract-template';
  static const String _signPath = '/v1/kyc/contract-template/sign';
  static const String _submitPath = '/v1/kyc/submit';
  static const String _statusPath = '/v1/kyc/status';

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _formSchemaPath,
      queryParameters: {'variant': variant},
    );
    return KycFormSchema.fromJson(response.data ?? {});
  }

  @override
  Future<KycContractTemplate> fetchContractTemplate() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _contractTemplatePath,
      queryParameters: {'type': 'tos'},
    );
    return KycContractTemplate.fromJson(response.data ?? {});
  }

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _signPath,
      data: {
        'template_id': templateId,
        'tos_version': tosVersion,
        'signature_blob': signatureBlob,
      },
    );
    return KycSignStamp.fromJson(response.data ?? {});
  }

  @override
  Future<KycSubmission> submit(KycSubmission draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      _submitPath,
      data: _toSubmitBody(draft),
    );
    return _parseSubmission(response.data ?? {});
  }

  @override
  Future<KycSubmission> fetchStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_statusPath);
      return _parseSubmission(response.data ?? {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const KycSubmission(status: KycStatus.notSubmitted);
      }
      rethrow;
    }
  }

  KycSubmission _parseSubmission(Map<String, dynamic> json) {
    final stateRaw = json['state'] as String?;
    final status = _parseStatus(stateRaw);
    final reasonRaw = json['rejection_reason'] as String?;
    final reason = status == KycStatus.rejected
        ? _parseReason(reasonRaw)
        : null;
    final submittedAtRaw = json['submitted_at'] as String?;
    final submittedAt = submittedAtRaw != null
        ? DateTime.tryParse(submittedAtRaw)
        : null;
    return KycSubmission(
      status: status,
      rejectionReason: reason,
      submittedAt: submittedAt,
    );
  }

  KycStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'Draft':
      case 'Submitted':
        return KycStatus.pending;
      case 'Approved':
        return KycStatus.approved;
      case 'Rejected':
        return KycStatus.rejected;
      default:
        return KycStatus.notSubmitted;
    }
  }

  KycRejectionReason _parseReason(String? raw) {
    switch (raw) {
      case 'id_document_illegible':
      case 'id_unreadable':
        return KycRejectionReason.idUnreadable;
      case 'selfie_mismatch':
        return KycRejectionReason.selfieMismatch;
      case 'expired':
        return KycRejectionReason.expired;
      default:
        // Covers legacy `vehicle_document_missing` (D20-removed) + anything
        // the back-office adds that the app does not model yet.
        return KycRejectionReason.other;
    }
  }

  // JM-040 (D20): no vehicle fields. The mock K1 `/v1/kyc/submit` body is
  // free-form and the identity photos are uploaded out-of-band (proof-photo
  // sink), so the submit POST carries the document-type marker the schema
  // (`national_id`) expects. Field names match the K1 contract.
  Map<String, dynamic> _toSubmitBody(KycSubmission draft) {
    return {
      'document_type': 'national_id',
      'has_id_front': draft.hasIdFront,
      'has_id_back': draft.hasIdBack,
      'has_selfie': draft.hasSelfie,
    };
  }
}
