// sprint-009 scenario matrix #8 (feat/request-scenarios).
//
// PROVES the request-unavailable terminal screen (cancelled/expired/matched
// request reached from a push tap or cold deep link) is a graceful, localized
// surface — not the sanity-build stub that hard-coded English "Request
// unavailable"/"Back" and gave no forward affordance.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  const requestId = 'req-dead-001';

  testWidgets(
      'renders localized OmdsEmptyState with the request id and a '
      '"Browse other requests" CTA', (tester) async {
    var backCount = 0;
    await tester.pumpWidget(
      wrapForTest(
        JeeberRequestUnavailableScreen(
          requestId: requestId,
          onBack: () => backCount++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // OMDS empty state — not a bare Text dead-end.
    expect(find.byType(OmdsEmptyState), findsOneWidget);
    expect(
      find.byKey(const Key('jeeber-request-unavailable-state')),
      findsOneWidget,
    );
    // Localized copy from the ARBs (title + id-bearing body).
    expect(find.text('Request no longer available'), findsNWidgets(2),
        reason: 'app bar + empty-state title share the localized key');
    expect(
      find.text('Request $requestId is no longer available.'),
      findsOneWidget,
    );
    // The pre-fix hard-coded strings are gone.
    expect(find.text('Request unavailable'), findsNothing);
    expect(find.text('Back'), findsNothing);

    // Semantics id for QA targeting.
    expect(
      find.bySemanticsIdentifier('jeeber_request_unavailable'),
      findsOneWidget,
    );

    // Forward affordance: browse-other-requests CTA fires the onBack edge.
    final cta = find.byKey(const Key('jeeber-request-unavailable-back-cta'));
    expect(cta, findsOneWidget);
    expect(find.text('Browse other requests'), findsOneWidget);
    await tester.tap(cta);
    expect(backCount, 1);
  });

  testWidgets('renders RTL-correct Arabic copy under the ar locale',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        JeeberRequestUnavailableScreen(
          requestId: requestId,
          onBack: () {},
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الطلب لم يعد متاحًا'), findsNWidgets(2));
    expect(find.text('تصفح الطلبات الأخرى'), findsOneWidget);
  });
}
