import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/kyc_wizard_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/midnight_test_harness.dart';

void main() {
  for (final locale in kFailureLocales) {
    testWidgets(
      'KYC catalog stale state runs refresh and real retry ${locale.languageCode}',
      (tester) async {
        useReduceMotion(tester);
        final entry = kScreenCatalog.singleWhere((e) => e.feature == 'kyc');
        final state = entry.states.singleWhere(
          (s) =>
              s.label == 'Status stale — the background refresh failed (F26)',
        );
        await tester.pumpWidget(
          wrapMidnight(
            Builder(builder: state.builder),
            locale: locale,
            scrollable: false,
          ),
        );
        await pumpPastFakeLatency(tester);
        final note = find.bySemanticsIdentifier(
          'kyc_status_refresh_failed_note',
        );
        expect(note, findsOneWidget);
        final context = tester.element(note);
        final cubit =
            context.read<KycWizardCubit>() as KycWizardScreenCatalogCubit;
        addTearDown(cubit.close);
        final gateway =
            cubit.observedGateway as KycWizardScreenRefreshFailingGateway;
        expect(gateway.statusReads, 2);
        expect(cubit.state.step, KycWizardStep.status);
        expect(cubit.state.submission.status, KycStatus.pending);
        expect(cubit.state.error, isNull);
        expect(cubit.state.refreshFailure, const NetworkFailure(offline: true));
        expect(
          find.text(AppLocalizations.of(context).errorNetworkBody),
          findsOneWidget,
        );
        final retry = find.bySemanticsIdentifier(
          'kyc_status_refresh_failed_note_retry_cta',
        );
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(gateway.statusReads, 3);
        expect(cubit.state.submission.status, KycStatus.pending);
        expect(cubit.state.error, isNull);
        expect(cubit.state.refreshFailure, const NetworkFailure(offline: true));
        expect(note, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
