// Render tests for the SocialSignInButton previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state pins a DISTINCT specimen title,
// because a suite that only asked "did something render?" would pass on five
// copies of the same pill.
//
// The title alone would be a weak pin here: the button's own text is only ever
// one of three localized labels, and `Google idle` and `Google disabled` render
// the SAME label. The `states` group below therefore pins what actually differs
// between them — the label the widget chooses, the semantics it publishes, and
// whether a tap reaches `onTap` — which is the part no screenshot can show.
//
// The three tests in `brand skin` pin behaviour that is currently WRONG — the
// Apple glyph colour, the unreachable disabled skin, and the label clipped at
// 200 % text — as does the semantics assertion in `busy`. They are regression
// pins with their reasoning attached, not endorsements; when one is fixed the
// pin is meant to fail so it can be updated.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/auth/social/social_sign_in_button.dart';
import 'package:jeeb_mobile/previews/auth/social_sign_in_button_preview.dart';

import '../preview_test_harness.dart';

/// The pill OMDS paints for every provider: one [AnimatedContainer] inside
/// [OmdsSocialButton], carrying the background colour and the border.
BoxDecoration _pill(WidgetTester tester) {
  final AnimatedContainer container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(OmdsSocialButton),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

/// The colour of the Apple mark. `_AppleGlyph` is private, so the [Icon] it
/// builds is the only handle a test has on it.
Color? _appleGlyphColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.apple)).color;

/// The Google brand mark. `_GoogleGlyph` is private and its disc is one of
/// several [Container]s in the subtree, so the centred "G" is the handle: it
/// sits dead centre of the disc.
Finder get _glyphInButton => find.descendant(
      of: find.byType(SocialSignInButton),
      matching: find.text('G'),
    );

