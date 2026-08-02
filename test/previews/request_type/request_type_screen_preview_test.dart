// Render tests for the RequestTypeScreen previews.

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/request_type_screen_fixtures.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_location_row.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_tier_card.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The phone the phone previews declare, and the narrowest supported one the
/// full-catalogue ceiling declares.
const Size _phoneBox = Size(390, 844);
const Size _compactBox = Size(320, 568);

/// The headings and the CTA, exactly as the ARB spells them. Declared here
/// rather than read off `AppLocalizations` so a reworded string breaks the test
const String _chooseHeading = 'Choose your request';
const String _locationHeading = 'Location';
const String _continueLabel = 'Continue';
const String _currentLocation = 'Current Location';

/// The ONE failure sentence this screen has — `requestSummaryErrorNetwork`,
/// borrowed from the request_summary feature and rendered for BOTH members of
const String _failureCopy =
    "Couldn't reach Jeeb. Check your connection and try again.";
const String _retryLabel = 'Try again';

/// The tier "value" line a customer reads as a price cue. Static ARB copy, and
/// the same in every catalogue.
const String _flashValueLine = 'Highest price • Priority pickup';

/// The semantics ids `requestTypeRadioId` mints, which the Maestro create-flow
/// asserts by name (63_W1_TEST_PLAN §2.2).
const String _flashRadio = 'request_type_flash_radio';
const String _expressRadio = 'request_type_express_radio';
const String _standardRadio = 'request_type_standard_radio';
const String _onTheWayRadio = 'request_type_on_the_way_radio';
const String _ecoRadio = 'request_type_eco_radio';
const String _changeLocationButton = 'request_type_change_location_button';

Finder get _continueCta => find.byKey(const Key('request-type-continue'));

bool _ctaEnabled(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(_continueCta).isEnabled;

CheckedState _checked(WidgetTester tester, String identifier) => tester
    .getSemantics(find.bySemanticsIdentifier(identifier))
    .flagsCollection
    .isChecked;

/// Every string rendered inside a tier card, in list order.
List<String> _tierCopy(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(RequestTierCard),
        matching: find.byType(Text),
      ),
    )
    .map((Text t) => t.data ?? '')
    .toList();

/// Every string on the screen except the preview's own dev-chrome caption.
List<String> _screenCopy(WidgetTester tester, String caption) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .where((String s) => s != caption)
    .toList();

/// The canvas, with the REAL font faces installed.
/// Identical to `previewCanvas` except for `withGoldenTestFonts`, which adds the
Widget _requestTypeCanvas(Widget Function() preview, Locale locale) {
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
/// The `pumpWidget(SizedBox)` first is load-bearing whenever a test pumps a
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
  await tester.pumpWidget(_requestTypeCanvas(preview, locale));
  await tester.pumpAndSettle();
}

