// Render tests for the ProfileAvatar previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The widget draws exactly one glyph, so THE GLYPH IS THE STATE: every fixture
// name was chosen to start with a different letter, and `expectedText` pins a
// distinct one per state. Two states sharing an initial could swap places
// unnoticed, which is the failure that map exists to catch.
//
// One deviation from the template, the same one `kyc_capture_tile_preview_test`
// makes. 'Stale local photo path' takes the `Image.file` branch and therefore
// renders NO text of its own — pinning it in `expectedText` is impossible
// rather than merely awkward. It is pinned negatively and then positively in
// the specifics group instead: it is the only state that mounts an `Image`, it
// is the only state with no `Text` at all, and once the failed file read lands
// it degrades to the same initial bubble as "no photo".
//
// The last two groups are not preview hygiene. They are what these previews
// exposed: the file branch has no loading placeholder where the network branch
// has one, so the avatar is a blank 96 dp hole for the whole read; and the
// initial's 36 dp `displaySmall` is fixed against a circle that is also fixed,
// which survives 200% text with 8 dp to spare and nothing more.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/presentation/widgets/profile_avatar.dart';
import 'package:jeeb_mobile/previews/settings/profile_avatar_preview.dart';

import '../preview_test_harness.dart';

/// `Sizes.tenXLarge`, the diameter every shipping call site takes.
const Size _kCircle = Size(96, 96);

