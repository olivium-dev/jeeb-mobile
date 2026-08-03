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

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
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

  testWidgets('summary renders a carded section (not a flat Text block)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('jeeber-request-detail-summary')),
      findsOneWidget,
    );
    // redesign-2026-08: the OMDSSectionCard became the kit's grouped outlined
    // card + a JeebSectionLabel above it. The assertion still is "the summary
    // is a card, not loose text" — only the card widget changed.
    expect(find.byType(JeebOutlinedCard), findsOneWidget);
    expect(find.byType(JeebSectionLabel), findsOneWidget);
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
    // redesign-2026-08: OmdsPrimaryButton → the kit's docked footer pair.
    expect(find.byType(JeebCtaButton), findsNWidgets(2));
    expect(
      find.bySemanticsIdentifier('jeeber-request-detail-make-offer'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('jeeber-request-detail-decline'),
      findsOneWidget,
    );
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
  //    buy/deliver, so it renders first, complete and untruncated. ───────────

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

  // ── redesign-2026-08: the docked footer is two stacked pills of fixed
  //    height, so a large text scale is the realistic overflow risk. ─────────

  testWidgets('redesign: no overflow at 200% text scale with a long request',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: harness(request: g1Request),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
