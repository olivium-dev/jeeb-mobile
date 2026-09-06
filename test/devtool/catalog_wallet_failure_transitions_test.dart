import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/wallet_hub_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/wallet_activity_list_screen_fixtures.dart';
import 'package:jeeb_mobile/features/wallet/application/wallet_hub_cubit.dart';
import 'package:jeeb_mobile/features/wallet/application/wallet_ledger_cubit.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/midnight_test_harness.dart';

void main() {
  for (final locale in kFailureLocales) {
    for (final kind in ['hub', 'ledger', 'page']) {
      testWidgets(
        'wallet catalog performs failed $kind operation: ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          tester.view.physicalSize = const Size(440, 956);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final state = kScreenCatalog
              .singleWhere(
                (e) =>
                    e.screen ==
                    (kind == 'hub'
                        ? 'WalletHubScreen'
                        : 'WalletActivityListScreen'),
              )
              .states
              .singleWhere(
                (s) =>
                    s.label ==
                    switch (kind) {
                      'hub' => 'Refresh failed — warm note over a live balance',
                      'page' =>
                        'Load-more failed — footer retry, no scroll loop',
                      _ => 'Refresh failed — rows stay up',
                    },
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
          if (kind == 'hub') {
            final note = find.byType(JeebRefreshFailedNote);
            expect(note, findsOneWidget);
            final cubit = tester.element(note).read<WalletHubCubit>();
            final balance = cubit.state.balance;
            expect(balance, isNotNull);
            expect(cubit.state.refreshError, isA<NetworkFailure>());
            final repository =
                (cubit as WalletHubCatalogCubit).observedRepository;
            expect(repository.fetchCalls, 2);
            await tester.tap(
              find.byTooltip(
                AppLocalizations.of(tester.element(note)).actionRetry,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              repository.fetchCalls,
              3,
              reason:
                  'retry must perform the operation, not leave an inert note',
            );
            expect(cubit.state.balance, balance);
            expect(cubit.state.refreshError, isA<NetworkFailure>());
            expect(note, findsOneWidget);
            await tester.pumpWidget(const SizedBox());
            expect(cubit.isClosed, isTrue);
          } else {
            final target = kind == 'page'
                ? find.byWidgetPredicate(
                    (w) =>
                        w is JeebCtaButton &&
                        w.identifier == 'wallet_activity_load_more_retry',
                  )
                : find.byType(JeebRefreshFailedNote);
            expect(target, findsOneWidget);
            final cubit = tester.element(target).read<WalletLedgerCubit>();
            final entries = cubit.state.entries;
            expect(entries.length, 3);
            expect(
              kind == 'page'
                  ? cubit.state.loadMoreFailure
                  : cubit.state.refreshError,
              isA<NetworkFailure>(),
            );
            final observed = cubit as WalletActivityCatalogCubit;
            expect(observed.requestedPages, kind == 'page' ? [1, 2] : [1, 1]);
            if (kind == 'page') {
              await tester.tap(target);
            } else {
              await tester.tap(
                find.byTooltip(
                  AppLocalizations.of(tester.element(target)).actionRetry,
                ),
              );
            }
            await tester.pumpAndSettle();
            expect(
              observed.requestedPages,
              kind == 'page' ? [1, 2, 2] : [1, 1, 1],
              reason: 'the actual repository must receive exactly one retry',
            );
            expect(cubit.state.entries, entries);
            expect(
              kind == 'page'
                  ? cubit.state.loadMoreFailure
                  : cubit.state.refreshError,
              isA<NetworkFailure>(),
            );
            expect(target, findsOneWidget);
            await tester.pumpWidget(const SizedBox());
            expect(cubit.isClosed, isTrue);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