/// The initial bubble's own [Container] — the one carrying the fill. It is the
/// innermost ancestor of the glyph, so `.first` is the right one.
BoxDecoration _bubble(WidgetTester tester, String glyph) {
  final Container box = tester.widget<Container>(
    find.ancestor(of: find.text(glyph), matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

/// WCAG contrast between the initial's ink and the circle it sits on, read off
/// the live render tree rather than off the palette constants — the point is
/// what this widget actually paints.
double _initialContrast(WidgetTester tester, String glyph) {
  final double ink = tester
      .widget<Text>(find.text(glyph))
      .style!
      .color!
      .computeLuminance();
  final double fill = _bubble(tester, glyph).color!.computeLuminance();
  final double lighter = ink > fill ? ink : fill;
  final double darker = ink > fill ? fill : ink;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Pumps [preview] and then lets REAL asynchronous work run until the widget
/// settles on something textual.
///
/// `Image.file` resolves through `dart:io`, and the fake-async zone a widget
/// test runs in never advances real IO — so under a plain `pumpPreview` the
/// failed read simply never happens and `errorBuilder` never fires. `runAsync`
/// hands the real event loop a turn; it takes two of them (one for the failed
/// `stat`, one for the error to reach the listener and rebuild), so this loops
/// rather than guessing a single delay.
Future<void> _pumpUntilIoSettles(
  WidgetTester tester,
  Widget Function() preview,
) async {
  // The preceding test pumped the same `FileImage` and left a PENDING entry in
  // the global image cache whose completion callbacks were registered in that
  // test's (now dead) fake-async zone — reusing it here would wait forever.
  imageCache.clear();
  imageCache.clearLiveImages();
  await tester.pumpWidget(previewCanvas(preview, const Locale('en')));
  for (int turn = 0; turn < 20; turn++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.byType(Text).evaluate().isNotEmpty) return;
  }
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ProfileAvatar',
    const <String, Widget Function()>{
      'Named, no photo': profileAvatarNamed,
      'No name yet': profileAvatarNoName,
      'Arabic name': profileAvatarArabicName,
      'Phone-only synthetic handle': profileAvatarSyntheticHandle,
      'Empty photo URL': profileAvatarEmptyPhotoUrl,
      'Stale local photo path': profileAvatarStaleLocalPath,
    },
    expectedText: const <String, String>{
      'Named, no photo': 'S',
      'No name yet': '?',
      // Lam — the first letter of 'ليلى حداد' as authored, uppercased to itself.
      'Arabic name': 'ل',
      'Phone-only synthetic handle': 'J',
      'Empty photo URL': 'Z',
      // 'Stale local photo path' renders no text; see the header note and the
      // two `Image.file` tests below.
    },
  );

  group('ProfileAvatar preview specifics', () {
    testWidgets('shows the uppercased initial and nothing else of the name', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);

      expect(find.text('S'), findsOneWidget);
      expect(find.textContaining('ami'), findsNothing);
    });

    testWidgets('an Arabic initial arrives as one whole grapheme', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarArabicName);

      // `_initial` takes `trimmed.characters.first` — a grapheme cluster — and
      // puts it straight into a Text. Contrast `OmdsProfileAvatar`, which
      // re-slices its initial with `initial[0]`, a UTF-16 code-unit index, and
      // loses the combining half of a decomposed letter
      // (`test/previews/rating/feedback_avatar_preview_test.dart`). If this
      // widget ever grows the same slice, this is the test that fails.
      expect(tester.widget<Text>(find.text('ل')).data, 'ل');
      expect(find.textContaining('حداد'), findsNothing);
    });

    testWidgets('a whitespace-only name falls back exactly like a null one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNoName);

      // `_initial` trims BEFORE testing for empty, so '   ' and null share this
      // rendering — the reason the 'No name yet' preview covers both.
      expect(find.text('?'), findsOneWidget);
    });

    // TRIPWIRE, not an endorsement. Jeeb mints `jeeb-<hash>` display names for
    // OTP-only signups. `ClientHomeGreeting` suppresses those via
    // `displayNameOrNull`; this widget has no such filter, so the avatar shows a
    // confident 'J' for a user whose name is unknown. If this test starts
    // failing, the suppression finally reached the avatar — expect '?'.
    testWidgets('a synthetic handle is rendered as a name, not suppressed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarSyntheticHandle);

      expect(find.text('J'), findsOneWidget);
      expect(find.text('?'), findsNothing);
    });

    testWidgets('an empty photoUrl takes the initial path, not an image path', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarEmptyPhotoUrl);

      // `build` short-circuits on `photoUrl!.isEmpty`. If that check is ever
      // dropped, '' is neither a local path nor a URL and this becomes the one
      // preview that reaches the network.
      expect(find.text('Z'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('ProfileAvatar local-file branch (JEBV4-13)', () {
    testWidgets('is the only state that mounts an Image, and it is textless', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarStaleLocalPath);

      // The negative pin that stands in for `expectedText` here: no other
      // preview in the set mounts an Image, and no other preview is textless,
      // so this state cannot be confused with any of them.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(ProfileAvatar)), _kCircle);

      // Textless is also the honest reading of what a user sees mid-read, and
      // that is an asymmetry in the widget rather than in this test. The
      // `OmdsCachedImage` branch is handed `placeholder: (_, _) => placeholder`,
      // so the network path shows the initial while it loads; the `Image.file`
      // branch passes only `errorBuilder` and no `frameBuilder`, so until the
      // decode succeeds OR fails there is nothing to paint — a blank 96 dp hole
      // where the avatar goes. Cheap on a warm read, visible on a cold one.
    });

    testWidgets('degrades to the initial bubble once the read fails', (
      WidgetTester tester,
    ) async {
      await _pumpUntilIoSettles(tester, profileAvatarStaleLocalPath);

      // An avatar whose stored path no longer resolves — the iOS app-container
      // UUID changes on reinstall — must land on the same bubble as "no photo",
      // never on a broken-image glyph or an exception.
      expect(find.text('K'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ProfileAvatar geometry and contrast', () {
    testWidgets('the initial scales with text size; the circle does not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);

      expect(tester.getSize(find.byType(ProfileAvatar)), _kCircle);
      expect(tester.widget<Text>(find.text('S')).style!.fontSize, 36.0);
      expect(tester.getSize(find.text('S')), const Size(36, 44));

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, profileAvatarNamed);

      // `displaySmall` has no `TextScaler` clamp and `diameter` has no scaler at
      // all, so at the accessibility ceiling an 88 dp line box sits in a 96 dp
      // circle that did not move: 4 dp of clearance top and bottom, and
      // `Container` sets no `clipBehavior` to catch it if that goes. The
      // headroom is arithmetic, not design — bump the type ramp one step and the
      // glyph paints onto the page background.
      expect(tester.getSize(find.byType(ProfileAvatar)), _kCircle);
      expect(tester.getSize(find.text('S')), const Size(72, 88));
    });

    // The same 36 dp glyph is what makes the public `diameter` parameter a trap:
    // it shrinks the circle and nothing else, so a caller passing anything under
    // the 44 dp line box above gets a letter larger than the bubble holding it.
    // No shipping call site overrides the default, which is why this is pinned
    // here rather than previewed.
    testWidgets('the glyph does not shrink with the diameter knob', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);

      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).diameter,
        96.0,
      );
      // 44 dp of glyph at 1x, whatever the circle is told to be. Any caller
      // passing a diameter below this gets a letter taller than its bubble.
      expect(tester.getSize(find.text('S')).height, 44.0);
    });

    // A positive pin, and the reason this widget is worth reading next to its
    // sibling. `_InitialBubble` takes `onPrimaryContainer` on `primaryContainer`
    // — the M3 tone-10/tone-90 pair the b02 audit installed — where
    // `OmdsProfileAvatar` hardcodes `Colors.white` on the same fill and measures
    // 1.29:1. If these numbers move, the tone pair moved.
    testWidgets('paints a real tone pair: 13.28:1 light, 7.23:1 dark', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileAvatarNamed);
      expect(_initialContrast(tester, 'S'), closeTo(13.28, 0.01));
      expect(_bubble(tester, 'S').shape, BoxShape.circle);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpPreview(tester, profileAvatarNamed);

      expect(_initialContrast(tester, 'S'), closeTo(7.23, 0.01));
    });
  });
}
