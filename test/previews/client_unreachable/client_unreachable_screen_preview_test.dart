// Render tests for the ClientUnreachableScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This screen renders the same title, the same icon, the same paragraph and the
// same three buttons in EVERY state and in EVERY locale, so "did it render" is
// close to a vacuous question here: all five previews would pass a render-only
// check while looking identical. The suite therefore does two extra jobs. The
// captions pin WHICH state each preview is — the window it was given and the
// stack it was put on — and the groups below measure what the screen actually
// did inside that window: whether its copy fits, whether its one working
// affordance is reachable, and what is left when it is not.
//
// The measurements marked FINDING are DEFECTS, not contracts. If one starts
// failing because the screen was fixed, delete the guard — do not restore the
// expectation.
//
// ## About the absolute pixel numbers quoted in comments
//
// `flutter_test` draws every glyph as a square of the font size, so English
// measures roughly twice as wide as Inter renders it and the wrapped paragraph
// in the notice card is correspondingly taller. Numbers taken at 100% are
// therefore an upper bound, and the assertions below never pin one — they pin
// the DIRECTION (fits / does not fit, above / below the edge). The 200% numbers
// are far past anything a font metric could explain: the flag CTA lands 172 pt
// (phone) and 736 pt (compact) below the display edge.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/client_unreachable_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/features/client_unreachable/presentation/client_unreachable_screen.dart';

import '../preview_test_harness.dart';

/// The frames the fixture declares, mirrored here so a preview quietly rewired
/// to a different window fails instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);

/// The screen's copy, as English string LITERALS — which is what it is in the
/// shipped source too. There is no ARB key to reference, and that is the point
/// of `not localized` below.
const String _title = 'Client Unreachable';
const String _noticeTitle = 'Cannot reach the Client';
const String _callCta = 'Try Calling Again';
const String _chatCta = 'Send Chat Message';
const String _flagCta = 'Flag as Unreachable';

/// Every preview, with the caption its fixture paints above the frame.
///
/// One map rather than several, because the caption is the ONLY thing that
/// differs between these five renderings and the suite has to be able to say so
/// about all of them at once.
final Map<Widget Function(), String> _previewCaptions =
    <Widget Function(), String>{
  clientUnreachableScreenPhone: ClientUnreachableScreenFixtures.phone.label,
  clientUnreachableScreenColdArrival:
      ClientUnreachableScreenFixtures.coldArrival.label,
  clientUnreachableScreenCompact: ClientUnreachableScreenFixtures.compact.label,
  clientUnreachableScreenLargeText:
      ClientUnreachableScreenFixtures.phoneLargeText.label,
  clientUnreachableScreenCompactLargeText:
      ClientUnreachableScreenFixtures.compactLargeText.label,
};

Finder _button(String label) => find.widgetWithText(OmdsPrimaryButton, label);

Rect _frame(WidgetTester tester) =>
    tester.getRect(find.byType(ClientUnreachableScreen));

/// Pumps [preview] into a FRESH element tree.
///
/// Two previews cannot simply be pumped one after the other: the canvas wrapper
/// is identical down to the fixture host, so Flutter reuses the element — and
/// with it the host's Navigator, which would still be sitting on whatever page
/// the previous test's tap left behind. Unmounting first forces a rebuild.
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await pumpPreview(tester, preview, locale: locale);
}

