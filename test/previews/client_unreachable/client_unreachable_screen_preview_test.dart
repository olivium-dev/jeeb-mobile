// Render tests for the ClientUnreachableScreen previews.

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
const String _title = 'Client Unreachable';
const String _noticeTitle = 'Cannot reach the Client';
const String _callCta = 'Try Calling Again';
const String _chatCta = 'Send Chat Message';
const String _flagCta = 'Flag as Unreachable';

/// Every preview, with the caption its fixture paints above the frame.
/// One map rather than several, because the caption is the ONLY thing that
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
/// Two previews cannot simply be pumped one after the other: the canvas wrapper
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
/// `tester.takeException()` cannot be used to inspect them: this screen produces
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
/// Filtered to the vertical overflow on purpose: the horizontal ones come from
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
  testPreviewsRender(
    'ClientUnreachableScreen',
    const <String, Widget Function()>{
      'Phone · from live tracking': clientUnreachableScreenPhone,
      'Cold arrival · nothing to pop': clientUnreachableScreenColdArrival,
    },
    // The caption is the ONLY thing that differs between these two: same title,
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
      await _pumpCatchingErrors(tester, clientUnreachableScreenPhone);
      expect(_frame(tester).size, _phoneFrame);

      await _pumpCatchingErrors(tester, clientUnreachableScreenCompact);
      expect(_frame(tester).size, _compactFrame);

      await _pumpCatchingErrors(tester, clientUnreachableScreenCompactLargeText);
      expect(_frame(tester).size, _compactFrame);
    });

    testWidgets('only the 200% windows are scaled', (WidgetTester tester) async {
      // `ClientUnreachableScreenWindow.textScale` is nullable on purpose: a
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
      await _pumpFresh(tester, clientUnreachableScreenColdArrival);

      expect(
        find.textContaining(ClientUnreachableScreenDeliveryIds.route),
        findsNothing,
      );
      expect(find.textContaining('b7d1a4c8'), findsNothing);
      // And the id it was NOT handed is equally absent — i.e. the two states
      expect(
        find.textContaining(ClientUnreachableScreenDeliveryIds.catalog),
        findsNothing,
      );
    });

    testWidgets('FINDING — two of the three buttons do nothing', (
      WidgetTester tester,
    ) async {
      // "Try Calling Again" and "Send Chat Message" are `onTap: () {}` literals
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
      await _pumpFresh(tester, clientUnreachableScreenColdArrival);
      expect(find.byIcon(Icons.arrow_back), findsNothing);

      // The contrast: the same pixels, one page deeper on the stack.
      await _pumpFresh(tester, clientUnreachableScreenPhone);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('FINDING — on a cold arrival the flag CTA empties the navigator',
        (WidgetTester tester) async {
      // `Navigator.of(context).pop(true)` assumes something is underneath it.
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
      expect(
        find.text(ClientUnreachableScreenFixtures.catalogDefault.label),
        findsNothing,
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
      // `parentOnStack: null` — no local Navigator, so the catalog's own route
      expect(find.text(clientUnreachableScreenParentLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
