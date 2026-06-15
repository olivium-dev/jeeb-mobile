// P2 polish — Jeeber request-detail summary enrichment (DEF-2).
//
// The summary used to render a single flat `Text(shortLabel)` under a
// "What the client says" header — sparse, and semantically wrong (the
// shortLabel the feed row sets is the PICKUP label, not the client's item
// description). These tests pin the enriched layout: the two genuinely-present
// FeedRequest fields (`shortLabel` → pickup, `id` → request reference) laid
// out with the OMDS `OMDSSectionCard` + detail-row idiom. No invented fields,
// no network calls — only data actually present on the model.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';

import 'support/sync_app_localizations.dart';

void main() {
  Widget harness({Locale locale = const Locale('en')}) => wrapForTest(
        JeeberRequestDetailScreen(
          request: const FeedRequest(
            id: 'REQ-001',
            shortLabel: '2kg tomatoes from the souq',
          ),
          reportService: const ProhibitedItemReportService(),
          onDeclined: (_) {},
        ),
        locale: locale,
      );

  testWidgets('summary renders an OMDS section card (not a flat Text block)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('jeeber-request-detail-summary')),
      findsOneWidget,
    );
    expect(find.byType(OMDSSectionCard), findsOneWidget);
  });

  testWidgets(
      'surfaces BOTH present fields: pickup label + request reference',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // shortLabel is the pickup, now under the "Pickup" row (was mislabelled
    // under the description header).
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('2kg tomatoes from the souq'), findsOneWidget);

    // FAIL-WITHOUT: the prior flat layout showed only shortLabel — it never
    // surfaced the request reference. This asserts the id is now visible.
    expect(find.text('Request reference'), findsOneWidget);
    expect(find.text('REQ-001'), findsOneWidget);
  });

  testWidgets('the offer + decline CTAs remain intact', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Both CTAs still present (enrichment must not regress the action bar).
    expect(find.byType(OmdsPrimaryButton), findsNWidgets(2));
  });

  testWidgets('Arabic locale renders the localized field labels',
      (tester) async {
    await tester.pumpWidget(harness(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    // jeeberRequestDetailSectionPickup / jeeberRequestDetailReference (ar).
    expect(find.text('نقطة الاستلام'), findsOneWidget);
    expect(find.text('مرجع الطلب'), findsOneWidget);
  });
}
