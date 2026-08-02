import 'package:dio/dio.dart';

import '../domain/cdn_asset_gateway.dart';
import '../domain/kyc_contract_template.dart';
import '../domain/kyc_form_schema.dart';
import '../domain/kyc_gateway.dart';
import '../domain/kyc_submission.dart';

class DioKycGateway implements KycGateway {
  const DioKycGateway(this._dio, this._cdn);

  final Dio _dio;
  final CdnAssetGateway _cdn;

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
    final refs = await _uploadAssets(draft);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _submitPath,
        data: _toSubmitBody(draft, refs),
      );
      return _parseSubmission(response.data ?? {});
    } on DioException catch (e) {
      final field = _fieldFrom(e);
      if (field != null) {
        throw KycSubmitFieldException(
          field: field,
          detail: _detailFrom(e),
        );
      }
      rethrow;
    }
  }

  static String? _fieldFrom(DioException e) {
    if (e.response?.statusCode != 400) return null;
    final data = e.response?.data;
    if (data is! Map) return null;
    final field = data['field'];
    return field is String && field.isNotEmpty ? field : null;
  }

  static String? _detailFrom(DioException e) {
    final data = e.response?.data;
    if (data is! Map) return null;
    final detail = data['detail'];
    return detail is String ? detail : null;
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
    final reason = (status == KycStatus.rejected ||
            status == KycStatus.resubmitRequested)
        ? _parseReason(reasonRaw)
        : null;
    final resubmitSteps = status == KycStatus.resubmitRequested
        ? _parseResubmitSteps(json['resubmit_steps'])
        : const <KycResubmitStep>[];
    final submittedAtRaw = json['submitted_at'] as String?;
    final submittedAt = submittedAtRaw != null
        ? DateTime.tryParse(submittedAtRaw)
        : null;
    return KycSubmission(
      status: status,
      rejectionReason: reason,
      resubmitSteps: resubmitSteps,
      submittedAt: submittedAt,
    );
  }

  static List<KycResubmitStep> _parseResubmitSteps(Object? raw) {
    if (raw is! List) return const [];
    final steps = <KycResubmitStep>[];
    for (final entry in raw) {
      if (entry is! String || entry.isEmpty) continue;
      final step = KycResubmitStep.fromWire(entry);
      if (!steps.contains(step)) steps.add(step);
    }
    return steps;
  }

  KycStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'Draft':
      case 'Submitted':
        return KycStatus.pending;
      case 'Approved':
      // (loadStatus read the terminal state as notSubmitted). JEBV4-271.
      case 'Verified':
        return KycStatus.approved;
      case 'Rejected':
        return KycStatus.rejected;
      case 'ResubmitRequested':
        return KycStatus.resubmitRequested;
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
        return KycRejectionReason.other;
    }
  }

  Future<_UploadedAssetRefs> _uploadAssets(KycSubmission draft) async {
    final idFrontBytes = draft.idFront?.bytes;
    final idBackBytes = draft.idBack?.bytes;
    final selfieBytes = draft.selfie?.bytes;
    final vehicleBytes = draft.vehicleRegistration?.bytes;

    final idFrontUrl = idFrontBytes != null
        ? await _cdn.uploadAsset(
            slot: CdnUploadSlot.idDocumentFront,
            bytes: idFrontBytes,
          )
        : null;
    final idBackUrl = idBackBytes != null
        ? await _cdn.uploadAsset(
            slot: CdnUploadSlot.idDocumentBack,
            bytes: idBackBytes,
          )
        : null;
    final selfieUrl = selfieBytes != null
        ? await _cdn.uploadAsset(
            slot: CdnUploadSlot.selfieWithLiveness,
            bytes: selfieBytes,
          )
        : null;
    final vehicleUrl = vehicleBytes != null
        ? await _cdn.uploadAsset(
            slot: CdnUploadSlot.vehicleRegistration,
            bytes: vehicleBytes,
          )
        : null;

    return _UploadedAssetRefs(
      idFrontUrl: idFrontUrl,
      idBackUrl: idBackUrl,
      selfieUrl: selfieUrl,
      vehicleRegistrationUrl: vehicleUrl,
    );
  }

  Map<String, dynamic> _toSubmitBody(
    KycSubmission draft,
    _UploadedAssetRefs refs,
  ) {
    final idNumber = draft.idNumber?.trim();
    return {
      'id_type': draft.idType.wire,
      if (idNumber != null && idNumber.isNotEmpty) 'id_number': idNumber,
      'id_document_front_url': refs.idFrontUrl,
      'id_document_back_url': refs.idBackUrl,
      'selfie_with_liveness_url': refs.selfieUrl,
      if (refs.vehicleRegistrationUrl != null)
        'vehicle_registration_url': refs.vehicleRegistrationUrl,
      if (draft.tosAcceptedVersion != null &&
          draft.tosAcceptedVersion!.isNotEmpty)
        'tos_accepted_version': draft.tosAcceptedVersion,
    };
  }
}

class _UploadedAssetRefs {
  const _UploadedAssetRefs({
    this.idFrontUrl,
    this.idBackUrl,
    this.selfieUrl,
    this.vehicleRegistrationUrl,
  });

  final String? idFrontUrl;
  final String? idBackUrl;
  final String? selfieUrl;
  final String? vehicleRegistrationUrl;
}
