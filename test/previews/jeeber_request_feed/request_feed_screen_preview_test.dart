// Render tests for the RequestFeedScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/request_feed_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_card.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_feed_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';

/// The previews under test, by their `@JeebPreview(name:)`.
const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Live request · countdown': requestFeedScreenLiveRequest,
  'Empty board': requestFeedScreenEmptyBoard,
  'Load failed · retry': requestFeedScreenLoadFailed,
  'Cold read in flight': requestFeedScreenColdRead,
  'Reconnecting · polling transport': requestFeedScreenReconnecting,
  'Incoming · pending · accepted (identical)': requestFeedScreenLifecycleRows,
  'Refresh failed over rows · silent': requestFeedScreenRefreshFailedOverRows,
  'Longest content · compact 320': requestFeedScreenLongestContent,
};

/// One string per state that no OTHER state below can produce.
/// 'Cold read in flight' is absent on purpose — see the header. It is pinned in
const Map<String, String> _expectedText = <String, String>{
  // The dev fixture's earnings, which no other feed uses.
  'Live request · countdown': '≈ 4.50 USD',
  // The only body with the empty hero.
  'Empty board': 'No requests right now',
  // The only body with an error surface at all.
  'Load failed · retry': "Couldn't load requests",
  // The degraded-transport banner — the one thing that state adds.
  'Reconnecting · polling transport': 'Reconnecting — falling back to polling',
  // The pending-response row's pickup, unique to the lifecycle board.
  'Incoming · pending · accepted (identical)':
      RequestFeedScreenPreviewFixtures.pendingPickupLabel,
  // The stale row's pickup, unique to the silent-failure board.
  'Refresh failed over rows · silent':
      RequestFeedScreenPreviewFixtures.stalePickupLabel,
  // The six-figure LBP amount on the ceiling row.
  'Longest content · compact 320': '≈ 4500000.00 LBP',
};

/// Wraps a preview the way the preview canvas does — real themes, real
/// localizations, the shared [jeebPreviewHost] — plus the golden font families
Widget _requestFeedScreenCanvas(Widget Function() preview, Locale locale) {
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

/// Pumps [preview] and returns a disposer that tears the tree down.
/// Call the disposer before the test ends: the screen's 1 Hz ticker is only
Future<Future<void> Function()> _pump(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_requestFeedScreenCanvas(preview, locale));
  await tester.pump(const Duration(milliseconds: 16));
  return () => tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
  });

  group('RequestFeedScreen previews', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        testWidgets('${entry.key} · ${locale.languageCode}', (
          WidgetTester tester,
        ) async {
          final Future<void> Function() dispose =
              await _pump(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);

          await dispose();
        });
      }
    }

    _expectedText.forEach((String state, String text) {
      testWidgets('$state renders its own state', (WidgetTester tester) async {
        final Future<void> Function() dispose =
            await _pump(tester, _previews[state]!);

        expect(find.text(text), findsOneWidget);

        await dispose();
      });
    });
  });

  group('RequestFeedScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenLiveRequest);

      expect(tester.getSize(find.byType(RequestFeedScreen)).width, 390);

      await dispose();
    });

    testWidgets('the ceiling preview pins the 320 pt compact width', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenLongestContent);

      expect(tester.getSize(find.byType(RequestFeedScreen)).width, 320);

      await dispose();
    });

    // The one state with no copy of its own. Pinned on the spinner AND on the
    testWidgets('the cold read is a bare spinner and nothing else', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenColdRead);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // None of the other three bodies.
      expect(find.byKey(const Key('requestFeed.list')), findsNothing);
      expect(find.byKey(const Key('requestFeed.empty')), findsNothing);
      expect(find.text("Couldn't load requests"), findsNothing);
      // …and no reconnecting banner over it either.
      expect(
        find.byKey(const Key('requestFeed.reconnectingBanner')),
        findsNothing,
      );

      await dispose();
    });

    // The reference state must NOT be the reconnecting one — the two render the
    testWidgets('the live-request preview has no reconnecting banner', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenLiveRequest);

      expect(find.byKey(const Key('requestFeed.list')), findsOneWidget);
      expect(
        find.byKey(const Key('requestFeed.reconnectingBanner')),
        findsNothing,
      );

      await dispose();
    });

    // The screen renders no lifecycle distinction at all: `_FeedListRow` never
    testWidgets('incoming, pending and accepted rows are the SAME card', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenLifecycleRows);

      // `ListView.builder` only builds what the viewport reaches, and two
      await tester.scrollUntilVisible(
        find.byKey(const Key('requestFeed.card.preview-feed-accepted')),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      // The row the jeeber has already bid on and the row they have already
      for (final String id in const <String>[
        'preview-feed-pending',
        'preview-feed-accepted',
      ]) {
        final Finder card = find.byKey(Key('requestFeed.card.$id'));
        expect(card, findsOneWidget, reason: id);
        expect(
          find.descendant(of: card, matching: find.text('Accept')),
          findsOneWidget,
          reason: id,
        );
        expect(
          find.descendant(of: card, matching: find.text('Decline')),
          findsOneWidget,
          reason: id,
        );
      }
      // And the accepted row's `nextDeliveryAction` is nowhere on screen.
      expect(find.textContaining('picked'), findsNothing);
      expect(find.byType(RequestCard), findsWidgets);

      await dispose();
    });

    // `RequestFeedCubit._refresh` keeps `status: ready` when the feed is
    testWidgets('a refresh failure over rows shows NO error surface', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenRefreshFailedOverRows);

      expect(find.byType(RequestCard), findsOneWidget);
      // Nothing anywhere says the data on screen is stale.
      expect(find.text("Couldn't load requests"), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(
        find.byKey(const Key('requestFeed.reconnectingBanner')),
        findsNothing,
      );
      expect(find.byType(SnackBar), findsNothing);

      await dispose();
    });

    // The degraded transport is the one axis that is NOT part of the
    testWidgets('the reconnecting banner sits ABOVE an unchanged list', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenReconnecting);

      final Finder banner = find.byKey(
        const Key('requestFeed.reconnectingBanner'),
      );
      expect(banner, findsOneWidget);
      expect(find.byKey(const Key('requestFeed.list')), findsOneWidget);
      expect(
        tester.getTopLeft(banner).dy,
        lessThan(tester.getTopLeft(find.byType(RequestCard)).dy),
      );

      await dispose();
    });

    // The empty body must be the SUCCESSFUL-read hero, wrapped in the
    testWidgets('the empty board honours the pull-to-refresh it promises', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenEmptyBoard);

      expect(find.byKey(const Key('requestFeed.empty')), findsOneWidget);
      expect(find.byType(OmdsPullToRefresh), findsOneWidget);
      expect(find.byType(RequestCard), findsNothing);

      await dispose();
    });

    // The error body replaces the WHOLE feed — there is no pull-to-refresh
    testWidgets('the error body replaces the feed, Retry the only way out', (
      WidgetTester tester,
    ) async {
      final Future<void> Function() dispose =
          await _pump(tester, requestFeedScreenLoadFailed);

      expect(find.text("Couldn't load requests"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(OmdsPullToRefresh), findsNothing);
      expect(find.byKey(const Key('requestFeed.empty')), findsNothing);

      await dispose();
    });
  });
}
