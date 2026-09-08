import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// Scriptable saved-locations repo. Mirrors the `has_saved_addresses` seam
/// (Home default + Office) by default; `empty` exercises the zero-state.
class _FakeRepo implements SavedLocationRepository {
  _FakeRepo(this.list);

  factory _FakeRepo.seamSeed() => _FakeRepo(const [
        SavedLocation(
          id: 'addr-client-001-home',
          label: 'Home',
          latitude: 33.8869,
          longitude: 35.5131,
          category: SavedLocationCategory.home,
          address: 'Sassine Square, Ashrafieh',
          isDefault: true,
        ),
        SavedLocation(
          id: 'addr-client-001-office',
          label: 'Office',
          latitude: 33.8938,
          longitude: 35.5018,
          category: SavedLocationCategory.work,
          address: 'Downtown Beirut',
        ),
      ]);

  final List<SavedLocation> list;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => list;

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

/// Repo whose first load throws, then (if [recoverWith] is set) succeeds — lets
/// the error-state test prove the OmdsErrorState retry re-runs the real load.
class _FlakyRepo extends _FakeRepo {
  _FlakyRepo({this.recoverWith = const []}) : super(const []);

  final List<SavedLocation> recoverWith;
  int fetchCalls = 0;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async {
    fetchCalls++;
    if (fetchCalls == 1) {
      throw const ServerFailure(status: 500);
    }
    return recoverWith;
  }
}

/// No session: `DioSavedLocationRepository` throws this rather than reading
/// another account's path.
class _UnauthorizedRepo extends _FakeRepo {
  _UnauthorizedRepo() : super(const []);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async =>
      throw const UnauthorizedFailure();
}

/// Never resolves, so the first frame is the loading state.
class _SlowRepo extends _FakeRepo {
  _SlowRepo() : super(const []);

  @override
  Future<List<SavedLocation>> fetchSavedLocations() =>
      Completer<List<SavedLocation>>().future;
}

/// Sentinel form screen so the `address-detail` route is assertable + carries
/// the destination id the jm-049 flow expects (`address_form_save_cta`).
class _FormSentinel extends StatelessWidget {
  const _FormSentinel({this.id});
  final String? id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          identifier: 'address_form_save_cta',
          button: true,
          child: Text('form id=${id ?? '<add>'}'),
        ),
      ),
    );
  }
}

String? lastFormId;
bool sawForm = false;

GoRouter _router(SavedLocationRepository repo) {
  return GoRouter(
    initialLocation: '/settings/addresses',
    routes: [
      GoRoute(
        path: '/settings/addresses',
        name: 'settings-addresses',
        builder: (context, state) => SavedLocationsScreen(repository: repo),
        routes: [
          GoRoute(
            path: 'edit',
            name: 'address-detail',
            builder: (context, state) {
              sawForm = true;
              lastFormId = state.uri.queryParameters['id'];
              return _FormSentinel(id: lastFormId);
            },
          ),
        ],
      ),
    ],
  );
}

