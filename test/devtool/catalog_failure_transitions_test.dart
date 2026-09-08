import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/prohibited_acknowledgment_dialog_fixtures.dart';
import 'package:jeeb_mobile/features/account_status/application/account_status_cubit.dart';
import 'package:jeeb_mobile/features/account_status/application/account_status_state.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_cubit.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/midnight_test_harness.dart';

Widget _catalogState(String feature, String label) => Builder(
  builder: kScreenCatalog
      .singleWhere((e) => e.feature == feature)
      .states
      .singleWhere((s) => s.label == label)
      .builder,
);

void main() {
  for (final locale in kFailureLocales) {
    testWidgets(
      'account catalog drives failed warm refresh: ${locale.languageCode}',
      (tester) async {
        useReduceMotion(tester);
        await tester.pumpWidget(
          wrapMidnight(
            _catalogState(
              'account_status',
              'Refresh failed over a loaded banner',
            ),
            locale: locale,
            scrollable: false,
          ),
        );
        await pumpPastFakeLatency(tester);
        expect(tester.takeException(), isNull);
        final note = find.byType(JeebRefreshFailedNote);
        expect(note, findsOneWidget);
        final cubit = tester.element(note).read<AccountStatusCubit>();
        expect(cubit.state.status, AccountStatusScreenStatus.loaded);
        expect(cubit.state.info, isNotNull);
        expect(cubit.state.refreshError, isA<NetworkFailure>());
        expect(
          tester.widget<JeebRefreshFailedNote>(note).identifier,
          'account_status_refresh_failed_note',
        );
        await tester.tap(
          find.byTooltip(AppLocalizations.of(tester.element(note)).actionRetry),
        );
        await tester.pumpAndSettle();
        expect(cubit.state.status, AccountStatusScreenStatus.loaded);
        expect(cubit.state.refreshError, isA<NetworkFailure>());
        expect(note, findsOneWidget);
      },
    );

    testWidgets(
      'policy catalog performs rejected acknowledgment: ${locale.languageCode}',
      (tester) async {
        useReduceMotion(tester);
        await tester.pumpWidget(
          wrapMidnight(
            _catalogState(
              'prohibited_acknowledgment',
              'Error — Acknowledge Failed (server)',
            ),
            locale: locale,
            scrollable: false,
          ),
        );
        await pumpPastFakeLatency(tester);
        expect(tester.takeException(), isNull);
        final host = tester.widget<ProhibitedAckDialogHost>(
          find.byType(ProhibitedAckDialogHost),
        );
        final repo = host.repository as AckFailingProhibitedAckRepository;
        final retry = find.byWidgetPredicate(
          (w) =>
              w is JeebCtaButton &&
              w.identifier == 'prohibited_acknowledgment_ack_retry_cta',
        );
        expect(retry, findsOneWidget);
        final context = tester.element(retry);
        final cubit = context.read<ProhibitedAcknowledgmentCubit>();
        expect(cubit.state.status, ProhibitedAckStatus.acknowledgeFailed);
        expect(cubit.state.failure, const ServerFailure(status: 503));
        expect(cubit.state.items, isNotEmpty);
        expect(cubit.state.matches, <String>['knife']);
        expect(
          find.text(AppLocalizations.of(context).prohibitedAckFailedBody),
          findsOneWidget,
        );
        expect(find.text('Weapons & Ammunition'), findsOneWidget);
        expect(repo.acknowledgmentAttempts, 1);
        expect(repo.savedLocally, isFalse);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(repo.acknowledgmentAttempts, 2);
        expect(repo.savedLocally, isFalse);
        expect(cubit.state.status, ProhibitedAckStatus.acknowledgeFailed);
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
