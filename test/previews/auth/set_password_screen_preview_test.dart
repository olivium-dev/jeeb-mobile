// Render tests for the SetPasswordScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// This screen is a hard case for "does this preview render ITS OWN state?".
// The builder reads exactly one thing off the state — `state.hasError` — and
// paints one hardcoded sentence for every reason it could be true, so FOUR of
// these previews (`mismatch`, `weak`, `empty`, `network`) are pixel-identical.
// Shipped copy therefore cannot separate them, and `expectedText` runs on
// captions ([SetPasswordScreenCaptions]) instead. The groups below assert the
// real state behind each caption — which fields are enabled, which eye icon is
// drawn, whether the error node is mounted, how wide the frame is — so a
// preview wired to the wrong fixture fails here rather than passing on its
// caption alone.
//
// The identity of the four error states is itself asserted (`one sentence for
// four causes`). That test is a CHARACTERIZATION of the defect, not an approval
// of it: if someone gives the network failure its own copy, it fails, and the
// fix is to split the expectation — not to re-merge the copy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/auth/presentation/set_password_screen.dart';

import '../preview_test_harness.dart';

/// The one sentence the screen has for every failure — EN, as shipped in
/// `lib/l10n/app_en.arb` (`setpwValidationError`).
const String _errorCopyEn =
    'Passwords must match and meet the strength requirements.';

/// `setpwSubmitCta`, EN.
const String _submitCtaEn = 'Save password';

/// The two password fields, in tree order: new, then confirm.
final Finder _fields = find.byType(OmdsTextField);

/// `setpw_submit_cta`.
final Finder _submit = find.byType(OmdsPrimaryButton);

OmdsTextField _newField(WidgetTester tester) =>
    tester.widget<OmdsTextField>(_fields.at(0));

OmdsTextField _confirmField(WidgetTester tester) =>
    tester.widget<OmdsTextField>(_fields.at(1));

OmdsPrimaryButton _submitButton(WidgetTester tester) =>
    tester.widget<OmdsPrimaryButton>(_submit);

