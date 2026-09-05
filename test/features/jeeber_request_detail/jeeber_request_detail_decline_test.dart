// X2: the awaitable decline, tested in-fence. `onDeclineRequest == null` keeps
// today's behaviour for every devtool entry and existing test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const _request = FeedRequest(id: 'req-101', shortLabel: 'Hamra, Beirut');

Widget _screen({
  required ValueChanged<String> onDeclined,
  Future<void> Function(String)? onDeclineRequest,
  Locale locale = const Locale('en'),
}) =>
    wrapForTest(
      JeeberRequestDetailScreen(
        request: _request,
        reportService: const ProhibitedItemReportService(),
        onDeclined: onDeclined,
        onDeclineRequest: onDeclineRequest,
      ),
      locale: locale,
    );

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a SUCCESSFUL awaited decline calls the repository, '
        'then onDeclined', (tester) async {
      final declined = <String>[];
      final calls = <String>[];

      useReduceMotion(tester);
      await tester.pumpWidget(
        _screen(
          onDeclined: declined.add,
          onDeclineRequest: (id) async => calls.add(id),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('jeeber-request-detail-decline'),
      );
      await tester.pumpAndSettle();

      expect(calls, ['req-101']);
      expect(declined, ['req-101']);
    });

    testWidgets('[$tag] a FAILING decline raises the snack and does NOT '
        'announce a decline', (tester) async {
      final declined = <String>[];

      useReduceMotion(tester);
      await tester.pumpWidget(
        _screen(
          onDeclined: declined.add,
          onDeclineRequest: (_) async => throw const ServerFailure(status: 500),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('jeeber-request-detail-decline'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.bySemanticsIdentifier(
          'jeeber_request_detail_decline_failed_snack',
        ),
        findsOneWidget,
      );
      expect(declined, isEmpty);
    });
  }

  testWidgets('with NO awaitable decline wired the screen behaves as today',
      (tester) async {
    final declined = <String>[];

    useReduceMotion(tester);
    await tester.pumpWidget(_screen(onDeclined: declined.add));
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsIdentifier('jeeber-request-detail-decline'),
    );
    await tester.pumpAndSettle();

    expect(declined, ['req-101']);
  });
}
