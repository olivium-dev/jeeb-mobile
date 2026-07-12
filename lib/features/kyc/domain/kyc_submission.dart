import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';

/// Decision the back-office returned for a [KycSubmission]. `pending` is the
/// state immediately after submit; `approved`/`rejected` are terminal.
///
/// [resubmitRequested] is the tri-state third path (E19 / Q-040 / SM-6): the
/// kyc-service `request_resubmit` review action bounces a submission back for
/// the jeeber to FIX-AND-RESEND specific documents (wire state
/// `ResubmitRequested`, `kyc-service Contracts.cs:12-28`). It is deliberately
/// DISTINCT from [rejected], which is FINAL/appeal-only (D52/D87): resubmit is
/// actionable — the jeeber re-opens the wizard and submits again — so the
/// status view renders a resubmit CTA (never shown on the rejected branch).
enum KycStatus { notSubmitted, pending, approved, rejected, resubmitRequested }

/// A single document slot the back-office asked the jeeber to re-capture when a
/// submission lands in [KycStatus.resubmitRequested] (the per-document-slot
/// resubmit list, `kyc-service Contracts.cs:30-42`). The UI renders one "what to
/// fix" line per step. Server-owned taxonomy: an unrecognised slot maps to
/// [other] so a new server slot degrades to a generic prompt instead of
/// vanishing.
enum KycResubmitStep {
  idFront,
  idBack,
  selfie,
  idNumber,
  other;

  /// Parses the snake_case slot name carried in `resubmit_steps`. Accepts both
  /// the submit-body document names (`id_document_front` …) and their short
  /// aliases; anything else folds into [other].
  static KycResubmitStep fromWire(String raw) {
    switch (raw) {
      case 'id_document_front':
      case 'id_front':
        return KycResubmitStep.idFront;
      case 'id_document_back':
      case 'id_back':
        return KycResubmitStep.idBack;
      case 'selfie_with_liveness':
      case 'selfie':
        return KycResubmitStep.selfie;
      case 'id_number':
        return KycResubmitStep.idNumber;
      default:
        return KycResubmitStep.other;
    }
  }
}

/// Structured reason returned with a rejected submission. Kept as an enum so
/// the UI can render localized copy and analytics can be keyed on the cause.
///
/// D20 (JM-040) removed the in-app Vehicle step, but the back-office reason
/// taxonomy is server-owned, so the legible-document reasons stay; a stray
/// `vehicleDocumentMissing` from a legacy submission still maps to "other".
enum KycRejectionReason {
  idUnreadable,
  selfieMismatch,
  expired,
  other,
}

/// One captured ID side: front or back of the national ID.
enum IdSide { front, back }

/// Identity-document variant sent as `id_type` on the KYC submit body.
///
/// E3 (JEBV4-197 / Q-042) ratifies exactly this pilot set —
/// `national_id | passport | residency` — no more, no less. The wizard's ID
/// step enumerates all three. NOTE: the deployed BFF still spells the third
/// variant `residency_permit`; the gateway lane (JEBV4-197) is aligning
/// `AllowedIdTypes` to this ratified vocabulary — until it lands, a
/// `residency` submit is answered by a field-scoped 400 that the wizard
/// surfaces inline on the type picker.
enum KycIdType {
  nationalId('national_id'),
  passport('passport'),
  residency('residency');

  const KycIdType(this.wire);

  /// The exact snake_case value sent on the wire as `id_type`.
  final String wire;
}

/// Snapshot of the user's KYC submission. Stored on the cubit's state and
/// echoed by [KycGateway.fetchStatus] after submit so the status screen can
/// re-render across cold starts.
///
/// JM-040 (D20): the vehicle type + registration fields were removed. The
/// platform is cash-on-delivery and never collected a vehicle; the KYC form
/// schema (K1) carries only `full_name, national_id, dob, id_front, id_back,
/// selfie`.
class KycSubmission extends Equatable {
  const KycSubmission({
    required this.status,
    this.idType = defaultIdType,
    this.idNumber,
    this.idFront,
    this.idBack,
    this.selfie,
    this.vehicleRegistration,
    this.tosAcceptedVersion,
    this.rejectionReason,
    this.resubmitSteps = const [],
    this.submittedAt,
  });

  /// Default ID variant pre-selected on the wizard's type picker (the most
  /// common document for the pilot market; also the form schema's default
  /// `variant=national_id`). The user can switch to any ratified [KycIdType].
  static const KycIdType defaultIdType = KycIdType.nationalId;

