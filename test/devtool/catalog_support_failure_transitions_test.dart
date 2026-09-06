import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/support_ticket_screen_fixtures.dart';
import 'package:jeeb_mobile/features/support/application/support_detail_cubit.dart';
import 'package:jeeb_mobile/features/support/application/support_detail_state.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/midnight_test_harness.dart';
import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';

void main() {
  test('support failure fixtures preserve the classified cause', () async {
    for (final fixture in [
      (SupportFailure.network, const NetworkFailure()),
      (SupportFailure.unauthorized, const UnauthorizedFailure()),
    ]) {
      final repo = SupportTicketScreenFailingRepository(fixture.$1, fixture.$2);
      await expectLater(
        repo.submitTicket(
          const SupportTicketDraft(
            category: SupportCategory.payment,
            body: 'A payment was charged twice.',
          ),
        ),
        throwsA(
          isA<SupportRepositoryException>()
              .having((e) => e.failure, 'kind', fixture.$1)
              .having((e) => e.appFailure, 'cause', fixture.$2),
        ),
      );
    }
  });
  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final pagination in [false, true]) {
      testWidgets(
        'support catalog performs failed ${pagination ? 'page' : 'refresh'}: ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final state = kScreenCatalog
              .singleWhere((e) => e.screen == 'SupportTicketDetailScreen')
              .states
              .singleWhere(
                (s) =>
                    s.label ==
                    (pagination
                        ? 'Pagination failed — footer retry (EP-14)'
                        : 'Refresh failed over a loaded thread'),
              );
          await tester.pumpWidget(
            wrapMidnight(
              Builder(builder: state.builder),
              locale: locale,
              scrollable: false,
            ),
          );
          await pumpPastFakeLatency(tester);
          expect(tester.takeException(), isNull);
          final cubit = tester
              .element(find.text('My delivery arrived with the box crushed.'))
              .read<SupportDetailCubit>();
          expect(cubit.state.phase, SupportDetailPhase.loaded);
          final ticket = cubit.state.ticket;
          expect(ticket, isNotNull);
          expect(ticket!.replies.single.id, 'reply-1');
          if (pagination) {
            expect(
              cubit.state.paginationAppFailure,
              const ServerFailure(status: 500),
            );
            expect(cubit.state.nextCursor, 'opaque:page+2');
            final retry = find.byWidgetPredicate(
              (w) =>
                  w is JeebCtaButton &&
                  w.identifier == 'support_thread_pagination_retry',
            );
          expect(retry, findsOneWidget);
          expect(find.text(AppLocalizations.of(tester.element(retry)).supportThreadLoadEarlierCta), findsNothing,
              reason: 'the failed page has one clear retry action');
            await tester.tap(retry);
          } else {
            expect(
              cubit.state.refreshError,
              const NetworkFailure(offline: true),
            );
            final note = find.byType(JeebRefreshFailedNote);
            expect(note, findsOneWidget);
            expect(
              tester.widget<JeebRefreshFailedNote>(note).identifier,
              'support_thread_refresh_error',
            );
            await tester.tap(
              find.byTooltip(
                AppLocalizations.of(tester.element(note)).actionRetry,
              ),
            );
          }
          await tester.pumpAndSettle();
          expect(cubit.state.ticket, ticket);
          expect(cubit.state.phase, SupportDetailPhase.loaded);
          expect(
            pagination
                ? cubit.state.paginationAppFailure
                : cubit.state.refreshError,
            pagination
                ? const ServerFailure(status: 500)
                : const NetworkFailure(offline: true),
          );
          expect(
            find.text('Thanks — we are checking with the courier now.'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          expect(cubit.isClosed, isTrue);
        },
      );
    }
  }
}
