// Render tests for the KycStatusScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// KycStatusScreen renders the SAME icon and the SAME two sentences in every
// state — it has no data axis at all — so "did it render" is a weak question
// here: all five previews would pass a render-only check while showing
// identical content. The suite therefore does two extra jobs. The expected
// strings pin WHICH window each preview simulates (the caption the fixture host
// paints), and the group below measures what the screen actually did inside
// that window. Those measurements are the only contract this screen has.
//
// One caveat on the overflow numbers. `flutter test` substitutes the
// `FlutterTest` font, whose glyphs are squares of the font size and therefore
// considerably wider than Inter's, so English wraps more often here than on a
// device and the *threshold* at which the column stops fitting is more
// pessimistic than a phone would show. The claims the suite leans on are the
// font-INDEPENDENT ones: the screen contains no scrollable at all, and its
// 100 pt icon does not follow the text scaler, so whenever the composition does
// not fit there is nothing that can absorb the shortfall — it is clipped, and
// the clipped part is unreachable.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/kyc_status_screen_fixtures.dart';
import 'package:jeeb_mobile/features/deep_link_targets/kyc_status_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _notchedFrame = Size(393, 852);

/// `OmdsEmptyStatePage.iconSize` default — a fixed logical size, not a scaled
/// one.
const double _iconSize = 100;

/// The two sentences the screen hardcodes, as string literals rather than ARB
/// lookups.
const String _title = 'KYC Status coming soon';
const String _subtitle = 'This screen is not yet available.';

