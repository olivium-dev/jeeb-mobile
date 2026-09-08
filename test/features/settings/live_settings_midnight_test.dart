// M3-37 per-element Midnight assertions for LiveSettingsScreen.
//
// Goldens are evidence, not gates (02-STUDY-NOTES, wave-C fixup): the shared
// comparator tolerates 5% pixel diff, so swapping an OMDSAppBar for the in-body
// bar or re-inking a glyph can pass three goldens unchanged. Every value this
// row moved is read back off the built widget here.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/live_settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// A `/v1/users/me` read that never lands — holds the loading frame.
Future<Map<String, dynamic>> _pending() =>
    Completer<Map<String, dynamic>>().future;

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

  group('LiveSettingsScreen — pre-load chrome is R22', () {
    testWidgets('loading mounts the content field, glow topEnd, decor still',
        (tester) async {
      await pump(tester, _pending);

      final field =
          tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
      // Carried from settings_screen.dart so the field does not change when the
      // future lands: R22's only radial is `480x380 at 88% -6%`.
      expect(field.variant, JeebFieldVariant.content);
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R22 declares zero periwinkle.
      expect(field.washPlacement, isNull);
      // R22 is board-still.
      expect(field.animateDecor, isFalse);
    });

    testWidgets('loading draws the in-body back bar, not a Material app bar',
        (tester) async {
      await pump(tester, _pending);

      final bar = tester.widget<JeebTopBar>(find.byType(JeebTopBar));
      expect(bar.identifier, 'settings_back');
      // The pre-Midnight chrome this row deleted.
      expect(find.byType(OMDSAppBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('loading is the radar empty state, discs dropped',
        (tester) async {
      await pump(tester, _pending);

      final state = emptyState(tester);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.effectiveStatus, JeebEmptyStateStatus.loading);
      // No second party on this surface to name.
      expect(state.medallions, isEmpty);
      expect(state.identifier, LiveSettingsScreen.loadingIdentifier);
      // The kit withholds a CTA while loading; nothing should be passed.
      expect(state.action, isNull);
    });
  });

  group('LiveSettingsScreen — failed read', () {
    testWidgets('error is the same illustration, danger-tinted', (tester) async {
      await pump(tester, _failing);

      final state = emptyState(tester);
      expect(state.variant, JeebEmptyStateVariant.radar);
      expect(state.effectiveStatus, JeebEmptyStateStatus.error);
      expect(state.identifier, LiveSettingsScreen.errorIdentifier);
      // NET-09: the copy follows the KIND. A StateError is not a connectivity
      // failure, so it must NOT print the network line.
      expect(find.text("We couldn't complete that. Try again."),
          findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsNothing);
    });

    testWidgets('retry is the glass pill, never an orange act', (tester) async {
      await pump(tester, _failing);

      final cta = tester.widget<JeebCtaButton>(find.byType(JeebCtaButton));
      // R22 draws no orange CTA; `accent` here would spend the budget (§2.2).
      expect(cta.variant, JeebCtaVariant.outline);
      expect(cta.expand, isFalse);
      // The FilledButton this replaced.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('the frozen retry identifier survived the re-home',
        (tester) async {
      await pump(tester, _failing);

      expect(
        find.bySemanticsIdentifier(LiveSettingsScreen.retryIdentifier),
        findsOneWidget,
      );
    });

    testWidgets('retry re-runs the read and reaches the loading frame',
        (tester) async {
      var calls = 0;
      final completers = <Completer<Map<String, dynamic>>>[];
      Future<Map<String, dynamic>> loader() {
        calls++;
        if (calls == 1) return Future<Map<String, dynamic>>.error(StateError('x'));
        final c = Completer<Map<String, dynamic>>();
        completers.add(c);
        return c.future;
      }

      await pump(tester, loader);
      expect(emptyState(tester).effectiveStatus, JeebEmptyStateStatus.error);

      await tester.tap(find.byType(JeebCtaButton));
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(emptyState(tester).effectiveStatus, JeebEmptyStateStatus.loading);
    });
  });
}
