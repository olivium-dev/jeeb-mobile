// Render tests for the NotificationsListScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// ## Why every state pins a string only IT can produce
//
// This screen picks ONE of four bodies off `state.status` — spinner, error,
// empty illustration, list — and three of the four carry almost no copy. The
// app-bar title is identical in all of them, and the two error cards are the
// same widget with one sentence swapped. A render-only check would pass with
// every preview wired to the same fixture, so each state below is pinned by
// copy unique to it, and the `preview specifics` group asserts the body behind
// the string.
//
// ## Fonts
//
// `loadInterTestFont()` runs before every test here, because the shared harness
// does not load fonts and Flutter's test face makes every glyph a 1-em square —
// Latin measures ~2x too wide, Arabic ~2.4x. No assertion in this file claims
// an overflow measured under that face: the one geometry claim that could be
// distorted by it (the 320 pt ceiling card in Arabic) is measured through
// `withGoldenTestFonts`, which is the only way to get real Arabic metrics. The
// preview host builds `AppTheme.light()` unmodified and the theme carries no
// `fontFamilyFallback`, so under the shared harness every Arabic glyph still
// falls back to the test face.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/features/notifications/presentation/widgets/notification_row.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The ceiling row's headline, declared here rather than imported so a preview
/// quietly rewired to a short fixture fails instead of silently losing the one
/// state that contests the 320 pt frame.
const String _kCeilingTitle =
    'Abdulrahman Al-Muhandis accepted your offer and is on the way to the '
    'pickup point';

/// `previewCanvas`, but with the deterministic Arabic face wired into the
/// theme.
///
/// The shared harness cannot do this — it builds `AppTheme.light()` directly —
/// and without it every Arabic glyph is laid out in the 1-em test face, which is
/// ~2.4x too wide. Used only where a geometry claim is being made.
Widget _notificationsListCanvasWithFonts(
  Widget Function() preview,
  Locale locale,
) {
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

Future<void> _pumpWithFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_notificationsListCanvasWithFonts(preview, locale));
  await tester.pumpAndSettle();
}

