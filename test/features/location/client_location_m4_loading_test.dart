// M4 — the create flow's two cold waits.
//
// Both were `Center(child: OmdsLoadingState())`; the session-resolve gate
// additionally returned a BARE `Scaffold`, so it painted the default surface
// with no `JeebMidnightField` behind it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/client_location_screen_fixtures.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// A session read that never lands — the only way to hold the create flow on
/// its session-resolve gate.
class _StalledAuthTokenStore extends AuthTokenStore {
  @override
  Future<String?> get userId => Completer<String?>().future;
}

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.midnight(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: inner ?? const SizedBox.shrink(),
      ),
      home: child,
    );

void main() {
  testWidgets('M4: the saved-address cold read draws the §2.7 loading member',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const ClientLocationScreen(
          userId: ClientLocationScreenFixtures.userId,
          repository: ClientLocationScreenFixtures.savedAddressesPending,
          currentLocationResolver: ClientLocationScreenFixtures.gpsResolved,
        ),
      ),
    );
    await tester.pump();

    final JeebEmptyState state =
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(state.status, JeebEmptyStateStatus.loading);
    expect(state.status, isNot(JeebEmptyStateStatus.empty));
    // `e1` — "bring me anything" is this screen's own subject, and its
    // already-migrated `_SavedAddressesError` sibling draws the same tile.
    expect(state.variant, JeebEmptyStateVariant.e1);
    expect(state.identifier, 'client_location_loading');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('M4: the cold wait is headlined by a shipped key, not invented',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const ClientLocationScreen(
          userId: ClientLocationScreenFixtures.userId,
          repository: ClientLocationScreenFixtures.savedAddressesPending,
          currentLocationResolver: ClientLocationScreenFixtures.gpsResolved,
        ),
      ),
    );
    await tester.pump();

    final AppLocalizations l10n =
        AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));
    expect(find.text(l10n.savedAddressesLoadingHeadline), findsOneWidget);
  });

  testWidgets(
      'M4: the session-resolve GATE brings its own field — it used to return '
      'a bare Scaffold that painted the theme surface', (tester) async {
    // No `userId`, so the screen must resolve one from `AuthTokenStore`. This
    // one never answers, which is what holds the gate open.
    sl.registerSingleton<AuthTokenStore>(_StalledAuthTokenStore());
    addTearDown(() => sl.unregister<AuthTokenStore>());
    await tester.pumpWidget(
      _host(
        const ClientLocationScreen(
          repository: ClientLocationScreenFixtures.savedAddresses,
          currentLocationResolver: ClientLocationScreenFixtures.gpsResolved,
        ),
      ),
    );
    await tester.pump();

    final JeebEmptyState state =
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
    expect(state.identifier, 'client_location_session_loading');
    expect(state.status, JeebEmptyStateStatus.loading);
    // The gate is one frame BEFORE the screen's own chrome, so no top bar.
    expect(find.byType(JeebTopBar), findsNothing);

    expect(find.byType(JeebMidnightField), findsOneWidget);
    final Scaffold scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(JeebMidnightField),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, Colors.transparent);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('M4: the loading frame still sits on a Midnight field',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const ClientLocationScreen(
          userId: ClientLocationScreenFixtures.userId,
          repository: ClientLocationScreenFixtures.savedAddressesPending,
          currentLocationResolver: ClientLocationScreenFixtures.gpsResolved,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(JeebMidnightField), findsOneWidget);
    final JeebMidnightField field =
        tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
    expect(field.variant, JeebFieldVariant.content);
    // A bare `Scaffold` here would paint the theme's own surface instead.
    final Scaffold scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(JeebMidnightField),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, Colors.transparent);
  });
}
