import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';

import 'support/sync_app_localizations.dart';

void main() {
  Widget harness({
    Locale locale = const Locale('en'),
    FeedRequest request = const FeedRequest(
      id: 'REQ-001',
      shortLabel: '2kg tomatoes from the souq',
    ),
  }) =>
      wrapForTest(
        JeeberRequestDetailScreen(
          request: request,
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
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('2kg tomatoes from the souq'), findsOneWidget);

    // FAIL-WITHOUT: the prior flat layout showed only shortLabel — it never
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

  // ── G1 (sprint-009 P0) — the FULL description is what the jeeber agrees to

  const g1Request = FeedRequest(
    id: 'REQ-001',
    shortLabel: 'Hamra, Beirut',
    description:
        '2 shawarma + cola from Barbar, extra garlic, no pickles — call me '
        'when you arrive at the building entrance, third floor, ring twice',
  );

  testWidgets('G1: renders the FULL description prominently, before pickup',
      (tester) async {
    await tester.pumpWidget(harness(request: g1Request));
    await tester.pumpAndSettle();

    // Section label + the complete text, verbatim.
    expect(find.text('What the client says'), findsOneWidget);
    final description = find.text(g1Request.description!);
    expect(description, findsOneWidget,
        reason: 'the jeeber must read the ENTIRE request before offering');
    expect(
      find.bySemanticsIdentifier('jeeber_request_detail_description'),
      findsOneWidget,
    );
    // No truncation on the detail (unlike the 2-line feed preview).
    expect(tester.widget<Text>(description).maxLines, isNull);

    // Description leads the card — above the pickup row.
    final descY = tester.getTopLeft(description).dy;
    final pickupY = tester.getTopLeft(find.text('Hamra, Beirut')).dy;
    expect(descY, lessThan(pickupY));
  });

  testWidgets('G1: description row is absent when the payload carries none',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('What the client says'), findsNothing);
    expect(
      find.bySemanticsIdentifier('jeeber_request_detail_description'),
      findsNothing,
    );
  });

  testWidgets('G1: Arabic locale renders the localized description label',
      (tester) async {
    await tester.pumpWidget(
      harness(locale: const Locale('ar'), request: g1Request),
    );
    await tester.pumpAndSettle();

    // jeeberRequestDetailSectionDescription (ar).
    expect(find.text('ما يقوله العميل'), findsOneWidget);
    expect(find.text(g1Request.description!), findsOneWidget);
  });
}
