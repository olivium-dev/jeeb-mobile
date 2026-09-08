import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/app/branded_splash.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/app/jeeb_bootstrap.dart';

import '../preview_test_harness.dart';

/// The failure host inlines its own last-resort table; these are the two lines
/// it can render, pinned to the ARB by `test/app/jeeb_bootstrap_error_test.dart`.
String _copy(String key) => kBootstrapFailureStrings['en']![key]!;

/// EP-01: the host renders product copy plus, in a non-release build only, the
/// raw payload as the block body. The previews run in debug, so the payload is
/// what a reviewer sees under a fixed headline.
String _errorLine(Object error) => bootstrapErrorDetail(error);

/// The branded-splash host: the [MaterialApp] `_SplashApp` builds.
/// Matches on the widget, not on its children, because the children are behind
Finder _splashHost() => find.byWidgetPredicate(
      (Widget w) => w is MaterialApp && w.home is BrandedSplash,
    );

Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeebBootstrap',
    const <String, Widget Function()>{
      'Cold start (splash)': jeebBootstrapColdStart,
      'Boot failed · opaque': jeebBootstrapFailedOpaque,
      'Boot failed · plugin missing': jeebBootstrapFailedMissingPlugin,
      'Boot failed · verbose': jeebBootstrapFailedVerbose,
      'Boot failed · Arabic payload': jeebBootstrapFailedArabicPayload,
    },
    expectedText: <String, String>{
      'Boot failed · opaque': _copy('bootstrapFailedTitle'),
      'Boot failed · plugin missing': _errorLine(
        jeebBootstrapMissingPluginError,
      ),
      'Boot failed · verbose': _errorLine(jeebBootstrapVerboseError),
      'Boot failed · Arabic payload': _errorLine(jeebBootstrapArabicError),
    },
  );

  group('JeebBootstrap cold-start preview', () {
    testWidgets('renders the branded-splash host and never mounts the app', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapColdStart);

      expect(_splashHost(), findsOneWidget);
      // The reason the ready state has no preview: mounting JeebApp fires
      expect(find.byType(JeebApp), findsNothing);
    });

    testWidgets('the splash host is wired to the production theme and ARB', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapColdStart);

      final MaterialApp host = tester.widget<MaterialApp>(_splashHost());
      // What this preview exists to review: the splash is NOT a bare frame — it
      expect(host.theme, isNotNull);
      expect(host.darkTheme, isNotNull);
      // M0 pinned this dark: `system` is where a light-mode device flashed
      // white on the first painted surface.
      expect(host.themeMode, ThemeMode.dark);
      expect(host.localizationsDelegates, contains(AppLocalizations.delegate));
      expect(host.supportedLocales, AppLocalizations.supportedLocales);
    });

    testWidgets('the splash follows the DEVICE locale, not the canvas locale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeebBootstrapColdStart,
        locale: const Locale('ar'),
      );

      // Prefs are not loaded yet, so the splash resolves its own locale from
      expect(tester.widget<MaterialApp>(_splashHost()).locale, const Locale('en'));
    });

    testWidgets('the splash subtree is withheld until the ARB asset loads', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapColdStart);

      // Documents, rather than asserts as desirable: AppLocalizations.delegate
      expect(_splashHost(), findsOneWidget);
      expect(find.byType(BrandedSplash), findsNothing);
    });
  });

  group('JeebBootstrap error-host preview specifics', () {
    testWidgets('a rejected bootstrap skips the splash entirely', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapFailedMissingPlugin);

      // FutureBuilder reports hasError before it reports done, so a broken boot
      expect(find.byType(BrandedSplash), findsNothing);
      expect(
        find.text(_errorLine(jeebBootstrapMissingPluginError)),
        findsOneWidget,
      );
    });

    testWidgets('the error host is themed Midnight — a broken boot must not '
        'render a stock Material white slab', (WidgetTester tester) async {
      await pumpPreview(tester, jeebBootstrapFailedOpaque);

      final ThemeData theme = Theme.of(
        tester.element(find.text(_errorLine(jeebBootstrapOpaqueError))),
      );
      // M0 gave `_BootstrapErrorApp` a real theme; this used to assert the
      // absence of one.
      expect(theme.colorScheme.primary, AppTheme.midnight().colorScheme.primary);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor,
          AppTheme.midnight().scaffoldBackgroundColor);
    });

    testWidgets('the error host stays LTR even with an Arabic payload', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        jeebBootstrapFailedArabicPayload,
        locale: const Locale('ar'),
      );

      final Finder line = find.text(_errorLine(jeebBootstrapArabicError));
      expect(line, findsOneWidget);
      // The host resolves its OWN locale from the device, not from the canvas,
      // so an Arabic canvas cannot flip it.
      expect(Directionality.of(tester.element(line)), TextDirection.ltr);
    });

    testWidgets('every error preview shows a different payload', (
      WidgetTester tester,
    ) async {
      // The failure this whole suite exists to catch: four previews of one
      final Set<String> seen = <String>{};
      for (final Widget Function() preview in <Widget Function()>[
        jeebBootstrapFailedOpaque,
        jeebBootstrapFailedMissingPlugin,
        jeebBootstrapFailedVerbose,
        jeebBootstrapFailedArabicPayload,
      ]) {
        await _unmount(tester);
        await pumpPreview(tester, preview);
        final JeebEmptyState block =
            tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
        seen.add(block.body!);
      }

      expect(seen, hasLength(4));
      // Under one fixed headline: the payload is the body, never the title.
      expect(seen.contains(_copy('bootstrapFailedTitle')), isFalse);
    });

    testWidgets('the host offers no retry it cannot honour', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapFailedVerbose);

      // `AppRestarter` is a dev-tool-build wrap; with none above the host, a
      // "Try again" CTA would be inert, so the block ships without one.
      expect(find.byType(ButtonStyleButton), findsNothing);
      expect(
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).action,
        isNull,
      );
    });

    testWidgets('the release body names no payload and no exception type', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapFailedVerbose);

      // The debug body IS the payload; the release constant must not be.
      expect(_copy('bootstrapFailedBody'), isNot(contains('Exception')));
      expect(_copy('bootstrapFailedBody'), isNot(contains('channel')));
      expect(_copy('bootstrapFailedBody'), isNot(contains(r'$')));
    });

    testWidgets('the verbose payload is capped, not clipped mid-word', (
      WidgetTester tester,
    ) async {
      // EP-01 replaced a silently clipped native stack trace with a bounded,
      // explicitly elided diagnostic: the end of the line is now visible.
      final String detail = bootstrapErrorDetail(jeebBootstrapVerboseError);
      expect(detail.length, bootstrapErrorDetailLimit);
      expect(detail.endsWith('\u2026'), isTrue);
      expect(detail.contains('\n'), isFalse);

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = jeebBootstrapPreviewBox;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, jeebBootstrapFailedVerbose);
      expect(find.text(detail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
