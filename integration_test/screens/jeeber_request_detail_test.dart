// Isolated native UI test — jeeber-request-detail (/jeeber/requests/:id). The
// JeeberRequestDetailLoader renders the detail SYNCHRONOUSLY when `initial` is a
// non-null FeedRequest (cache-hit path: no fetch, no timers); the by-id `fetch`
// is a no-op here. The detail's Make-offer/Decline CTAs navigate only on tap, so
// the plain MaterialApp harness is enough. We also capture the graceful
// JeeberRequestUnavailableScreen fallback directly. Covers loaded en, the
// unavailable fallback, and loaded Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';

import '../support/screen_harness.dart';

Widget _detail(FeedRequest request) => JeeberRequestDetailLoader(
      requestId: request.id,
      initial: request,
      fetch: () async => null,
      reportService: const ProhibitedItemReportService(),
      onDeclined: (_) {},
      onBack: () {},
    );

const _request = FeedRequest(
  id: 'e30b7f2e-7914-402d-8dd3-e699e6775eae',
  shortLabel: 'Souq Waqif pickup',
  description: 'Two bags of groceries from the corner market, pay on pickup',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jeeber-request-detail: loaded detail (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _detail(_request),
      'jeeber-request-detail__loaded',
    );
  });

  testWidgets('jeeber-request-detail: unavailable fallback (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      JeeberRequestUnavailableScreen(requestId: _request.id, onBack: () {}),
      'jeeber-request-detail__unavailable',
    );
  });

  testWidgets('jeeber-request-detail: loaded detail (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _detail(_request),
      'jeeber-request-detail__ar',
      locale: const Locale('ar'),
    );
  });
}
