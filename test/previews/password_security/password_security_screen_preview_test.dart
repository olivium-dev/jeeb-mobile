// Render tests for the PasswordSecurityScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This screen is a hard case for "does this preview render ITS OWN state?".
// The two error nodes both paint one hardcoded sentence
// (`l10n.setpwValidationError`), and `PasswordSecurityStatus.unavailable`
// paints nothing at all — so SIX of these ten previews cannot be told apart by
// shipped copy. `expectedText` therefore runs on captions
// ([PasswordSecurityScreenCaptions]) and the groups below assert the real state
// behind each caption: which fields are enabled, which are masked, which
// `Semantics` node is mounted, how wide the frame is. A preview wired to the
// wrong fixture fails here rather than passing on its caption alone.
//
// The identity of the four error states is itself asserted ("one sentence for
// four causes"). That test is a CHARACTERIZATION of the defect, not an approval
// of it: if someone gives `sameAsCurrent` its own copy, it fails, and the fix
// is to split the expectation — not to re-merge the copy.
//
// ## Fonts
//
// `preview_test_harness.dart` does NOT load real fonts, so text lays out in
// Flutter's 1-em test face (Latin ~2x too wide, Arabic ~2.4x). Every geometry
// claim in this file is measured through [_passwordSecurityCanvasWithFonts],
// which is the same canvas with real Inter + the deterministic Noto Arabic
// subset wired into the theme — `loadInterTestFont()` alone only REGISTERS the
// Arabic family, `withGoldenTestFonts` is what selects it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/password_security/presentation/password_security_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The one sentence the screen has for every validation failure — EN, as
/// shipped in `lib/l10n/app_en.arb` (`setpwValidationError`).
const String _errorCopyEn =
    'Passwords must match and meet the strength requirements.';

/// `setpwSubmitCta`, EN.
const String _submitCtaEn = 'Save password';

/// `passwordSetEntryCta`, EN — rendered for BOTH `hasPassword` values.
const String _setEntryCtaEn = 'Set a password';

/// The three password fields, in tree order: current, new, confirm.
final Finder _fields = find.byType(OmdsTextField);

OmdsTextField _fieldAt(WidgetTester tester, int index) =>
    tester.widget<OmdsTextField>(_fields.at(index));

OmdsTextField _currentField(WidgetTester tester) => _fieldAt(tester, 0);
OmdsTextField _newField(WidgetTester tester) => _fieldAt(tester, 1);
OmdsTextField _confirmField(WidgetTester tester) => _fieldAt(tester, 2);

/// `password_submit_cta` — the first `OmdsPrimaryButton` on the surface. The
/// second is `password_set_entry`, which is a primary button too.
OmdsPrimaryButton _submitButton(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton).at(0));

/// Restricts [matching] to the screen's own subtree, excluding the preview
/// caption painted above the device frame.
Finder _onScreen(Finder matching) => find.descendant(
      of: find.byType(PasswordSecurityScreen),
      matching: matching,
    );

