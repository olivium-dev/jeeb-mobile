// §3.3 warm-failure rule on the saved-address manager.
//
// Returning from the add/edit form calls `load()`. When that reload fails the
// rows must survive AND the user must be told — the note is that telling.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/cubit/saved_locations_cubit.dart';
import 'package:jeeb_mobile/features/location/presentation/cubit/saved_locations_state.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const List<SavedLocation> _rows = <SavedLocation>[
  SavedLocation(
    id: 'addr-home',
    label: 'Home',
    latitude: 33.8869,
    longitude: 35.5131,
    category: SavedLocationCategory.home,
    address: 'Sassine Square, Ashrafieh',
    isDefault: true,
  ),
];

/// First fetch succeeds, every later one fails: the shape of a reload after a
/// save, which is the live path through `_onAdd`/`_onEdit`.
class _WarmFailRepo implements SavedLocationRepository {
  int calls = 0;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    calls++;
    if (calls == 1) return _rows;
    throw const ServerFailure(status: 500);
  }

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      throw UnimplementedError();

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteLocation(String id) async {}
}

Widget _harness(SavedLocationsCubit cubit, {required Locale locale}) {
  final GoRouter router = GoRouter(
    initialLocation: '/settings/addresses',
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Scaffold(body: Text('settings')),
        routes: <RouteBase>[
          GoRoute(
            path: 'addresses',
            name: 'settings-addresses',
            builder: (_, _) => SavedLocationsScreen(cubit: cubit),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

void main() {
  group('saved addresses · warm refresh failure', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('renders the note and keeps the rows · ${locale.languageCode}',
          (WidgetTester tester) async {
        final repo = _WarmFailRepo();
        final cubit = SavedLocationsCubit(repo);
        addTearDown(cubit.close);

        await cubit.load();
        await tester.pumpWidget(_harness(cubit, locale: locale));
        await tester.pumpAndSettle();

        await cubit.load();
        await tester.pumpAndSettle();

        expect(cubit.state, isA<SavedLocationsLoaded>());
        expect((cubit.state as SavedLocationsLoaded).locations, _rows);
        expect(
          find.bySemanticsIdentifier('saved_locations_refresh_note'),
          findsOneWidget,
        );
        // The rows survived: no cold error page.
        expect(
          find.bySemanticsIdentifier('saved_locations_error'),
          findsNothing,
        );
      });
    }

    testWidgets('dismissing the note clears it and keeps the rows',
        (WidgetTester tester) async {
      final repo = _WarmFailRepo();
      final cubit = SavedLocationsCubit(repo);
      addTearDown(cubit.close);

      await cubit.load();
      await tester.pumpWidget(_harness(cubit, locale: const Locale('en')));
      await tester.pumpAndSettle();
      await cubit.load();
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('saved_locations_refresh_note_dismiss_cta'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('saved_locations_refresh_note'),
        findsNothing,
      );
      expect((cubit.state as SavedLocationsLoaded).locations, _rows);
    });

    testWidgets('the note retry refetches', (WidgetTester tester) async {
      final repo = _WarmFailRepo();
      final cubit = SavedLocationsCubit(repo);
      addTearDown(cubit.close);

      await cubit.load();
      await tester.pumpWidget(_harness(cubit, locale: const Locale('en')));
      await tester.pumpAndSettle();
      await cubit.load();
      await tester.pumpAndSettle();

      final int before = repo.calls;
      await tester.tap(
        find.bySemanticsIdentifier('saved_locations_refresh_note_retry_cta'),
      );
      await tester.pumpAndSettle();

      expect(repo.calls, greaterThan(before));
    });
  });
}
