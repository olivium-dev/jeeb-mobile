// COPY-09 — the tier picker's error rung used ONE sentence for every kind:
// `requestSummaryErrorNetwork`, "check your connection", for a 403 and a 500
// alike. Now the copy family answers the kind, in both locales.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/features/tier_selection/presentation/tier_selection_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const String _connectivityBody = 'Check your connection and try again.';

class _Throwing implements TierRepository {
  const _Throwing(this.failure);

  final AppFailure failure;

  @override
  Future<List<Tier>> fetchTiers() async => throw failure;
}

Future<List<String>> _bodyFor(
  WidgetTester tester,
  AppFailure failure, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  // A fresh element tree per reading: the screen builds its cubit in
  // `BlocProvider.create`, so re-pumping the same type would reuse the first.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapForTest(
      TierSelectionScreen(repository: _Throwing(failure)),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  return tester
      .widgetList<Text>(find.byType(Text))
      .map((Text t) => t.data ?? '')
      .where((String s) => s.isNotEmpty)
      .toList();
}

void main() {
  group('TierSelectionScreen · failure copy is kind-aware', () {
    testWidgets('403, 429 and 500 each render a DIFFERENT body', (
      WidgetTester tester,
    ) async {
      final List<String> forbidden =
          await _bodyFor(tester, const ForbiddenFailure());
      final List<String> rateLimited =
          await _bodyFor(tester, const RateLimitedFailure());
      final List<String> server =
          await _bodyFor(tester, const ServerFailure(status: 500));

      expect(forbidden, isNot(rateLimited));
      expect(forbidden, isNot(server));
      expect(rateLimited, isNot(server));
    });

    testWidgets('ONLY offline network and timeout failures blame connectivity', (
      WidgetTester tester,
    ) async {
      expect(
        await _bodyFor(tester, const NetworkFailure(offline: true)),
        contains(_connectivityBody),
      );
      expect(
        await _bodyFor(
          tester,
          const TimeoutFailure(phase: DioExceptionType.receiveTimeout),
        ),
        isNotEmpty,
      );

      for (final AppFailure other in const <AppFailure>[
        NetworkFailure(),
        ForbiddenFailure(),
        RateLimitedFailure(),
        ServerFailure(status: 500),
        NotFoundFailure(),
        UnknownFailure(parse: true),
      ]) {
        expect(
          await _bodyFor(tester, other),
          isNot(contains(_connectivityBody)),
          reason: '$other must not blame the connection',
        );
      }
    });

    testWidgets('AR renders Arabic — no English body survives', (
      WidgetTester tester,
    ) async {
      final List<String> arabic = await _bodyFor(
        tester,
        const ServerFailure(status: 500),
        locale: const Locale('ar'),
      );

      expect(arabic, isNot(contains(_connectivityBody)));
      expect(
        arabic.any((String s) => RegExp(r'[؀-ۿ]').hasMatch(s)),
        isTrue,
      );
    });

    // R6: an unrecoverable kind gets an exit CTA, never an inert Retry.
    testWidgets('403 has no Retry; 500 does', (WidgetTester tester) async {
      await _bodyFor(tester, const ForbiddenFailure());
      expect(
        find.bySemanticsIdentifier('tier_selection_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('tier_selection_exit_cta'),
        findsOneWidget,
      );

      await _bodyFor(tester, const ServerFailure(status: 500));
      expect(
        find.bySemanticsIdentifier('tier_selection_retry_cta'),
        findsOneWidget,
      );
    });
  });
}
