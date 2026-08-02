// Render tests for the PasswordSecurityScreen previews.

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
/// Two of these previews pumped back to back are identical widget types with no
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
      await _pumpFresh(tester, passwordSecurityScreenMismatch);
      expect(tester.getSize(find.byType(PasswordSecurityScreen)).width, 390.0);

      await _pumpFresh(tester, passwordSecurityScreenCompact);
      expect(tester.getSize(find.byType(PasswordSecurityScreen)).width, 320.0);
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

      expect(_onScreen(find.textContaining('8')), findsNothing);

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

        expect(find.bySemanticsIdentifier(entry.key), findsOneWidget);
        expect(find.text(_errorCopyEn), findsOneWidget);
        expect(_submitButton(tester).isEnabled, isTrue);
        expect(_currentField(tester).enabled, isTrue);
      }

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
        expect(_onScreen(find.textContaining('current')), findsNothing);
        expect(_onScreen(find.textContaining('different')), findsNothing);
        expect(_onScreen(find.textContaining('blank')), findsNothing);
      }
    });

    testWidgets('B-33: the unavailable state leaves NO trace — it is the idle '
        'form again', (WidgetTester tester) async {
      await _pumpFresh(tester, passwordSecurityScreenUnavailable);

      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.text("Changing your password isn't available yet. "
            'Nothing was saved.'),
        findsNothing,
      );

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

      expect(_currentField(tester).obscureText, isFalse);
      expect(_newField(tester).obscureText, isFalse);
      expect(_confirmField(tester).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
      expect(find.byIcon(Icons.visibility), findsNothing);
      for (int i = 0; i < 3; i++) {
        expect(_fieldAt(tester, i).controller!.text, isEmpty);
      }
    });

    testWidgets('the compact ceiling scrolls rather than overflows, and the '
        'CTA leaves the viewport', (WidgetTester tester) async {
      // Measured through `withGoldenTestFonts`, so the metrics are the device's
      await _pumpFresh(tester, passwordSecurityScreenCompact);

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget);

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
