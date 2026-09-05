// Phase V D5 — a failed `GET /v1/users/me` rendered "Something went wrong" plus
// Retry and NOTHING else, so the app's only in-UI sign-out was unreachable.
//
// Anti-vacuity: `signOutIdentifier` is proved to swing BOTH ways under this same
// harness — one widget on the error frame, zero on the loading frame — and the
// loaded body's own `settings-row-sign-out` key is asserted absent, so a loaded
// SettingsScreen can never stand in for the affordance under test.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/live_settings_screen.dart';
import 'package:jeeb_mobile/features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// A `/v1/users/me` read that never lands — holds the loading frame.
Future<Map<String, dynamic>> _pending() =>
    Completer<Map<String, dynamic>>().future;

/// The D1 shape: the gateway answered 500, Dio threw.
Future<Map<String, dynamic>> _failing() =>
    Future<Map<String, dynamic>>.error(StateError('offline'));

Widget _harness(Future<Map<String, dynamic>> Function() loader) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(
        path: '/settings',
        builder: (context, state) => LiveSettingsScreen(snapshotLoader: loader),
      ),
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    Future<Map<String, dynamic>> Function() loader,
  ) async {
    await tester.pumpWidget(_harness(loader));
    await tester.pumpAndSettle();
  }

  JeebEmptyState emptyState(WidgetTester tester) =>
      tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));

  // A function, not a top-level final: `bySemanticsIdentifier` throws "Semantics
  // are not enabled" if it is built outside a running test body.
  Finder signOut() =>
      find.bySemanticsIdentifier(LiveSettingsScreen.signOutIdentifier);

  group('LiveSettingsScreen — D5 sign-out survives a failed read', () {
    testWidgets('the error frame carries a sign-out affordance', (tester) async {
      await pump(tester, _failing);

      // The frame under test really is the failed one, not the loaded body.
      expect(emptyState(tester).effectiveStatus, JeebEmptyStateStatus.error);
      expect(emptyState(tester).identifier, LiveSettingsScreen.errorIdentifier);
      expect(find.byKey(const Key('settings-row-sign-out')), findsNothing);

      expect(signOut(), findsOneWidget);
    });

    testWidgets('CAPABILITY CONTROL: the same finder is empty while loading',
        (tester) async {
      await pump(tester, _pending);

      expect(emptyState(tester).effectiveStatus, JeebEmptyStateStatus.loading);
      // Same harness, same finder, opposite answer — so `findsOneWidget` above
      // is a measured difference, not a finder that always matches.
      expect(signOut(), findsNothing);
    });

    testWidgets('tapping it opens the logout confirm sheet', (tester) async {
      await pump(tester, _failing);
      expect(find.byType(LogoutDeleteConfirmSheet), findsNothing);

      await tester.tap(signOut());
      await tester.pumpAndSettle();

      expect(find.byType(LogoutDeleteConfirmSheet), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('logout_delete_confirm_sheet'),
        findsOneWidget,
      );
    });

    testWidgets('retry is still the only JeebCtaButton on the frame',
        (tester) async {
      await pump(tester, _failing);

      // Guards the M3-37 assertions in live_settings_midnight_test.dart, which
      // resolve the retry pill by type and would break on a second one.
      expect(find.byType(JeebCtaButton), findsOneWidget);
      expect(
        find.bySemanticsIdentifier(LiveSettingsScreen.retryIdentifier),
        findsOneWidget,
      );
    });
  });
}
