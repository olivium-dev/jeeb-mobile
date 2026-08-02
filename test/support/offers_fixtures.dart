import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';

/// Reusable offer payloads for the cubit and widget tests. All baseline
/// timestamps anchor to the same epoch instant so the secondary-sort
final DateTime kBaseTime = DateTime.utc(2026, 5, 17, 12);

Offer buildOffer({
  String id = 'offer-1',
  String jeeberName = 'Karim',
  double fee = 30,
  String currency = 'USD',
  int etaMinutes = 12,
  JeeberVehicle vehicle = JeeberVehicle.scooter,
  double rating = 4.6,
  int ratingCount = 80,
  DateTime? submittedAt,
  String? note,
}) {
  return Offer(
    id: id,
    jeeberId: 'jeeber-$id',
    jeeberName: jeeberName,
    fee: fee,
    currency: currency,
    etaMinutes: etaMinutes,
    vehicle: vehicle,
    rating: rating,
    ratingCount: ratingCount,
    submittedAt: submittedAt ?? kBaseTime,
    note: note,
  );
}
