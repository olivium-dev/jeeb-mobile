// Render tests for the JeebBootstrap previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT string, because a
// suite that only asked "did something render?" would pass on five copies of
// the same boot host — and four of these five ARE the same host, told apart
// only by the payload it prints.
//
// The cold-start preview is the one state `expectedText` cannot reach, and not
// for a harness reason: the splash host builds its own MaterialApp with the
// app's REAL AppLocalizations delegate, which parses the ARB out of the asset
// bundle asynchronously, so its subtree — every string it would render — is
// withheld until that load completes. It never completes under this binding
// (that is the same limitation `test/app/jeeb_bootstrap_test.dart` documents,
// and warming the bundle inside `tester.runAsync` deadlocks on the widget's own
// already-pending, cached load). So that state is pinned on the host it builds
// and on that host's configuration, in the group below — which is a stronger
// discriminator than a string anyway: no error preview can produce it.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/app/branded_splash.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/previews/app/jeeb_bootstrap_preview.dart';

import '../preview_test_harness.dart';

/// The exact line the error host renders — `'App failed to start: $error'`.
/// Mirrors the format string in `_BootstrapErrorApp` so the test breaks if that
/// copy ever changes.
String _errorLine(Object error) => 'App failed to start: $error';

/// The branded-splash host: the [MaterialApp] `_SplashApp` builds.
///
/// Matches on the widget, not on its children, because the children are behind
/// the async ARB load described above. This is the same discriminator
/// `test/app/jeeb_bootstrap_test.dart` uses, for the same reason.
Finder _splashHost() => find.byWidgetPredicate(
      (Widget w) => w is MaterialApp && w.home is BrandedSplash,
    );

/// Unmounts the tree between two `pumpPreview` calls in one test.
///
/// `JeebBootstrap` caches its future in a `late final` and has no
/// `didUpdateWidget`, so pumping a second preview of the same widget type reuses
/// the element — and therefore the FIRST preview's bootstrap future. Without
/// this, a loop over four states silently asserts the same one four times.
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
      'Boot failed · opaque': _errorLine(jeebBootstrapOpaqueError),
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
      // Bootstrap.deferred (Firebase.initializeApp) from a post-frame callback,
      // and the widget exposes no seam to suppress it. A never-completing
      // bootstrap future is what keeps this preview inside the no-network rule.
      expect(find.byType(JeebApp), findsNothing);
    });

    testWidgets('the splash host is wired to the production theme and ARB', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapColdStart);

      final MaterialApp host = tester.widget<MaterialApp>(_splashHost());
      // What this preview exists to review: the splash is NOT a bare frame — it
      // carries both real themes and the real delegates, so it consumes
      // colorScheme roles and ARB strings rather than literals.
      expect(host.theme, isNotNull);
      expect(host.darkTheme, isNotNull);
      expect(host.themeMode, ThemeMode.system);
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
      // PlatformDispatcher.instance.locale (en under this binding, and the host
      // machine's locale in the canvas). The AR RTL rendering of this preview is
      // therefore English and LTR: the mirrored splash is not reviewable from
      // the canvas at all, only from a device whose system locale is Arabic.
      expect(tester.widget<MaterialApp>(_splashHost()).locale, const Locale('en'));
    });

    testWidgets('the splash subtree is withheld until the ARB asset loads', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapColdStart);

      // Documents, rather than asserts as desirable: AppLocalizations.delegate
      // reads the ARB from the asset bundle asynchronously, and Localizations
      // renders an empty Container until every delegate resolves. So the host
      // is mounted (previous tests) while BrandedSplash is not — on device that
      // is a blank frame between the native launch screen and the branded one,
      // which is exactly the window the splash exists to fill.
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
      // never shows a branded frame — the first thing the user sees is the
      // error host.
      expect(find.byType(BrandedSplash), findsNothing);
      expect(
        find.text(_errorLine(jeebBootstrapMissingPluginError)),
        findsOneWidget,
      );
    });

    testWidgets('the error host is built from a bare MaterialApp — no AppTheme',
        (WidgetTester tester) async {
      await pumpPreview(tester, jeebBootstrapFailedOpaque);

      final ThemeData theme = Theme.of(
        tester.element(find.text(_errorLine(jeebBootstrapOpaqueError))),
      );
      expect(
        theme.colorScheme.primary,
        isNot(AppTheme.light().colorScheme.primary),
        reason: '_BootstrapErrorApp passes no `theme:`, so the one screen that '
            'appears when the app is broken is stock Material, not Jeeb brand',
      );
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
      // No `locale:`, no delegates, no Directionality of its own: the inner
      // MaterialApp resolves to en/LTR regardless of the ambient locale, so the
      // English label and the Arabic message share one LTR bidi run.
      expect(Directionality.of(tester.element(line)), TextDirection.ltr);
    });

    testWidgets('every error preview shows a different payload', (
      WidgetTester tester,
    ) async {
      // The failure this whole suite exists to catch: four previews of one
      // widget that all render the same thing.
      final Set<String> seen = <String>{};
      for (final Widget Function() preview in <Widget Function()>[
        jeebBootstrapFailedOpaque,
        jeebBootstrapFailedMissingPlugin,
        jeebBootstrapFailedVerbose,
        jeebBootstrapFailedArabicPayload,
      ]) {
        await _unmount(tester);
        await pumpPreview(tester, preview);
        final Text text = tester.widget<Text>(
          find.descendant(
            of: find.byType(MaterialApp).last,
            matching: find.byType(Text),
          ),
        );
        seen.add(text.data!);
      }

      expect(seen, hasLength(4));
      expect(
        seen.every((String s) => s.startsWith('App failed to start: ')),
        isTrue,
      );
    });

    testWidgets('the message has no scroll view and no retry affordance', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebBootstrapFailedVerbose);

      // The structural half of the overflow finding below: the longest payload
      // sits in a centred Text with nothing to scroll, no ellipsis, and no way
      // out of the screen.
      expect(find.byType(Scrollable), findsNothing);
      expect(find.byType(ButtonStyleButton), findsNothing);
      final Text message = tester.widget<Text>(find.byType(Text).last);
      expect(message.overflow, isNull);
      expect(message.maxLines, isNull);
    });

    testWidgets('at 200% text the verbose payload is SILENTLY truncated', (
      WidgetTester tester,
    ) async {
      // The finding the `EN 200% text` rendering of this preview surfaces, held
      // as a number so it cannot regress unnoticed. Nothing else in the suite
      // would catch it: clipped text throws no exception, so `takeException`
      // stays null and every render test passes while half the message is gone.
      double clippedHeight() {
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          find.byType(Text).last,
        );
        return paragraph.getMaxIntrinsicHeight(paragraph.size.width) -
            paragraph.size.height;
      }

      Future<void> pumpAtScale(double scale) async {
        await _unmount(tester);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: previewCanvas(jeebBootstrapFailedVerbose, const Locale('en')),
          ),
        );
        await tester.pumpAndSettle();
      }

      // The preview's own canvas box, so this measures what a reviewer sees.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = jeebBootstrapPreviewBox;
      addTearDown(tester.view.reset);

      await pumpAtScale(1.0);
      expect(
        clippedHeight(),
        0,
        reason: 'at 100% the whole message fits — which is why this is easy to '
            'miss without the large-text rendering',
      );

      await pumpAtScale(2.0);
      expect(
        clippedHeight(),
        greaterThan(700),
        reason: 'at 200% the paragraph needs ~1520 dp inside an ~796 dp box: '
            'over half the message — the details and the stack trace — is '
            'clipped mid-word, with no ellipsis and no scroll',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