void main() {
  setUpAll(loadPreviewArbs);

  // `Compact · 200% text` is deliberately NOT in this map. It overflows by
  // design-defect (see "the smallest phone at 200% clips" below), and
  // `testPreviewsRender` asserts `takeException() is null` for every state it is
  // given. Rather than weaken that assertion for the other four, the fifth
  // preview gets its own pair of tests further down which pump it in BOTH
  // locales, pin its caption the way `expectedText` would, and assert the
  // overflow instead of tolerating it.
  testPreviewsRender(
    'KycStatusScreen',
    const <String, Widget Function()>{
      'Phone 390 × 844': kycStatusScreenPhone,
      'Compact 320 × 568': kycStatusScreenCompact,
      'Phone · 200% text': kycStatusScreenPhoneLargeText,
      'Notched · 200% text': kycStatusScreenNotchedLargeText,
    },
    // Every state names its own window. The screen shows the same icon and the
    // same two sentences in all five, so without this a preview wired to the
    // wrong window — or five previews accidentally sharing one — would pass
    // unnoticed.
    expectedText: const <String, String>{
      'Phone 390 × 844': 'Phone · 390 × 844 · 100% text',
      'Compact 320 × 568': 'Compact · 320 × 568 · 100% text',
      'Phone · 200% text': 'Phone · 390 × 844 · 200% text',
      'Notched · 200% text': 'Notched · 393 × 852 · inset 59/34 · 200% text',
    },
  );

  group('KycStatusScreen preview specifics', () {
    test('every window the fixture publishes has a preview above', () {
      // `KycStatusScreenWindows.all` is what the Screen Catalog enumerates, so
      // a window added there without a matching `@JeebPreview` would silently
      // exist for the designer and not for the engineer. That is exactly the
      // drift the shared fixture file exists to prevent, so it is asserted
      // rather than trusted.
      expect(
        KycStatusScreenWindows.all
            .map((KycStatusScreenWindow w) => w.label)
            .toList(),
        <String>[
          'Phone · 390 × 844 · 100% text',
          'Compact · 320 × 568 · 100% text',
          'Phone · 390 × 844 · 200% text',
          'Compact · 320 × 568 · 200% text',
          'Notched · 393 × 852 · inset 59/34 · 200% text',
        ],
      );
      expect(
        KycStatusScreenWindows.all
            .map((KycStatusScreenWindow w) => w.size)
            .toList(),
        <Size>[
          _phoneFrame,
          _compactFrame,
          _phoneFrame,
          _compactFrame,
          _notchedFrame,
        ],
      );
    });

    /// Pumps [preview] and returns the rect of the screen inside its simulated
    /// window, draining any layout exception so the caller decides what to do
    /// with it.
    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(tester, preview, locale: locale);
      final Rect rect = tester.getRect(find.byType(KycStatusScreen));
      tester.takeException();
      return rect;
    }

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the rest of this group
      // would be asserting nothing.
      expect(
        (await frameRect(tester, kycStatusScreenPhone)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenCompact)).size,
        _compactFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenPhoneLargeText)).size,
        _phoneFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenCompactLargeText)).size,
        _compactFrame,
      );
      expect(
        (await frameRect(tester, kycStatusScreenNotchedLargeText)).size,
        _notchedFrame,
      );
    });

    testWidgets('the 200% windows really are scaled and the rest are not', (
      WidgetTester tester,
    ) async {
      // `KycStatusScreenWindow.textScale` is nullable on purpose: a window that
      // pinned 1.0 would overwrite the `matrix: true` 200% card and label a
      // 100% rendering "EN 200% text". This pins both halves of that.
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        final double s = MediaQuery.textScalerOf(
          tester.element(find.byType(KycStatusScreen)),
        ).scale(10);
        tester.takeException();
        return s;
      }

      expect(await scale(kycStatusScreenPhone), 10);
      expect(await scale(kycStatusScreenCompact), 10);
      expect(await scale(kycStatusScreenPhoneLargeText), 20);
      expect(await scale(kycStatusScreenCompactLargeText), 20);
      expect(await scale(kycStatusScreenNotchedLargeText), 20);
    });

    testWidgets('the screen contains no scrollable of any kind', (
      WidgetTester tester,
    ) async {
      // The structural half of the clipping defect, and the half that does not
      // depend on the test font. `OmdsEmptyStatePage` is
      // `Scaffold(body: Center(child: OmdsEmptyState(...)))` and
      // `OmdsEmptyState` is a bare `Column(mainAxisSize: min)` — no ListView,
      // no SingleChildScrollView. Whatever does not fit is not merely below the
      // fold, it is unreachable.
      //
      // The fixture host's own two SingleChildScrollViews sit ABOVE the screen,
      // which is why this is scoped to descendants of KycStatusScreen.
      await pumpPreview(tester, kycStatusScreenPhone);

      expect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      // The screen brings its own Scaffold (OmdsEmptyStatePage returns one), so
      // `jeebPreviewHost`'s wrapper Scaffold nests around a second one. Recorded
      // because the canvas shows the doubled surface and it looks like a bug.
      expect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Scaffold),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the 100 pt icon does not follow the text scaler', (
      WidgetTester tester,
    ) async {
      // The other font-independent half. `OmdsEmptyStatePage` passes a fixed
      // `iconSize` of 100, so at the accessibility ceiling the text doubles
      // around an illustration that stays exactly as tall — the column can only
      // grow, never rebalance.
      await pumpPreview(tester, kycStatusScreenPhone);
      final Size atDefault =
          tester.getSize(find.byIcon(Icons.construction_outlined));

      await pumpPreview(tester, kycStatusScreenPhoneLargeText);
      final Size atCeiling =
          tester.getSize(find.byIcon(Icons.construction_outlined));

      expect(atDefault, const Size(_iconSize, _iconSize));
      expect(
        atCeiling,
        atDefault,
        reason: 'the icon is a fixed 100 pt: it claims the same share of a '
            '568 pt display whether the user reads at 100% or at 200%',
      );
    });

    testWidgets('on a 390 × 844 phone the whole composition fits', (
      WidgetTester tester,
    ) async {
      // The reference reading, and the reason the state below went unnoticed:
      // in the one window everybody reviews, this screen is exactly as simple
      // as it looks.
      final Rect frame = await frameRect(tester, kycStatusScreenPhone);
      final Rect column = tester.getRect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Column),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(column.top, greaterThanOrEqualTo(frame.top));
      expect(column.bottom, lessThanOrEqualTo(frame.bottom));
    });

    testWidgets('a notched phone at 200% still clears the system chrome', (
      WidgetTester tester,
    ) async {
      // `appBar: null` means nothing consumes the 59 pt status bar, and
      // `Scaffold` does not SafeArea its body, so the only thing keeping this
      // screen out from under the notch is that its content is centred and
      // short. Asserted rather than assumed — it stops being true the moment
      // someone gives the placeholder a third line or a CTA.
      final Rect frame = await frameRect(
        tester,
        kycStatusScreenNotchedLargeText,
      );
      final Rect column = tester.getRect(
        find.descendant(
          of: find.byType(KycStatusScreen),
          matching: find.byType(Column),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        column.top - frame.top,
        greaterThan(59),
        reason: 'top inset (status bar) is not consumed by anything',
      );
      expect(
        frame.bottom - column.bottom,
        greaterThan(34),
        reason: 'bottom inset (home indicator) is not consumed by anything',
      );
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'the smallest phone at 200% clips, in ${locale.languageCode}',
        (WidgetTester tester) async {
          // The state that breaks, and the reason `Compact · 200% text` is kept
          // out of `testPreviewsRender` above. The centred column asks for more
          // height than the padded window has; with no scrollable and no icon
          // that can give way, the ends of the composition are cut off and the
          // user has no gesture that would bring them back.
          //
          // Both locales, because the copy is identical in both (it is
          // hardcoded English) and the padding is symmetric, so the defect is
          // locale-independent — asserted rather than assumed, since "it is
          // only an English problem" is the usual first guess.
          await pumpPreview(
            tester,
            kycStatusScreenCompactLargeText,
            locale: locale,
          );

          // Pins WHICH window this preview simulates, the same job
          // `expectedText` does for the other four states.
          expect(find.text('Compact · 320 × 568 · 200% text'), findsOneWidget);
          expect(
            tester.takeException().toString(),
            contains('overflowed'),
            reason: 'a Column(mainAxisSize: min) inside a Center, with a fixed '
                '100 pt icon above two wrapping paragraphs, on a 320 × 568 '
                'display at the 200% accessibility ceiling',
          );
        },
      );
    }

    testWidgets('the copy is hardcoded English, so Arabic renders English', (
      WidgetTester tester,
    ) async {
      // Both sentences are string literals in `build`, not `AppLocalizations`
      // lookups, so the AR RTL card of the `Phone 390 × 844` matrix shows
      // English inside a right-to-left layout. If this test starts failing,
      // someone localized the screen — delete it, that is the fix.
      await pumpPreview(
        tester,
        kycStatusScreenPhone,
        locale: const Locale('ar'),
      );

      expect(
        Directionality.of(tester.element(find.byType(KycStatusScreen))),
        TextDirection.rtl,
      );
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_subtitle), findsOneWidget);
    });

    testWidgets('the Semantics wrapper announces the copy twice', (
      WidgetTester tester,
    ) async {
      // `Semantics(container: true, label: 'KYC Status coming soon. This screen
      // is not yet available.')` wraps a subtree that already publishes both
      // sentences as Text, and does not set `explicitChildNodes`, so the
      // wrapper's label and the two Texts MERGE into a single node. A screen
      // reader reads the pair, then reads it again.
      // Disposed inline rather than via `addTearDown`: the framework's
      // end-of-test verification runs BEFORE tear-downs and fails on a live
      // handle.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, kycStatusScreenPhone);

      // One node covers the whole screen — the wrapper's label and both Texts
      // collapsed into it — so asking for the title's node returns the merged
      // announcement.
      final SemanticsNode node = tester.getSemantics(find.text(_title));
      final String label = node.label;

      expect(
        _occurrences(label, _title),
        2,
        reason: 'merged label was: $label',
      );
      expect(_occurrences(label, _subtitle), 2);

      handle.dispose();
    });
  });
}

int _occurrences(String haystack, String needle) =>
    needle.isEmpty ? 0 : haystack.split(needle).length - 1;