/// Pumps a preview WITHOUT settling, for the state that never settles.
/// Unmounts afterwards so the indicator's ticker is disposed before the test
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
    'RequestTypeScreen',
    const <String, Widget Function()>{
      'Loaded · served catalogue, no selection':
          requestTypeScreenServedCatalogue,
      'Selected · Standard': requestTypeScreenSelected,
      'Repriced catalogue · identical cards':
          requestTypeScreenRepricedCatalogue,
      'Empty · catalogue answered 200 with nothing':
          requestTypeScreenEmptyCatalogue,
      'Error · network': requestTypeScreenErrorNetwork,
      'Error · server 5xx (same copy)': requestTypeScreenErrorServer,
      'Full catalogue · compact 320x568':
          requestTypeScreenFullCatalogueCompact,
    },
    expectedText: const <String, String>{
      // Nothing in production copy tells these seven apart — see the header.
      'Loaded · served catalogue, no selection':
          RequestTypeScreenCaptions.servedCatalogue,
      'Selected · Standard': RequestTypeScreenCaptions.selected,
      'Repriced catalogue · identical cards':
          RequestTypeScreenCaptions.repricedCatalogue,
      'Empty · catalogue answered 200 with nothing':
          RequestTypeScreenCaptions.emptyCatalogue,
      'Error · network': RequestTypeScreenCaptions.errorNetwork,
      'Error · server 5xx (same copy)': RequestTypeScreenCaptions.errorServer,
      'Full catalogue · compact 320x568':
          RequestTypeScreenCaptions.fullCatalogueCompact,
    },
  );

  group('RequestTypeScreen previews · Loading · never settles', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('renders its own state · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await _pumpUnsettled(tester, requestTypeScreenLoading, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.text(RequestTypeScreenCaptions.loading), findsOneWidget);
        expect(find.byType(OmdsLoadingState), findsOneWidget);
      });
    }

    testWidgets('the whole footer is ABSENT while the read is in flight, not '
        'merely disabled', (WidgetTester tester) async {
      await _pumpUnsettled(tester, requestTypeScreenLoading);

      // `_ContinueFooter` short-circuits to `SizedBox.shrink()` for every status
      expect(_continueCta, findsNothing);
      expect(find.byType(RequestTierCard), findsNothing);
      // The back arrow is the only stable furniture on the screen. It is an
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });
  });

  group('RequestTypeScreen previews · the declared frames', () {
    // These two are the ONLY tests pumped on the harness's 800 x 600 surface:
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, requestTypeScreenServedCatalogue);

      expect(tester.getSize(find.byType(RequestTypeScreen)).width, 390);
    });

    testWidgets('the compact ceiling pins the 320 pt frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, requestTypeScreenFullCatalogueCompact);

      expect(tester.getSize(find.byType(RequestTypeScreen)).width, 320);
    });
  });

  group('RequestTypeScreen previews · the served catalogue', () {
    testWidgets('opens on the three SERVED tiers, with the headings and a '
        'location row', (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenServedCatalogue);

      expect(find.byType(RequestTierCard), findsNWidgets(3));
      for (final String id in const <String>[
        _flashRadio,
        _expressRadio,
        _standardRadio,
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget);
      }
      // `DevtoolTierRepository` filters the legacy five down to the three the
      expect(find.bySemanticsIdentifier(_onTheWayRadio), findsNothing);
      expect(find.bySemanticsIdentifier(_ecoRadio), findsNothing);
      expect(find.text(_chooseHeading), findsOneWidget);
      expect(find.text(_locationHeading), findsOneWidget);
      expect(find.text(_currentLocation), findsOneWidget);
      expect(find.byType(RequestLocationRow), findsOneWidget);
    });

    testWidgets('nothing is pre-selected and Continue is inert (JM-024 wants a '
        'DELIBERATE tap)', (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenServedCatalogue);

      for (final String id in const <String>[
        _flashRadio,
        _expressRadio,
        _standardRadio,
      ]) {
        expect(_checked(tester, id), CheckedState.isFalse, reason: id);
      }
      expect(_ctaEnabled(tester), isFalse);
    });

    testWidgets('the full catalogue adds the two tiers the served one hides', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(
        tester,
        requestTypeScreenFullCatalogueCompact,
        logical: _compactBox,
      );

      // `FakeTierRepository` is the SHIPPING fallback, so five cards is a state
      expect(
        find.byType(RequestTierCard, skipOffstage: false),
        findsNWidgets(5),
      );
    });
  });

  group('RequestTypeScreen previews · selection and the dead seams', () {
    testWidgets('the Selected preview arrives with Standard chosen and the CTA '
        'live', (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenSelected);

      expect(_checked(tester, _standardRadio), CheckedState.isTrue);
      expect(_checked(tester, _flashRadio), CheckedState.isFalse);
      expect(_checked(tester, _expressRadio), CheckedState.isFalse);
      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets('a tier tap checks that card and arms Continue', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, requestTypeScreenServedCatalogue);

      await tester.tap(find.bySemanticsIdentifier(_expressRadio));
      await tester.pump();

      expect(_checked(tester, _expressRadio), CheckedState.isTrue);
      expect(_checked(tester, _flashRadio), CheckedState.isFalse);
      expect(_ctaEnabled(tester), isTrue);
    });

    testWidgets('Continue navigates to client-location — and NEITHER '
        'onTierSelected nor onContinue is ever called', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, requestTypeScreenServedCatalogue);

      await tester.tap(find.bySemanticsIdentifier(_expressRadio));
      await tester.pump();
      await tester.tap(_continueCta);
      await tester.pumpAndSettle();

      // The screen owns this edge: `context.pushNamed('client-location')`
      expect(find.text(requestTypeScreenDestinationCaption), findsOneWidget);
      // …and the two callbacks the CONSTRUCTOR advertises are dead. `build`
      expect(
        requestTypeScreenSeamCalls,
        isEmpty,
        reason: 'onTierSelected/onContinue are declared and never forwarded',
      );
    });

    testWidgets('Change Location takes the same edge, and does not need a tier '
        'at all', (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenServedCatalogue);

      await tester.tap(find.bySemanticsIdentifier(_changeLocationButton));
      await tester.pumpAndSettle();

      // `_LocationSection._onChange` falls through to
      expect(find.text(requestTypeScreenDestinationCaption), findsOneWidget);
      expect(requestTypeScreenSeamCalls, isEmpty);
    });
  });

  group('RequestTypeScreen previews · the gateway payload is discarded', () {
    testWidgets('a repriced catalogue renders the SAME cards as the served '
        'one', (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenServedCatalogue);
      final List<String> served = _tierCopy(tester);

      await _pumpAtDevice(tester, requestTypeScreenRepricedCatalogue);
      final List<String> repriced = _tierCopy(tester);

      expect(served, isNotEmpty);
      // `_RequestTierCopy.of(l10n, tier.id)` keys every line on the id, so
      expect(repriced, served);
    });

    testWidgets('no price, currency, SLA or server id from the fixture reaches '
        'a card', (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenRepricedCatalogue);

      // Read off the fixture, not retyped, so a repriced catalogue that changed
      final Tier flash = RequestTypeScreenRepricedTierRepository.catalogue.first;
      for (final String token in <String>[
        '${flash.priceLow}',
        '${flash.priceHigh}',
        flash.currency,
        flash.serverId!,
      ]) {
        expect(
          find.descendant(
            of: find.byType(RequestTierCard),
            matching: find.textContaining(token),
          ),
          findsNothing,
          reason: 'the card renders static ARB copy, never the Tier',
        );
      }
      // What a customer compares prices with is this, in both catalogues.
      expect(find.text(_flashValueLine), findsOneWidget);
    });
  });

  group('RequestTypeScreen previews · empty catalogue', () {
    testWidgets('a 200 with no tiers is LOADED: a heading over nothing, and a '
        'CTA that can never enable', (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenEmptyCatalogue);

      expect(find.byType(RequestTierCard), findsNothing);
      // Every affordance of a working screen is present…
      expect(find.text(_chooseHeading), findsOneWidget);
      expect(find.text(_locationHeading), findsOneWidget);
      expect(find.text(_continueLabel), findsOneWidget);
      // …and nothing at all says why there is nothing to choose.
      expect(find.byType(OmdsErrorState), findsNothing);
      expect(find.text(_retryLabel), findsNothing);
      expect(find.text(_failureCopy), findsNothing);
      // The CTA is disabled because `selectedTierId` can never be set, so this
      expect(_ctaEnabled(tester), isFalse);
    });
  });

  group('RequestTypeScreen previews · the two load failures', () {
    testWidgets('a network failure offers a retry that can actually help', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, requestTypeScreenErrorNetwork);

      expect(find.text(_failureCopy), findsOneWidget);
      expect(find.text(_retryLabel), findsOneWidget);
      expect(find.byType(RequestTierCard), findsNothing);
      // The footer is gone entirely on error, so the in-body retry is the only
      expect(_continueCta, findsNothing);
    });

    testWidgets('a SERVER failure renders the identical sentence, blaming the '
        "customer's connection for a 5xx", (WidgetTester tester) async {
      await _pumpAtDevice(tester, requestTypeScreenErrorNetwork);
      final List<String> networkTexts =
          _screenCopy(tester, RequestTypeScreenCaptions.errorNetwork);

      await _pumpAtDevice(tester, requestTypeScreenErrorServer);
      final List<String> serverTexts =
          _screenCopy(tester, RequestTypeScreenCaptions.errorServer);

      // `_Body` never reads `state.failure`; it passes
      expect(networkTexts, contains(_failureCopy));
      expect(serverTexts, networkTexts);
    });

    testWidgets('the retry re-runs load() and stays on the same failure', (
      WidgetTester tester,
    ) async {
      await _pumpAtDevice(tester, requestTypeScreenErrorServer);

      await tester.tap(find.text(_retryLabel));
      await tester.pumpAndSettle();

      expect(find.text(_failureCopy), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // The layout claims the two matrixed previews are there to let a reviewer
  group('RequestTypeScreen previews · measured at the declared devices', () {
    /// The tier list's scroll position — 0 pt of extent means the whole screen
    /// is on screen.
    ScrollPosition listPosition(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(RequestTypeScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    testWidgets('390 x 844 fits the WHOLE screen at 100% text, and stops '
        'fitting at 200%', (WidgetTester tester) async {
      await _pumpAtDevice(
        tester,
        requestTypeScreenServedCatalogue,
        logical: _phoneBox,
        textScale: 1,
      );

      // Three tiers, both headings and the location row, with nothing below the
      expect(listPosition(tester).maxScrollExtent, 0);
      expect(find.byType(RequestLocationRow), findsOneWidget);
      expect(
        tester.getRect(_continueCta).bottom,
        lessThanOrEqualTo(_phoneBox.height),
      );

      await _pumpAtDevice(
        tester,
        requestTypeScreenServedCatalogue,
        logical: _phoneBox,
        textScale: 2,
      );

      // At 200% the same three tiers no longer fit — measured 318 pt of extent,
      expect(listPosition(tester).maxScrollExtent, greaterThan(0));
      expect(tester.getRect(_continueCta).height, 48);
    });

    testWidgets('320 x 568 with all five tiers scrolls hard, and the CTA stays '
        'on screen in both locales at both scales', (
      WidgetTester tester,
    ) async {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        for (final double scale in const <double>[1, 2]) {
          final String at = '${locale.languageCode} · ${scale}x';
          await _pumpAtDevice(
            tester,
            requestTypeScreenFullCatalogueCompact,
            logical: _compactBox,
            textScale: scale,
            locale: locale,
          );

          // Five cards against a 384 pt viewport: measured 760 pt of extent at
          expect(
            listPosition(tester).maxScrollExtent,
            greaterThan(0),
            reason: at,
          );
          // The Continue CTA is OUTSIDE that list, so it has to survive on its
          final Rect cta = tester.getRect(_continueCta);
          expect(cta.height, greaterThan(0), reason: at);
          expect(
            cta.bottom,
            lessThanOrEqualTo(_compactBox.height),
            reason: at,
          );
          // …and at least one tier is visible under the heading, so the screen
          expect(find.byType(RequestTierCard), findsWidgets, reason: at);
        }
      }
    });
  });
}