  /// 12-digit national-ID shape enforced by the live BFF
  /// (`KycSubmissionBffController.ValidateSubmitFieldsAsync`, `^\d{12}$`) when
  /// [idType] is `national_id`. Mirrored here so the client can present the
  /// requirement instead of round-tripping to a 400.
  static final RegExp nationalIdPattern = RegExp(r'^\d{12}$');

  final KycStatus status;

  /// KYC identity-document type sent as `id_type` (E3/JEBV4-197 — REQUIRED on
  /// the live contract). One of the ratified [KycIdType] variants; defaults
  /// to [defaultIdType].
  final KycIdType idType;

  /// KYC identity-document number sent as `id_number` (E3/JEBV4-197 —
  /// REQUIRED). For [KycIdType.nationalId] the live BFF requires exactly 12
  /// digits (see [nationalIdPattern]); passport/residency numbers carry no
  /// BFF-enforced shape today, so the client requires only a non-empty value.
  final String? idNumber;

  final PhotoAttachment? idFront;
  final PhotoAttachment? idBack;
  final PhotoAttachment? selfie;

  /// Vehicle-registration document asset, if one ever exists in state. JM-040
  /// (D20) removed the in-app capture step for this (the platform is
  /// COD-only), so no shipped UI path populates it today — this field exists
  /// purely so the submit gateway can send `vehicle_registration_url` on a
  /// send-if-present basis. Whether it is ever required is an open owner
  /// decision (JEBV4-113 §4); this field makes neither call.
  final PhotoAttachment? vehicleRegistration;

  /// ToS acceptance version stamped by [KycGateway.signContract]. Threaded
  /// onto the draft before [KycGateway.submit] so the submit body can carry
  /// `tos_accepted_version` (JEBV4-113).
  final String? tosAcceptedVersion;

  /// Reason attached to a terminal-or-actionable decision. Set when [status]
  /// is [KycStatus.rejected] (final) OR [KycStatus.resubmitRequested] — the
  /// kyc-service makes a reason mandatory on both `reject` and
  /// `request_resubmit` (`KycStore.cs:226-240`).
  final KycRejectionReason? rejectionReason;

  /// The document slots the back-office asked the jeeber to re-capture. Only
  /// populated when [status] is [KycStatus.resubmitRequested]; empty otherwise.
  final List<KycResubmitStep> resubmitSteps;

  /// Server-assigned timestamp echoed in the status response. Null pre-submit.
  final DateTime? submittedAt;

  bool get hasIdFront => idFront != null;
  bool get hasIdBack => idBack != null;
  bool get hasSelfie => selfie != null;
  bool get hasVehicleRegistration => vehicleRegistration != null;

  /// Whether [idNumber] satisfies the live contract for the current [idType]:
  /// `^\d{12}$` for [KycIdType.nationalId] (the only shape the BFF enforces
  /// today — mirrored, not invented), non-empty for passport/residency (E3
  /// makes `id_number` required; the BFF applies no shape to those variants).
  bool get hasValidIdNumber {
    final number = idNumber?.trim() ?? '';
    if (number.isEmpty) return false;
    if (idType == KycIdType.nationalId) {
      return nationalIdPattern.hasMatch(number);
    }
    return true;
  }

  KycSubmission copyWith({
    KycStatus? status,
    KycIdType? idType,
    String? idNumber,
    PhotoAttachment? idFront,
    PhotoAttachment? idBack,
    PhotoAttachment? selfie,
    PhotoAttachment? vehicleRegistration,
    String? tosAcceptedVersion,
    KycRejectionReason? rejectionReason,
    bool clearRejectionReason = false,
    List<KycResubmitStep>? resubmitSteps,
    DateTime? submittedAt,
  }) {
    return KycSubmission(
      status: status ?? this.status,
      idType: idType ?? this.idType,
      idNumber: idNumber ?? this.idNumber,
      idFront: idFront ?? this.idFront,
      idBack: idBack ?? this.idBack,
      selfie: selfie ?? this.selfie,
      vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
      tosAcceptedVersion: tosAcceptedVersion ?? this.tosAcceptedVersion,
      rejectionReason:
          clearRejectionReason ? null : (rejectionReason ?? this.rejectionReason),
      resubmitSteps: resubmitSteps ?? this.resubmitSteps,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        idType,
        idNumber,
        idFront,
        idBack,
        selfie,
        vehicleRegistration,
        tosAcceptedVersion,
        rejectionReason,
        resubmitSteps,
        submittedAt,
      ];
}
