// Render tests for the RepliesTab previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
// Every state pins a DISTINCT string, because all six previews are the same
// widget over the same cubit, told apart only by the snapshot the fake
// repository hands it — a suite that only asked "did something render?" would
// pass on six copies of the empty state.
//
// `Loading` is the one preview `testPreviewsRender` cannot carry, for a harness
// reason worth writing down: `pumpPreview` ends in `pumpAndSettle`, and
// `_RepliesLoading` is an `OmdsLoadingState` — a `CircularProgressIndicator`,
// whose animation NEVER settles, so the pump runs to its 10-minute simulated
// timeout and throws. Any preview of an indefinite-progress state hits this.
// It is pumped without settling in its own group below, in both locales, and
// pinned on its key — a stronger discriminator than a string anyway, since it
// is also the only branch of this tab that renders no text at all.
//
// The last two tests are not preview hygiene. They are the two defects these
// previews exposed in `RepliesCard`, held as numbers so they cannot regress
// unnoticed; both are invisible in the EN-light-100% rendering, which is the
// only one a reviewer sees without the matrix.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/replies_tab.dart';

import '../preview_test_harness.dart';

/// The exact ARB copy each full-tab state renders, so a reworded string breaks
/// the test instead of silently unpinning the preview.
const String _emptySubtitle =
    'No replies yet — pending requests with offers will appear here.';
const String _errorTitle = "Couldn't load your home";

/// The request id `repliesTabWithOverflowCount` seeds, lower-cased into the
/// card's widget keys the way `_reply` builds it.
const String _figmaRowId = 'ord-23470';

/// WCAG 2.1 relative-contrast ratio, 1.0 (identical) to 21.0 (black on white).
double _contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = la > lb ? la : lb;
  final double darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Pumps a preview WITHOUT settling, for states that never settle.
///
/// Unmounts the tree afterwards so the indicator's ticker is disposed before
/// the test ends — a live ticker at teardown is itself a test failure.
Future<void> _pumpUnsettled(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pump();
}

