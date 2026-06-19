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
    this.rejectionReason,
    this.submittedAt,
  });

  final KycStatus status;
  final PhotoAttachment? idFront;
  final PhotoAttachment? idBack;
  final PhotoAttachment? selfie;

  /// Only set when [status] is [KycStatus.rejected].
  final KycRejectionReason? rejectionReason;

  /// Server-assigned timestamp echoed in the status response. Null pre-submit.
  final DateTime? submittedAt;

  bool get hasIdFront => idFront != null;
  bool get hasIdBack => idBack != null;
  bool get hasSelfie => selfie != null;

  KycSubmission copyWith({
    KycStatus? status,
    PhotoAttachment? idFront,
    PhotoAttachment? idBack,
    PhotoAttachment? selfie,
    KycRejectionReason? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? submittedAt,
  }) {
    return KycSubmission(
      status: status ?? this.status,
      idFront: idFront ?? this.idFront,
      idBack: idBack ?? this.idBack,
      selfie: selfie ?? this.selfie,
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
        rejectionReason,
        submittedAt,
      ];
}
