// LR-14 / ES-17 / JRD-04: a transport failure on the by-id recovery is a
// RETRYABLE rung, and the loading headline is its own line, not the bar title.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_request_detail_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const _requestId = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';
const _recovered = FeedRequest(id: _requestId, shortLabel: 'Souq Waqif');

Widget _loader(
  Future<FeedRequest?> Function() fetch, {
  Locale locale = const Locale('en'),
}) =>
    wrapForTest(
      JeeberRequestDetailLoader(
        requestId: _requestId,
        initial: null,
        fetch: fetch,
        reportService: const ProhibitedItemReportService(),
        onDeclined: (_) {},
        onBack: () {},
      ),
      locale: locale,
    );

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a NetworkFailure draws the retryable rung, not the '
        'unavailable dead end', (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _loader(
          throwingRequestDetailFetch(const NetworkFailure(offline: true)),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('jeeber_request_detail_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_request_detail_retry_cta'),
        findsOneWidget,
      );
      expect(find.byType(JeeberRequestUnavailableScreen), findsNothing);
    });

    testWidgets('[$tag] a genuine MISS still lands on the unavailable screen',
        (tester) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _loader(missingRequestDetailFetch(), locale: locale),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JeeberRequestUnavailableScreen), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('jeeber_request_detail_error'),
        findsNothing,
      );
    });
  }

  testWidgets('the retry re-runs the fetch and resolves', (tester) async {
    var calls = 0;
    useReduceMotion(tester);
    await tester.pumpWidget(
      _loader(() async {
        calls++;
        if (calls == 1) throw const NetworkFailure();
        return _recovered;
      }),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.tap(
      find.bySemanticsIdentifier('jeeber_request_detail_retry_cta'),
    );
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.byType(JeeberRequestDetailScreen), findsOneWidget);
  });

  testWidgets('the loading rung uses its OWN headline, not the bar title',
      (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      _loader(() => Future<FeedRequest?>.delayed(
            const Duration(seconds: 5),
            () => _recovered,
          )),
    );
    await tester.pump();

    final block = find.bySemanticsIdentifier(
      'jeeber_request_detail_loading_state',
    );
    expect(block, findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(block));
    expect(
      find.descendant(
        of: block,
        matching: find.text(l10n.jeeberRequestDetailLoadingHeadline),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: block,
        matching: find.text(l10n.jeeberRequestDetailTitle),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}
