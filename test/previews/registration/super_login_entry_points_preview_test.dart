// Render tests for the SuperLoginEntryPoints previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// One deviation from that template, on purpose — the same one
// `jeeb_verified_badge_preview_test.dart` makes. The widget under review draws
// the SAME two strings in every state (its content is a function of the locale,
// not of any input), so the `expectedText` map below binds to each preview's
// caption, which is preview scaffolding rather than widget output. On its own
// that would be exactly the weak assertion the harness warns about. The real
// per-state contract is asserted underneath, against the three things this
// widget actually decides: the box each link offers a finger, the gap between
// the two, and where they land in each reading direction.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_entry_points.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Login footer (production placement)': superLoginEntryPointsLoginFooter,
  'Narrow column (160pt)': superLoginEntryPointsNarrowColumn,
  'Text scale 200%': superLoginEntryPointsLargeText,
  'Hit area vs the 48dp minimum': superLoginEntryPointsTapTargets,
  'Bare on surface (baseline)': superLoginEntryPointsBare,
};

/// The two links, by the keys the widget pins on them.
const Key _superLogin = Key('login.superLogin');
const Key _superLoginPlus = Key('login.superLoginPlus');

/// The English labels, straight out of `lib/l10n/app_en.arb`.
const String _enTitle = 'Super user login';
const String _enPlusTitle = 'Super user login plus';

/// The Arabic labels, straight out of `lib/l10n/app_ar.arb`.
const String _arTitle = 'تسجيل دخول المستخدم الخارق';
const String _arPlusTitle = 'تسجيل دخول المستخدم الخارق بلس';