/// Text rendered by the button itself, ignoring the specimen's title and note.
Finder _labelInButton(String text) => find.descendant(
      of: find.byType(SocialSignInButton),
      matching: find.text(text),
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SocialSignInButton',
    const <String, Widget Function()>{
      'Google idle': socialSignInButtonGoogleIdle,
      'Google busy': socialSignInButtonGoogleBusy,
      'Google disabled': socialSignInButtonGoogleDisabled,
      'Apple idle': socialSignInButtonAppleIdle,
      'Facebook generic label': socialSignInButtonFacebookGenericLabel,
    },
    expectedText: const <String, String>{
      'Google idle': 'Google idle',
      'Google busy': 'Google busy',
      'Google disabled': 'Google disabled',
      'Apple idle': 'Apple idle',
      'Facebook generic label': 'Facebook generic label',
    },
  );

  group('SocialSignInButton preview states', () {
    testWidgets('Google idle labels the provider and lands its taps', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInButtonGoogleIdle);

      expect(_labelInButton('Continue with Google'), findsOneWidget);
      expect(find.text('taps landed: 0'), findsOneWidget);

      await tester.tap(find.byType(SocialSignInButton));
      await tester.pumpAndSettle();

      expect(find.text('taps landed: 1'), findsOneWidget);
    });

    testWidgets('Google idle localizes its label in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        socialSignInButtonGoogleIdle,
        locale: const Locale('ar'),
      );

      // The specimen title stays English on purpose (it names the state, not
      // the product); the button's own label must not.
      expect(_labelInButton('Continue with Google'), findsNothing);
      expect(_labelInButton('المتابعة بحساب Google'), findsOneWidget);
    });

    testWidgets('busy collapses the label but still announces the provider', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, socialSignInButtonGoogleBusy);

      // One hardcoded ellipsis replaces the label — not a spinner, and not a
      // localized string.
      expect(_labelInButton('Continue with Google'), findsNothing);
      expect(_labelInButton('…'), findsOneWidget);

      // ...but the announcement still leads with the provider name, so a
      // screen-reader user is told nothing about the sheet that just opened —
      // only the enabled flag moves.
      //
      // The exact string is the second finding: `Semantics` is given a `label`
      // but NOT `excludeSemantics: true`, so the wrapper MERGES its children
      // instead of replacing them. The decorative brand glyph — a bare `Text`
      // reading "G", with no `ExcludeSemantics` around it — is announced as
      // content, and the busy ellipsis after it. TalkBack reads
      // "Continue with Google, G, …".
      expect(
        tester.getSemantics(find.byType(SocialSignInButton)),
        isSemantics(
          identifier: 'preview_social_google',
          label: 'Continue with Google\nG\n…',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );

      handle.dispose();
    });

    testWidgets('busy drops taps through a live onTap', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInButtonGoogleBusy);

      await tester.tap(find.byType(SocialSignInButton));
      await tester.pumpAndSettle();

      // `effectiveOnTap` is `() {}`, never null, so the GestureDetector is
      // still live and still eats the gesture — it just discards it.
      expect(find.text('taps landed: 0'), findsOneWidget);
    });

    testWidgets('disabled swallows taps while looking identical to idle', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, socialSignInButtonGoogleDisabled);

      expect(_labelInButton('Continue with Google'), findsOneWidget);
      expect(
        tester.getSemantics(find.byType(SocialSignInButton)),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();

      await tester.tap(find.byType(SocialSignInButton));
      await tester.pumpAndSettle();

      expect(find.text('taps landed: 0'), findsOneWidget);
    });

    testWidgets('the glyph moves to the trailing edge in Arabic', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpPreview(tester, socialSignInButtonGoogleIdle);
      final Rect pillEn = tester.getRect(find.byType(OmdsSocialButton));
      final double glyphEn = tester.getRect(_glyphInButton).center.dx;

      await pumpPreview(
        tester,
        socialSignInButtonGoogleIdle,
        locale: const Locale('ar'),
      );
      final Rect pillAr = tester.getRect(find.byType(OmdsSocialButton));
      final double glyphAr = tester.getRect(_glyphInButton).center.dx;

      // OmdsSocialButton spaces the row with `EdgeInsets.symmetric` and a plain
      // `Row`, both direction-aware, so the disc really does swap edges rather
      // than staying pinned left. Worth a pin: a later `EdgeInsets.only(left:)`
      // would still look right in EN and break only here.
      expect(glyphEn, lessThan(pillEn.center.dx));
      expect(glyphAr, greaterThan(pillAr.center.dx));
      expect(glyphEn - pillEn.left, closeTo(pillAr.right - glyphAr, 0.01));
    });

    testWidgets('Facebook never names its provider on screen', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInButtonFacebookGenericLabel);

      // Scoped to the button so the specimen's own title/note do not count.
      expect(_labelInButton('Continue'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SocialSignInButton),
          matching: find.textContaining('Facebook'),
        ),
        findsNothing,
      );
    });
  });

  group('SocialSignInButton preview brand skin', () {
    // TRIPWIRE, not an endorsement. `SocialSignInButton` still derives the
    // Apple mark's colour from the theme brightness — white in light, black in
    // dark — on the assumption that `OmdsSocialButtons.apple` flips to a black
    // vendor slab. Since P0-X02 it does not: every provider shares one white
    // pill and `isDark` is kept for source compatibility only. So the light
    // theme, which is the one this screen ships in, paints white on white.
    // If this test starts failing, the glyph was finally given an on-pill ink
    // (JEEB-57) — replace the colours with the new ones.
    testWidgets('paints the Apple mark in the pill colour in light theme', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInButtonAppleIdle);

      expect(_pill(tester).color, const Color(0xFFFFFFFF));
      expect(_appleGlyphColor(tester), const Color(0xFFFFFFFF));

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpPreview(tester, socialSignInButtonAppleIdle);

      // Mirror image: the pill is still white and NOW the glyph is black, so
      // the only readable Apple button is the one in the theme the auth screen
      // never uses.
      expect(_pill(tester).color, const Color(0xFFFFFFFF));
      expect(_appleGlyphColor(tester), const Color(0xFF000000));
    });

    // TRIPWIRE, not an endorsement. `OmdsSocialButtons._branded` never forwards
    // `isEnabled` to `OmdsSocialButton`, so the OMDS disabled skin (60 % alpha
    // pill, 38 % alpha label) is unreachable from this widget. Disabled and
    // idle paint the same pill; only the Google/Facebook glyph disc changes,
    // and Apple has no disabled treatment at all. If this fails, the disabled
    // state finally got a visual — delete the pin.
    testWidgets('disabled and idle paint the same pill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, socialSignInButtonGoogleIdle);
      final BoxDecoration idle = _pill(tester);

      await pumpPreview(tester, socialSignInButtonGoogleDisabled);
      final BoxDecoration disabled = _pill(tester);

      expect(disabled.color, idle.color);
      expect(disabled.border, idle.border);
      expect(disabled.borderRadius, idle.borderRadius);
    });

    // TRIPWIRE, not an endorsement. This is what the `EN 200% text` rendering
    // of the matrix shows, measured: the pill is a hard `Sizes.fourXLarge`
    // (48) and `OmdsSocialButton` spends 26 of it on `Spacing.small` padding
    // plus the 1 dp border, so the label lives in a 22 dp box at EVERY text
    // scale. At 200 % the paragraph needs 120 (three lines of 40) and gets 22.
    // Nothing throws and no overflow stripe appears — `Text` defaults to
    // `TextOverflow.clip`, so the label just silently loses ~80 % of itself.
    // If this fails, the pill learned to grow — replace the numbers.
    testWidgets('clips the label at 200% instead of growing the pill', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpPreview(tester, socialSignInButtonGoogleIdle);
      final Size labelAtNormal =
          tester.getSize(_labelInButton('Continue with Google'));
      final double titleAtNormal =
          tester.getSize(find.text('Google idle')).height;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, socialSignInButtonGoogleIdle);

      // The scaler really is in effect — the specimen's own title doubles.
      expect(
        tester.getSize(find.text('Google idle')).height,
        greaterThan(titleAtNormal),
      );

      // The button does not move, and neither does the box its label sits in.
      expect(tester.getSize(find.byType(OmdsSocialButton)).height, 48.0);
      expect(labelAtNormal.height, 22.0);
      expect(tester.getSize(_labelInButton('Continue with Google')),
          labelAtNormal);

      // ...while the text inside that box now wants five times the room.
      final RenderBox label = tester.renderObject<RenderBox>(
        _labelInButton('Continue with Google'),
      );
      expect(label.getMaxIntrinsicHeight(labelAtNormal.width), 120.0);
      expect(tester.takeException(), isNull);
    });
  });
}
