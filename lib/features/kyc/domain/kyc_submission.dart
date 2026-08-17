import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';

/// Back-office decision: notSubmitted → pending → approved/rejected (terminal).
enum KycStatus { notSubmitted, pending, approved, rejected, resubmitRequested }

enum KycResubmitStep {
  idFront,
  idBack,
  selfie,
  idNumber,
  other;

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

/// Structured rejection reason; enum so UI renders localized copy and analytics keys on cause.
enum KycRejectionReason {
  idUnreadable,
  selfieMismatch,
  expired,
  other,
}

enum IdSide { front, back }

enum KycIdType {
  nationalId('national_id'),
  passport('passport'),
  residency('residency');

  const KycIdType(this.wire);

  final String wire;
}

/// User's KYC submission; echoed by [KycGateway.fetchStatus] after submit.
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

  static const KycIdType defaultIdType = KycIdType.nationalId;

  static final RegExp nationalIdPattern = RegExp(r'^\d{12}$');

  /// Server-enforced `id_number` shapes, per `id_type`. These MIRROR the
  /// gateway BFF (JEBV4-256), which in turn mirrors the form-builder
  /// `jeeb_jeeber_v1` flavor patterns — so a value this app accepts is a value
  /// the BFF accepts. Until now only [nationalIdPattern] was checked here, on a
  /// stale premise that passport/residency were unconstrained server-side; they
  /// are not, so the client let users submit values the BFF 400s.
  static final RegExp passportPattern = RegExp(r'^[A-Z0-9]{6,9}$');
  static final RegExp residencyPattern = RegExp(r'^[A-Z0-9]{6,12}$');

  /// The shape the BFF will enforce for [type]. Single source of truth for
  /// validation, the character filter and the length cap.
  static RegExp patternFor(KycIdType type) {
    switch (type) {
      case KycIdType.nationalId:
        return nationalIdPattern;
      case KycIdType.passport:
        return passportPattern;
      case KycIdType.residency:
        return residencyPattern;
    }
  }

  /// Longest value the BFF accepts for [type] — the field's `maxLength`.
  static int maxLengthFor(KycIdType type) {
    switch (type) {
      case KycIdType.nationalId:
        return 12;
      case KycIdType.passport:
        return 9;
      case KycIdType.residency:
        return 12;
    }
  }

  final KycStatus status;

  final KycIdType idType;

  final String? idNumber;

  final PhotoAttachment? idFront;
  final PhotoAttachment? idBack;
  final PhotoAttachment? selfie;

  // JM-040 (D20) removed in-app capture step for vehicle registration.
  final PhotoAttachment? vehicleRegistration;

  final String? tosAcceptedVersion;

  /// Set when [status] is [KycStatus.rejected] (final) or [KycStatus.resubmitRequested].
  final KycRejectionReason? rejectionReason;

  final List<KycResubmitStep> resubmitSteps;

  final DateTime? submittedAt;

  bool get hasIdFront => idFront != null;
  bool get hasIdBack => idBack != null;
  bool get hasSelfie => selfie != null;
  bool get hasVehicleRegistration => vehicleRegistration != null;

  bool get hasValidIdNumber {
    final number = idNumber?.trim() ?? '';
    if (number.isEmpty) return false;
    return patternFor(idType).hasMatch(number);
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
