// Isolated native UI test — ClientOffersScreen (offer-review-list). Drives the
// screen off an in-memory OffersRepository through the test cubit factory (empty
// poll/clock ticks so the binding has no pending timers). The screen owns its
// own Scaffold + BlocProvider, so we pump it directly.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/client_offers/application/client_offers_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';

import '../support/screen_harness.dart';

/// In-memory OffersRepository serving a single fixed snapshot (inlined so the
/// integration test doesn't reach into test/support/).
class _StaticOffersRepository implements OffersRepository {
  _StaticOffersRepository(this._snapshot);

  final OffersSnapshot _snapshot;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async => _snapshot;

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async =>
      OfferAcceptResult.empty;
}

/// Mirrors test/support/offers_fixtures.dart's buildOffer with the same
/// defaults so the cards render exactly like the widget tests.
Offer _offer({
  String id = 'offer-1',
  String jeeberName = 'Karim',
  double fee = 30,
  String currency = 'USD',
  int etaMinutes = 12,
  JeeberVehicle vehicle = JeeberVehicle.scooter,
  double rating = 4.6,
  int ratingCount = 80,
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
    submittedAt: DateTime.utc(2026, 5, 17, 12),
  );
}

OffersSnapshot _snapshot(List<Offer> offers) => OffersSnapshot(
      offers: List.unmodifiable(offers),
      windowExpiresAt: DateTime.now().add(const Duration(minutes: 5)),
      requestIsOpen: true,
    );

/// Injects empty poll/clock ticks so the on-device binding has no pending
/// timers (mirrors the widget test's _testCubitFactory).
ClientOffersCubit _cubitFactory(OffersRepository repository, String requestId) {
  return ClientOffersCubit(
    repository: repository,
    requestId: requestId,
    pollTicks: const Stream.empty(),
    clockTicks: const Stream.empty(),
  );
}

Widget _offers(OffersSnapshot snapshot) => ClientOffersScreen(
      requestId: 'req-1',
      repository: _StaticOffersRepository(snapshot),
      cubitFactory: _cubitFactory,
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('client-offers: populated offer list (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _offers(_snapshot([
        _offer(id: 'a', jeeberName: 'Karim', fee: 30, vehicle: JeeberVehicle.scooter),
        _offer(id: 'b', jeeberName: 'Hadi', fee: 15, vehicle: JeeberVehicle.bicycle),
      ])),
      'client-offers__populated',
    );
  });

  testWidgets('client-offers: empty / waiting for offers (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _offers(_snapshot(const [])),
      'client-offers__empty',
    );
  });

  testWidgets('client-offers: populated offer list (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _offers(_snapshot([
        _offer(id: 'a', jeeberName: 'Karim', fee: 30),
        _offer(id: 'b', jeeberName: 'Hadi', fee: 15),
      ])),
      'client-offers__ar',
      locale: const Locale('ar'),
    );
  });
}
