import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/domain/client_home_request.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/offer_status_requests_tab.dart';

import '../../support/sync_app_localizations.dart';

ClientHomeRequest _request({
  required String id,
  String? deliveryId,
  Set<ClientOfferStatus> statuses = const {ClientOfferStatus.accepted},
}) =>
    ClientHomeRequest(
      id: id,
      title: 'Two coffees',
      status: ClientRequestStatus.accepted,
      destinationLabel: 'Achrafieh',
      displayId: 'ORD-38D786',
      deliveryId: deliveryId,
      offerStatuses: statuses,
    );

void main() {
  testWidgets('the Accepted filter card opens the order (it was inert)',
      (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      wrapForTest(
        OfferStatusRequestsTab(
          status: ClientOfferStatus.accepted,
          requests: [_request(id: 'req-1', deliveryId: 'delivery-1')],
          onOpenRequest: (r) => opened.add(r.trackingId),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('offer_status_request_req-1'));
    await tester.pump();

    expect(opened, ['delivery-1']);
  });

  testWidgets('a card with no request id stays inert rather than opening a '
      'dead route', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      wrapForTest(
        OfferStatusRequestsTab(
          status: ClientOfferStatus.accepted,
          requests: [_request(id: '')],
          onOpenRequest: (r) => opened.add(r.id),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsIdentifier('offer_status_request_'));
    await tester.pump();

    expect(opened, isEmpty);
  });
}