/// Pumps [preview] into a FRESH element tree.
///
/// Two of these previews pumped back to back are identical widget types with no
/// keys, so Flutter reuses the elements — and `BlocProvider.create` runs only on
/// first build, which hands the SECOND preview the FIRST one's cubit and
/// silently asserts the wrong state. Clearing the tree makes every pump a real
/// mount. Only needed inside a test that pumps more than once.
Future<void> _pumpFresh(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpPreview(tester, preview);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SetPasswordScreen',
    const <String, Widget Function()>{
      'Idle · nothing typed': setPasswordScreenIdle,
      'Submitting · POST in flight': setPasswordScreenSubmitting,
      'Error · passwords differ': setPasswordScreenMismatch,
      'Error · below strength floor': setPasswordScreenWeak,
      'Error · both fields blank': setPasswordScreenEmptyFields,
      'Error · never reached the gateway': setPasswordScreenNetworkFailure,
      'Both fields revealed': setPasswordScreenRevealed,
      'Compact 320 pt · error at the ceiling': setPasswordScreenCompact,
    },
    expectedText: const <String, String>{
      'Idle · nothing typed': SetPasswordScreenCaptions.idle,
      'Submitting · POST in flight': SetPasswordScreenCaptions.submitting,
      'Error · passwords differ': SetPasswordScreenCaptions.mismatch,
      'Error · below strength floor': SetPasswordScreenCaptions.weak,
      'Error · both fields blank': SetPasswordScreenCaptions.emptyFields,
      'Error · never reached the gateway':
          SetPasswordScreenCaptions.networkFailure,
      'Both fields revealed': SetPasswordScreenCaptions.revealed,
      'Compact 320 pt · error at the ceiling':
          SetPasswordScreenCaptions.compact,
    },
  );

  group('SetPasswordScreen preview specifics', () {
    testWidgets('Idle mounts no error node, and the CTA is live on a form '
        'with nothing in it', (WidgetTester tester) async {
      await pumpPreview(tester, setPasswordScreenIdle);

      expect(_fields, findsNWidgets(2));
      expect(find.text(_errorCopyEn), findsNothing);

      expect(_newField(tester).enabled, isTrue);
      expect(_confirmField(tester).enabled, isTrue);
      expect(_newField(tester).obscureText, isTrue);
      expect(_confirmField(tester).obscureText, isTrue);
      expect(_newField(tester).controller!.text, isEmpty);
      expect(_confirmField(tester).controller!.text, isEmpty);

      // Nothing anywhere states the strength floor (8 chars, a letter and a
      // digit) before it is failed — the only text on the surface is the two
      // labels, the two hints, the title and the CTA.
      expect(find.textContaining('8'), findsNothing);

      // The only gate on submit is `!submitting`, so an empty form can be
      // submitted. This is what produces the `Both fields blank` state.
      expect(_submitButton(tester).isEnabled, isTrue);
    });

    testWidgets('Submitting disables both fields and the CTA but shows no '
        'progress indicator and no changed label', (WidgetTester tester) async {
      await pumpPreview(tester, setPasswordScreenSubmitting);

      expect(_newField(tester).enabled, isFalse);
      expect(_confirmField(tester).enabled, isFalse);
      expect(_submitButton(tester).isEnabled, isFalse);

      // The finding: in-flight looks exactly like disabled. `OmdsPrimaryButton`
      // has no loading state and the screen adds none, so the only signal is
      // the 45%-alpha fill — the label is unchanged and there is no spinner
      // anywhere on the surface.
      expect(_submitButton(tester).text, _submitCtaEn);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // An in-flight submit is not an error state.
      expect(find.text(_errorCopyEn), findsNothing);
    });

    testWidgets('one sentence for four causes: mismatch, weak, empty and a '
        'network failure are the same picture', (WidgetTester tester) async {
      const List<Widget Function()> causes = <Widget Function()>[
        setPasswordScreenMismatch,
        setPasswordScreenWeak,
        setPasswordScreenEmptyFields,
        setPasswordScreenNetworkFailure,
      ];

      for (final Widget Function() preview in causes) {
        await _pumpFresh(tester, preview);

        // Every one of the four mounts the node...
        expect(find.text(_errorCopyEn), findsOneWidget);
        // ...with the fields still live and the CTA still offering the same
        // retry, including for the network failure, where retyping the
        // password cannot possibly help.
        expect(_newField(tester).enabled, isTrue);
        expect(_confirmField(tester).enabled, isTrue);
        expect(_submitButton(tester).isEnabled, isTrue);
        // ...and nothing else on the surface names the actual cause.
        expect(find.textContaining('network'), findsNothing);
        expect(find.textContaining('Network'), findsNothing);
      }
    });

    testWidgets('Revealed flips both eye icons, over fields that are still '
        'empty because the text is not part of the state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, setPasswordScreenIdle);
      expect(find.byIcon(Icons.visibility), findsNWidgets(2));
      expect(find.byIcon(Icons.visibility_off), findsNothing);

      await _pumpFresh(tester, setPasswordScreenRevealed);
      expect(find.byIcon(Icons.visibility_off), findsNWidgets(2));
      expect(find.byIcon(Icons.visibility), findsNothing);

      expect(_newField(tester).obscureText, isFalse);
      expect(_confirmField(tester).obscureText, isFalse);
      // The controllers live in `_SetPasswordViewState`, so no fixture can put
      // characters behind the revealed masks.
      expect(_newField(tester).controller!.text, isEmpty);
      expect(_confirmField(tester).controller!.text, isEmpty);
    });

    testWidgets('the device frame is pinned in the tree, so the compact state '
        'is genuinely narrower than the phone states', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, setPasswordScreenMismatch);
      expect(tester.getSize(find.byType(SetPasswordScreen)).width, 390.0);

      await _pumpFresh(tester, setPasswordScreenCompact);
      expect(tester.getSize(find.byType(SetPasswordScreen)).width, 320.0);
      // Same designed state, narrower device — the caption is the only thing
      // that differs in the fixture wiring.
      expect(find.text(_errorCopyEn), findsOneWidget);
    });
  });
}
