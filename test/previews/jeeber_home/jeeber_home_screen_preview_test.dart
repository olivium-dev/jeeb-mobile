// Render tests for the JeeberHomeScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`, with one deliberate deviation
// described below.
//
// This screen renders NO content of its own — it is a four-way branch that
// picks a body, and three of its four bodies open with the same greeting band
// and the same availability row. A render-only check ("something painted")
// therefore passes on almost any mis-wiring: an "online, no requests" preview
// that silently lost its online gateway looks exactly like the offline one, and
// the JEBV4-13 pull-to-refresh wrapper is invisible in a screenshot entirely.
//
// So every state pins a string only IT can produce. Where two states differ
// only in copy the screen does not vary — offline vs online vs still-loading —
// the discriminator is the greeting name each preview carries, and the
// STRUCTURAL difference is pinned separately in the specifics group at the
// bottom (which body mounted, whether a refresh indicator wraps it, whether the
// active-work banner is present).
//
// ## Why this suite builds its own canvas
//
// `previewCanvas` in the shared harness builds `AppTheme.light()` unmodified
// and loads no fonts, so every glyph lays out in Flutter's 1-em test face —
// Latin ~2x too wide, Arabic ~2.4x. Two of the previews below are layout
// ceilings on narrow frames (360x640 and 320x568) whose whole point is whether
// the content fits; measured through the fake face they would report overflows
// that exist on no device. This suite therefore loads the real Inter faces AND
// applies `withGoldenTestFonts`, which is what puts the Arabic fallback family
// on the theme's text roles — without it `loadInterTestFont` registers the Noto
// subset but nothing selects it. Everything else (the host, the two locales,
// the three assertions per state) is the shared template, reproduced.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/jeeber_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_no_requests_view.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';

/// The previews under test, by their `@JeebPreview(name:)`.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Unregistered · upsell': jeeberHomeScreenUnregistered,
  'Offline · no requests': jeeberHomeScreenOffline,
  'Online · no requests': jeeberHomeScreenOnlineNoRequests,
  'Cold read in flight': jeeberHomeScreenColdRead,
  'Availability load failed · retry': jeeberHomeScreenLoadError,
  'Online · live feed': jeeberHomeScreenLiveFeed,
  'Online · empty feed · pull to refresh': jeeberHomeScreenEmptyFeed,
  'Won delivery · no-requests state': jeeberHomeScreenActiveWork,
  'Just won · above a live feed': jeeberHomeScreenJustWonOverFeed,
  'Longest content · compact 320': jeeberHomeScreenLongestContent,
};

