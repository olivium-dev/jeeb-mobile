// M4 — the location subtree's six state surfaces, read off the widget.
//
// Five of the six were catalog-invisible; three inked something with
// `colorScheme.primary`, which is #D73B00 under Midnight and not the cool
// accent the pass-1 code assumed.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart'
    show LocationPoint;
import 'package:jeeb_mobile/features/location/presentation/location_search_bar.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/gps_denied_state.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/saved_locations_screen_fixtures.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: JeebMidnightField(
          variant: JeebFieldVariant.content,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('M4 · GPS denied', () {
    testWidgets('is the §2.7 ERROR member on radar, not a Material glyph',
        (tester) async {
      await tester.pumpWidget(_host(const GpsDeniedState()));
      await tester.pump();

      final JeebEmptyState state =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(state.status, JeebEmptyStateStatus.error);
      expect(state.status, isNot(JeebEmptyStateStatus.empty));
      // The location subtree's variant (saved_locations, address_detail_form):
      // a sweep looking for a fix it cannot get.
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.variant, isNot(JeebEmptyStateVariant.e1));
      expect(state.identifier, 'capture_location_gps_denied');
      // The retired hand-built head.
      expect(find.byIcon(Icons.location_off_rounded), findsNothing);
    });

    testWidgets('keeps its three shipped strings, verbatim', (tester) async {
      await tester.pumpWidget(_host(const GpsDeniedState()));
      await tester.pump();
      final AppLocalizations l10n =
          AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));

      expect(find.text(l10n.captureLocationGpsDeniedTitle), findsOneWidget);
      expect(find.text(l10n.captureLocationGpsDeniedBody), findsOneWidget);
      expect(
        find.text(l10n.captureLocationGpsDeniedOpenSettings),
        findsOneWidget,
      );
    });

    testWidgets('draws NO light-theme type: headline and body are token ink',
        (tester) async {
      await tester.pumpWidget(_host(const GpsDeniedState()));
      await tester.pump();
      final BuildContext context = tester.element(find.byType(JeebEmptyState));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final JeebSemanticColors semantic =
          Theme.of(context).extension<JeebSemanticColors>() ??
              JeebSemanticColors.midnight();
      final AppLocalizations l10n = AppLocalizations.of(context);

      final Text headline =
          tester.widget<Text>(find.text(l10n.captureLocationGpsDeniedTitle));
      final Text body =
          tester.widget<Text>(find.text(l10n.captureLocationGpsDeniedBody));
      expect(headline.style?.color?.toARGB32(), scheme.onSurface.toARGB32());
      expect(body.style?.color?.toARGB32(), semantic.mutedText.toARGB32());
      // `textTheme.titleMedium` under Midnight has no explicit colour at all —
      // that null is what the residue looked like.
      expect(headline.style?.color, isNotNull);
    });

    testWidgets('the CTA is dead only when no callback is wired',
        (tester) async {
      await tester.pumpWidget(_host(const GpsDeniedState()));
      await tester.pump();
      expect(
        find.bySemanticsIdentifier('capture_location_gps_denied_cta'),
        findsOneWidget,
      );

      int opened = 0;
      await tester.pumpWidget(
        _host(GpsDeniedState(onOpenSettings: () => opened++)),
      );
      await tester.pump();
      await tester.tap(
        find.text(
          AppLocalizations.of(tester.element(find.byType(JeebEmptyState)))
              .captureLocationGpsDeniedOpenSettings,
        ),
      );
      await tester.pump();
      expect(opened, 1);
    });
  });

  group('M4 · saved-locations mutation overlay', () {
    testWidgets('marks with MUTED ink — it used to ink itself primary',
        (tester) async {
      // The screen owns a `RootAwareBackScope`, so it needs a real Router.
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.midnight(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: GoRouter(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (_, _) => SavedLocationsScreen(
                  cubit: SavedLocationsScreenMutatingCubit(),
                ),
              ),
            ],
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final Finder mark = find.byType(CircularProgressIndicator);
      expect(mark, findsOneWidget);
      final BuildContext context = tester.element(mark);
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final CircularProgressIndicator spinner =
          tester.widget<CircularProgressIndicator>(mark);

      expect(spinner.color, isNotNull,
          reason: 'an untinted ring falls back to colorScheme.primary');
      expect(spinner.color!.toARGB32(), isNot(scheme.primary.toARGB32()));
      // The list stays underneath, so this is deliberately not a §2.7 block.
      expect(find.text('Home'), findsOneWidget);
    });
  });

  group('M4 · search bar', () {
    Widget searchBar({required bool isSearching, List<LocationPoint> results =
        const <LocationPoint>[]}) =>
        _host(
          LocationSearchBar(
            hintText: 'Search',
            query: 'beirut',
            results: results,
            isSearching: isSearching,
            onChanged: (_) {},
            onResultSelected: (_) {},
          ),
        );

    testWidgets('the in-flight bar is NOT a 2px orange strip', (tester) async {
      await tester.pumpWidget(searchBar(isSearching: true));
      await tester.pump();

      final Finder bar = find.byType(LinearProgressIndicator);
      expect(bar, findsOneWidget);
      final BuildContext context = tester.element(bar);
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final JeebSemanticColors semantic =
          Theme.of(context).extension<JeebSemanticColors>() ??
              JeebSemanticColors.midnight();
      final LinearProgressIndicator indicator =
          tester.widget<LinearProgressIndicator>(bar);

      expect(indicator.color?.toARGB32(), semantic.mutedText.toARGB32());
      expect(indicator.color?.toARGB32(), isNot(scheme.primary.toARGB32()));
      expect(
        indicator.backgroundColor?.toARGB32(),
        semantic.glassFillPressed.toARGB32(),
      );
    });

    testWidgets('the results panel is glass, not a Material elevation slab',
        (tester) async {
      await tester.pumpWidget(
        searchBar(
          isSearching: false,
          results: const <LocationPoint>[
            LocationPoint(latitude: 33.88, longitude: 35.49, address: 'Hamra'),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(JeebOutlinedCard), findsOneWidget);
      final BuildContext context =
          tester.element(find.byType(JeebOutlinedCard));
      final JeebSemanticColors semantic =
          Theme.of(context).extension<JeebSemanticColors>() ??
              JeebSemanticColors.midnight();
      // Was `colorScheme.primary`: an orange pin on every result row.
      final Icon pin = tester.widget<Icon>(find.byIcon(Icons.place_outlined));
      expect(pin.color?.toARGB32(), semantic.mutedText.toARGB32());
      expect(
        pin.color?.toARGB32(),
        isNot(Theme.of(context).colorScheme.primary.toARGB32()),
      );
    });

    testWidgets('the no-matches row is localized, not a hard-coded fallback',
        (tester) async {
      await tester.pumpWidget(searchBar(isSearching: false));
      await tester.pump();

      final AppLocalizations l10n =
          AppLocalizations.of(tester.element(find.byType(LocationSearchBar)));
      expect(find.text(l10n.locationSearchEmpty), findsOneWidget);
      expect(find.text('No matches'), findsNothing);
    });
  });
}
