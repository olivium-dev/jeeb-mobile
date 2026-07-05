// Isolated native UI test — JeeberPendingOffersScreen (jeeber-pending-offers,
// JM-047). The screen builds a SubmittedOffersCubit off the `repository` seam
// and calls load(), so injecting a scripted in-memory list avoids DI/network.
// Covers the populated list (awaiting + a terminal badge), the empty state, and
// the populated list in Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offer.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/domain/submitted_offers_repository.dart';

import '../support/screen_harness.dart';

/// In-memory submitted-offers repo serving a fixed list (or throwing). Inlined
/// so the integration test never reaches into test/support/.
class _FakePendingRepository implements SubmittedOffersRepository {
  _FakePendingRepository({List<SubmittedOffer>? offers, this.listThrows = false})
      : _offers = List<SubmittedOffer>.of(offers ?? const <SubmittedOffer>[]);

  final List<SubmittedOffer> _offers;
  final bool listThrows;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    if (listThrows) throw Exception('boom');
    return _offers;
  }

  @override
  Future<bool> withdraw(String offerId) async => true;
}

SubmittedOffer _offer(
  String id, {
  int? eta = 25,
  double price = 12.5,
  OfferStatus status = OfferStatus.submitted,
}) =>
    SubmittedOffer(
      id: id,
      requestId: 'req-$id',
      price: price,
      currency: 'USD',
      etaMinutes: eta,
      status: status,
    );

JeeberPendingOffersScreen _screen({
  List<SubmittedOffer>? offers,
  bool listThrows = false,
}) =>
    JeeberPendingOffersScreen(
      jeeberId: 'user-jeeber-002',
      repository: _FakePendingRepository(offers: offers, listThrows: listThrows),
    );

final _offers = <SubmittedOffer>[
  _offer('open-1', price: 12.5, eta: 25),
  _offer('open-2', price: 8.0, eta: 15),
  _offer('accepted-1', price: 9.0, status: OfferStatus.accepted),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jeeber-pending-offers: populated list (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(offers: _offers),
      'jeeber-pending-offers__populated',
    );
  });

  testWidgets('jeeber-pending-offers: empty list (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(offers: const []),
      'jeeber-pending-offers__empty',
    );
  });

  testWidgets('jeeber-pending-offers: populated list (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(offers: _offers),
      'jeeber-pending-offers__ar',
      locale: const Locale('ar'),
    );
  });
}