/// `previewCanvas`, but with the real Inter faces and the deterministic Arabic
/// family wired into the theme.
///
/// The shared harness cannot do this — it builds `AppTheme.light()` directly —
/// and without it every glyph is laid out in the 1-em test face. Used wherever
/// a geometry claim is being made.
Widget _passwordSecurityCanvasWithFonts(
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

/// Pumps [preview] into a FRESH element tree, with real fonts.
///
/// Two of these previews pumped back to back are identical widget types with no
/// keys, so Flutter reuses the elements — and `BlocProvider.create` runs only on
/// first build, which hands the SECOND preview the FIRST one's cubit and
/// silently asserts the wrong state.
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_passwordSecurityCanvasWithFonts(preview, locale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'PasswordSecurityScreen',
    const <String, Widget Function()>{
      'Change form · idle': passwordSecurityScreenIdle,
      'Social-only · no change form': passwordSecurityScreenSocialOnly,
      'Submitting · unreachable state': passwordSecurityScreenSubmitting,
      'Error · below strength floor': passwordSecurityScreenWeak,
      'Error · new and confirm differ': passwordSecurityScreenMismatch,
      'Error · blank form submitted': passwordSecurityScreenEmptyFields,
      'Error · new equals current': passwordSecurityScreenSameAsCurrent,
      'Valid submit · nothing saved': passwordSecurityScreenUnavailable,
      'All three fields unmasked': passwordSecurityScreenRevealed,
      'Compact 320 pt · error at the ceiling': passwordSecurityScreenCompact,
    },
    expectedText: const <String, String>{
      'Change form · idle': PasswordSecurityScreenCaptions.idle,
      'Social-only · no change form': PasswordSecurityScreenCaptions.socialOnly,
      'Submitting · unreachable state':
          PasswordSecurityScreenCaptions.submitting,
      'Error · below strength floor': PasswordSecurityScreenCaptions.weak,
      'Error · new and confirm differ': PasswordSecurityScreenCaptions.mismatch,
      'Error · blank form submitted':
          PasswordSecurityScreenCaptions.emptyFields,
      'Error · new equals current':
          PasswordSecurityScreenCaptions.sameAsCurrent,
      'Valid submit · nothing saved':
          PasswordSecurityScreenCaptions.unavailable,
      'All three fields unmasked': PasswordSecurityScreenCaptions.revealed,
      'Compact 320 pt · error at the ceiling':
          PasswordSecurityScreenCaptions.compact,
    },
  );

  group('PasswordSecurityScreen preview specifics', () {
    testWidgets('the phone previews pin a 390 pt frame and the compact one the '
        '320 pt floor, so they are not the same widget', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await _pumpFresh(tester, passwordSecurityScreenMismatch);
      expect(tester.getSize(find.byType(PasswordSecurityScreen)).width, 390.0);

      await _pumpFresh(tester, passwordSecurityScreenCompact);
      expect(tester.getSize(find.byType(PasswordSecurityScreen)).width, 320.0);
      // Same designed state, narrower device — the caption and the box are the
      // only things that differ in the fixture wiring.
      expect(find.text(_errorCopyEn), findsOneWidget);
    });

    testWidgets('Idle mounts no error node, and the CTA is live on a form with '
        'nothing in it', (WidgetTester tester) async {
      await _pumpFresh(tester, passwordSecurityScreenIdle);

      expect(_fields, findsNWidgets(3));
      expect(find.bySemanticsIdentifier('password_strength_error'), findsNothing);
      expect(find.bySemanticsIdentifier('password_mismatch_error'), findsNothing);
      expect(find.text(_errorCopyEn), findsNothing);

      for (int i = 0; i < 3; i++) {
        expect(_fieldAt(tester, i).enabled, isTrue);
        expect(_fieldAt(tester, i).obscureText, isTrue);
        expect(_fieldAt(tester, i).controller!.text, isEmpty);
      }

      // Nothing anywhere states the strength floor (8 chars, a letter and a
      // digit) before it is failed.
      expect(_onScreen(find.textContaining('8')), findsNothing);

      // The only gate on submit is `!submitting` — a status nothing emits (see
      // below) — so an empty form can always be submitted. That is what
      // produces `Error · blank form submitted`.
      expect(_submitButton(tester).isEnabled, isTrue);
      expect(_submitButton(tester).text, _submitCtaEn);
    });

    testWidgets('the social-only variant is the real EMPTY state: no form, and '
        'the SAME "Set a password" button a password user is shown', (
      WidgetTester tester,
    ) async {
      await _pumpFresh(tester, passwordSecurityScreenSocialOnly);

      expect(_fields, findsNothing);
      expect(find.bySemanticsIdentifier('password_submit_cta'), findsNothing);
      expect(find.text(_submitCtaEn), findsNothing);
      expect(find.bySemanticsIdentifier('password_set_entry'), findsOneWidget);
      expect(find.text(_setEntryCtaEn), findsOneWidget);

      // The finding: the password account gets that button too, so "Set a
      // password" sits directly under a form for changing the one it has.
      await _pumpFresh(tester, passwordSecurityScreenIdle);
      expect(find.bySemanticsIdentifier('password_set_entry'), findsOneWidget);
      expect(find.text(_setEntryCtaEn), findsOneWidget);
    });

    testWidgets('Submitting greys everything and shows no progress affordance '
        '— a picture no user can reach', (WidgetTester tester) async {
      await _pumpFresh(tester, passwordSecurityScreenSubmitting);

      for (int i = 0; i < 3; i++) {
        expect(_fieldAt(tester, i).enabled, isFalse);
      }
      expect(_submitButton(tester).isEnabled, isFalse);

      // In-flight looks exactly like disabled: `OmdsPrimaryButton` has no
      // loading state and the screen adds none, so the only signal is the
      // 45%-alpha fill — the label is unchanged and there is no spinner.
      expect(_submitButton(tester).text, _submitCtaEn);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(_errorCopyEn), findsNothing);
    });

    testWidgets('one sentence for four causes: weak, mismatch, blank and '
        'same-as-current are the same picture', (WidgetTester tester) async {
      const Map<String, Widget Function()> causes = <String, Widget Function()>{
        'password_strength_error': passwordSecurityScreenWeak,
        'password_mismatch_error': passwordSecurityScreenMismatch,
      };
      const Map<String, Widget Function()> strengthCauses =
          <String, Widget Function()>{
        'blank': passwordSecurityScreenEmptyFields,
        'sameAsCurrent': passwordSecurityScreenSameAsCurrent,
      };

      for (final MapEntry<String, Widget Function()> entry in causes.entries) {
        await _pumpFresh(tester, entry.value);

        // Each mounts its OWN node — that much is discriminated...
        expect(find.bySemanticsIdentifier(entry.key), findsOneWidget);
        // ...and then both paint the identical sentence.
        expect(find.text(_errorCopyEn), findsOneWidget);
        // Fields stay live and the CTA still offers the same retry.
        expect(_submitButton(tester).isEnabled, isTrue);
        expect(_currentField(tester).enabled, isTrue);
      }

      // `empty` and `sameAsCurrent` do not even get their own node: both are
      // folded into `hasStrengthError`. So a user who typed nothing, and a user
      // whose new password is strong AND matching but unchanged, are both told
      // it fails the strength requirements.
      for (final Widget Function() preview in strengthCauses.values) {
        await _pumpFresh(tester, preview);

        expect(
          find.bySemanticsIdentifier('password_strength_error'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('password_mismatch_error'),
          findsNothing,
        );
        expect(find.text(_errorCopyEn), findsOneWidget);
        // Nothing on the SCREEN names the actual cause. Scoped to the screen
        // subtree because the preview caption above the device frame says
        // "new equals current" — that is dev chrome, not shipped copy.
        expect(_onScreen(find.textContaining('current')), findsNothing);
        expect(_onScreen(find.textContaining('different')), findsNothing);
        expect(_onScreen(find.textContaining('blank')), findsNothing);
      }
    });

    testWidgets('B-33: the unavailable state leaves NO trace — it is the idle '
        'form again', (WidgetTester tester) async {
      await _pumpFresh(tester, passwordSecurityScreenUnavailable);

      // The snackbar is fired from `listenWhen` on a status CHANGE. A fixture
      // that is already `unavailable` when the consumer subscribes never fires
      // it, which is exactly what a rebuild/rotate looks like.
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.text("Changing your password isn't available yet. "
            'Nothing was saved.'),
        findsNothing,
      );

      // And the state itself renders nothing: no error node, every field live
      // and empty, the CTA live. Identical to `Change form · idle`.
      expect(find.bySemanticsIdentifier('password_strength_error'), findsNothing);
      expect(find.bySemanticsIdentifier('password_mismatch_error'), findsNothing);
      expect(find.text(_errorCopyEn), findsNothing);
      expect(_submitButton(tester).isEnabled, isTrue);
      for (int i = 0; i < 3; i++) {
        expect(_fieldAt(tester, i).enabled, isTrue);
        expect(_fieldAt(tester, i).obscureText, isTrue);
      }
    });

    testWidgets('the current-password field can be unmasked by the cubit but '
        'the screen offers no control for it', (WidgetTester tester) async {
      await _pumpFresh(tester, passwordSecurityScreenIdle);

      // Two eye buttons for three maskable fields.
      expect(
        find.bySemanticsIdentifier('password_new_visibility_toggle'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('password_confirm_visibility_toggle'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('password_current_visibility_toggle'),
        findsNothing,
      );
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      expect(find.byIcon(Icons.visibility_off), findsNothing);
      expect(_currentField(tester).suffixIcon, isNull);

      await _pumpFresh(tester, passwordSecurityScreenRevealed);

      // `currentObscured` is honoured by the screen — so this IS a state the
      // widget can render, and `toggleCurrentObscured` has no caller under
      // `lib/` that could ever produce it.
      expect(_currentField(tester).obscureText, isFalse);
      expect(_newField(tester).obscureText, isFalse);
      expect(_confirmField(tester).obscureText, isFalse);
      // Still only two icons, and both flipped.
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
      expect(find.byIcon(Icons.visibility), findsNothing);
      // The typed characters live in `_PasswordSecurityViewState`'s
      // controllers, so no fixture can put text behind the lifted masks.
      for (int i = 0; i < 3; i++) {
        expect(_fieldAt(tester, i).controller!.text, isEmpty);
      }
    });

    testWidgets('the compact ceiling scrolls rather than overflows, and the '
        'CTA leaves the viewport', (WidgetTester tester) async {
      // Measured through `withGoldenTestFonts`, so the metrics are the device's
      // rather than the 1-em test face's — an overflow claim taken under the
      // test face would be a phantom.
      await _pumpFresh(tester, passwordSecurityScreenCompact);

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);

      // The whole form fits at 100% text on the 320 pt floor: both buttons and
      // the error node are on screen.
      expect(find.text(_errorCopyEn), findsOneWidget);
      expect(find.text(_submitCtaEn), findsOneWidget);
      expect(find.text(_setEntryCtaEn), findsOneWidget);
    });

    testWidgets('the Arabic rendering keeps the error node and both CTAs', (
      WidgetTester tester,
    ) async {
      await _pumpFresh(
        tester,
        passwordSecurityScreenMismatch,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('يجب أن تتطابق كلمتا المرور وأن تستوفيا متطلبات القوة.'),
        findsOneWidget,
      );
      expect(find.text('حفظ كلمة المرور'), findsOneWidget);
      expect(find.text('تعيين كلمة مرور'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(ListView))),
        TextDirection.rtl,
      );
    });
  });
}