Widget _harness(GoRouter router, {Locale locale = const Locale('en')}) {
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // `JeebEmptyState`'s illustrations loop ∞ by design (02-STUDY-NOTES
    // §Motion), so pumpAndSettle only terminates under reduce motion.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

void main() {
  setUp(() {
    lastFormId = null;
    sawForm = false;
  });

  group('SavedLocationsScreen — JM-049', () {
    testWidgets('AC1: default badge + add CTA visible with seeded addresses',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('saved_address_add_cta'),
        findsOneWidget,
      );
      // Home is the default → exactly one default badge.
      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsOneWidget,
      );
      // Index-0 edit affordance present (coined pattern).
      expect(
        find.bySemanticsIdentifier('saved_address_0_edit'),
        findsOneWidget,
      );
    });

    testWidgets('add CTA visible on empty state (signature id)',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo(const []))));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('saved_address_add_cta'),
        findsOneWidget,
      );
      // No addresses → no default badge / edit row.
      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsNothing,
      );
    });

    testWidgets('AC2: add CTA → address-detail (add path, no id)',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('saved_address_add_cta'));
      await tester.pumpAndSettle();

      expect(sawForm, isTrue);
      expect(lastFormId, isNull); // add path carries no id
      expect(
        find.bySemanticsIdentifier('address_form_save_cta'),
        findsOneWidget,
      );
    });

    testWidgets('AC3: edit → address-detail?id=<addressId>', (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsIdentifier('saved_address_0_edit'));
      await tester.pumpAndSettle();

      expect(sawForm, isTrue);
      expect(lastFormId, 'addr-client-001-home');
      expect(
        find.bySemanticsIdentifier('address_form_save_cta'),
        findsOneWidget,
      );
    });

    // MIDNIGHT M3-28: empty/error/loading are the §2.7 family, not OMDS.
    testWidgets('empty state uses JeebEmptyState with honest zero-state copy',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo(const []))));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved-locations-empty')), findsOneWidget);
      final empty = tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      // `radar` is the one variant that draws no microphone — the settings
      // subtree's convention. `e1`/`pocket` would put a mic on an address list.
      expect(empty.variant, JeebEmptyStateVariant.radar);
      expect(empty.status, JeebEmptyStateStatus.empty);
      // The ring is the three real SavedLocationCategory glyphs, not radar's
      // default jeeber initials.
      expect(
        empty.medallions?.map((m) => m.icon).toList(),
        <IconData>[Icons.home, Icons.work, Icons.place],
      );
      expect(find.text('No saved addresses yet'), findsOneWidget);
    });

    testWidgets('loading state is the §2.7 loading member, not a bare spinner',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_SlowRepo())));
      await tester.pump();

      expect(find.byKey(const Key('saved-locations-loading')), findsOneWidget);
      final loading =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(loading.status, JeebEmptyStateStatus.loading);
      expect(loading.variant, JeebEmptyStateVariant.radar);
      // The Add CTA stays reachable in every non-fatal state, but disabled
      // while the first load is in flight.
      expect(
        find.bySemanticsIdentifier('saved_address_add_cta'),
        findsOneWidget,
      );
    });

    testWidgets('error state is a kind-aware JeebFailureBlock and retry '
        're-runs the load', (tester) async {
      final repo = _FlakyRepo(
        recoverWith: const [
          SavedLocation(
            id: 'addr-1',
            label: 'Home',
            latitude: 0,
            longitude: 0,
            category: SavedLocationCategory.home,
          ),
        ],
      );
      await tester.pumpWidget(_harness(_router(repo)));
      await tester.pumpAndSettle();

      // First load threw → the failure block, identified and kind-aware.
      expect(find.byKey(const Key('saved-locations-error')), findsOneWidget);
      expect(find.bySemanticsIdentifier('saved_locations_error'), findsOneWidget);
      final block =
          tester.widget<JeebFailureBlock>(find.byType(JeebFailureBlock));
      expect(block.failure, const ServerFailure(status: 500));
      // COPY-09: the copy family answers a 500, and never blames the network.
      expect(find.textContaining('connection'), findsNothing);

      // Retry re-runs the real load (no fabricated data); second load recovers.
      // The §2.7 block is taller than a 600pt test viewport, so scroll first.
      final retry = find.bySemanticsIdentifier('saved_address_error_retry_cta');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(repo.fetchCalls, 2);
      expect(find.byKey(const Key('saved-locations-error')), findsNothing);
      expect(find.bySemanticsIdentifier('saved_locations_error'), findsNothing);
      expect(find.text('Home'), findsOneWidget);
    });

    // R6: a non-retryable kind must still give the user a way out, and the
    // declared exit id must actually resolve.
    testWidgets('a 401 renders the exit CTA and no Retry', (tester) async {
      await tester.pumpWidget(
        _harness(_router(_UnauthorizedRepo())),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('saved_locations_error'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('saved_address_error_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('saved_address_error_exit_cta'),
        findsOneWidget,
      );
    });
  });

  group('SavedLocationsScreen — MIDNIGHT M3-28', () {
    testWidgets('mounts the content field with R22\'s top-end glow, still',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      final field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField).first,
      );
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      expect(field.animateDecor, isFalse);
      // Transparent scaffold, so the field is what paints (no navy slab on top).
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.transparent);
    });

    testWidgets('rows are ONE grouped glass band, R22\'s MORE-card shape',
        (tester) async {
      await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
      await tester.pumpAndSettle();

      // Two addresses, one card — a card per row was the pass-1 shape.
      expect(find.byType(JeebOutlinedCard), findsOneWidget);
      final card = tester.widget<JeebOutlinedCard>(
        find.byType(JeebOutlinedCard),
      );
      expect(card.children.length, 2);
      expect(card.dividers, isTrue);
      expect(card.state, JeebCardState.normal);
    });

    testWidgets(
      'row glyph and title carry NO orange — colorScheme.primary is #D73B00',
      (tester) async {
        await tester.pumpWidget(_harness(_router(_FakeRepo.seamSeed())));
        await tester.pumpAndSettle();

        final scheme = AppTheme.midnight().colorScheme;
        final glyph = tester.widget<Icon>(find.byIcon(Icons.home));
        expect(glyph.color, isNot(scheme.primary));
        expect(glyph.color, scheme.onSurface);

        final title = tester.widget<Text>(find.text('Home'));
        expect(title.style?.color, isNot(scheme.primary));
        expect(title.style?.color, scheme.onSurface);
        expect(title.style?.fontWeight, FontWeight.w700);
      },
    );
  });
}
