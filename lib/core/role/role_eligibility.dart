import 'package:equatable/equatable.dart';

/// Inputs the [RoleToggle] uses to decide whether a role switch is allowed.
///
/// - [isJeeberKycApproved]: when false, switching to [UserRole.jeeber] is
///   gated by the KYC prompt CTA instead of flipping the role directly.
/// - [hasActiveDelivery]: when true, any role switch is blocked and the user
///   is shown an explanation — switching mid-delivery would orphan tracking
///   state and break the offer pipeline.
class RoleEligibility extends Equatable {
  const RoleEligibility({
    this.isJeeberKycApproved = false,
    this.hasActiveDelivery = false,
  });

  final bool isJeeberKycApproved;
  final bool hasActiveDelivery;

  RoleEligibility copyWith({
    bool? isJeeberKycApproved,
    bool? hasActiveDelivery,
  }) {
    return RoleEligibility(
      isJeeberKycApproved: isJeeberKycApproved ?? this.isJeeberKycApproved,
      hasActiveDelivery: hasActiveDelivery ?? this.hasActiveDelivery,
    );
  }

  @override
  List<Object?> get props => [isJeeberKycApproved, hasActiveDelivery];
}
