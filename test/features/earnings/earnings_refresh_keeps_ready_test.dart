// LR-16: pull-to-refresh must never blank the dashboard to a skeleton, and a
// failed refresh raises a dismissible note over the rows that are up.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_state.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/earnings/presentation/earnings_dashboard_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const EarningsSummary _funded = EarningsSummary(
  totalCashEarned: 1000,
  feesPaid: 100,
  currency: 'USD',
  deliveryCount: 5,
);

/// The cold load lands; every read after it fails.
class _WarmFailingRepo implements EarningsRepository {
  _WarmFailingRepo();

  bool _served = false;
  int reads = 0;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    reads++;
    if (_served) {
      throw const EarningsRepositoryException(
        EarningsErrorKind.network,
        null,
        NetworkFailure(),
      );
    }
    _served = true;
    return _funded;
  }

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => '/tmp/e.pdf';
}

void main() {
  test(
    'refresh() never emits loading and keeps the summary identical',
    () async {
      final repo = _WarmFailingRepo();
      final cubit = EarningsCubit(repository: repo);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final EarningsSummary? before = cubit.state.summary;
      final modes = <EarningsViewMode>[];
      final sub = cubit.stream.listen((s) => modes.add(s.mode));

      await cubit.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(modes, isNot(contains(EarningsViewMode.loading)));
      expect(cubit.state.mode, EarningsViewMode.ready);
      expect(identical(cubit.state.summary, before), isTrue);
      expect(cubit.state.refreshError, isA<NetworkFailure>());

      await sub.cancel();
      await cubit.close();
    },
  );

  test('a period tap DOES flip to loading — the split is deliberate', () async {
    final repo = _WarmFailingRepo();
    final cubit = EarningsCubit(repository: repo);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final modes = <EarningsViewMode>[];
    final sub = cubit.stream.listen((s) => modes.add(s.mode));

    await cubit.loadEarnings(period: EarningsPeriod.month);

    expect(modes.first, EarningsViewMode.loading);

    await sub.cancel();
    await cubit.close();
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode}: a failed refresh renders the note '
        'over a dashboard that stays up', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final repo = _WarmFailingRepo();
      await tester.pumpWidget(
        wrapForTest(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: BlocProvider<EarningsCubit>(
                create: (_) => EarningsCubit(repository: repo),
                child: const EarningsDashboardScreen(),
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('earnings_error'), findsNothing);

      await tester.fling(
        find.byType(Scrollable).last,
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('earnings_refresh_failed_note'),
        findsOneWidget,
      );
      // The dashboard is still up — the refresh did NOT blank it.
      expect(find.bySemanticsIdentifier('earnings_loading'), findsNothing);
      expect(find.bySemanticsIdentifier('earnings_error'), findsNothing);

      await tester.tap(
        find.bySemanticsIdentifier('earnings_refresh_failed_note_dismiss_cta'),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('earnings_refresh_failed_note'),
        findsNothing,
      );

      handle.dispose();
    });
  }
}
