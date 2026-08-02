// Render tests for the DeliveryRegisterPromptScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// DeliveryRegisterPromptScreen renders the SAME four strings in every state — it
// has no data axis at all — so "did it render" is a weak question here: all six
// previews would pass a render-only check while showing identical content, and
// two of them (`Phone 390 × 844` and `Pushed from the gate`) are pixel-identical
// BY DESIGN. The suite therefore does two extra jobs. The expected strings pin
// WHICH window each preview simulates (the caption the fixture host paints), and
// the group below measures what the screen actually did inside that window —
// geometry, reachability, and where each of its three exits leads. Those are the
// only contract this screen has.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/delivery_register_prompt_screen_fixtures.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _notchedFrame = Size(393, 852);

/// The home indicator the notched windows simulate.
const double _notchedBottomInset = 34;

/// `Spacing.xLarge` — the ListView's own bottom padding, and the only thing
/// between the last action and the display edge.
const double _listBottomPadding = 24;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryRegisterPromptScreen',
    const <String, Widget Function()>{
      'Phone 390 × 844': deliveryRegisterPromptScreenPhone,
      'Compact 320 × 568': deliveryRegisterPromptScreenCompact,
      'Notched 393 × 852 · inset 59/34': deliveryRegisterPromptScreenNotched,
      'Phone · 200% text': deliveryRegisterPromptScreenLargeText,
      'Compact · 200% text': deliveryRegisterPromptScreenCompactLargeText,
      'Notched · 200% text': deliveryRegisterPromptScreenNotchedLargeText,
      'Pushed from the gate': deliveryRegisterPromptScreenPushed,
    },
    // Every state names its own window. The screen shows the same icon, the
    // same headline and the same two buttons in all six, so without this a
    // preview wired to the wrong window — or seven previews accidentally sharing
    // one — would pass unnoticed. `Pushed from the gate` is the case that makes
    // this mandatory rather than tidy: it is the phone window with one more page
    // under it, and NOTHING on screen distinguishes the two.
    expectedText: const <String, String>{
      'Phone 390 × 844': 'Phone · 390 × 844 · 100% text · stack root',
      'Compact 320 × 568': 'Compact · 320 × 568 · 100% text',
      'Notched 393 × 852 · inset 59/34': 'Notched · 393 × 852 · inset 59/34',
      'Phone · 200% text': 'Phone · 390 × 844 · 200% text',
      'Compact · 200% text': 'Compact · 320 × 568 · 200% text',
      'Notched · 200% text': 'Notched · 393 × 852 · inset 59/34 · 200% text',
      'Pushed from the gate': 'Phone · 390 × 844 · pushed from the gate',
    },
  );

  group('DeliveryRegisterPromptScreen preview specifics', () {
    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(tester, preview, locale: locale);
      return tester.getRect(find.byType(DeliveryRegisterPromptScreen));
    }

    ScrollableState bodyScrollable(WidgetTester tester) =>
        tester.state(find.byType(Scrollable).last);

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the rest of this group
      // would be asserting nothing.
      expect((await frameRect(tester, deliveryRegisterPromptScreenPhone)).size,
          _phoneFrame);
      expect((await frameRect(tester, deliveryRegisterPromptScreenCompact)).size,
          _compactFrame);
      expect((await frameRect(tester, deliveryRegisterPromptScreenNotched)).size,
          _notchedFrame);
      expect(
          (await frameRect(tester, deliveryRegisterPromptScreenLargeText)).size,
          _phoneFrame);
      expect(
          (await frameRect(
                  tester, deliveryRegisterPromptScreenCompactLargeText))
              .size,
          _compactFrame);
      expect(
          (await frameRect(tester, deliveryRegisterPromptScreenNotchedLargeText))
              .size,
          _notchedFrame);
      expect((await frameRect(tester, deliveryRegisterPromptScreenPushed)).size,
          _phoneFrame);
    });

    testWidgets('the 200% windows really are scaled and the rest are not', (
      WidgetTester tester,
    ) async {
      // `DeliveryRegisterPromptScreenWindow.textScale` is nullable on purpose: a
      // window that pinned 1.0 would overwrite the `matrix: true` 200% card on
      // `Phone 390 × 844` and label a 100% rendering "EN 200% text". This pins
      // both halves of that.
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(DeliveryRegisterPromptScreen)),
        ).scale(10);
      }

      expect(await scale(deliveryRegisterPromptScreenPhone), 10);
      expect(await scale(deliveryRegisterPromptScreenCompact), 10);
      expect(await scale(deliveryRegisterPromptScreenNotched), 10);
      expect(await scale(deliveryRegisterPromptScreenPushed), 10);
      expect(await scale(deliveryRegisterPromptScreenLargeText), 20);
      expect(await scale(deliveryRegisterPromptScreenCompactLargeText), 20);
      expect(await scale(deliveryRegisterPromptScreenNotchedLargeText), 20);
    });

    testWidgets('the gate copy is what this screen actually says', (
      WidgetTester tester,
    ) async {
      // The finding, pinned as text. Every string on the register-as-a-jeeber
      // prompt is an `offerKycGate*` / `gate*` key: the screen talks about
      // verification and about SENDING OFFERS, never about registering or
      // delivering, and the CTA labelled "Start verification" opens the
      // onboarding wizard rather than KYC. If someone rewrites the copy for this
      // route, this test fails and that is the correct outcome — replace it with
      // the new strings.
      await pumpPreview(tester, deliveryRegisterPromptScreenPhone);

      expect(find.bySemanticsIdentifier('delivery_register_prompt'),
          findsOneWidget);
      expect(find.text('Verification required'), findsOneWidget);
      expect(find.text('Get approved to start sending offers'), findsOneWidget);
      expect(
        find.text(
          'Finish your identity verification to unlock offering. '
          'It only takes a few minutes.',
        ),
        findsOneWidget,
      );
      expect(find.text('Start verification'), findsOneWidget);
      expect(find.text('Back to requests'), findsOneWidget);
      expect(
        find.textContaining('deliver'),
        findsNothing,
        reason: 'the standalone REGISTER-AS-A-DELIVERY-PERSON prompt does not '
            'contain the word "deliver" anywhere in its copy',
      );
    });

    testWidgets('on a 390 × 844 phone everything fits and both actions are '
        'on screen', (WidgetTester tester) async {
      // The reference reading, and the reason the states below went unnoticed:
      // in the one window everybody reviews, this screen is exactly as simple as
      // it looks.
      final Rect frame =
          await frameRect(tester, deliveryRegisterPromptScreenPhone);

      expect(bodyScrollable(tester).position.maxScrollExtent, 0);
      expect(find.bySemanticsIdentifier('delivery_register_prompt_cta'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('delivery_register_prompt_back'),
          findsOneWidget);
      expect(tester.getRect(find.byType(TextButton)).bottom,
          lessThan(frame.bottom));
    });

    testWidgets('on the smallest phone at 100% it still fits', (
      WidgetTester tester,
    ) async {
      // The small-phone axis alone does not break this screen — which is why
      // the 200% state below is the one that matters.
      await pumpPreview(tester, deliveryRegisterPromptScreenCompact);

      expect(bodyScrollable(tester).position.maxScrollExtent, 0);
      expect(find.bySemanticsIdentifier('delivery_register_prompt_cta'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('delivery_register_prompt_back'),
          findsOneWidget);
    });

    testWidgets('the notched insets are handled at the top and survived at the '
        'bottom', (WidgetTester tester) async {
      // The top half is the app bar's arithmetic and it is right: 56 pt of
      // toolbar plus the 59 pt status bar. The bottom half only looks right —
      // at 100% the content is short enough that the back link stops well clear
      // of the home indicator, which is why the missing bottom SafeArea stays
      // invisible until `Notched · 200% text`.
      final Rect frame =
          await frameRect(tester, deliveryRegisterPromptScreenNotched);

      expect(tester.getRect(find.byType(AppBar)).height,
          moreOrLessEquals(115, epsilon: 1));
      expect(bodyScrollable(tester).position.maxScrollExtent, 0);
      expect(
        frame.bottom - tester.getRect(find.byType(TextButton)).bottom,
        greaterThan(_notchedBottomInset),
      );
    });

    testWidgets('at 200% neither action is reachable, on ANY phone', (
      WidgetTester tester,
    ) async {
      // Both actions live inside the ListView rather than pinned to the bottom
      // of the Scaffold, and the list does not paint past its viewport.
      // `delivery_register_prompt_cta` and `delivery_register_prompt_back` —
      // the two ids the screen's dartdoc publishes as its QA targets — are
      // therefore absent from the widget tree AND from the semantics tree on
      // arrival, while the ROOT id the Maestro flows actually assert is still
      // there. A flow that checks "the prompt opened" stays green with both of
      // the prompt's actions off the display.
      //
      // The ordinary 390 × 844 phone is in this list on purpose: this is not a
      // small-device edge case, it is a text-size setting on a mainstream phone.
      for (final Widget Function() preview in <Widget Function()>[
        deliveryRegisterPromptScreenLargeText,
        deliveryRegisterPromptScreenCompactLargeText,
        deliveryRegisterPromptScreenNotchedLargeText,
      ]) {
        await pumpPreview(tester, preview);

        expect(bodyScrollable(tester).position.maxScrollExtent, greaterThan(0));
        expect(find.byType(OmdsPrimaryButton), findsNothing);
        expect(
          find.bySemanticsIdentifier('delivery_register_prompt_cta'),
          findsNothing,
        );
        expect(
          find.bySemanticsIdentifier('delivery_register_prompt_back'),
          findsNothing,
        );
        // The screen root and the app-bar arrow are both still there — the user
        // is not trapped, they just cannot see either button the copy points at.
        expect(
          find.bySemanticsIdentifier('delivery_register_prompt'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      }
    });

    testWidgets('nothing overflows at the accessibility ceiling', (
      WidgetTester tester,
    ) async {
      // The ListView is what saves this screen: at the worst window the app
      // supports the composition becomes a long scroll rather than clipped copy,
      // in both locales. Recorded because it is cheap to lose — a `Column` here
      // instead would clip the CTA off the bottom.
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        await pumpPreview(
          tester,
          deliveryRegisterPromptScreenCompactLargeText,
          locale: locale,
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Arabic is the LONGER rendering at the ceiling', (
      WidgetTester tester,
    ) async {
      // Worth pinning because the instinct is the opposite. On this screen the
      // AR copy costs more vertical room than the EN copy at 200% (measured 220
      // pt of scroll against 180 on a 390 × 844 phone), so a reviewer who only
      // opens the English card is reading the better case — which is why the
      // reference preview is matrixed.
      await pumpPreview(tester, deliveryRegisterPromptScreenLargeText);
      final double english = bodyScrollable(tester).position.maxScrollExtent;

      await pumpPreview(
        tester,
        deliveryRegisterPromptScreenLargeText,
        locale: const Locale('ar'),
      );
      final double arabic = bodyScrollable(tester).position.maxScrollExtent;

      expect(english, greaterThan(0));
      expect(arabic, greaterThan(english));
    });

    testWidgets('the body runs under the home indicator', (
      WidgetTester tester,
    ) async {
      // `app_router.dart` mounts this screen as a bare top-level GoRoute — no
      // ShellRoute, no SafeArea — and `Scaffold` does not SafeArea its body, so
      // the scroll viewport ends at the physical bottom edge of the display.
      final Rect frame = await frameRect(
        tester,
        deliveryRegisterPromptScreenNotchedLargeText,
      );
      expect(
        tester.getRect(find.byType(Scrollable).last).bottom,
        frame.bottom,
        reason: 'the viewport stops short of the display edge only if someone '
            'added a bottom SafeArea — in which case delete the rest of this '
            'test, it is fixed',
      );

      // Scrolled to the end, the back link comes to rest on the ListView's own
      // 24 pt bottom padding. The home indicator claims 34.
      final ScrollableState scrollable = bodyScrollable(tester);
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final Rect back = tester.getRect(find.byType(TextButton));
      expect(
        frame.bottom - back.bottom,
        moreOrLessEquals(_listBottomPadding, epsilon: 0.5),
      );
      expect(
        frame.bottom - back.bottom,
        lessThan(_notchedBottomInset),
        reason: 'measured 24 pt of clearance against a 34 pt home indicator: '
            'the last 10 pt of the app\'s own back affordance sits under the '
            'system gesture bar. Font-independent — it is 24 < 34.',
      );
    });

    // The three exits. Each gets its OWN test: pumping a second preview into
    // the same tester reuses the first preview's element, and with it the
    // fixture host's State — the router would still be sitting on the page the
    // previous tap navigated to.
    Future<void> tapExit(
      WidgetTester tester,
      Widget Function() preview,
      Finder target,
    ) async {
      await pumpPreview(tester, preview);
      expect(find.byType(DeliveryRegisterPromptScreen), findsOneWidget);

      // The 390 × 844 frame is taller than the 800 × 600 test surface, so the
      // target has to be scrolled into the hit-testable area first.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.byType(DeliveryRegisterPromptScreen), findsNothing);
    }

    testWidgets('on the production stack the app-bar arrow lands on the shell', (
      WidgetTester tester,
    ) async {
      // JEBV4-13 P1-6: the screen passes an explicit `onBackPressed`, so the
      // arrow is a working exit even as the stack root — without it
      // `OMDSAppBar`'s default `maybePop()` would no-op and the arrow would be
      // dead. This is that fix, made visible.
      await tapExit(
        tester,
        deliveryRegisterPromptScreenPhone,
        find.byIcon(Icons.arrow_back),
      );
      expect(
        find.text(deliveryRegisterPromptScreenShellStandInLabel),
        findsOneWidget,
      );
    });

    testWidgets('"Back to requests" also lands on the shell, not on requests', (
      WidgetTester tester,
    ) async {
      // `gateBackCta` is the offer-KYC gate's string, where "requests" is the
      // jeeber feed the gate was opened from. Here the tap resolves to
      // `context.go('/')` — the shell root — because both shipped callers reach
      // this route with a stack-REPLACING `goNamed`. For a customer sent here
      // from the profile row, "requests" is a place they have never been.
      await tapExit(
        tester,
        deliveryRegisterPromptScreenPhone,
        find.bySemanticsIdentifier('delivery_register_prompt_back'),
      );
      expect(
        find.text(deliveryRegisterPromptScreenShellStandInLabel),
        findsOneWidget,
      );
    });

    testWidgets('the CTA replaces the stack the onboarding wizard expects to '
        'pop', (WidgetTester tester) async {
      // `dm_onboarding_screen.dart:216` documents step-1 Back as returning "to
      // the `delivery-register-prompt` the wizard was pushed from", and
      // implements it as `canPop() ? pop() : go('/')`. This screen uses
      // `goNamed`, which REPLACES — so the wizard opens on a one-page stack and
      // its Back drops the user on the shell instead of back here.
      await tapExit(
        tester,
        deliveryRegisterPromptScreenPhone,
        find.bySemanticsIdentifier('delivery_register_prompt_cta'),
      );

      final Finder wizard =
          find.text(deliveryRegisterPromptScreenOnboardingStandInLabel);
      expect(wizard, findsOneWidget);
      expect(
        GoRouter.of(tester.element(wizard)).canPop(),
        isFalse,
        reason: 'nothing under the wizard to pop back to: the CTA would have to '
            'be `pushNamed` for the documented round trip to exist',
      );
    });

    testWidgets('with the gate underneath, both back exits pop to the gate', (
      WidgetTester tester,
    ) async {
      // The contrast state. Same pixels as `Phone 390 × 844`, different
      // destination — which is the whole reason a navigation state is worth a
      // preview card of its own.
      await tapExit(
        tester,
        deliveryRegisterPromptScreenPushed,
        find.byIcon(Icons.arrow_back),
      );
      expect(
        find.text(deliveryRegisterPromptScreenGateStandInLabel),
        findsOneWidget,
      );
      expect(
        find.text(deliveryRegisterPromptScreenShellStandInLabel),
        findsNothing,
      );
    });

    testWidgets('Arabic is localized and mirrored, not raw English', (
      WidgetTester tester,
    ) async {
      // And the copy mismatch is not an English-only problem: the AR strings are
      // the gate's too — "verification required" / "start verification".
      await pumpPreview(
        tester,
        deliveryRegisterPromptScreenPhone,
        locale: const Locale('ar'),
      );

      expect(find.text('التوثيق مطلوب'), findsOneWidget);
      expect(find.text('احصل على الموافقة لتبدأ بإرسال العروض'), findsOneWidget);
      expect(find.text('بدء التوثيق'), findsOneWidget);
      expect(find.text('Verification required'), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byType(DeliveryRegisterPromptScreen)),
        ),
        TextDirection.rtl,
      );
    });
  });
}
