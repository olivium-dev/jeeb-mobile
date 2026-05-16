import 'package:equatable/equatable.dart';

import '../../photo_attachment/domain/photo_attachment.dart';
import 'vehicle_type.dart';

/// Decision the back-office returned for a [KycSubmission]. `pending` is the
/// state immediately after submit; `approved`/`rejected` are terminal.
enum KycStatus { notSubmitted, pending, approved, rejected }

/// Structured reason returned with a rejected submission. Kept as an enum so
/// the UI can render localized copy and analytics can be keyed on the cause.
enum KycRejectionReason {
  idUnreadable,
  selfieMismatch,
  vehicleDocumentMissing,
  expired,
  other,
}

/// One captured ID side: front or back of the national ID.
enum IdSide { front, back }

/// Snapshot of the user's KYC submission. Stored on the cubit's state and
/// echoed by [KycGateway.fetchStatus] after submit so the status screen can
/// re-render across cold starts.
class KycSubmission extends Equatable {
  const KycSubmission({
    required this.status,
    this.idFront,
    this.idBack,
    this.selfie,
    this.vehicleType,
    this.vehicleRegistration = '',
    this.rejectionReason,
    this.submittedAt,
  });

  final KycStatus status;
  final PhotoAttachment? idFront;
  final PhotoAttachment? idBack;
  final PhotoAttachment? selfie;
  final VehicleType? vehicleType;

  /// Free-text registration / plate number. Empty until the user fills step 3.
  final String vehicleRegistration;

  /// Only set when [status] is [KycStatus.rejected].
  final KycRejectionReason? rejectionReason;

  /// Server-assigned timestamp echoed in the status response. Null pre-submit.
  final DateTime? submittedAt;

  bool get hasIdFront => idFront != null;
  bool get hasIdBack => idBack != null;
  bool get hasSelfie => selfie != null;
  bool get hasVehicle =>
      vehicleType != null && vehicleRegistration.trim().isNotEmpty;

  KycSubmission copyWith({
    KycStatus? status,
    PhotoAttachment? idFront,
    PhotoAttachment? idBack,
    PhotoAttachment? selfie,
    VehicleType? vehicleType,
    String? vehicleRegistration,
    KycRejectionReason? rejectionReason,
    bool clearRejectionReason = false,
    DateTime? submittedAt,
  }) {
    return KycSubmission(
      status: status ?? this.status,
      idFront: idFront ?? this.idFront,
      idBack: idBack ?? this.idBack,
      selfie: selfie ?? this.selfie,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
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
        vehicleType,
        vehicleRegistration,
        rejectionReason,
        submittedAt,
      ];
}
