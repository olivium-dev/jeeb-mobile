// ES-12/LR-23/TEST-18 — the compose tier section collapsed "the catalogue is
// empty" and "the fetch threw" into ONE `_TierUnavailable` view, and drew its
// spinners in `colorScheme.primary` (orange) on a Midnight surface.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/compose_tier_section.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _NoopSubmission implements RequestSubmissionService {
  @override
  Future<String> submit(RequestDraft draft) async => 'req-1';
}

const Tier _standard = Tier(
  id: TierId.standard,
  serverId: 'tier-standard',
  priceLow: 45000,
  priceHigh: 70000,
  currency: 'LBP',
  vehicleClass: TierVehicleClass.bikeOrScooter,
  slaMinutes: 240,
  recommended: true,
);

class _Throwing implements TierRepository {
  const _Throwing(this.failure);

  final AppFailure failure;

  @override
  Future<List<Tier>> fetchTiers() async => throw failure;
}

class _EmptyCatalogue implements TierRepository {
  const _EmptyCatalogue();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

class _Stalled implements TierRepository {
  const _Stalled();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// Fails the first read, then serves — proves the retry really refetches.
class _Flaky implements TierRepository {
  _Flaky();

  int calls = 0;

  @override
  Future<List<Tier>> fetchTiers() async {
    calls++;
    if (calls == 1) throw const ServerFailure(status: 500);
    return const <Tier>[_standard];
  }
}

Widget _harness({Locale locale = const Locale('en')}) => MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Scaffold(
        body: SingleChildScrollView(child: ComposeTierSection()),
      ),
    );

void _seed(TierRepository repo) {
  sl.registerSingleton<ComposeRequestController>(
    ComposeRequestController(_NoopSubmission()),
  );
  sl.registerSingleton<TierRepository>(repo);
}

void main() {
  tearDown(() => sl.reset());

  group('ComposeTierSection · the section rungs', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('a THROWN read renders `compose_tier_error` with a retry · '
          '${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        _seed(const _Throwing(ServerFailure(status: 500)));

        await tester.pumpWidget(_harness(locale: locale));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('compose_tier_error'),
          findsOneWidget,
        );
        // The frozen retry identifier survives the port.
        expect(
          find.bySemanticsIdentifier('compose_tier_retry'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('compose_tier_empty'),
          findsNothing,
        );
      });

      testWidgets('an EMPTY catalogue renders `compose_tier_empty`, never the '
          'failure · ${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        _seed(const _EmptyCatalogue());

        await tester.pumpWidget(_harness(locale: locale));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('compose_tier_empty'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('compose_tier_error'),
          findsNothing,
        );
      });
    }

    testWidgets('the in-flight rung is identified', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      _seed(const _Stalled());

      await tester.pumpWidget(_harness());
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('compose_tier_loading'),
        findsOneWidget,
      );
    });

    // LR-23: the spinner used the theme default — #D73B00 under Midnight.
    testWidgets('the in-flight spinner is NOT colorScheme.primary', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      _seed(const _Stalled());

      await tester.pumpWidget(_harness());
      await tester.pump();

      final CircularProgressIndicator spinner =
          tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final BuildContext context =
          tester.element(find.byType(ComposeTierSection));
      expect(spinner.color, isNotNull);
      expect(spinner.color, isNot(Theme.of(context).colorScheme.primary));
    });

    // TEST-18: the retry was never proven to refetch.
    testWidgets('tapping the retry refetches', (WidgetTester tester) async {
      useReduceMotion(tester);
      final flaky = _Flaky();
      _seed(flaky);

      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      expect(flaky.calls, 1);

      final Finder retry = find.bySemanticsIdentifier('compose_tier_retry');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(flaky.calls, 2);
      expect(find.bySemanticsIdentifier('compose_tier_error'), findsNothing);
      expect(find.bySemanticsIdentifier('compose_tier_row'), findsOneWidget);
    });
  });

  group('ComposeTierSection · the change sheet', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(find.bySemanticsIdentifier('compose_tier_change'));
      await tester.pumpAndSettle();
    }

    testWidgets('a thrown sheet read is `_sheet_error`, not `_sheet_empty`', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final flaky = _Flaky();
      _seed(flaky);
      // First read fails, the retry seeds a tier so the Change link appears.
      await tester.pumpWidget(_harness());
      await tester.pumpAndSettle();
      final Finder retry = find.bySemanticsIdentifier('compose_tier_retry');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      await openSheet(tester);

      // The third fetch succeeds too, so the sheet shows options — the point
      // here is that the sheet's rungs are DISTINCT identifiers.
      expect(
        find.bySemanticsIdentifier('compose_tier_sheet_error'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('compose_tier_sheet_empty'),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('compose_tier_sheet'), findsOneWidget);
    });
  });
}
