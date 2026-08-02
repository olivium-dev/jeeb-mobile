// Render tests for the TierSelectionScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Eight previews, ONE screen, and most of them are told apart by nothing a
// screenshot could show: `Loaded` and `Selected` render the same three tiers,
// the two failure modes render the same sentence, and the empty catalogue
// renders the same subtitle over nothing. Every preview therefore carries a
// [TierSelectionScreenCaptions] line and the shared suite pins that; the groups
// below then pin the production contract each state exists for, which is what
// separates a real state from a card that merely rendered.
//
// Five of those contracts are defects the canvas cannot show you on its own, so
// they are pinned here:
//
//   * `TierSelectionScreen.retryButtonKey` is published and attached to
//     nothing — `OmdsErrorState` builds its own unkeyed `FilledButton.icon`.
//   * `TierSelectionState.usingCachedFallback` has no producer: the cubit
//     writes `false` on all three of its emits, so `_CachedBanner` and
//     `tierSelectionCachedBanner` are unreachable in the app.
//   * `_Body` ignores `state.failure`, so a 5xx renders the network sentence.
//   * A `200 OK` with no tiers is `loaded`, so the screen shows its subtitle
//     over nothing with a Confirm button that can never enable.
//   * Confirming the SAME tier twice fires `onConfirmed` once: `confirm()`
//     re-emits an equal state, `Cubit.emit` drops it, the listener never runs.
//
// ## Where the claims are measured
//
// The shared harness pumps an 800 x 600 surface, which is SHORTER than the
// phone these previews declare. Every content, interaction and geometry claim
// below is therefore made on the declared device through [_pumpAtDevice]; only
// the two frame-pinning tests use the harness surface, because "the preview pins
// its own width" is a claim about exactly that difference.
//
// ## Fonts
//
// `preview_test_harness.dart` does not load real fonts, so text lays out in
// Flutter's 1-em test face — Latin ~2x too wide, Arabic ~2.4x. `loadInterTestFont`
// is loaded here, and [_pumpAtDevice] goes through [_tierSelectionCanvas], which
// adds `withGoldenTestFonts` so the Arabic run is laid out in a real Arabic face
// rather than in the test binding's. Nothing below asserts an overflow.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/features/tier_selection/presentation/tier_card.dart';
import 'package:jeeb_mobile/features/tier_selection/presentation/tier_selection_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The phone the phone previews declare, and the narrowest supported one the
/// full-catalogue ceiling declares.
const Size _phoneBox = Size(390, 844);
const Size _compactBox = Size(320, 568);

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _subtitle = 'Price varies by Jeeber';
const String _confirmLabel = 'Confirm';
const String _recommended = 'Recommended';

/// The tier footers — the one line that is unique per tier, where the names and
/// the price pattern are not.
const String _flashFooter = 'Hyper-local, fastest';
const String _expressFooter = 'Best balance of speed and reach';
const String _standardFooter = 'Most coverage, lower cost';
const String _onTheWayFooter = 'Cheapest, opportunistic match';
const String _ecoFooter = 'Best price, plan ahead';

/// The two SLA edges only the full catalogue reaches: the tier with no SLA at
/// all, and the only one the `minutes % 60 == 0` branch renders in hours.
const String _slaNone = 'No SLA';
const String _slaEco = '≤ 48 hr';
const String _slaFlash = '≤ 1 hr';

/// The ONE failure sentence this screen has — `requestSummaryErrorNetwork`,
/// borrowed from the request_summary feature and rendered for BOTH members of
/// `TierLoadFailure`.
const String _failureCopy =
    "Couldn't reach Jeeb. Check your connection and try again.";
const String _retryLabel = 'Try again';

/// The banner nothing in the app can raise.
const String _cachedBannerCopy = 'Showing cached options — prices may differ';
const Key _cachedBannerKey = Key('tier-selection-cached-banner');

Finder get _confirmCta => find.byKey(TierSelectionScreen.confirmButtonKey);

bool _ctaEnabled(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(_confirmCta).isEnabled;

Finder get _tierList => find.descendant(
      of: find.byKey(TierSelectionScreen.listKey),
      matching: find.byType(Scrollable),
    );

/// Every string on the screen except the preview's own dev-chrome caption.
List<String> _screenCopy(WidgetTester tester, String caption) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s != caption)
    .toList();

