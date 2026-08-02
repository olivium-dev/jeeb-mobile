import 'package:equatable/equatable.dart';

import 'jeeber_vehicle.dart';

class Offer extends Equatable {
  const Offer({
    required this.id,
    required this.jeeberId,
    required this.jeeberName,
    required this.fee,
    required this.currency,
    required this.etaMinutes,
    required this.vehicle,
    required this.rating,
    required this.ratingCount,
    required this.submittedAt,
    this.avatarUrl,
    this.note,
  });

  final String id;
  final String jeeberId;
  final String jeeberName;

  final double fee;
  final String currency;
  final int etaMinutes;
  final JeeberVehicle vehicle;

  final double rating;

  final int ratingCount;

  final DateTime submittedAt;

  final String? avatarUrl;

  final String? note;

  @override
  List<Object?> get props => [
        id,
        jeeberId,
        jeeberName,
        fee,
        currency,
        etaMinutes,
        vehicle,
        rating,
        ratingCount,
        submittedAt,
        avatarUrl,
        note,
      ];
}
