// F31 — a failed chip fetch shrank to a `SizedBox.shrink()`, so it looked
// exactly like an account with no saved locations. An EMPTY account still
// shrinks; a FAILURE now says so and offers a retry.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/saved_locations_chip_row_fixtures.dart';
import 'package:jeeb_mobile/features/location/cubit/location_picker_cubit.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/saved_locations_chip_row.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// Fails once, then serves — proves the retry really refetches.
class _Flaky extends SavedLocationsChipRowFakeRepository {
  _Flaky() : super(const <SavedLocation>[savedLocationsChipRowHome]);

  int calls = 0;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    calls++;
    if (calls == 1) throw const ServerFailure(status: 500);
    return locations;
  }
}

Widget _harness(
  SavedLocationRepository repo, {
  Locale locale = const Locale('en'),
}) =>
    MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: BlocProvider<LocationPickerCubit>(
          create: (_) =>
              LocationPickerCubit(repository: InMemoryLocationRepository()),
          child: SingleChildScrollView(
            child: SavedLocationsChipRow(repository: repo),
          ),
        ),
      ),
    );

void main() {
  group('SavedLocationsChipRow · a failure is not an absence', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('a thrown fetch renders the failure block · '
          '${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        await tester.pumpWidget(
          _harness(
            const SavedLocationsChipRowFailingRepository(),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('saved_locations_chips_error'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('saved_locations_chips_retry_cta'),
          findsOneWidget,
        );
      });
    }

    testWidgets('an EMPTY account still shrinks silently', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(const SavedLocationsChipRowFakeRepository(<SavedLocation>[])),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('saved_locations_chips_error'),
        findsNothing,
      );
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('the retry refetches and recovers to the chips', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final flaky = _Flaky();
      await tester.pumpWidget(_harness(flaky));
      await tester.pumpAndSettle();

      expect(flaky.calls, 1);
      final Finder retry =
          find.bySemanticsIdentifier('saved_locations_chips_retry_cta');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(flaky.calls, 2);
      expect(
        find.bySemanticsIdentifier('saved_locations_chips_error'),
        findsNothing,
      );
      expect(find.text('Home'), findsOneWidget);
    });

    // A pending read is a subordinate strip: no skeleton budget, so it stays
    // collapsed rather than reserving space it may never use.
    testWidgets('an in-flight read shows nothing at all', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(const SavedLocationsChipRowPendingRepository()),
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('saved_locations_chips_error'),
        findsNothing,
      );
    });
  });
}