/// Vertical distance between the bottom of the first link's hit box and the top
/// of the second's — i.e. what `Spacing.medium` actually buys.
double _gap(WidgetTester tester) {
  final Rect first = tester.getRect(find.byKey(_superLogin));
  final Rect second = tester.getRect(find.byKey(_superLoginPlus));
  return second.top - first.bottom;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SuperLoginEntryPoints',
    _previews,
    expectedText: const <String, String>{
      'Login footer (production placement)':
          'Login screen footer · under the CTA',
      'Narrow column (160pt)': 'Narrow column · 160pt',
      'Text scale 200%': 'Text scale 200% · gap stays 16pt',
      'Hit area vs the 48dp minimum': 'Hit area vs the 48dp minimum',
      'Bare on surface (baseline)': 'Bare widget on surface · baseline',
    },
  );

  group('SuperLoginEntryPoints preview specifics', () {
    testWidgets('every state renders BOTH links, not just the first', (
      WidgetTester tester,
    ) async {
      for (final MapEntry<String, Widget Function()> entry
          in _previews.entries) {
        await pumpPreview(tester, entry.value);

        expect(find.text(_enTitle), findsOneWidget, reason: entry.key);
        expect(find.text(_enPlusTitle), findsOneWidget, reason: entry.key);
      }
    });

    testWidgets('the labels are localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        superLoginEntryPointsBare,
        locale: const Locale('ar'),
      );

      expect(find.text(_arTitle), findsOneWidget);
      expect(find.text(_arPlusTitle), findsOneWidget);
      expect(find.text(_enTitle), findsNothing);
      expect(find.text(_enPlusTitle), findsNothing);
    });

    testWidgets('neither link reaches the 48dp minimum tap target', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, superLoginEntryPointsTapTargets);

      // The reference square drawn beside the links, so the comparison the
      // canvas makes visually is the one asserted here.
      expect(
        tester.getSize(
          find.byKey(const Key('superLoginEntryPoints.minTargetSquare')),
        ),
        const Size(48, 48),
      );

      for (final Key key in const <Key>[_superLogin, _superLoginPlus]) {
        final Size box = tester.getSize(find.byKey(key));
        // Each link is a bare GestureDetector around a `bodySmall` Text: no
        // padding, no InkWell, no MaterialTapTargetSize floor, and
        // `deferToChild` hit testing. The tappable region is the glyph box.
        expect(
          box.height,
          lessThan(48),
          reason: '$key now meets the 48dp minimum — if a Padding or an '
              'IconButton was added, delete this expectation and the note on '
              '`superLoginEntryPointsTapTargets`',
        );
        expect(
          box.height,
          greaterThan(0),
          reason: 'a zero-height target would be untappable, not merely small',
        );
      }
    });

    testWidgets('both links are hittable at their measured size', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, superLoginEntryPointsBare);

      // `tester.tap` hits the CENTRE of the finder's box, so this proves the
      // GestureDetector really is wired through the Semantics wrapper and the
      // preview's no-op callbacks — not that a finger would find it.
      await tester.tap(find.byKey(_superLogin));
      await tester.tap(find.byKey(_superLoginPlus));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the 16pt gap does NOT grow with text scale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, superLoginEntryPointsBare);
      final double gapAt100 = _gap(tester);
      final double linkAt100 = tester.getSize(find.byKey(_superLogin)).height;

      await pumpPreview(tester, superLoginEntryPointsLargeText);
      final double gapAt200 = _gap(tester);
      final double linkAt200 = tester.getSize(find.byKey(_superLogin)).height;

      // Sanity check that the pinned-200% state really is scaled.
      expect(
        linkAt200,
        greaterThan(linkAt100 * 1.5),
        reason: 'the 200% fixture is not scaling — MediaQuery override lost?',
      );
      // `Spacing.medium` is a fixed SizedBox, so the separation between two
      // targets that each doubled has not moved at all.
      expect(gapAt100, closeTo(16.0, 0.01));
      expect(
        gapAt200,
        closeTo(gapAt100, 0.01),
        reason: 'if the separator ever scales with text this will fail — that '
            'would be the fix, not a regression',
      );
      expect(
        gapAt200,
        lessThan(linkAt200),
        reason: 'at the accessibility ceiling the two links are closer '
            'together than either one is tall',
      );
    });

    testWidgets('the layout is direction-agnostic — nothing to mirror', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, superLoginEntryPointsBare);
      final double enCentre = tester.getCenter(find.byKey(_superLogin)).dx;
      final double enPlusCentre =
          tester.getCenter(find.byKey(_superLoginPlus)).dx;

      await pumpPreview(
        tester,
        superLoginEntryPointsBare,
        locale: const Locale('ar'),
      );

      // Every child is a Center, the separator is a symmetric SizedBox and
      // there is no EdgeInsets.only anywhere in the widget, so the RTL
      // rendering is the LTR one with different glyphs. Asserted rather than
      // assumed: it is what makes the AR card of the matrix a copy-length
      // review instead of a mirroring review.
      expect(tester.getCenter(find.byKey(_superLogin)).dx, closeTo(enCentre, 0.01));
      expect(
        tester.getCenter(find.byKey(_superLoginPlus)).dx,
        closeTo(enPlusCentre, 0.01),
      );
    });

    testWidgets('each link announces itself as a labelled button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, superLoginEntryPointsBare);

      final SemanticsNode primary = tester.getSemantics(find.byKey(_superLogin));
      expect(primary.label, contains(_enTitle));
      expect(primary.flagsCollection.isButton, isTrue);

      final SemanticsNode plus =
          tester.getSemantics(find.byKey(_superLoginPlus));
      expect(plus.label, contains(_enPlusTitle));
      expect(plus.flagsCollection.isButton, isTrue);

      handle.dispose();
    });

    testWidgets('the narrow column wraps the Arabic labels, not the English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, superLoginEntryPointsNarrowColumn);
      final double enHeight = tester.getSize(find.byKey(_superLoginPlus)).height;

      await pumpPreview(
        tester,
        superLoginEntryPointsNarrowColumn,
        locale: const Locale('ar'),
      );
      final double arHeight = tester.getSize(find.byKey(_superLoginPlus)).height;

      // 160pt holds "Super user login plus" on one line; it does not hold
      // "تسجيل دخول المستخدم الخارق بلس". Neither ellipsizes — Text with no
      // maxLines wraps — so the AR link is a taller block, and the state that
      // looks settled in EN light is the one to look at in AR.
      expect(
        arHeight,
        greaterThan(enHeight),
        reason: 'the narrow state must actually differ by locale, or it is one '
            'state rendered twice',
      );
    });
  });
}
