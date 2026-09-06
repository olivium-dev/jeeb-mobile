import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/data/dev_client_home_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/client_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/midnight_test_harness.dart';

void main() {
  test('combined home fixture never assigns one display ID to two orders', () {
    final snapshot = DevClientHomeFixtures.snapshot();
    final orders = [...snapshot.pending, ...snapshot.replies];
    expect(orders, hasLength(4));
    expect(orders.map((order) => order.id).toSet(), hasLength(4));
    expect(orders.map((order) => order.displayId).toSet(), hasLength(4));
    expect(
      orders.every((order) => order.displayId?.isNotEmpty ?? false),
      isTrue,
    );
  });
  for (final locale in kFailureLocales) {
    testWidgets(
      'shipping all view retains healthy replies after partial failure: ${locale.languageCode}',
      (tester) async {
        useReduceMotion(tester);
        final cubit = ClientHomeScreenPreviewFixtures.cubit(
          ClientHomeScreenPreviewFixtures.partialFailureRepository(),
        );
        addTearDown(cubit.close);
        await cubit.load();
        expect(cubit.state.status, ClientHomeStatus.ready);
        expect(cubit.state.inProgressError, isA<NetworkFailure>());
        expect(cubit.state.replies, hasLength(1));
        await tester.pumpWidget(
          wrapMidnight(
            BlocProvider<ClientHomeCubit>.value(
              value: cubit,
              child: const ClientHomeScreen(),
            ),
            locale: locale,
            scrollable: false,
          ),
        );
        await pumpPastFakeLatency(tester);
        expect(tester.takeException(), isNull);
        final row = find.text('\u2068ORD-23473\u2069');
        await tester.scrollUntilVisible(
          row,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(row, findsOneWidget);
        expect(
          find.bySemanticsIdentifier('in_progress_error_state'),
          findsNothing,
          reason:
              'default all view is the healthy request/replies surface, not the isolated active-delivery bucket',
        );
      },
    );
    testWidgets('home catalog warm failure actually refreshes: '
        '${locale.languageCode}', (tester) async {
      useReduceMotion(tester);
      final entry = kScreenCatalog.singleWhere(
        (e) => e.feature == 'home_client',
      );
      final state = entry.states.singleWhere(
        (s) => s.label == 'Refresh failed over rows',
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
      final context = tester.element(find.byType(ClientHomeScreen));
      final cubit = context.read<ClientHomeCubit>();
      expect(cubit.state.refreshError, const NetworkFailure(offline: true));
      expect(cubit.state.pending, isNotEmpty);
      expect(find.byType(JeebRefreshFailedNote), findsOneWidget);
      expect(
        find.text(AppLocalizations.of(context).errorNetworkBody),
        findsOneWidget,
      );
      // The error band can sit above the first lazy row at this viewport; scroll
      // the real screen so retained rows are proven reachable, not fold-dependent.
      await tester.scrollUntilVisible(
        find.text('\u2068ORD-23470\u2069'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('\u2068ORD-23470\u2069'), findsOneWidget);
    });
  }
}
