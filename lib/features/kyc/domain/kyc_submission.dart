import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';

/// Decision the back-office returned for a [KycSubmission]. `pending` is the
/// state immediately after submit; `approved`/`rejected` are terminal.
enum KycStatus { notSubmitted, pending, approved, rejected }

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
    this.idFront,
    this.idBack,
    this.selfie,
    this.vehicleRegistration,
    this.tosAcceptedVersion,
    this.rejectionReason,
    this.submittedAt,
  });

  final KycStatus status;
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

  /// Only set when [status] is [KycStatus.rejected].
  final KycRejectionReason? rejectionReason;

  /// Server-assigned timestamp echoed in the status response. Null pre-submit.
  final DateTime? submittedAt;

  bool get hasIdFront => idFront != null;
  bool get hasIdBack => idBack != null;
  bool get hasSelfie => selfie != null;
  bool get hasVehicleRegistration => vehicleRegistration != null;

  KycSubmission copyWith({
    KycStatus? status,
    PhotoAttachment? idFront,
    PhotoAttachment? idBack,
    PhotoAttachment? selfie,
    PhotoAttachment? vehicleRegistration,
    String? tosAcceptedVersion,
    KycRejectionReason? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? submittedAt,
  }) {
    return KycSubmission(
      status: status ?? this.status,
      idFront: idFront ?? this.idFront,
      idBack: idBack ?? this.idBack,
      selfie: selfie ?? this.selfie,
      vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
      tosAcceptedVersion: tosAcceptedVersion ?? this.tosAcceptedVersion,
      rejectionReason:
          clearRejectionReason ? null : (rejectionReason ?? this.rejectionReason),
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  @override
  List<Object?> get props => [
        status,
        idFront,
        idBack,
        selfie,
        vehicleRegistration,
        tosAcceptedVersion,
        rejectionReason,
        submittedAt,
      ];
}
