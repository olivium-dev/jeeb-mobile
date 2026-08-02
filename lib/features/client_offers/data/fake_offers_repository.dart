import 'dart:async';
import 'dart:math';

import '../domain/jeeber_vehicle.dart';
import '../domain/offer.dart';
import '../domain/offers_repository.dart';

class FakeOffersRepository implements OffersRepository {
  FakeOffersRepository({
    DateTime? windowExpiresAt,
    List<Offer>? seed,
    List<Offer>? incoming,
    Duration incomingInterval = const Duration(seconds: 5),
    OffersFailure? acceptFailure,
  })  : _windowExpiresAt = windowExpiresAt,
        _offers = List<Offer>.of(seed ?? _defaultSeed()),
        _incoming = List<Offer>.of(incoming ?? const <Offer>[]),
        _incomingInterval = incomingInterval,
        _acceptFailure = acceptFailure;

  final DateTime? _windowExpiresAt;
  final List<Offer> _offers;
  final List<Offer> _incoming;
  final Duration _incomingInterval;
  OffersFailure? _acceptFailure;
  bool _requestOpen = true;

  void pushOffer(Offer offer) => _offers.add(offer);

  void closeRequest() => _requestOpen = false;

  void scriptAcceptFailure(OffersFailure failure) => _acceptFailure = failure;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    if (_incoming.isNotEmpty &&
        DateTime.now().isAfter(_lastEmittedAt.add(_incomingInterval))) {
      _offers.add(_incoming.removeAt(0));
      _lastEmittedAt = DateTime.now();
    }
    return OffersSnapshot(
      offers: List.unmodifiable(_offers),
      windowExpiresAt: _windowExpiresAt,
      requestIsOpen: _requestOpen,
    );
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    if (_acceptFailure != null) {
      final failure = _acceptFailure!;
      _acceptFailure = null;
      throw OffersRepositoryException(failure);
    }
    if (!_requestOpen) {
      throw const OffersRepositoryException(OffersFailure.requestNotOpen);
    }
    if (_offers.every((o) => o.id != offerId)) {
      throw const OffersRepositoryException(OffersFailure.offerNotPending);
    }
    _requestOpen = false;
    return OfferAcceptResult(
      deliveryId: requestId,
      conversationId: 'conv-for-$requestId',
    );
  }

  DateTime _lastEmittedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static List<Offer> _defaultSeed() {
    final now = DateTime.now();
    final rng = Random(7);
    return List<Offer>.generate(3, (i) {
      return Offer(
        id: 'demo-offer-${i + 1}',
        jeeberId: 'jeeber-${i + 1}',
        jeeberName: _demoNames[i % _demoNames.length],
        fee: 25.0 + i * 7,
        currency: 'USD',
        etaMinutes: 8 + i * 4,
        vehicle: _demoVehicles[i % _demoVehicles.length],
        rating: 4.2 + rng.nextDouble() * 0.7,
        ratingCount: 24 + rng.nextInt(180),
        submittedAt: now.subtract(Duration(seconds: i * 12)),
      );
    });
  }

  static const List<String> _demoNames = ['Karim', 'Hadi', 'Rana', 'Sami'];
  static const List<JeeberVehicle> _demoVehicles = [
    JeeberVehicle.scooter,
    JeeberVehicle.motorcycle,
    JeeberVehicle.car,
    JeeberVehicle.bicycle,
  ];
}
