import 'package:equatable/equatable.dart';

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