/// The canvas, with the REAL font faces installed.
///
/// Identical to `previewCanvas` except for `withGoldenTestFonts`, which adds the
/// deterministic Noto Arabic family to the theme's `fontFamilyFallback`. Without
/// it `loadInterTestFont` fixes Latin only and every Arabic glyph still lays out
/// in the 1-em test face.
Widget _tierSelectionCanvas(Widget Function() preview, Locale locale) {
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

/// Pumps a preview at the device its `size:` declares, in a FRESH tree.
///
/// The `pumpWidget(SizedBox)` first is load-bearing whenever a test pumps a
/// second preview: the canvas produces the same widget types either way, so the
/// host's Element would be UPDATED rather than replaced and its `late final`
/// repository — created once per mount, on purpose — would still be the first
/// preview's.
Future<void> _pumpAtDevice(
  WidgetTester tester,
  Widget Function() preview, {
  Size logical = _phoneBox,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_tierSelectionCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// Pumps a preview WITHOUT settling, for the state that never settles.
///
/// Unmounts afterwards so the indicator's ticker is disposed before the test
/// ends — a live ticker at teardown is itself a failure.
Future<void> _pumpUnsettled(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  // Every preview except `Loading`, whose indeterminate spinner cannot settle.
  testPreviewsRender(
    'TierSelectionScreen',
    const <String, Widget Function()>{
      'Loaded · served catalogue, no selection':
          tierSelectionScreenServedCatalogue,
      'Selected · Express': tierSelectionScreenSelected,
      'Empty · catalogue answered 200 with nothing':
          tierSelectionScreenEmptyCatalogue,
      'Error · network': tierSelectionScreenErrorNetwork,
      'Error · server 5xx (same copy)': tierSelectionScreenErrorServer,
      'Cached banner · SEEDED, no producer in the app':
          tierSelectionScreenCachedFallback,
      'Full catalogue · compact 320x568':
          tierSelectionScreenFullCatalogueCompact,
    },
    expectedText: const <String, String>{
      // Production copy tells almost none of these apart — see the header.
      'Loaded · served catalogue, no selection':
          TierSelectionScreenCaptions.servedCatalogue,
      'Selected · Express': TierSelectionScreenCaptions.selected,
      'Empty · catalogue answered 200 with nothing':
          TierSelectionScreenCaptions.emptyCatalogue,
      'Error · network': TierSelectionScreenCaptions.errorNetwork,
      'Error · server 5xx (same copy)':
          TierSelectionScreenCaptions.errorServer,
      'Cached banner · SEEDED, no producer in the app':
          TierSelectionScreenCaptions.cachedFallback,
      'Full catalogue · compact 320x568':
          TierSelectionScreenCaptions.fullCatalogueCompact,
    },
  );

  group('TierSelectionScreen previews · Loading · never settles', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('renders its own state · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pumpUnsettled(tester, tierSelectionScreenLoading, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.text(TierSelectionScreenCaptions.loading), findsOneWidget);
        expect(find.byType(OmdsLoadingState), findsOneWidget);
      });
    }

    testWidgets('the whole body is ABSENT while the read is in flight — '
        'subtitle, list and CTA arrive together', (WidgetTester tester) async {
      await _pumpUnsettled(tester, tierSelectionScreenLoading);

      // `_Body` returns a bare spinner for `initial`/`loading`; everything else
      // on the screen lives inside `_LoadedView`. Pinned as CURRENT behaviour.
      expect(find.text(_subtitle), findsNothing);
      expect(find.byType(TierCard), findsNothing);
      expect(_confirmCta, findsNothing);
      expect(find.byKey(TierSelectionScreen.listKey), findsNothing);
    });
  });

  group('TierSelectionScreen previews · the declared frames', () {
    // These two are the ONLY tests pumped on the harness's 800 x 600 surface:
    // the claim is precisely that the preview pins its own device instead of
    // taking the canvas width.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, tierSelectionScreenServedCatalogue);

      expect(tester.getSize(find.byType(TierSelectionScreen)).width, 390);
    });

    testWidgets('the compact ceiling pins the 320 pt frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, tierSelectionScreenFullCatalogueCompact);

      expect(tester.getSize(find.byType(TierSelectionScreen)).width, 320);
    });
  });

  group('TierSelectionScreen previews · the served catalogue', () {
    testWidgets('opens on the three SERVED tiers with nothing selected', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenServedCatalogue);

      expect(find.byType(TierCard), findsNWidgets(3));
      expect(find.text(_flashFooter), findsOneWidget);
      expect(find.text(_expressFooter), findsOneWidget);
      expect(find.text(_standardFooter), findsOneWidget);
      // `DevtoolTierRepository` filters the legacy five down to the three the
      // gateway really returns.
      expect(find.text(_onTheWayFooter), findsNothing);
      expect(find.text(_ecoFooter), findsNothing);
      expect(find.text(_subtitle), findsOneWidget);
      expect(find.text(_slaFlash), findsOneWidget);
    });

    testWidgets('the recommended tier is BADGED, not pre-selected', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenServedCatalogue);

      // A recommendation is display metadata, not a customer choice — the same
      // contract `test/tier_selection_screen_test.dart` pins from the outside.
      expect(find.text(_recommended), findsOneWidget);
      expect(_ctaEnabled(tester), isFalse);
      for (final TierCard card
          in tester.widgetList<TierCard>(find.byType(TierCard))) {
        expect(card.selected, isFalse);
      }
    });

    testWidgets('pressing the disabled CTA hands nothing back', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenServedCatalogue);

      await tester.tap(_confirmCta, warnIfMissed: false);
      await tester.pump();

      expect(tierSelectionScreenConfirmations, isEmpty);
    });

    testWidgets('the CTA never announces an enabled/disabled state to a '
        'screen reader', (WidgetTester tester) async {
      await _pumpAtDevice(tester, tierSelectionScreenServedCatalogue);

      // `Semantics(identifier: …, button: true)` carries no `enabled:`, and
      // `OmdsPrimaryButton` is a bare `GestureDetector` underneath, so the
      // disabled CTA reads as an ordinary button that silently does nothing.
      // Pinned as CURRENT behaviour, not as the desired one.
      final flags = tester
          .getSemantics(find.bySemanticsIdentifier('tier_selection_confirm_cta'))
          .flagsCollection;
      expect(_ctaEnabled(tester), isFalse);
      expect(flags.isButton, isTrue);
      expect(flags.isEnabled, Tristate.none);
    });
  });

  group('TierSelectionScreen previews · selection and confirm', () {
    testWidgets('the cubit seam lands on Express selected, CTA live', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenSelected);

      final List<TierCard> cards =
          tester.widgetList<TierCard>(find.byType(TierCard)).toList();
      expect(cards.where((TierCard c) => c.selected).length, 1);
      expect(
        cards.singleWhere((TierCard c) => c.selected).description,
        _expressFooter,
      );
      expect(_ctaEnabled(tester), isTrue);
      expect(find.text(_confirmLabel), findsOneWidget);
    });

    testWidgets('Confirm hands the tier back ONCE — the second press on the '
        'same tier is a no-op', (WidgetTester tester) async {
      await _pumpAtDevice(tester, tierSelectionScreenSelected);

      await tester.tap(_confirmCta);
      await tester.pump();
      expect(tierSelectionScreenConfirmations, <String>['express']);

      // `confirm()` re-emits a state that is `==` to the current one, so
      // `Cubit.emit` drops it and the `BlocConsumer` listener never runs. The
      // CTA is still enabled and still does nothing. Pinned as CURRENT
      // behaviour.
      await tester.tap(_confirmCta);
      await tester.pump();
      expect(_ctaEnabled(tester), isTrue);
      expect(tierSelectionScreenConfirmations, <String>['express']);
    });

    testWidgets('choosing another tier re-arms Confirm', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenSelected);

      await tester.tap(_confirmCta);
      await tester.pump();
      await tester.tap(find.byKey(TierSelectionScreen.cardKey(TierId.flash)));
      await tester.pump();
      await tester.tap(_confirmCta);
      await tester.pump();

      expect(tierSelectionScreenConfirmations, <String>['express', 'flash']);
    });
  });

  group('TierSelectionScreen previews · the empty catalogue', () {
    testWidgets('a 200 with no tiers is LOADED: subtitle over nothing, no '
        'message, no retry, CTA dead', (WidgetTester tester) async {
      await _pumpAtDevice(tester, tierSelectionScreenEmptyCatalogue);

      expect(find.byType(TierCard), findsNothing);
      // Loaded, not error — so none of the error affordances exist.
      expect(find.text(_subtitle), findsOneWidget);
      expect(find.byKey(TierSelectionScreen.listKey), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.text(_failureCopy), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(_confirmCta, findsOneWidget);
      expect(_ctaEnabled(tester), isFalse);
    });
  });

  group('TierSelectionScreen previews · the two failures', () {
    testWidgets('network: the retryable failure, with a retry that is not '
        'keyed by `retryButtonKey`', (WidgetTester tester) async {
      await _pumpAtDevice(tester, tierSelectionScreenErrorNetwork);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text(_failureCopy), findsOneWidget);
      expect(find.text(_retryLabel), findsOneWidget);
      // The screen publishes `Key('tier-selection-retry')` and attaches it to
      // nothing: `OmdsErrorState` builds its own unkeyed `FilledButton.icon`.
      // Pinned as CURRENT behaviour — anything keying off the constant finds
      // nothing.
      expect(find.byKey(TierSelectionScreen.retryButtonKey), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
      // No tier list and no CTA on the failure path.
      expect(find.byType(TierCard), findsNothing);
      expect(_confirmCta, findsNothing);
    });

    testWidgets('server 5xx renders the SAME screen, word for word', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenErrorNetwork);
      final List<String> network =
          _screenCopy(tester, TierSelectionScreenCaptions.errorNetwork);

      await _pumpAtDevice(tester, tierSelectionScreenErrorServer);
      final List<String> server =
          _screenCopy(tester, TierSelectionScreenCaptions.errorServer);

      // `_Body` ignores `state.failure`, so a 5xx tells the customer to check a
      // connection that is working. Pinned as CURRENT behaviour.
      expect(server, network);
      expect(server, contains(_failureCopy));
    });
  });

  group('TierSelectionScreen previews · the cached-options banner', () {
    testWidgets('the SEEDED state is the only place the banner renders', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenCachedFallback);

      expect(find.byKey(_cachedBannerKey), findsOneWidget);
      expect(find.text(_cachedBannerCopy), findsOneWidget);
      // Same three tiers underneath, so the banner is the only difference.
      expect(find.byType(TierCard), findsNWidgets(3));
    });

    testWidgets('no state reached through the cubit can raise it', (
      WidgetTester tester,
    ) async {
      // `TierSelectionCubit` writes `usingCachedFallback: false` on all three of
      // its emits and `true` on none, so `_CachedBanner` is unreachable in the
      // app — every preview below goes through the cubit's public API.
      for (final Widget Function() preview in <Widget Function()>[
        tierSelectionScreenServedCatalogue,
        tierSelectionScreenSelected,
        tierSelectionScreenEmptyCatalogue,
        tierSelectionScreenErrorNetwork,
      ]) {
        await _pumpAtDevice(tester, preview);
        expect(find.byKey(_cachedBannerKey), findsNothing);
        expect(find.text(_cachedBannerCopy), findsNothing);
      }
    });
  });

  group('TierSelectionScreen previews · the compact ceiling', () {
    testWidgets('all five tiers are reachable on a 320 x 568 phone, including '
        'the two SLA edges', (WidgetTester tester) async {
      await _pumpAtDevice(
        tester,
        tierSelectionScreenFullCatalogueCompact,
        logical: _compactBox,
      );

      expect(find.text(_flashFooter), findsOneWidget);
      // The last two tiers are below the fold on this device — the list is a
      // `ListView`, so they are built on demand rather than clipped.
      await tester.scrollUntilVisible(
        find.byKey(TierSelectionScreen.cardKey(TierId.eco)),
        200,
        scrollable: _tierList,
      );
      expect(find.text(_ecoFooter), findsOneWidget);
      expect(find.text(_slaEco), findsOneWidget);
      expect(find.text(_onTheWayFooter), findsOneWidget);
      expect(find.text(_slaNone), findsOneWidget);
    });

    testWidgets('the Confirm CTA stays outside the scrolling list', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(
        tester,
        tierSelectionScreenFullCatalogueCompact,
        logical: _compactBox,
      );

      final double before = tester.getTopLeft(_confirmCta).dy;
      await tester.scrollUntilVisible(
        find.byKey(TierSelectionScreen.cardKey(TierId.eco)),
        200,
        scrollable: _tierList,
      );

      expect(tester.getTopLeft(_confirmCta).dy, before);
      expect(_ctaEnabled(tester), isFalse);
    });
  });
}
