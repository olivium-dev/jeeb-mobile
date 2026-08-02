import 'package:equatable/equatable.dart';

class JeeberSummary extends Equatable {
  const JeeberSummary({
    required this.displayName,
    required this.vehicleLabel,
    this.phoneE164,
    this.avatarUrl,
    this.rating,
  });

  final String displayName;

  final String vehicleLabel;

  final String? phoneE164;

  final String? avatarUrl;

  final double? rating;

  @override
  List<Object?> get props => [
        displayName,
        vehicleLabel,
        phoneE164,
        avatarUrl,
        rating,
      ];
}
