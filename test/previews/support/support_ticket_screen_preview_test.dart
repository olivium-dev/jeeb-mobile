// Render tests for the SupportTicketScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// ## Why `expectedText` pins captions
//
// `expectedText` pins the dev-chrome CAPTION each card carries, not screen
// copy. Six of the eleven states are copy-identical: the form's own strings are
// fixed, the details a user "typed" never reaches the field (that IS the first
// finding), and what varies between them is which radio is filled, what the
// order-reference field holds and how many attachment chips there are. A suite
// that pinned screen copy would pass with six previews wired to the same
// fixture. The `preview specifics` group below asserts the real state behind
// every caption, so the caption is never the whole proof.
//
// ## Fonts
//
// `loadInterTestFont()` runs before every test here, because the shared harness
// does not load fonts and Flutter's test face makes every glyph a 1-em square —
// Latin measures ~2x too wide, Arabic ~2.4x. Nothing in this file asserts an
// overflow. The two geometry claims that the fake face could distort (the 320 pt
// frame, in EN and in AR) are measured through `withGoldenTestFonts`, which is
// the only way to get real Arabic metrics: the preview host builds
// `AppTheme.light()` unmodified and the theme carries no `fontFamilyFallback`,
// so under the shared harness every Arabic glyph falls back to the test face.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/support_ticket_screen_fixtures.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// `previewCanvas`, but with the deterministic Arabic face wired into the
/// theme.
///
/// The shared harness cannot do this — it builds `AppTheme.light()` directly —
/// and without it every Arabic glyph is laid out in the 1-em test face, which is
/// ~2.4x too wide. Used only where a geometry claim is being made.
Widget _supportCanvasWithFonts(Widget Function() preview, Locale locale) {
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

Future<void> _pumpWithFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_supportCanvasWithFonts(preview, locale));
  await tester.pumpAndSettle();
}

/// The `isEnabled` flag on the form's Submit CTA, read from the tree.
bool _submitEnabled(WidgetTester tester) {
  return tester
      .widget<OmdsPrimaryButton>(
        find.descendant(
          of: find.bySemanticsIdentifier('support_submit_cta'),
          matching: find.byType(OmdsPrimaryButton),
        ),
      )
      .isEnabled;
}

