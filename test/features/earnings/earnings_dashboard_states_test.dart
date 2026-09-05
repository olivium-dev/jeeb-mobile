// TEST-01: the four earnings rungs are findable, and the error rung is
// kind-aware — only a network failure blames the connection.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/earnings/application/earnings_cubit.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_repository.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/earnings/presentation/earnings_dashboard_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _SeededRepo implements EarningsRepository {
  const _SeededRepo(this.summary);

  final EarningsSummary summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => summary;

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => '/tmp/e.pdf';
}

class _FailingRepo implements EarningsRepository {
  const _FailingRepo(this.kind, this.failure);

  final EarningsErrorKind kind;
  final AppFailure failure;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => throw EarningsRepositoryException(kind, null, failure);

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async => throw EarningsRepositoryException(kind, null, failure);
}

class _StalledRepo implements EarningsRepository {
  _StalledRepo();

  final Completer<EarningsSummary> _never = Completer<EarningsSummary>();

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) => _never.future;

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) => Completer<String>().future;
}

const EarningsSummary _empty = EarningsSummary(
  totalCashEarned: 0,
  feesPaid: 0,
  currency: 'USD',
  deliveryCount: 0,
);

const EarningsSummary _fundedNoRows = EarningsSummary(
  totalCashEarned: 1000,
  feesPaid: 100,
  currency: 'USD',
  deliveryCount: 5,
);

Future<void> _pump(
  WidgetTester tester,
  EarningsRepository repo, {
  Locale locale = const Locale('en'),
}) async {
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
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('$tag: earnings_loading renders while the read is in flight', (
      tester,
    ) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapForTest(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: BlocProvider<EarningsCubit>(
                create: (_) => EarningsCubit(repository: _StalledRepo()),
                child: const EarningsDashboardScreen(),
              ),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('earnings_loading'), findsOneWidget);
      expect(find.bySemanticsIdentifier('earnings_error'), findsNothing);

      handle.dispose();
    });

    testWidgets('$tag: earnings_empty renders on an empty period, WITHOUT a '
        'retry CTA', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, const _SeededRepo(_empty), locale: locale);

      expect(find.bySemanticsIdentifier('earnings_empty'), findsOneWidget);
      expect(find.bySemanticsIdentifier('earnings_retry_cta'), findsNothing);

      handle.dispose();
    });

    testWidgets('$tag: earnings_error renders with its retry CTA', (
      tester,
    ) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        const _FailingRepo(EarningsErrorKind.network, NetworkFailure()),
        locale: locale,
      );

      expect(find.bySemanticsIdentifier('earnings_error'), findsOneWidget);
      expect(find.bySemanticsIdentifier('earnings_retry_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('earnings_empty'), findsNothing);

      handle.dispose();
    });

    testWidgets('$tag: earnings_breakdown_empty renders on a funded period '
        'with no rows', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, const _SeededRepo(_fundedNoRows), locale: locale);

      expect(
        find.bySemanticsIdentifier('earnings_breakdown_empty'),
        findsOneWidget,
      );

      handle.dispose();
    });
  }

  testWidgets('a ServerFailure and a NetworkFailure render DIFFERENT bodies, '
      'and only the network one mentions connectivity', (tester) async {
    useReduceMotion(tester);
    await _pump(
      tester,
      const _FailingRepo(EarningsErrorKind.network, NetworkFailure()),
    );
    expect(find.text('Check your connection and try again.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pump(
      tester,
      const _FailingRepo(EarningsErrorKind.server, ServerFailure(status: 500)),
    );
    expect(find.text('Check your connection and try again.'), findsNothing);
    expect(find.bySemanticsIdentifier('earnings_error'), findsOneWidget);
  });

  testWidgets('a 401 gets the way out, never a headline with no act', (
    tester,
  ) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(
      tester,
      const _FailingRepo(EarningsErrorKind.server, UnauthorizedFailure()),
    );

    expect(find.bySemanticsIdentifier('earnings_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('earnings_retry_cta'), findsNothing);
    expect(find.bySemanticsIdentifier('earnings_exit_cta'), findsOneWidget);

    handle.dispose();
  });
}