/// Pumps a preview into a real 390 dp phone-width box at [textScale], the way
/// the canvas renders it, rather than into the 800×600 default test surface.
Future<void> _pumpInPreviewBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = repliesTabCardBox,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RepliesTab',
    const <String, Widget Function()>{
      'Nine offers · +6': repliesTabWithOverflowCount,
      'Long content · +117': repliesTabLongContent,
      'Three replies': repliesTabMultipleReplies,
      'Empty': repliesTabEmpty,
      'Load failed': repliesTabFailed,
    },
    expectedText: const <String, String>{
      'Nine offers · +6': 'ORD-23470',
      'Long content · +117': 'ORD-23470-EXPRESS-REDELIVERY-ATTEMPT-3',
      'Three replies': 'ORD-23473',
      'Empty': _emptySubtitle,
      'Load failed': _errorTitle,
    },
  );

  group('RepliesTab · Loading preview', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('builds · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pumpUnsettled(tester, repliesTabLoading, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('replies-loading')), findsOneWidget);
      });
    }

    testWidgets('is the spinner branch and renders no text at all', (
      WidgetTester tester,
    ) async {
      await _pumpUnsettled(tester, repliesTabLoading);

      // Why this state has no `expectedText`: there is nothing to pin. No
      // message, no skeleton row, no label — a screen reader on this tab is
      // told nothing while the read is in flight.
      expect(find.byType(Text), findsNothing);
      expect(find.byKey(const Key('replies-empty')), findsNothing);
      expect(find.byKey(const Key('replies-error')), findsNothing);
      expect(find.byKey(const Key('replies-tab-list')), findsNothing);
    });
  });

  group('RepliesTab preview specifics', () {
    testWidgets('every preview lands on a different branch of the tab', (
      WidgetTester tester,
    ) async {
      // The failure this suite exists to catch: six previews of one widget that
      // all render the same branch.
      Key branch() {
        for (final Key key in const <Key>[
          Key('replies-tab-list'),
          Key('replies-empty'),
          Key('replies-error'),
          Key('replies-loading'),
        ]) {
          if (find.byKey(key).evaluate().isNotEmpty) return key;
        }
        fail('no RepliesTab branch rendered');
      }

      Future<Key> settledBranch(Widget Function() preview) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpPreview(tester, preview);
        return branch();
      }

      expect(await settledBranch(repliesTabEmpty), const Key('replies-empty'));
      expect(await settledBranch(repliesTabFailed), const Key('replies-error'));
      expect(
        await settledBranch(repliesTabWithOverflowCount),
        const Key('replies-tab-list'),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpUnsettled(tester, repliesTabLoading);
      expect(branch(), const Key('replies-loading'));
    });

    testWidgets('the "+N" cluster counts OFFERS, not avatars', (
      WidgetTester tester,
    ) async {
      // Nine offers, three inline avatars -> "+6", the Figma cluster. The card
      // derives the badge from `offerCount - inlineAvatars`, so a row whose
      // avatar list is shorter than its count still tells the truth.
      await pumpPreview(tester, repliesTabWithOverflowCount);

      expect(find.text('+6'), findsOneWidget);
    });

    testWidgets('a single offer renders no overflow badge at all', (
      WidgetTester tester,
    ) async {
      // The three-row preview spans all three shapes of the cluster in one
      // frame: 1 offer (no badge), 5 (+2), 9 (+6). `extra > 0` is what hides
      // the counter, so an off-by-one there would print "+0" on ORD-23471.
      await pumpPreview(tester, repliesTabMultipleReplies);

      expect(find.text('+0'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('+6'), findsOneWidget);
    });

    testWidgets('no preview reaches the network for an avatar', (
      WidgetTester tester,
    ) async {
      // The previews pass empty avatar URLs so `OmdsProfileAvatar` short-
      // circuits to its initials placeholder instead of constructing a
      // `CachedNetworkImage`. If a future edit puts a URL back, this fails.
      await pumpPreview(tester, repliesTabMultipleReplies);

      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('RepliesTab defects the preview matrix exposed', () {
    testWidgets('DARK: the order id is a container colour used as ink', (
      WidgetTester tester,
    ) async {
      // `_RepliesHeader` paints the order id — the card's primary identifier —
      // in `colorScheme.secondaryContainer`. That is a BACKGROUND role. In the
      // light scheme it is hand-pinned to `_jeebNavy`, so the mistake is
      // invisible: navy on white is 17:1. The dark scheme is generated by
      // `ColorScheme.fromSeed`, where `secondaryContainer` is a dark tonal fill
      // — and painted on the dark surface it lands at ~1.98:1, below even the
      // 3:1 large-text floor, while `onSurface` on the same surface is ~14:1.
      //
      // The AR-RTL-dark rendering of every preview above is where this shows.
      final ColorScheme dark = AppTheme.dark().colorScheme;
      final ColorScheme light = AppTheme.light().colorScheme;

      expect(
        _contrastRatio(light.secondaryContainer, light.surface),
        greaterThan(4.5),
        reason: 'light is fine, which is why this survives review',
      );
      expect(
        _contrastRatio(dark.secondaryContainer, dark.surface),
        lessThan(3.0),
        reason: 'the order id is illegible in dark mode; the header should ask '
            'for an ON- role (onSurface / onSurfaceVariant), not a container '
            'fill. Delete this expectation when the header is fixed.',
      );
      // What the fix should reach.
      expect(
        _contrastRatio(dark.onSurface, dark.surface),
        greaterThan(4.5),
      );
    });

    testWidgets('200% TEXT: the CTA row overflows a phone-width card', (
      WidgetTester tester,
    ) async {
      // `_RepliesActions` is an end-aligned Row of two `IntrinsicWidth` pills
      // with no Wrap, Flexible or FittedBox, so its width scales with the text
      // scale while the card does not. Measured in the preview's own 390 dp
      // box, which is what makes this a preview finding: the 800 dp default
      // test surface is wide enough to hide it, and so is 100% text.
      await _pumpInPreviewBox(tester, repliesTabWithOverflowCount,
          textScale: 1.0, box: const Size(390, 2000));
      final double acceptAt1x =
          tester.getSize(find.byKey(const Key('replies-accept-$_figmaRowId'))).width;
      final double checkAt1x = tester
          .getSize(find.byKey(const Key('replies-check-offers-$_figmaRowId')))
          .width;
      expect(
        tester.takeException(),
        isNull,
        reason: 'at 100% the two CTAs fit inside 390 dp',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      // A tall box so the only thing that can overflow is the horizontal axis.
      await _pumpInPreviewBox(tester, repliesTabWithOverflowCount,
          textScale: 2.0, box: const Size(390, 2000));

      final Object? overflow = tester.takeException();
      expect(overflow, isFlutterError);
      expect(
        overflow.toString(),
        contains('overflowed'),
        reason: 'accept ${acceptAt1x.toStringAsFixed(1)} dp + check '
            '${checkAt1x.toStringAsFixed(1)} dp fits at 100%; at 200% the same '
            'row needs ~562 dp against ~358 dp of content width',
      );
      expect(
        RegExp(r'overflowed by ([\d.]+) pixels')
            .firstMatch(overflow.toString())
            ?.group(1),
        isNotNull,
      );
      expect(
        double.parse(
          RegExp(r'overflowed by ([\d.]+) pixels')
              .firstMatch(overflow.toString())!
              .group(1)!,
        ),
        greaterThan(150),
        reason: 'clipped by ~208 dp — the whole primary CTA plus part of the '
            'secondary one is off the trailing edge, with no way to reach it',
      );
    });

    testWidgets('200% TEXT: Arabic overflows too, just by less', (
      WidgetTester tester,
    ) async {
      // Shorter labels (قبول / عرض العروض) shrink the overflow to ~94 dp but do
      // not remove it, so this is a layout defect and not a copy-length one.
      await _pumpInPreviewBox(tester, repliesTabWithOverflowCount,
          textScale: 2.0, box: const Size(390, 2000), locale: const Locale('ar'));

      expect(tester.takeException(), isFlutterError);
    });
  });
}
