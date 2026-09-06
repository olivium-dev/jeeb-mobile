// ES-03 / JAD-02: an in-flight delivery must never vanish because a read
// failed, and the cubit must never be pinned on `loading` forever.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_active_deliveries_fixtures.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const _delivery = ActiveDeliverySummary(
  id: 'd1',
  status: JeeberDeliveryStatus.picked,
  title: 'Pharmacy run',
);

class _TypeErrorRepository implements ActiveDeliveriesRepository {
  const _TypeErrorRepository();

  @override
  Future<List<ActiveDeliverySummary>> listActive() async =>
      // A malformed row: the exact shape `ActiveDeliverySummary.fromJson`
      // raises, which used to escape every catch.
      (<Object?>[] as List<ActiveDeliverySummary>);
}

class _ScriptedRepository implements ActiveDeliveriesRepository {
  _ScriptedRepository(this.rows);

  List<ActiveDeliverySummary>? rows;
  AppFailure? failure;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    final f = failure;
    if (f != null) throw f;
    return rows!;
  }
}

Future<void> _pumpBanner(
  WidgetTester tester,
  ActiveDeliveriesCubit cubit, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapForTest(
      Scaffold(
        body: BlocProvider<ActiveDeliveriesCubit>.value(
          value: cubit,
          child: ActiveDeliveriesBanner(
            onOpenChat: (_) {},
            onManageDelivery: (_) {},
          ),
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('cubit', () {
    test('a thrown failure lands on `failed`, never stuck on `loading`',
        () async {
      final cubit = ActiveDeliveriesCubit(
        repository: const FailingActiveDeliveriesRepository(
          ServerFailure(status: 500),
        ),
      );
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.phase, ActiveDeliveriesPhase.failed);
      expect(cubit.state.error, isA<ServerFailure>());
    });

    test('a parse TypeError is classified too (no bare escape)', () async {
      final cubit = ActiveDeliveriesCubit(
        repository: const _TypeErrorRepository(),
      );
      addTearDown(cubit.close);

      await cubit.refresh();

      expect(cubit.state.phase, ActiveDeliveriesPhase.failed);
      expect(cubit.state.error, isNotNull);
    });

    test('a WARM failure keeps the last-good cards and stays `loaded`',
        () async {
      final repo = _ScriptedRepository(const <ActiveDeliverySummary>[_delivery]);
      final cubit = ActiveDeliveriesCubit(repository: repo);
      addTearDown(cubit.close);

      await cubit.refresh();
      expect(cubit.state.deliveries, hasLength(1));

      repo.failure = const NetworkFailure();
      await cubit.refresh();

      expect(cubit.state.phase, ActiveDeliveriesPhase.loaded);
      expect(cubit.state.deliveries, hasLength(1));
      expect(cubit.state.refreshError, isA<NetworkFailure>());
      expect(cubit.state.error, isNull);
    });
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a cold failure draws the compact block, not an empty '
        'band', (tester) async {
      final cubit = ActiveDeliveriesCubit(
        repository: const FailingActiveDeliveriesRepository(NetworkFailure()),
      );
      addTearDown(cubit.close);
      await cubit.refresh();

      await _pumpBanner(tester, cubit, locale: locale);

      expect(
        find.bySemanticsIdentifier('jeeber_active_deliveries_error'),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] `loaded` with nothing to show stays invisible',
        (tester) async {
      final cubit = ActiveDeliveriesCubit(
        repository: _ScriptedRepository(const <ActiveDeliverySummary>[]),
      );
      addTearDown(cubit.close);
      await cubit.refresh();

      await _pumpBanner(tester, cubit, locale: locale);

      expect(
        find.bySemanticsIdentifier('jeeber_active_deliveries_error'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('jeeber_active_deliveries'),
        findsNothing,
      );
    });
  }

  testWidgets('a warm failure keeps the cards on screen', (tester) async {
    final repo = _ScriptedRepository(const <ActiveDeliverySummary>[_delivery]);
    final cubit = ActiveDeliveriesCubit(repository: repo);
    addTearDown(cubit.close);
    await cubit.refresh();
    repo.failure = const NetworkFailure();
    await cubit.refresh();

    await _pumpBanner(tester, cubit);

    expect(
      find.bySemanticsIdentifier('jeeber_active_deliveries'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('jeeber_active_deliveries_error'),
      findsNothing,
    );
  });
}