/// One string per state that no OTHER state below can produce.
const Map<String, String> _expectedText = <String, String>{
  // The only body with no availability control at all.
  'Unregistered · upsell': 'Register as a delivery man',
  // The settled offline switch title.
  'Offline · no requests': "You're offline",
  // Online and offline differ in the switch title, but online-idle,
  // online-with-an-empty-feed-cubit and the in-flight cold read do not differ
  // from each other in ANY copy — see the specifics group for what does.
  'Online · no requests': 'Hello, Nadia',
  'Cold read in flight': 'Hello, Rima',
  'Online · empty feed · pull to refresh': 'Hello, Hiba',
  // The only state that replaces the whole dashboard.
  'Availability load failed · retry': "Couldn't load your availability.",
  // The Figma screen-24 client — only a mounted feed card renders it.
  'Online · live feed': 'Sami Fawaz',
  // The won order in the no-requests body…
  'Won delivery · no-requests state':
      JeeberHomeScreenPreviewFixtures.wonCounterpartName,
  // …and the one that arrived while the feed was still non-empty.
  'Just won · above a live feed':
      JeeberHomeScreenPreviewFixtures.justWonCounterpartName,
  // The ceiling row's client name, rendered in full by the card even though it
  // ellipsizes on screen.
  'Longest content · compact 320':
      JeeberHomeScreenPreviewFixtures.longestSenderName,
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
/// so Latin and Arabic measure the way they do on a device.
Widget _jeeberHomeScreenCanvas(Widget Function() preview, Locale locale) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_jeeberHomeScreenCanvas(preview, locale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
  });

  group('JeeberHomeScreen previews', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (
          WidgetTester tester,
        ) async {
          await _pump(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    _expectedText.forEach((String state, String text) {
      testWidgets('$state renders its own state', (WidgetTester tester) async {
        await _pump(tester, _previews[state]!);

        expect(find.text(text), findsOneWidget);
      });
    });
  });

  group('JeeberHomeScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `_jeeberHomeScreenCanvas` produces the same
    // widget types, so the `BlocProvider` element is UPDATED rather than
    // replaced and keeps the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await _pump(tester, jeeberHomeScreenOffline);

      expect(tester.getSize(find.byType(JeeberHomeScreen)).width, 390);
    });

    testWidgets('the ceiling preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberHomeScreenLongestContent);

      expect(
        tester.getSize(find.byType(JeeberHomeScreen)),
        const Size(320, 568),
      );
    });

    // Screen-19 regression, made visible: the unregistered path is the ONE
    // path that mounts this screen with no `BlocProvider<AvailabilityCubit>`
    // above it, and `didChangeDependencies` used to read the cubit
    // unconditionally and throw before the first frame painted.
    testWidgets('the unregistered preview mounts with no availability cubit', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberHomeScreenUnregistered);

      expect(tester.takeException(), isNull);
      expect(find.byKey(JeeberUnregisteredView.rootKey), findsOneWidget);
      // Neither registered body is anywhere near this path.
      expect(find.byKey(JeeberNoRequestsView.rootKey), findsNothing);
      expect(find.byKey(JeeberHomeScreen.loadErrorRetryKey), findsNothing);
    });

    testWidgets('a failed availability read replaces the WHOLE dashboard', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberHomeScreenLoadError);

      expect(find.byKey(JeeberHomeScreen.loadErrorRetryKey), findsOneWidget);
      // Not a banner over the dashboard — the greeting, the availability row
      // and the empty hero are all gone, which is why a jeeber cannot go
      // online from this state at all.
      expect(find.byKey(JeeberNoRequestsView.rootKey), findsNothing);
      expect(find.text("You're offline"), findsNothing);
    });

    // The cold read has NO surface of its own. This pins the defect rather than
    // asserting it away: while `GET /v1/availability` is outstanding the screen
    // states, in the settled offline styling, that the jeeber is offline.
    testWidgets('an in-flight cold read is drawn as a settled OFFLINE '
        'dashboard', (WidgetTester tester) async {
      await _pump(tester, jeeberHomeScreenColdRead);

      expect(find.byKey(JeeberNoRequestsView.rootKey), findsOneWidget);
      expect(find.text("You're offline"), findsOneWidget);
      // Nothing anywhere says a read is in progress.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    // JEBV4-13 P2-6. Both states render the same body and the same copy; only
    // one of them can honour the "Pull down to refresh" that copy promises.
    testWidgets('only the feed-cubit-backed empty state carries a refresh '
        'indicator', (WidgetTester tester) async {
      await _pump(tester, jeeberHomeScreenEmptyFeed);

      expect(find.byKey(JeeberNoRequestsView.rootKey), findsOneWidget);
      expect(find.byType(OmdsPullToRefresh), findsOneWidget);
    });

    testWidgets('the online-idle state renders the same copy with NO refresh '
        'indicator', (WidgetTester tester) async {
      await _pump(tester, jeeberHomeScreenOnlineNoRequests);

      expect(find.byKey(JeeberNoRequestsView.rootKey), findsOneWidget);
      // The same promise, and nothing behind it: with no feed cubit there is no
      // `refresh()` to call, so the wrapper is absent.
      expect(find.text('No requests right now'), findsOneWidget);
      expect(find.byType(OmdsPullToRefresh), findsNothing);
    });

    testWidgets('a live feed replaces the no-requests body and shows no '
        'active work', (WidgetTester tester) async {
      await _pump(tester, jeeberHomeScreenLiveFeed);

      expect(find.byKey(JeeberFeedTabView.rootKey), findsOneWidget);
      expect(find.byKey(JeeberNoRequestsView.rootKey), findsNothing);
      // No won order in this fixture — so neither active-work row may appear,
      // which is what stops this preview passing on another state's tree.
      expect(
        find.text(JeeberHomeScreenPreviewFixtures.wonCounterpartName),
        findsNothing,
      );
      expect(
        find.text(JeeberHomeScreenPreviewFixtures.justWonCounterpartName),
        findsNothing,
      );
    });

    // PUSH-UI-REACTION (2026-07-05): the just-won card has to mount on the FEED
    // branch too. It rendered nowhere for ~95 s because its builder was only on
    // the no-requests branch, and the accepted request keeps the feed non-empty
    // for exactly that long.
    testWidgets('a just-won delivery mounts ABOVE a still-populated feed', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberHomeScreenJustWonOverFeed);

      expect(find.byKey(JeeberFeedTabView.rootKey), findsOneWidget);
      expect(
        find.text(JeeberHomeScreenPreviewFixtures.justWonCounterpartName),
        findsOneWidget,
      );
      // The request that is still on the board, i.e. the overlap itself.
      expect(find.text('Sami Fawaz'), findsOneWidget);
    });

    testWidgets('the won-delivery state discloses active work inside the '
        'no-requests body', (WidgetTester tester) async {
      await _pump(tester, jeeberHomeScreenActiveWork);

      expect(find.byKey(JeeberNoRequestsView.rootKey), findsOneWidget);
      expect(
        find.text(JeeberHomeScreenPreviewFixtures.wonCounterpartName),
        findsOneWidget,
      );
      // …and the empty hero still sits under it: the jeeber is online with work
      // in hand and an empty board, not "no requests" alone.
      expect(find.text('No requests right now'), findsOneWidget);
    });

    testWidgets('the ceiling preview greets the FIRST name only', (
      WidgetTester tester,
    ) async {
      await _pump(tester, jeeberHomeScreenLongestContent);

      expect(find.text('Hello, Abdulrahman'), findsOneWidget);
      // The card header carries the whole name (ellipsized on screen), so the
      // two are different strings from the same fixture.
      expect(
        find.text(JeeberHomeScreenPreviewFixtures.longestSenderName),
        findsOneWidget,
      );
    });
  });
}
