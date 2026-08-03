import 'package:equatable/equatable.dart';

enum TierId { flash, express, standard, onTheWay, eco }

/// constraints map to "what kind of Jeeber will pick this up" not to a single
enum TierVehicleClass { bikeOrScooter, scooterOrCar, carOrVan, any }

class Tier extends Equatable {
  const Tier({
    required this.id,
    required this.priceLow,
    required this.priceHigh,
    required this.currency,
    required this.vehicleClass,
    this.serverId,
    this.slaMinutes,
    this.recommended = false,
  });

  final TierId id;

  final String? serverId;

  final int priceLow;
  final int priceHigh;
  final String currency;
  final TierVehicleClass vehicleClass;

  final int? slaMinutes;

  final bool recommended;

  String? get wireId => serverId;

  @override
  List<Object?> get props => [
    id,
    serverId,
    priceLow,
    priceHigh,
    currency,
    vehicleClass,
    slaMinutes,
    recommended,
  ];
}