/// Every string currently inside an editable field on the card.
List<String> _fieldTexts(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .map((EditableText e) => e.controller.text)
    .toList();

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'SupportTicketScreen',
    const <String, Widget Function()>{
      'Form · empty': supportTicketScreenFormEmpty,
      'Form · ready to submit': supportTicketScreenReadyToSubmit,
      'Form · selected category is hidden': supportTicketScreenHiddenCategory,
      'Form · jeeber · six categories': supportTicketScreenJeeberCategories,
      'Form · attachments at the 5 cap': supportTicketScreenAttachmentsAtCap,
      'Submitting': supportTicketScreenSubmitting,
      'Success · confirmation': supportTicketScreenSuccess,
      'Error · network': supportTicketScreenNetworkError,
      'Error · session expired': supportTicketScreenSessionExpired,
      'Longest content': supportTicketScreenLongestContent,
      'Longest content · compact 320x568': supportTicketScreenCompact,
    },
    expectedText: const <String, String>{
      'Form · empty': SupportTicketScreenCaptions.formEmpty,
      'Form · ready to submit': SupportTicketScreenCaptions.readyToSubmit,
      'Form · selected category is hidden':
          SupportTicketScreenCaptions.hiddenCategory,
      'Form · jeeber · six categories':
          SupportTicketScreenCaptions.jeeberCategories,
      'Form · attachments at the 5 cap':
          SupportTicketScreenCaptions.attachmentsAtCap,
      'Submitting': SupportTicketScreenCaptions.submitting,
      'Success · confirmation': SupportTicketScreenCaptions.success,
      'Error · network': SupportTicketScreenCaptions.networkError,
      'Error · session expired': SupportTicketScreenCaptions.sessionExpired,
      'Longest content': SupportTicketScreenCaptions.longestContent,
      'Longest content · compact 320x568': SupportTicketScreenCaptions.compact,
    },
  );

  group('SupportTicketScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — the canvas produces the same widget types, so the
    // `BlocProvider` element is UPDATED rather than replaced and keeps the cubit
    // the first preview created.

    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await pumpPreview(tester, supportTicketScreenFormEmpty);

      expect(tester.getSize(find.byType(SupportTicketScreen)).width, 390);
    });

    testWidgets('the compact preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, supportTicketScreenCompact);

      expect(tester.getSize(find.byType(SupportTicketScreen)).width, 320);
    });

    testWidgets('the empty form offers a client four categories and a dead '
        'Submit', (WidgetTester tester) async {
      await pumpPreview(tester, supportTicketScreenFormEmpty);

      // The JM-063 identifier contract, all of it on one card.
      for (final String id in const <String>[
        'support_root',
        'support_category',
        'support_body',
        'support_order_link',
        'support_attach',
        'support_submit_cta',
        'support_dispute_link',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }

      // Four categories for a client — `payment` and `kycAppeal` are filtered
      // out when no RoleAvailabilityCubit carries `jeeber`.
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.text('Earnings'), findsNothing);
      expect(find.text('Appeal via support'), findsNothing);

      // Nothing selected and nothing typed → the gate is closed, and the card
      // says nothing about which of the two required fields is missing.
      expect(_submitEnabled(tester), isFalse);
      expect(_fieldTexts(tester), <String>['', '']);
    });

    testWidgets('four of the six category labels are borrowed from other '
        'screens', (WidgetTester tester) async {
      // The finding, pinned. `_CategoryTile._label` maps `account` to
      // `customerProfileSectionSupport` — the same key the section heading
      // above the list uses — and `dispute` to `disputeStatusSupportCta`, which
      // is also this screen's own app-bar title.
      await pumpPreview(tester, supportTicketScreenFormEmpty);

      // "Support": once as the section heading, once as the `account` option.
      expect(find.text('Support'), findsNWidgets(2));
      // "Contact support": once in the app bar, once as the `dispute` option.
      expect(find.text('Contact support'), findsNWidgets(2));
      // And the delivery option wears the bottom-nav label.
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('the required details field is labelled "(optional)" and the '
        'order field is labelled "Your Orders"', (WidgetTester tester) async {
      // Both findings, pinned. `canSubmit` requires a non-empty body; the label
      // on that field is `escalateCommentLabel`. The reference field borrows
      // `ordersTitle`, the order-HISTORY screen's title.
      await pumpPreview(tester, supportTicketScreenFormEmpty);

      expect(find.text('Additional details (optional)'), findsOneWidget);
      expect(find.text('Your Orders'), findsOneWidget);
    });

    testWidgets('"ready to submit" renders an EMPTY details box over a live '
        'Submit', (WidgetTester tester) async {
      // The headline finding, pinned on the Screen Catalog's own designed
      // state. `_BodyField` builds an `OmdsTextField` with an `onChanged` and no
      // `controller`, and `OmdsTextField` has no `initialValue` — it forwards
      // `controller` straight to `TextField` — so the text this ticket will be
      // submitted with cannot be rendered at all.
      await pumpPreview(tester, supportTicketScreenReadyToSubmit);

      expect(_submitEnabled(tester), isTrue);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      // The body is on the cubit …
      expect(
        find.textContaining('My delivery never arrived'),
        findsNothing,
        reason: 'the seeded body reaches no pixel of the form',
      );
      // … and every editable field on the card is empty.
      expect(_fieldTexts(tester), <String>['', '']);
    });

    testWidgets('a category the role cannot SEE leaves no radio filled and the '
        'CTA live', (WidgetTester tester) async {
      // The finding, pinned. `_visibleCategories` hides `payment` from a
      // client while `SupportCubit` holds it quite happily — which is exactly
      // what the Screen Catalog's own `Error — network failure` state seeds.
      await pumpPreview(tester, supportTicketScreenHiddenCategory);

      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.text('Earnings'), findsNothing);
      // …and the gate is open anyway.
      expect(_submitEnabled(tester), isTrue);
    });

    testWidgets('a jeeber sees six categories, and the field seams that DO '
        'work', (WidgetTester tester) async {
      await pumpPreview(tester, supportTicketScreenJeeberCategories);

      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsNWidgets(5),
      );
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Appeal via support'), findsOneWidget);

      // `_OrderLinkField` IS a StatefulWidget seeded from `state.orderRef`, so
      // this field round-trips. Read beside the empty details box above: two
      // fields on one form, two different contracts.
      expect(_fieldTexts(tester), contains('REQ-4821'));
    });

    testWidgets('five attachments read as five different counters, and the '
        'add button vanishes', (WidgetTester tester) async {
      // The finding, pinned. `_AttachSection` labels chip `i` with
      // `escalatePhotoAttached(i + 1)` — the plural "{count} of 5 attached" —
      // so the row is five claims about the same set. `if (paths.length < 5)`
      // then drops the CTA with nothing in its place.
      await pumpPreview(tester, supportTicketScreenAttachmentsAtCap);

      for (int i = 1; i <= 5; i++) {
        expect(find.text('$i of 5 attached'), findsOneWidget);
      }
      expect(find.bySemanticsIdentifier('support_attach'), findsNothing);
      expect(find.text('Add photo'), findsNothing);
      // Nothing says WHY it went.
      expect(find.textContaining('maximum'), findsNothing);
      expect(find.textContaining('limit'), findsNothing);
    });

    testWidgets('submitting replaces the whole draft with a spinner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, supportTicketScreenSubmitting);

      expect(find.bySemanticsIdentifier('support_submitting'), findsOneWidget);
      expect(find.text('Submitting…'), findsOneWidget);
      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // The form is gone — draft, attachments, dispute link and CTA together.
      expect(find.bySemanticsIdentifier('support_submit_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('support_dispute_link'), findsNothing);
      // …and the app bar's back button is still live throughout: leaving mid
      // flight takes the ticket with it.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('the confirmation never shows the ticket reference', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `SupportCubit` stores the created ticket's id and
      // `_ConfirmationView` renders three fixed strings — the escalation flow's
      // copy — and a Done button.
      await pumpPreview(tester, supportTicketScreenSuccess);

      expect(find.bySemanticsIdentifier('support_success'), findsOneWidget);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(
        find.text(
          'Our team will review your case and respond within 24 hours.',
        ),
        findsOneWidget,
      );
      // The id the repository returned reaches no pixel. Scoped to the
      // confirmation body — the dev caption above the frame is the only place
      // on the card that says "ticket" at all, which is itself the point.
      final Finder confirmation = find.bySemanticsIdentifier('support_success');
      for (final String fragment in const <String>[
        'ticket-preview-902',
        'ticket',
        'reference',
        '#',
      ]) {
        expect(
          find.descendant(
            of: confirmation,
            matching: find.textContaining(fragment),
          ),
          findsNothing,
          reason: fragment,
        );
      }
    });

    testWidgets('the offline error promises an automatic retry nothing '
        'implements', (WidgetTester tester) async {
      // The finding, pinned. `escalateErrorNetwork` says the report "will be
      // retried automatically"; nothing in `SupportCubit` queues, persists or
      // re-sends it.
      await pumpPreview(tester, supportTicketScreenNetworkError);

      expect(find.bySemanticsIdentifier('support_error'), findsOneWidget);
      expect(
        find.text(
          'No internet connection. Your report will be retried automatically.',
        ),
        findsOneWidget,
      );
      // The one affordance is labelled "Submit" and calls `retryFromError()`,
      // which returns to the form rather than re-sending anything.
      expect(find.bySemanticsIdentifier('support_retry_cta'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('an expired session is told only that something went wrong', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `_ErrorView._message` folds `unauthorized` in with
      // `unknown` and `null`, so a 401 is pixel-identical to an unclassified
      // failure.
      await pumpPreview(tester, supportTicketScreenSessionExpired);

      expect(find.text("Couldn't submit. Please try again."), findsOneWidget);
      final Finder errorBody = find.bySemanticsIdentifier('support_error');
      for (final String word in const <String>[
        'session',
        'sign in',
        'Sign in',
        'expired',
      ]) {
        expect(
          find.descendant(of: errorBody, matching: find.textContaining(word)),
          findsNothing,
          reason: word,
        );
      }
    });

    testWidgets('retrying out of an error restores the order ref and loses the '
        'body, with Submit still live', (WidgetTester tester) async {
      // The finding, pinned end to end. `retryFromError()` only flips the phase
      // back to `inputting`; the `BlocBuilder` swaps `_ErrorView` for a FRESH
      // `_SupportForm`, so `_OrderLinkField` re-seeds its controller from
      // `state.orderRef` and `_BodyField` — which has no controller to seed —
      // comes back empty. `SupportState.body` is untouched, so `canSubmit` is
      // still true and the next tap re-sends text the user can no longer read.
      await pumpPreview(tester, supportTicketScreenSessionExpired);
      expect(find.bySemanticsIdentifier('support_error'), findsOneWidget);

      final Finder retry = find.bySemanticsIdentifier('support_retry_cta');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      // Back on the form.
      expect(find.bySemanticsIdentifier('support_submit_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('support_error'), findsNothing);

      // The reference survived …
      expect(_fieldTexts(tester), contains('REQ-4821'));
      // … the body did not, on screen …
      expect(
        _fieldTexts(tester),
        isNot(contains(kSupportTicketScreenSessionExpiredBody)),
      );
      expect(
        find.textContaining('the jeeber stopped'),
        findsNothing,
        reason: 'the typed body reaches no pixel of the returning form',
      );
      // … and the gate the invisible body opens is still open.
      expect(_submitEnabled(tester), isTrue);
    });

    testWidgets('the longest content wraps rather than clipping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, supportTicketScreenLongestContent);

      // The UUID-shaped reference is in the field, at full length.
      expect(
        _fieldTexts(tester),
        contains(kSupportTicketScreenLongOrderRef),
      );
      // Six categories, the longest label selected, five chips.
      expect(find.text('Appeal via support'), findsOneWidget);
      expect(find.text('5 of 5 attached'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // …and 380 characters of body still reach nothing.
      expect(find.textContaining('concierge'), findsNothing);
    });

    testWidgets('the compact frame survives the ceiling in EN and AR, measured '
        'through the real faces', (WidgetTester tester) async {
      // Measured through `withGoldenTestFonts`, so the Arabic here is Noto Sans
      // Arabic rather than the 1-em test face. The form scrolls, so the ceiling
      // costs reach rather than layout in both directions.
      await _pumpWithFonts(tester, supportTicketScreenCompact);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SupportTicketScreen)).width, 320);

      await _pumpWithFonts(
        tester,
        supportTicketScreenCompact,
        locale: const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SupportTicketScreen)).width, 320);
      expect(find.text('استئناف عبر الدعم'), findsOneWidget);
    });
  });
}
