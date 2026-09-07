// Critic A2 / GEN-01: in RELEASE a DI miss must NEVER hand the dashboard a
// fabricated empty list as real data.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import 'package:jeeb_mobile/features/shell/tabs/dashboard_tab.dart';

void main() {
  group('active-deliveries fallback', () {
    test('release mode yields a repository that THROWS, not an empty list',
        () async {
      final repo = activeDeliveriesDiFallback(
        releaseMode: true,
      );

      await expectLater(repo.listActive(), throwsA(isA<AppFailure>()));
    });

    test('debug/harness mode keeps the inert empty repository', () async {
      final repo = activeDeliveriesDiFallback(
        releaseMode: false,
      );

      expect(await repo.listActive(), isEmpty);
    });
  });

  group('submitted-offers fallback', () {
    test('release mode yields a repository that THROWS on BOTH calls',
        () async {
      final repo = submittedOffersDiFallback(
        releaseMode: true,
      );

      await expectLater(repo.listSubmitted(), throwsA(isA<AppFailure>()));
      await expectLater(repo.withdraw('o1'), throwsA(isA<AppFailure>()));
    });

    test('debug/harness mode keeps the inert empty repository', () async {
      final repo = submittedOffersDiFallback(
        releaseMode: false,
      );

      expect(await repo.listSubmitted(), isEmpty);
      expect(await repo.withdraw('o1'), isFalse);
    });
  });
}