Finder _row(String id) => find.bySemanticsIdentifier('notif_row_$id');

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'NotificationsListScreen',
    const <String, Widget Function()>{
      'Populated · mixed inbox': notificationsListScreenPopulated,
      'Empty · nothing yet': notificationsListScreenEmpty,
      'Load failed · network': notificationsListScreenLoadFailedNetwork,
      'Load failed · session expired': notificationsListScreenSessionExpired,
      'Longest content · compact 320': notificationsListScreenLongestContent,
    },
    expectedText: const <String, String>{
      // The newest row's payload headline — unique to this cast.
      'Populated · mixed inbox': 'New offer received',
      // A read that came back with nothing. The only state that says this.
      'Empty · nothing yet': "You're all caught up",
      // The one failure branch with copy of its own.
      'Load failed · network': 'No connection. Check your network and try again.',
      // …and the branch that collapses `unauthorized` into the generic line.
      'Load failed · session expired': 'Could not load notifications.',
      // The unclamped headline, at the width it has to survive.
      'Longest content · compact 320': _kCeilingTitle,
    },
  );

  // `Loading · cold read` is not in the suite above, for two reasons that both
  // come from the same fact: the body is a bare `OmdsLoadingState`.
  //
  //  * A `CircularProgressIndicator` is an indefinite animation, so
  //    `pumpAndSettle` — which `pumpPreview` calls — never returns. Fixed pumps
  //    below instead.
  //  * It has NO copy of its own to pin. The app-bar title is common to all six
  //    states, so this state is pinned by the indicator plus the absence of
  //    every other body.
  //
  // It still gets the same three assertions the shared suite makes: it builds
  // in EN, it builds in AR, and it renders its own state.
  group('NotificationsListScreen previews · Loading · cold read', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(notificationsListScreenLoading, locale),
      );
      await tester.pump(); // the mount-time load() emit
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold read · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold read renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // None of the other three bodies.
      expect(find.byType(NotificationRow), findsNothing);
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(OmdsErrorState), findsNothing);
      // `OmdsLoadingState` is built with no `message:`, so the app-bar title is
      // the only text on the card — and there is nothing to pull, nothing to
      // retry and no timeout behind it. `load()` guards re-entry on
      // `status != initial`, so this is where a read that never lands leaves
      // the inbox for as long as it is open.
      expect(find.byType(OmdsPullToRefresh), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('NotificationsListScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — the canvas produces the same widget types, so
    // the `BlocProvider` element is UPDATED rather than replaced and keeps the
    // cubit the first preview created.

    testWidgets('the phone previews pin a 390 x 844 frame, not the canvas', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 x 600 surface: a preview that left its size to
      // the host would measure that, and none of this layout applies there.
      await pumpPreview(tester, notificationsListScreenPopulated);

      expect(
        tester.getSize(find.byType(NotificationsListScreen)),
        const Size(390, 844),
      );
    });

    testWidgets('the ceiling preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationsListScreenLongestContent);

      expect(
        tester.getSize(find.byType(NotificationsListScreen)),
        const Size(320, 568),
      );
    });

    testWidgets('the reference state renders every row, newest first', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationsListScreenPopulated);

      expect(find.bySemanticsIdentifier('notifications_root'), findsOneWidget);
      expect(_row('n-1'), findsOneWidget);
      expect(_row('n-2'), findsOneWidget);
      expect(_row('n-3'), findsOneWidget);
      // The cubit owns the order: newest first, by row timestamp.
      expect(
        tester.getTopLeft(_row('n-1')).dy,
        lessThan(tester.getTopLeft(_row('n-2')).dy),
      );
      expect(
        tester.getTopLeft(_row('n-2')).dy,
        lessThan(tester.getTopLeft(_row('n-3')).dy),
      );
      // Unread is carried by a dot, and the READ row is the one that has none.
      // A cast of three unread rows would never show that difference.
      expect(_row('n-1_unread_badge'), findsOneWidget);
      expect(_row('n-2_unread_badge'), findsNothing);
      expect(_row('n-3_unread_badge'), findsOneWidget);
      // P0-X08: the eyebrow is the per-KIND category label, never the payload
      // headline rendered twice.
      expect(find.text('New offer'), findsOneWidget);
      expect(find.text('Order update'), findsOneWidget);
      expect(find.text('Low balance'), findsOneWidget);
    });

    testWidgets('the fixture ages are stable, because the screen has no clock', (
      WidgetTester tester,
    ) async {
      // `_LoadedList` never passes `now:` to `NotificationRow`, so every age is
      // measured against the wall clock. The fixtures answer that by expressing
      // each row as an OFFSET from the read — which is what makes these three
      // strings assertable at all. A fixture carrying a literal instant (what
      // the catalog held before this file existed) would print a number that
      // grows every day, and this test would have to be deleted.
      await pumpPreview(tester, notificationsListScreenPopulated);

      expect(find.text('12m ago'), findsOneWidget);
      expect(find.text('2h ago'), findsOneWidget);
      expect(find.text('3d ago'), findsOneWidget);
    });

    testWidgets('the empty preview is the EMPTY state, not the error one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationsListScreenEmpty);

      expect(find.byType(OmdsEmptyState), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.byType(NotificationRow), findsNothing);
      // Empty is `loaded` with no rows, not a fifth status — so the list is
      // still there and still pullable, and there is nothing else to press.
      expect(find.byType(OmdsPullToRefresh), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a network failure is the one error that names its cause', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationsListScreenLoadFailedNetwork);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      // An error the user cannot act on is barely better than the empty state
      // it replaced.
      expect(find.text('Retry'), findsOneWidget);
      // The cold failure replaces the whole body: no empty illustration, no
      // stale rows, and no pull-to-refresh either.
      expect(find.byType(OmdsEmptyState), findsNothing);
      expect(find.byType(OmdsPullToRefresh), findsNothing);
    });

    testWidgets('an expired session is told only that something went wrong', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, notificationsListScreenSessionExpired);

      // `_errorCopy` maps `unauthorized` onto the generic line, so a 401 and an
      // unclassified 500 are the same page — and the Retry offered here cannot
      // succeed until the user signs in again, which nothing says.
      expect(find.text('Could not load notifications.'), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsNothing,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('the ceiling row grows instead of clamping, over the two '
        'degenerate payloads', (WidgetTester tester) async {
      await pumpPreview(tester, notificationsListScreenLongestContent);

      // Nothing on the row sets `maxLines`, so the headline is present in full
      // and the row is most of a 320 pt viewport on its own.
      expect(find.text(_kCeilingTitle), findsOneWidget);
      expect(tester.getSize(_row('n-long')).height, greaterThan(200));

      // G3: a data-only push persists an empty title and body; the render layer
      // supplies the localized fallback so the row is never blank.
      expect(find.text('New request nearby'), findsOneWidget);
      expect(
        find.text('A customer is looking for a jeeber. Tap to view.'),
        findsOneWidget,
      );

      // …and the same shape with no fallback: an `unknown` kind whose title,
      // body and timestamp are all empty leaves a bare category eyebrow.
      expect(_row('n-unknown'), findsOneWidget);
      expect(find.text('Notification'), findsOneWidget);
      expect(_row('n-unknown_timestamp'), findsNothing);

      // The cubit sorts a timestamp-less row LAST, so a malformed row can never
      // jump to the top of the inbox.
      expect(
        tester.getTopLeft(_row('n-unknown')).dy,
        greaterThan(tester.getTopLeft(_row('n-bg')).dy),
      );
    });

    testWidgets('the ceiling survives 320 pt in EN and AR, measured through '
        'the real faces', (WidgetTester tester) async {
      // Measured through `withGoldenTestFonts`, so the Latin really is Inter
      // and the Arabic really is Noto — the only footing on which "this does
      // not overflow" is a claim about a device rather than about the 1-em test
      // face, which is ~2.4x too wide for Arabic.
      await _pumpWithFonts(tester, notificationsListScreenLongestContent);
      expect(tester.takeException(), isNull);
      expect(find.text(_kCeilingTitle), findsOneWidget);

      await _pumpWithFonts(
        tester,
        notificationsListScreenLongestContent,
        locale: const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
      // The row mirrors rather than reflows: the leading icon swaps to the
      // right of the row and the trailing unread dot to the left (AC-16 FM1).
      final Rect ceiling = tester.getRect(_row('n-long'));
      expect(
        tester.getRect(_row('n-long_unread_badge')).center.dx,
        lessThan(ceiling.center.dx),
      );
    });
  });
}
