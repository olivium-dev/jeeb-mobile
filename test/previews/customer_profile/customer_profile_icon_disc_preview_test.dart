// Render tests for the CustomerProfileIconDisc previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// The disc renders no text, so `expectedText` pins each specimen's caption.
// That is not a formality here: six navy circles are the easiest possible case
// for a preview file to render the same state six times and still pass.
//
// The specifics below pin the PREMISE of each specimen (the disc is 32dp, the
// dark specimen really is dark, the disc passes its glyph through untouched) —
// never the defects those specimens exist to show. Fixing the dark-scheme
// contrast or mirroring the sign-out glyph must not turn this file red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_icon_disc.dart';
import 'package:jeeb_mobile/previews/customer_profile/customer_profile_icon_disc_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerProfileIconDisc',
    const <String, Widget Function()>{
      'Password row · lock': customerProfileIconDiscLock,
      'Widest glyph · scooter': customerProfileIconDiscScooter,
      'All 8 production glyphs': customerProfileIconDiscProductionSet,
      'Sign-out glyph · no mirroring': customerProfileIconDiscLogout,
      'Dark scheme · glyph vanishes': customerProfileIconDiscOnDarkSurface,
      'Beside its row label': customerProfileIconDiscBesideLabel,
    },
    expectedText: const <String, String>{
      'Password row · lock': 'Password row · lock',
      'Widest glyph · scooter': 'Widest glyph · scooter',
      'All 8 production glyphs': 'All 8 production glyphs',
      'Sign-out glyph · no mirroring': 'Sign-out glyph · no mirroring',
      'Dark scheme · glyph vanishes': 'Dark scheme · glyph vanishes',
      'Beside its row label': 'Beside its row label',
    },
  );

  group('CustomerProfileIconDisc preview specifics', () {
    IconData glyphIn(WidgetTester tester, Finder disc) => tester
        .widget<Icon>(find.descendant(of: disc, matching: find.byType(Icon)))
        .icon!;

    testWidgets('each single-disc specimen shows exactly one disc', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in <Widget Function()>[
        customerProfileIconDiscLock,
        customerProfileIconDiscScooter,
        customerProfileIconDiscLogout,
        customerProfileIconDiscBesideLabel,
      ]) {
        await pumpPreview(tester, preview);
        expect(find.byType(CustomerProfileIconDisc), findsOneWidget);
      }
    });

    // The whole point of the set specimen is seeing all eight together; if a
    // glyph is dropped the canvas still looks plausible.
    testWidgets('the set specimen shows all 8 production glyphs', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileIconDiscProductionSet);

      expect(find.byType(CustomerProfileIconDisc), findsNWidgets(8));
      for (final IconData glyph in <IconData>[
        Icons.delivery_dining_outlined,
        Icons.lock_outline,
        Icons.notifications_none,
        Icons.language_outlined,
        Icons.location_on_outlined,
        Icons.call_outlined,
        Icons.star_outline,
        Icons.logout_outlined,
      ]) {
        expect(find.byIcon(glyph), findsOneWidget);
      }
    });

    // Each specimen must show ITS OWN glyph — the captions differ, so a
    // copy-paste slip that left every sample on `lock_outline` would sail
    // through `expectedText` alone.
    testWidgets('each specimen carries the glyph its caption names', (
      WidgetTester tester,
    ) async {
      final Finder disc = find.byType(CustomerProfileIconDisc);

      await pumpPreview(tester, customerProfileIconDiscLock);
      expect(glyphIn(tester, disc), Icons.lock_outline);

      await pumpPreview(tester, customerProfileIconDiscScooter);
      expect(glyphIn(tester, disc), Icons.delivery_dining_outlined);

      await pumpPreview(tester, customerProfileIconDiscLogout);
      expect(glyphIn(tester, disc), Icons.logout_outlined);
    });

    // Design §5: a 32dp disc around a 20dp glyph. The specimens are only
    // readable as specimens if that geometry holds.
    testWidgets('the disc is 32dp with a 20dp glyph', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileIconDiscLock);

      final Finder disc = find.byType(CustomerProfileIconDisc);
      expect(
        tester.getSize(disc),
        const Size(Sizes.twoXLarge, Sizes.twoXLarge),
      );
      expect(
        tester
            .widget<Icon>(
              find.descendant(of: disc, matching: find.byType(Icon)),
            )
            .size,
        Sizes.large,
      );
    });

    // The disc takes its fill from the theme rather than a literal — the half
    // of the class doc's "both from the theme (no literals)" claim that is not
    // the thing the dark specimen is complaining about.
    testWidgets('the fill comes from colorScheme.secondaryContainer', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileIconDiscLock);

      final BuildContext context = tester.element(
        find.byType(CustomerProfileIconDisc),
      );
      final Container container = tester.widget<Container>(
        find.descendant(
          of: find.byType(CustomerProfileIconDisc),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;

      expect(decoration.shape, BoxShape.circle);
      expect(
        decoration.color,
        Theme.of(context).colorScheme.secondaryContainer,
      );
    });

    // The contrast specimen means nothing unless the sample really renders
    // under the dark scheme, whatever brightness the canvas cell is using.
    testWidgets('the contrast specimen forces the dark scheme', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileIconDiscOnDarkSurface);

      final BuildContext context = tester.element(
        find.byType(CustomerProfileIconDisc),
      );
      expect(Theme.of(context).brightness, Brightness.dark);
    });

    // The mirroring specimen's premise: the disc is a pass-through. It adds no
    // Transform and no `matchTextDirection` of its own, so whatever the sign-out
    // glyph does under RTL is decided by the IconData the caller picked — which
    // is where the fix belongs (`customer_profile_rows.dart`), not here.
    testWidgets('the disc passes its IconData through untouched in RTL', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        customerProfileIconDiscLogout,
        locale: const Locale('ar'),
      );

      final Finder disc = find.byType(CustomerProfileIconDisc);
      final BuildContext context = tester.element(disc);
      expect(Directionality.of(context), TextDirection.rtl);
      expect(glyphIn(tester, disc), Icons.logout_outlined);
    });

    // The row-label specimen exists to be read at 200% text, and it only
    // carries meaning if the label is the real localized string.
    testWidgets('the row-label specimen localizes its label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, customerProfileIconDiscBesideLabel);
      expect(find.text('Password and security'), findsOneWidget);

      await pumpPreview(
        tester,
        customerProfileIconDiscBesideLabel,
        locale: const Locale('ar'),
      );
      expect(find.text('كلمة المرور والأمان'), findsOneWidget);
    });
  });
}
