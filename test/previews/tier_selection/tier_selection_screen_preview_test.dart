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

/// The phone the phone previews declare, and the narrowest supp
const Size _phoneBox = Size(390, 844);
const Size _compactBox = Size(320, 568);

/// Exact ARB copy, so a reworded string breaks the test instead
const String _subtitle = 'Price varies by Jeeber';
const String _confirmLabel = 'Confirm';
const String _recommended = 'Recommended';

/// The tier footers — the one line that is unique per tier, whe
const String _flashFooter = 'Hyper-local, fastest';
const String _expressFooter = 'Best balance of speed and reach';
const String _standardFooter = 'Most coverage, lower cost';
const String _onTheWayFooter = 'Cheapest, opportunistic match';
const String _ecoFooter = 'Best price, plan ahead';

/// The two SLA edges only the full catalogue reaches: the tier 
const String _slaNone = 'No SLA';
const String _slaEco = '≤ 48 hr';
const String _slaFlash = '≤ 1 hr';

/// The ONE failure sentence this screen has — `requestSummaryEr
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

/// Every string on the screen except the preview's own dev-chro
List<String> _screenCopy(WidgetTester tester, String caption) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s != caption)
    .toList();

/// The canvas, with the REAL font faces installed. Identical to
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

/// Pumps a preview at the device its `size:` declares, in a FRE
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

/// Pumps a preview WITHOUT settling, for the state that never s
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

      expect(find.text(_subtitle), findsNothing);
      expect(find.byType(TierCard), findsNothing);
      expect(_confirmCta, findsNothing);
      expect(find.byKey(TierSelectionScreen.listKey), findsNothing);
    });
  });

  group('TierSelectionScreen previews · the declared frames', () {
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
      expect(find.text(_onTheWayFooter), findsNothing);
      expect(find.text(_ecoFooter), findsNothing);
      expect(find.text(_subtitle), findsOneWidget);
      expect(find.text(_slaFlash), findsOneWidget);
    });

    // MIDNIGHT R9 / doc-13 P0-4: the cubit now seeds the recommended tier, so
    // "badged but never selected" is retired for every consumer of the cubit.
    testWidgets('the recommended tier is BADGED and pre-selected', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenServedCatalogue);

      expect(find.text(_recommended), findsOneWidget);
      expect(_ctaEnabled(tester), isTrue);
      final Iterable<TierCard> selected = tester
          .widgetList<TierCard>(find.byType(TierCard))
          .where((TierCard card) => card.selected);
      expect(selected.length, 1);
    });

    testWidgets('pressing the live CTA hands back the seeded tier', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenServedCatalogue);

      await tester.tap(_confirmCta, warnIfMissed: false);
      await tester.pump();

      expect(tierSelectionScreenConfirmations, <String>['standard']);
    });

    testWidgets('the CTA announces itself as an enabled button', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, tierSelectionScreenServedCatalogue);

      final flags = tester
          .getSemantics(find.bySemanticsIdentifier('tier_selection_confirm_cta'))
          .flagsCollection;
      expect(_ctaEnabled(tester), isTrue);
      expect(flags.isButton, isTrue);
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
      expect(find.byKey(TierSelectionScreen.retryButtonKey), findsNothing);
      expect(find.byType(FilledButton), findsOneWidget);
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
      expect(find.byType(TierCard), findsNWidgets(3));
    });

    testWidgets('no state reached through the cubit can raise it', (
      WidgetTester tester,
    ) async {
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
      expect(_ctaEnabled(tester), isTrue);
    });
  });
}
