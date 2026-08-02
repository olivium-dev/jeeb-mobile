// Render tests for the SocialSignInButton previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/auth/social/social_sign_in_button.dart';

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
      expect(_labelInButton('Continue with Google'), findsNothing);
      expect(_labelInButton('المتابعة بحساب Google'), findsOneWidget);
    });

    testWidgets('busy collapses the label but still announces the provider', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, socialSignInButtonGoogleBusy);

      // One hardcoded ellipsis replaces the label — not a spinner, and not a
      expect(_labelInButton('Continue with Google'), findsNothing);
      expect(_labelInButton('…'), findsOneWidget);

      // ...but the announcement still leads with the provider name, so a
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
      expect(_pill(tester).color, const Color(0xFFFFFFFF));
      expect(_appleGlyphColor(tester), const Color(0xFF000000));
    });

    // TRIPWIRE, not an endorsement. `OmdsSocialButtons._branded` never forwards
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