/// Pumps [preview] with framework errors intercepted rather than recorded.
///
/// `tester.takeException()` cannot be used to inspect them: this screen produces
/// THREE layout errors in its failing windows (two button rows plus the body
/// column), and once a second error lands the binding collapses them into
/// "Multiple exceptions (3) were detected…", which says nothing about what they
/// were. Taking them at [FlutterError.onError] keeps each one, and the handler
/// is restored before any assertion runs.
Future<List<FlutterErrorDetails>> _pumpCatchingErrors(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await _pumpFresh(tester, preview, locale: locale);
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

/// How many pixels the BODY column overflowed by, or 0 when nothing did.
///
/// Filtered to the vertical overflow on purpose: the horizontal ones come from
/// the button rows (a separate finding, measured separately below) and would
/// otherwise mask a body that had been fixed.
int _bottomOverflow(List<FlutterErrorDetails> caught) {
  for (final FlutterErrorDetails details in caught) {
    final String message = '${details.exception}';
    if (!message.contains('on the bottom')) continue;
    final RegExpMatch? match =
        RegExp(r'overflowed by ([\d.]+) pixels').firstMatch(message);
    if (match != null) return double.parse(match.group(1)!).round();
  }
  return 0;
}

void main() {
  setUpAll(loadPreviewArbs);

  setUp(ClientUnreachableScreenPopLog.reset);

  // Only the two states that fit. `testPreviewsRender` asserts no exception,
  // and every other preview overflows on purpose — see `layout ceiling` below.
  // The excluded three are pinned by caption in `every preview is pinned by its
  // own caption`, so no state goes unpinned.
  testPreviewsRender(
    'ClientUnreachableScreen',
    const <String, Widget Function()>{
      'Phone · from live tracking': clientUnreachableScreenPhone,
      'Cold arrival · nothing to pop': clientUnreachableScreenColdArrival,
    },
    // The caption is the ONLY thing that differs between these two: same title,
    // same paragraph, same buttons, same (English) copy in both locales, and an
    // id that is never drawn. Nothing inside the frame can pin a state.
    expectedText: <String, String>{
      'Phone · from live tracking': ClientUnreachableScreenFixtures.phone.label,
      'Cold arrival · nothing to pop':
          ClientUnreachableScreenFixtures.coldArrival.label,
    },
  );

  group('ClientUnreachableScreen preview specifics', () {
    testWidgets('every preview is pinned by its own caption', (
      WidgetTester tester,
    ) async {
      // Including the three that overflow, which `testPreviewsRender` cannot
      // carry. Without this, a preview rewired to the wrong fixture would look
      // exactly like the right one — the frames are identical.
      for (final MapEntry<Widget Function(), String> entry
          in _previewCaptions.entries) {
        await _pumpCatchingErrors(tester, entry.key);
        expect(find.text(entry.value), findsOneWidget);
        for (final String other in _previewCaptions.values) {
          if (other == entry.value) continue;
          expect(find.text(other), findsNothing);
        }
      }
    });

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the geometry
      // measurements below would be asserting nothing.
      await _pumpCatchingErrors(tester, clientUnreachableScreenPhone);
      expect(_frame(tester).size, _phoneFrame);

      await _pumpCatchingErrors(tester, clientUnreachableScreenCompact);
      expect(_frame(tester).size, _compactFrame);

      await _pumpCatchingErrors(tester, clientUnreachableScreenCompactLargeText);
      expect(_frame(tester).size, _compactFrame);
    });

    testWidgets('only the 200% windows are scaled', (WidgetTester tester) async {
      // `ClientUnreachableScreenWindow.textScale` is nullable on purpose: a
      // window that pinned 1.0 would overwrite the `matrix: true` 200% card on
      // `Phone` and label a 100% rendering "EN 200% text".
      Future<double> scale(Widget Function() preview) async {
        await _pumpCatchingErrors(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(ClientUnreachableScreen)),
        ).scale(10);
      }

      expect(await scale(clientUnreachableScreenPhone), 10);
      expect(await scale(clientUnreachableScreenColdArrival), 10);
      expect(await scale(clientUnreachableScreenCompact), 10);
      expect(await scale(clientUnreachableScreenLargeText), 20);
      expect(await scale(clientUnreachableScreenCompactLargeText), 20);
    });

    testWidgets('FINDING — the screen is not localized, at all', (
      WidgetTester tester,
    ) async {
      // There is no `AppLocalizations` lookup anywhere in the file: every
      // string is an English literal. Pumped in Arabic, the surface mirrors and
      // the words do not move. Every other previewed screen in this app has an
      // ARB key per string.
      await _pumpFresh(tester, clientUnreachableScreenPhone,
          locale: const Locale('ar'));

      expect(
        Directionality.of(tester.element(find.byType(ClientUnreachableScreen))),
        TextDirection.rtl,
        reason: 'the layout does mirror — it is only the copy that does not',
      );
      for (final String english in const <String>[
        _title,
        _noticeTitle,
        _callCta,
        _chatCta,
        _flagCta,
      ]) {
        expect(
          find.text(english),
          findsOneWidget,
          reason: 'raw English is still on screen in the AR locale',
        );
      }
    });

    testWidgets('FINDING — the required deliveryId is never drawn', (
      WidgetTester tester,
    ) async {
      // `deliveryId` is a required constructor parameter that `build` never
      // reads, so `Cold arrival` — handed a real 36-character id — is
      // pixel-identical to `Phone`, which is handed the catalog demo id. A
      // jeeber about to flag a delivery has nothing on screen to check it
      // against, and the flag reports only `true`, never WHICH delivery.
      await _pumpFresh(tester, clientUnreachableScreenColdArrival);

      expect(
        find.textContaining(ClientUnreachableScreenDeliveryIds.route),
        findsNothing,
      );
      expect(find.textContaining('b7d1a4c8'), findsNothing);
      // And the id it was NOT handed is equally absent — i.e. the two states
      // really are indistinguishable from inside the frame.
      expect(
        find.textContaining(ClientUnreachableScreenDeliveryIds.catalog),
        findsNothing,
      );
    });

    testWidgets('FINDING — two of the three buttons do nothing', (
      WidgetTester tester,
    ) async {
      // "Try Calling Again" and "Send Chat Message" are `onTap: () {}` literals
      // in the shipped source, not callbacks a preview forgot to wire. They
      // look, hover and press exactly like the one button that works.
      await _pumpFresh(tester, clientUnreachableScreenPhone);

      for (final String label in const <String>[_callCta, _chatCta]) {
        await tester.ensureVisible(_button(label));
        await tester.pumpAndSettle();
        await tester.tap(_button(label));
        await tester.pumpAndSettle();
      }

      expect(find.byType(ClientUnreachableScreen), findsOneWidget);
      expect(find.text(clientUnreachableScreenParentLabel), findsNothing);
      expect(
        ClientUnreachableScreenPopLog.results,
        isEmpty,
        reason: 'nothing observable happened — the handlers are empty blocks',
      );
    });

    testWidgets('the flag CTA pops `true` back to the caller', (
      WidgetTester tester,
    ) async {
      // The screen's ENTIRE output. It takes no callbacks, writes to no cubit
      // and calls no repository, so the boolean it hands back is the only thing
      // a caller can observe.
      await _pumpFresh(tester, clientUnreachableScreenPhone);

      await tester.ensureVisible(_button(_flagCta));
      await tester.pumpAndSettle();
      await tester.tap(_button(_flagCta));
      await tester.pumpAndSettle();

      expect(ClientUnreachableScreenPopLog.results, <Object?>[true]);
      expect(find.byType(ClientUnreachableScreen), findsNothing);
      expect(find.text(clientUnreachableScreenParentLabel), findsOneWidget);
    });

    testWidgets('FINDING — a cold arrival has no back arrow at all', (
      WidgetTester tester,
    ) async {
      // `OMDSAppBar` is constructed without `showBackButton`, which DEFAULTS TO
      // FALSE, and passes `automaticallyImplyLeading: true` through to
      // Material's AppBar — so the arrow exists only when the enclosing route
      // can be popped. Reached from live tracking there is one; arrived at by a
      // stack-replacing navigation there is not.
      await _pumpFresh(tester, clientUnreachableScreenColdArrival);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      // The contrast: the same pixels, one page deeper on the stack.
      await _pumpFresh(tester, clientUnreachableScreenPhone);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('FINDING — on a cold arrival the flag CTA empties the navigator',
        (WidgetTester tester) async {
      // `Navigator.of(context).pop(true)` assumes something is underneath it.
      // On a stack-replacing arrival there is nothing, so the one working
      // button on the screen removes the only route and leaves a blank surface
      // — and the `true` it reports has no caller to receive it.
      await _pumpFresh(tester, clientUnreachableScreenColdArrival);

      await tester.ensureVisible(_button(_flagCta));
      await tester.pumpAndSettle();
      await tester.tap(_button(_flagCta));
      await tester.pumpAndSettle();

      expect(find.byType(ClientUnreachableScreen), findsNothing);
      expect(find.text(_flagCta), findsNothing);
      expect(
        find.text(clientUnreachableScreenParentLabel),
        findsNothing,
        reason: 'there was never anything underneath — this is a blank surface, '
            'not a return',
      );
    });
  });

  // What the pinned device frames exposed that a bare 800 × 600 pump hides.
  group('ClientUnreachableScreen layout ceiling', () {
    testWidgets('the body never scrolls — there is no viewport inside it', (
      WidgetTester tester,
    ) async {
      // Everything below rests on this: `Scaffold > Padding > Column` with a
      // `Spacer` and nothing scrollable in the chain, so content that does not
      // fit is laid out off the display rather than reachable by a gesture. The
      // only Scrollables in the tree are the fixture's own two, outside the
      // screen.
      await _pumpFresh(tester, clientUnreachableScreenPhone);

      expect(
        find.descendant(
          of: find.byType(ClientUnreachableScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'on the reference phone at 100% everything fits, in both locales '
        '(control) (${locale.languageCode})',
        (WidgetTester tester) async {
          // The reason the states below went unnoticed: on 390 × 844 at default
          // text this screen is exactly as simple as it looks — the `Spacer`
          // absorbs whatever the notice paragraph costs, and the flag CTA
          // clears the edge (measured y 812–860 against an edge at y 876).
          //
          // Both locales, because the copy is the same English in both. There
          // is no shorter translation to be saved by, which is why every other
          // measurement in this group holds identically in AR.
          final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
            tester,
            clientUnreachableScreenPhone,
            locale: locale,
          );

          expect(caught, isEmpty);
          expect(
            tester.getRect(_button(_flagCta)).bottom,
            lessThan(_frame(tester).bottom),
          );
        },
      );
    }

    testWidgets(
      'FINDING — on the smallest supported phone the flag CTA is cut off at '
      'DEFAULT text',
      (WidgetTester tester) async {
        // 320 × 568, text scale 1.0 — no accessibility setting involved. The
        // `Spacer` has already collapsed to zero and the body column overflows,
        // leaving the flag CTA straddling the bottom edge: measured y 572–620
        // against an edge at y 600, i.e. the lower half of the only working
        // button is off the display and nothing scrolls it back.
        //
        // The margin here is the one number the test font really does inflate
        // (the wrapped paragraph in the notice card is roughly twice as tall as
        // Inter renders it), so treat 320 pt as the BOUNDARY rather than as a
        // guaranteed break on a device — the reference phone has only 16 pt of
        // slack at 100%, and this window is 276 pt shorter.
        final List<FlutterErrorDetails> caught =
            await _pumpCatchingErrors(tester, clientUnreachableScreenCompact);

        expect(_bottomOverflow(caught), greaterThan(0));
        final Rect flag = tester.getRect(_button(_flagCta));
        expect(flag.top, lessThan(_frame(tester).bottom));
        expect(
          flag.bottom,
          greaterThan(_frame(tester).bottom),
          reason: 'straddling the edge — visible, tappable, and truncated',
        );
      },
    );

    testWidgets(
      'FINDING — at 200% text on an ORDINARY phone the flag CTA is below the '
      'viewport',
      (WidgetTester tester) async {
        // Not just the smallest display: 390 × 844, the reference device. The
        // `Spacer` collapses to zero and then the fixed children overflow by a
        // measured 236 px, putting the CTA at y 1048–1096 against an edge at
        // y 876. What is cut is the only button on the screen that does
        // anything, and no gesture brings it back.
        final List<FlutterErrorDetails> caught =
            await _pumpCatchingErrors(tester, clientUnreachableScreenLargeText);

        expect(
          _bottomOverflow(caught),
          greaterThan(0),
          reason: 'if this stops overflowing the screen was fixed — replace '
              'this test with the fits-everywhere assertion above',
        );
        expect(
          tester.getRect(_button(_flagCta)).top,
          greaterThan(_frame(tester).bottom),
          reason: 'the flag CTA is the only working affordance on this screen',
        );
      },
    );

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'FINDING — on the smallest phone at 200% there is NO working '
        'affordance left (${locale.languageCode})',
        (WidgetTester tester) async {
          // The worst case the app supports, and one a stack-replacing arrival
          // can really produce: 320 × 568 at the accessibility ceiling. The
          // body overflows by a measured 800 px, putting the flag CTA at
          // y 1336 against an edge at y 600 — and there is no back arrow,
          // because nothing can be popped. What is left on the surface is the
          // two buttons wired to `onTap: () {}`.
          final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
            tester,
            clientUnreachableScreenCompactLargeText,
            locale: locale,
          );

          expect(_bottomOverflow(caught), greaterThan(0));
          expect(
            tester.getRect(_button(_flagCta)).top,
            greaterThan(_frame(tester).bottom),
          );
          expect(find.byIcon(Icons.arrow_back), findsNothing);
          // The survivors are the dead ones.
          expect(_button(_callCta), findsOneWidget);
          expect(_button(_chatCta), findsOneWidget);
        },
      );
    }

    testWidgets(
      'FINDING — the CTA labels are painted OUTSIDE their own pill rather than '
      'wrapped',
      (WidgetTester tester) async {
        // Independent of the vertical overflow above, and it bites on the two
        // buttons that are still on screen when the flag CTA is not.
        // `OmdsPrimaryButton` centres a `Row(mainAxisSize: min)` of icon +
        // UNCONSTRAINED `Text` inside a fixed 48 pt pill, so a label wider than
        // the pill neither wraps nor ellipsizes — it is laid out past the edge.
        // Measured on the reference phone: the "Try Calling Again" paragraph is
        // 478 pt wide inside a 358 pt button at 200%, and the row reports 187 px
        // of horizontal overflow. Halve those for Inter and the label still does
        // not fit.
        await _pumpCatchingErrors(tester, clientUnreachableScreenPhone);
        final double pill = tester.getSize(_button(_callCta)).width;
        final RenderParagraph atDefault =
            tester.renderObject<RenderParagraph>(find.text(_callCta));
        expect(
          atDefault.size.width,
          lessThan(pill),
          reason: 'at 100% on a 390 pt phone the label fits, which is why this '
              'is invisible until someone raises the text size',
        );

        await _pumpCatchingErrors(tester, clientUnreachableScreenLargeText);
        expect(
          tester.getSize(_button(_callCta)).height,
          48,
          reason: 'the pill never grows with the text scale',
        );
        final RenderParagraph scaled =
            tester.renderObject<RenderParagraph>(find.text(_callCta));
        expect(
          scaled.size.width,
          greaterThan(tester.getSize(_button(_callCta)).width),
          reason: 'the label is wider than the entire button it sits in',
        );
        expect(
          scaled.size.height,
          lessThan(48),
          reason: 'and it stayed on ONE line — it was never given the chance '
              'to wrap into the space it needed',
        );
      },
    );
  });

  // The previews and the Screen Catalog now read one fixture file. This group
  // is what stops that claim from quietly becoming false: the catalog is a
  // designer-facing tool, nothing else in `test/devtool/` renders THIS entry,
  // and the catalog path through the shared host (`window: null`,
  // `parentOnStack: null`) is the one branch no preview exercises.
  group('the extracted fixtures still drive the Screen Catalog', () {
    testWidgets('the cataloged state renders, bare, on the shared id', (
      WidgetTester tester,
    ) async {
      final CatalogEntry entry = kScreenCatalog.singleWhere(
        (CatalogEntry e) => e.feature == 'client_unreachable',
      );
      final CatalogState state = entry.states.single;
      expect(
        state.label,
        ClientUnreachableScreenFixtures.catalogDefault.label,
        reason: 'the label a designer signs off against comes from the fixture',
      );

      await tester.pumpWidget(
        previewCanvas(() => Builder(builder: state.builder), const Locale('en')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ClientUnreachableScreen), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_noticeTitle), findsOneWidget);
      expect(_button(_flagCta), findsOneWidget);
      // `window: null` — no simulated frame and no caption strip. On a device
      // the device IS the frame, which is how this entry has always rendered.
      expect(
        find.text(ClientUnreachableScreenFixtures.catalogDefault.label),
        findsNothing,
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      // `parentOnStack: null` — no local Navigator, so the catalog's own route
      // (and its close button) stay in charge of getting back.
      expect(find.text(clientUnreachableScreenParentLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
