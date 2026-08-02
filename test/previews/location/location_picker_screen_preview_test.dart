// Render tests for the LocationPickerScreen previews.

// ## Two screens, one file

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/'
    'location_picker_placeholder_screen_fixtures.dart';
import 'package:jeeb_mobile/features/location/presentation/location_picker_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/location_search_bar.dart';
import 'package:jeeb_mobile/features/location/presentation/screens/'
    'location_picker_screen.dart' as placeholder;
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// `previewCanvas`, but with the deterministic Arabic face wired into the theme.
/// The shared harness cannot do this — it builds `AppTheme.light()` directly and
Widget _placeholderCanvasWithFonts(
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

/// Points the test surface at [box] at 1:1 density, undone after the test.
/// `testPreviewsRender` pumps at whatever the surface happens to be, while the
void _useBox(WidgetTester tester, Size box) {
  tester.view.physicalSize = box;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Applies the app's 200% accessibility ceiling — the third card of a
/// `matrix: true` preview — for the duration of the test.
void _useLargeText(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Height the empty-state content wants, as laid out right now.
/// `OmdsEmptyState` is the `Padding` + `Column` that `OmdsEmptyStatePage`
double _emptyStateHeight(WidgetTester tester) =>
    tester.getSize(find.byType(OmdsEmptyState)).height;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'LocationPickerScreen',
    const <String, Widget Function()>{
      'Pickup · nothing selected': locationPickerScreenPickupEmpty,
      'Pickup · finding GPS': locationPickerScreenLocatingGps,
      'Pickup · resolving dragged pin': locationPickerScreenResolvingAddress,
      'Pickup · suggestions open': locationPickerScreenSearchResults,
      'Pickup · just tapped a suggestion':
          locationPickerScreenSuggestionSelected,
      'Pickup · GPS permission denied': locationPickerScreenGpsDenied,
      'Pickup · GPS + Pin on map row': locationPickerScreenMapPinRow,
      'Dropoff · pickup confirmed': locationPickerScreenDropoff,
      'Dropoff · longest addresses': locationPickerScreenLongestAddresses,
      'Dropoff · saving': locationPickerScreenSaving,
      'Dropoff · save failed': locationPickerScreenSaveFailed,
      'Confirmed · both legs saved': locationPickerScreenConfirmed,
    },
    expectedText: const <String, String>{
      'Pickup · nothing selected': 'No location selected yet',
      'Pickup · finding GPS': 'Detecting your location…',
      'Pickup · resolving dragged pin': 'Resolving address…',
      'Pickup · suggestions open': 'Gemmayze, Beirut',
      'Pickup · just tapped a suggestion': 'Hamra Street, Beirut',
      'Pickup · GPS permission denied':
          'Location permission was denied. Allow it in Settings to use GPS.',
      'Pickup · GPS + Pin on map row': 'Pin on map',
      'Dropoff · pickup confirmed': 'Step 2 of 2 — choose dropoff',
      'Dropoff · longest addresses':
          'Saint George Hospital University Medical Center — Building C, '
              '4th floor reception, Achrafieh, Beirut, Lebanon',
      'Dropoff · saving': 'Saving…',
      'Dropoff · save failed': 'Could not save your locations. Try again.',
      'Confirmed · both legs saved': 'Both locations saved',
    },
  );

  group('LocationPickerScreen preview specifics', () {
    testWidgets('the empty state cannot be confirmed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenPickupEmpty);

      // Step 1 copy, and the CTA that goes with it.
      expect(find.text('Step 1 of 2 — choose pickup'), findsOneWidget);
      expect(find.text('Continue to dropoff'), findsOneWidget);
      // No committed leg yet, so the pair preview is collapsed.
      expect(find.text('No location selected yet'), findsOneWidget);
    });

    testWidgets('an in-flight GPS lookup shows copy, never a spinner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenLocatingGps);

      expect(find.text('Detecting your location…'), findsOneWidget);
      // The whole loading affordance is one line of body copy — if a spinner
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'a dragged pin is confirmable before its address resolves',
      (WidgetTester tester) async {
        await pumpPreview(tester, locationPickerScreenResolvingAddress);

        // `locationCoordinatesFallback` — the leg a user would commit right now.
        expect(find.text('33.89380, 35.50180'), findsOneWidget);
        expect(find.text('Resolving address…'), findsOneWidget);
      },
    );

    testWidgets(
      'a populated dropdown sits over an EMPTY search field',
      (WidgetTester tester) async {
        await pumpPreview(tester, locationPickerScreenSearchResults);

        // The cubit's query filtered these rows in.
        expect(find.text('Downtown, Beirut'), findsOneWidget);
        expect(find.text('Gemmayze, Beirut'), findsOneWidget);
        // …but nothing ever seeded the controller from `state.searchQuery`:
        expect(find.text('beirut'), findsNothing);
      },
    );

    testWidgets(
      'tapping a suggestion leaves the "no matches" line under it',
      (WidgetTester tester) async {
        await pumpPreview(tester, locationPickerScreenSuggestionSelected);

        expect(find.text('Hamra Street, Beirut'), findsOneWidget);
        // Same (query, results, isSearching) triple as a query that matched
        expect(find.text('No matching addresses'), findsOneWidget);
      },
    );

    testWidgets('an error surfaces ONLY as a snackbar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenSaveFailed);

      expect(
        find.text('Could not save your locations. Try again.'),
        findsOneWidget,
      );
      // Nothing in `builder` renders `state.error`: the step, the pair and the
      expect(find.text('Step 2 of 2 — choose dropoff'), findsOneWidget);
      expect(find.text('Confirm & save'), findsOneWidget);
    });

    testWidgets('a denied GPS permission leaves the screen untouched', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenGpsDenied);

      expect(
        find.text(
          'Location permission was denied. Allow it in Settings to use GPS.',
        ),
        findsOneWidget,
      );
      // Back to the empty state — the denial leaves no persistent trace.
      expect(find.text('No location selected yet'), findsOneWidget);
    });

    testWidgets('the dropoff draft is pre-seeded with the pickup pin', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenDropoff);

      expect(find.text('Step 2 of 2 — choose dropoff'), findsOneWidget);
      // The draft card already holds the PICKUP address, so a user who taps
      expect(find.text('Hamra Street, Beirut'), findsOneWidget);
      expect(find.text('Confirm & save'), findsOneWidget);
    });

    testWidgets('an in-flight save swaps and disables the CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenSaving);

      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Confirm & save'), findsNothing);
      // The search bar has no `isSaving` input, so it stays fully live while
      expect(find.byType(LocationSearchBar), findsOneWidget);
    });

    testWidgets('the map row is the only preview with three affordances', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenMapPinRow);

      expect(find.text('Use current GPS'), findsOneWidget);
      expect(find.text('Pin on map'), findsOneWidget);
      // Clean here only because `flutter test` renders on an 800 pt-wide
      expect(tester.takeException(), isNull);
    });

    testWidgets('the terminal state repeats its own title on the CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenConfirmed);

      expect(find.text('Both locations saved'), findsOneWidget);
      // App-bar title AND button label — `_confirmCta` has no copy of its own
      expect(find.text('Locations confirmed'), findsNWidgets(2));
    });
  });

  // ===================================================================
  group('LocationPickerScreen · /location placeholder', () {
    setUpAll(loadInterTestFont);

    setUp(() {
      final TestWidgetsFlutterBinding binding =
          TestWidgetsFlutterBinding.ensureInitialized();
      final view = binding.platformDispatcher.views.first;
      view.physicalSize = LocationPickerPlaceholderScreenFixtures.phoneBox;
      view.devicePixelRatio = 1.0;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);
    });

    testPreviewsRender(
      'LocationPickerScreen (placeholder)',
      const <String, Widget Function()>{
        'Placeholder · phone':
            placeholder.locationPickerScreenPlaceholderPhone,
        'Placeholder · compact device':
            placeholder.locationPickerScreenPlaceholderCompact,
        'Placeholder · landscape, short viewport':
            placeholder.locationPickerScreenPlaceholderLandscape,
        'Placeholder · pushed route, no way back':
            placeholder.locationPickerScreenPlaceholderDeadEnd,
      },
      expectedText: const <String, String>{
        'Placeholder · phone':
            LocationPickerPlaceholderScreenFixtures.captionPhone,
        'Placeholder · compact device':
            LocationPickerPlaceholderScreenFixtures.captionCompact,
        'Placeholder · landscape, short viewport':
            LocationPickerPlaceholderScreenFixtures.captionLandscape,
        'Placeholder · pushed route, no way back':
            LocationPickerPlaceholderScreenFixtures.captionDeadEnd,
      },
    );

    group('specifics', () {
      // What the single state actually is, pinned so "the previews render" can
      testWidgets('the one state is a dead end with no affordances', (
        WidgetTester tester,
      ) async {
        await pumpPreview(
          tester,
          placeholder.locationPickerScreenPlaceholderPhone,
        );

        expect(
          find.text(LocationPickerPlaceholderScreenFixtures.title),
          findsOneWidget,
        );
        expect(
          find.text(LocationPickerPlaceholderScreenFixtures.subtitle),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.construction_outlined), findsOneWidget);
        // `appBar: null` — no app bar, so no back affordance of any kind.
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(BackButton), findsNothing);
        // `buttonText`/`onButtonTap` are left null, so no action out either.
        expect(find.byType(ButtonStyleButton), findsNothing);
        // And nothing to scroll — see the height-ceiling tests below.
        expect(find.byType(Scrollable), findsNothing);
      });

      // The screen wraps itself in `Semantics(container: true, label: …)` over
      testWidgets('the screen announces its copy twice, in one node', (
        WidgetTester tester,
      ) async {
        // Semantics data is only built while a handle is alive. Disposed
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpPreview(
          tester,
          placeholder.locationPickerScreenPlaceholderPhone,
        );

        final SemanticsNode node = tester.getSemantics(
          find.byType(placeholder.LocationPickerScreen),
        );
        expect(
          node.label,
          '${LocationPickerPlaceholderScreenFixtures.semanticsLabel}\n'
              '${LocationPickerPlaceholderScreenFixtures.title}\n'
              '${LocationPickerPlaceholderScreenFixtures.subtitle}',
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
          reason: 'and there is nothing on it to activate',
        );
        // The wrapper label itself is just the two sentences run together.
        expect(
          LocationPickerPlaceholderScreenFixtures.semanticsLabel,
          '${LocationPickerPlaceholderScreenFixtures.title}. '
              '${LocationPickerPlaceholderScreenFixtures.subtitle}',
        );
        handle.dispose();
      });

      // The copy is three string literals, not `l10n` lookups, even though the
      testWidgets('an Arabic build still renders the English copy', (
        WidgetTester tester,
      ) async {
        await pumpPreview(
          tester,
          placeholder.locationPickerScreenPlaceholderPhone,
          locale: const Locale('ar'),
        );

        expect(
          Directionality.of(
            tester.element(find.byType(placeholder.LocationPickerScreen)),
          ),
          TextDirection.rtl,
          reason: 'the frame mirrors…',
        );
        expect(
          find.text(LocationPickerPlaceholderScreenFixtures.title),
          findsOneWidget,
          reason: '…but the words do not: the screen ships string literals',
        );

        // And the Arabic this screen is ignoring is already in the ARB.
        final String arb = File('lib/l10n/app_ar.arb').readAsStringSync();
        expect(
          arb.contains('"locationPickerTitle"'),
          isTrue,
          reason: 'a localized title already exists for this feature',
        );
      });

      // The finding that separates this placeholder from the identical one on
      testWidgets('a poppable route still draws no way back', (
        WidgetTester tester,
      ) async {
        await pumpPreview(
          tester,
          placeholder.locationPickerScreenPlaceholderDeadEnd,
        );

        // The nested navigator is the deepest one — MaterialApp owns the outer.
        final NavigatorState nested = tester.state<NavigatorState>(
          find.byType(Navigator).last,
        );
        expect(
          nested.canPop(),
          isTrue,
          reason: 'there IS a route underneath to go back to',
        );
        expect(
          find.text(LocationPickerPlaceholderScreenFixtures.title),
          findsOneWidget,
          reason: 'and the placeholder is the one on top',
        );
        // …but nothing on screen says so.
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(BackButton), findsNothing);
        expect(find.byType(ButtonStyleButton), findsNothing);
      });

      // The one width-driven difference between the boxes. 272 pt of usable
      testWidgets('the headline fits the phone and wraps on the compact device',
          (WidgetTester tester) async {
        _useBox(tester, LocationPickerPlaceholderScreenFixtures.phoneBox);
        await tester.pumpWidget(
          _placeholderCanvasWithFonts(
            placeholder.locationPickerScreenPlaceholderPhone,
            const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        final Finder headline =
            find.text(LocationPickerPlaceholderScreenFixtures.title);
        final Text title = tester.widget<Text>(headline);
        expect(title.maxLines, isNull);
        expect(title.overflow, isNull);

        RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          headline,
        );
        final double wanted = paragraph.getMaxIntrinsicWidth(double.infinity);
        final double oneLine = paragraph.getMinIntrinsicHeight(double.infinity);
        expect(
          paragraph.size.height,
          oneLine,
          reason: '390 pt gives the headline the 331 pt it wants',
        );

        _useBox(tester, LocationPickerPlaceholderScreenFixtures.compactBox);
        await tester.pumpWidget(
          _placeholderCanvasWithFonts(
            placeholder.locationPickerScreenPlaceholderCompact,
            const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        paragraph = tester.renderObject<RenderParagraph>(headline);
        expect(
          paragraph.size.width,
          lessThan(wanted),
          reason: '320 pt does not, once 24 pt of padding is off each side',
        );
        expect(
          paragraph.size.height,
          greaterThan(oneLine),
          reason: 'so it occupies more than one line',
        );
        expect(tester.takeException(), isNull);
      });

      // The height ceiling — and NOT where it looks like it should be.
      testWidgets('the narrow device, not the short one, is the tight box', (
        WidgetTester tester,
      ) async {
        _useLargeText(tester);

        _useBox(tester, LocationPickerPlaceholderScreenFixtures.landscapeBox);
        await tester.pumpWidget(
          _placeholderCanvasWithFonts(
            placeholder.locationPickerScreenPlaceholderLandscape,
            const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();
        final double shortViewport = _emptyStateHeight(tester);
        expect(
          tester.takeException(),
          isNull,
          reason: 'the 390 pt-tall viewport is NOT where this screen breaks',
        );

        _useBox(tester, LocationPickerPlaceholderScreenFixtures.compactBox);
        await tester.pumpWidget(
          _placeholderCanvasWithFonts(
            placeholder.locationPickerScreenPlaceholderCompact,
            const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();
        final double narrowViewport = _emptyStateHeight(tester);

        expect(
          narrowViewport,
          greaterThan(shortViewport),
          reason: 'the wrapped headline costs more height than the short '
              'viewport ever asks for',
        );
        // Still fits — this screen does not overflow anywhere today.
        final double compactHeight =
            LocationPickerPlaceholderScreenFixtures.compactBox.height;
        expect(tester.takeException(), isNull);
        expect(narrowViewport, lessThan(compactHeight));
        // …but only just, and there is no scroll view underneath it.
        expect(
          compactHeight - narrowViewport,
          lessThan(0.1 * compactHeight),
          reason: 'under a tenth of the viewport is left over',
        );
        expect(find.byType(Scrollable), findsNothing);
      });

      // The control that makes the margin above attributable to the DEVICE and
      testWidgets('the reference phone has room for the same content at 200%', (
        WidgetTester tester,
      ) async {
        _useLargeText(tester);
        _useBox(tester, LocationPickerPlaceholderScreenFixtures.phoneBox);
        await tester.pumpWidget(
          _placeholderCanvasWithFonts(
            placeholder.locationPickerScreenPlaceholderPhone,
            const Locale('en'),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          _emptyStateHeight(tester),
          lessThan(
            0.6 * LocationPickerPlaceholderScreenFixtures.phoneBox.height,
          ),
        );
      });

      // The catalog and the canvas must be showing the same state. If someone
      testWidgets('the previews and the fixtures build one screen', (
        WidgetTester tester,
      ) async {
        await pumpPreview(
          tester,
          placeholder.locationPickerScreenPlaceholderPhone,
        );

        expect(
          find.byType(placeholder.LocationPickerScreen),
          findsOneWidget,
        );
        expect(
          LocationPickerPlaceholderScreenFixtures.placeholder(),
          isA<placeholder.LocationPickerScreen>(),
        );
      });
    });
  });
}
