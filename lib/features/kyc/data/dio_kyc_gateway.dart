import 'package:dio/dio.dart';

import '../domain/cdn_asset_gateway.dart';
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
/// `submit` uploads the captured photos to the CDN signed-PUT broker
/// (`POST /api/cdn/assets`, `docs/adr/0004-s03-kyc-service-and-gateway-bff.md`)
/// via [_cdn] BEFORE posting the submit body, because the live gateway
/// contract (`KycSubmissionBffController.SubmitJson`) requires `*_url` refs,
/// not raw bytes or the booleans this gateway sent previously (JEBV4-113).
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
      // The BFF answers invalid submissions with a field-scoped RFC-7807
      // ProblemDetails ({"field": "id_number", "detail": ...}). Translate it
      // into the domain exception so the wizard can surface the failure on
      // the offending field instead of a generic snackbar (JEBV4-113).
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

  /// Extracts the RFC-7807 `field` extension from a 400 response, or null
  /// when the failure is not field-scoped.
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
    // A reason is mandatory on both `Rejected` (final) and `ResubmitRequested`
    // (fix-and-resend) — kyc-service enforces it on reject/request_resubmit.
    final reasonRaw = json['rejection_reason'] as String?;
    final reason = (status == KycStatus.rejected ||
            status == KycStatus.resubmitRequested)
        ? _parseReason(reasonRaw)
        : null;
    // Per-document-slot resubmit list, only present on `ResubmitRequested`.
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

  /// Reads `resubmit_steps` — an array of snake_case slot names — into the
  /// domain step list, de-duplicated and order-preserving. Non-list / non-string
  /// entries are ignored so a malformed payload degrades to an empty list (the
  /// resubmit CTA still shows; only the "what to fix" hints are omitted).
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
      // The live kyc-service emits `Verified` (not `Approved`) on both the
      // (auto-)approve submit RESPONSE and GET /v1/kyc/status — there is no
      // Verified→Approved normalization in the gateway (JeebGateway
      // KycServiceClient). Without this case `Verified` fell to `default`
      // (notSubmitted): the approved status view never rendered (so the jeeber
      // role never activated) AND "Start now" looped back to the KYC form
      // (loadStatus read the terminal state as notSubmitted). JEBV4-271.
      case 'Verified':
        return KycStatus.approved;
      case 'Rejected':
        return KycStatus.rejected;
      // E19 / Q-040 tri-state: kyc-service `request_resubmit` bounces the
      // submission back for a fix-and-resend (distinct from final `Rejected`).
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
        // Covers legacy `vehicle_document_missing` (D20-removed) + anything
        // the back-office adds that the app does not model yet.
        return KycRejectionReason.other;
    }
  }

  /// Uploads the captured photos to the CDN broker and returns the resulting
  /// object refs to embed in the submit body. `idFront`/`idBack`/`selfie` are
  /// uploaded unconditionally — the live gateway (`SubmitJson`) requires all
  /// three. `vehicleRegistration` is uploaded only when [draft] already has
  /// one (send-if-present); whether a vehicle ref is ever required is an open
  /// owner decision (JEBV4-113 §4) this gateway does not presume.
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

  // Live gateway contract (`KycSubmissionBffController.SubmitJson`): requires
  // `id_document_front_url` / `id_document_back_url` /
  // `selfie_with_liveness_url`. `id_type` is REQUIRED on the live contract
  // (E3/JEBV4-197) and always sent — one of the ratified {national_id,
  // passport, residency} wire values; `id_number` is sent when captured —
  // for `national_id` the BFF enforces `^\d{12}$`.
  // `vehicle_registration_url` is sent only if a vehicle-registration asset
  // exists in [draft] (send-if-present); E3 relaxes the BFF's vehicle
  // requirement, but that BFF change is a separate gateway lane — until it
  // lands the live BFF still 400s a vehicle-less submit (JEBV4-113).
  // `tos_accepted_version` is threaded through from `signContract()` when
  // present on [draft]; the BFF accepts and cross-validates it optionally.
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

/// Object refs resolved from the CDN broker for a single submit call.
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
