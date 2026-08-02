// Render tests for the RequestSummaryScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Eight previews, ONE screen, one input. Every state is the same `ListView` of
// the same `_SectionCard`s behind the same app bar, differing only in the
// `RequestDraft` it was seeded with and whether a submit was driven — so "did
// something render" is close to worthless here: a preview rewired to the wrong
// draft would still show an app bar, some cards and a CTA. Each state therefore
// pins a string only IT can produce.
//
// The groups below then pin what the preview section claims about this screen,
// so those claims fail here rather than rot in a comment: the review is
// READ-ONLY (a tier-card tap arrives with an empty description and no way to
// fix it), it hides `recipientPhone` (the number the at-door handover OTP is
// sent to), its only failure surface is a four-second snackbar carrying
// hardcoded ENGLISH, and success leaves nothing behind.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/request_summary_screen_fixtures.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';

import '../preview_test_harness.dart';

/// The full draft's description — the string the Screen Catalog's three states
/// are signed off against. Declared here rather than read off the fixture so a
/// preview quietly rewired to a different draft fails instead of agreeing with
/// itself.
const String _fullDescription =
    'Pick up my prescription from Pharmacie Beshara.';

/// The floor state's description.
const String _descriptionOnly = 'Two bags of ice from the corner shop, please.';

/// The Speed card of a tier-CARD tap: the raw `TierId` enum name, lowercase and
/// untranslated. The full draft carries the localized `Express` instead, so this
/// exact string belongs to that preview alone.
const String _rawTierId = 'express';

/// The longest draft's photo line — twelve files the client cannot look at,
/// counted in copy that never pluralizes.
const String _twelvePhotos = '12 photo(s) attached';

/// The submit CTA, and the whole of what changes between idle and in-flight.
const String _submitCta = 'Send request';

/// `RequestSummaryCubit._messageFor(network)` — a literal in the cubit, not an
/// ARB lookup. See the AR test below.
const String _networkErrorEn =
    'No connection. Check your network and try again.';

/// `requestSummaryErrorNetwork` as it is really translated. Three OTHER screens
/// render this string; this one cannot reach it.
const String _networkErrorAr =
    'تعذّر الاتصال بجيب. تحقق من الإنترنت وحاول مجددًا.';

/// The app-bar title in both shipped locales.
const String _titleEn = 'Review & submit';
const String _titleAr = 'مراجعة وإرسال';

/// The canvas box every preview in this file declares — a real phone, because
/// a list of cards under an app bar cannot be judged in the harness's default
/// 800x600 strip.
const Size _phoneBox = Size(390, 844);

/// The six card titles, in the order `_RequestSummaryBody` emits them.
const List<String> _cardTitles = <String>[
  'Description',
  'Transcription',
  'Photos',
  'Speed',
  'Pickup',
  'Drop-off',
];

void main() {
  setUpAll(loadPreviewArbs);

  /// Pumps a preview at the box it declares rather than at the harness's
  /// 800x600 default, in logical pixels at dpr 1.
  ///
  /// Not cosmetic: the CTA is the LAST child of a lazy `ListView`, and with the
  /// full draft's six cards it is outside the built range on the 800x600
  /// surface — `find.byType(OmdsLoadingButton)` returns nothing there. Every
  /// assertion about the submit button therefore has to be made in the window
  /// the preview actually declares.
  ///
  /// [settle] is off for the two previews holding an indeterminate
  /// `CircularProgressIndicator`: its controller repeats forever, so
  /// `pumpAndSettle` never returns on them.
  Future<void> pumpAtBox(
    WidgetTester tester,
    Widget Function() preview, {
    Locale locale = const Locale('en'),
    double textScale = 1.0,
    Size size = _phoneBox,
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(previewCanvas(preview, locale));
    if (settle) {
      await tester.pumpAndSettle();
      return;
    }
    // Mount, the seeded `setDraft` emit, the driven `submit()` emit, then one
    // frame of the spinner.
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  // Every preview whose surface actually settles. `Submitting · in flight` and
  // `No draft · bare spinner` hold a spinner (see [pumpAtBox]); they get the
  // same three assertions in the dedicated groups below, driven by fixed pumps.
  testPreviewsRender(
    'RequestSummaryScreen',
    const <String, Widget Function()>{
      'Full draft · every section': requestSummaryScreenFullDraft,
      'Description only · optionals absent': requestSummaryScreenDescriptionOnly,
      'Tier-card entry · empty description': requestSummaryScreenTierCardEntry,
      'Longest content': requestSummaryScreenLongest,
      'Error · network': requestSummaryScreenErrorNetwork,
      'Submitted · navigates away': requestSummaryScreenSubmitted,
    },
    // The app-bar title is shared by all six (and by the sibling
    // `RequestSummaryUnavailableScreen`), so none of these may be pinned by it.
    expectedText: const <String, String>{
      'Full draft · every section': _fullDescription,
      'Description only · optionals absent': _descriptionOnly,
      // The defect IS the pin: the localized label would read `Express`.
      'Tier-card entry · empty description': _rawTierId,
      'Longest content': _twelvePhotos,
      // The card list is identical to `Full draft`; the snackbar is the only
      // thing that tells this state apart.
      'Error · network': _networkErrorEn,
      // …and this one has no card list left at all.
      'Submitted · navigates away':
          RequestSummaryScreenPreviewHost.requestsTabCaption,
    },
  );

  group('RequestSummaryScreen previews · Submitting · in flight', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Submitting · in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpAtBox(
          tester,
          requestSummaryScreenSubmitting,
          locale: locale,
          settle: false,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Submitting · in flight renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpAtBox(
        tester,
        requestSummaryScreenSubmitting,
        settle: false,
      );

      // This state has NO string of its own — the cards are the full draft's,
      // unchanged and at full contrast — so it is pinned by the one thing that
      // does change: the CTA has swapped its label for a spinner and stopped
      // accepting taps. Everything else on screen still says "nothing is
      // happening", which is the point of looking at this preview.
      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byType(OmdsLoadingButton),
      );
      expect(cta.isLoading, isTrue);
      expect(find.text(_submitCta), findsNothing);
      expect(
        find.descendant(
          of: find.byType(OmdsLoadingButton),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text(_fullDescription), findsOneWidget);
      expect(find.text(_titleEn), findsOneWidget);
    });
  });

  group('RequestSummaryScreen previews · No draft · bare spinner', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('No draft · bare spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpAtBox(
          tester,
          requestSummaryScreenNoDraft,
          locale: locale,
          settle: false,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('No draft · bare spinner renders its own state — and it is a '
        'dead end', (WidgetTester tester) async {
      await pumpAtBox(tester, requestSummaryScreenNoDraft, settle: false);

      // `build` returns `const OmdsLoadingState()` from ABOVE the `Scaffold`,
      // so this state has no app bar, no title and no back affordance: a
      // spinner on an empty surface with no way off it. The shipped route
      // cannot produce it (`app_router.dart` substitutes
      // `RequestSummaryUnavailableScreen` on a bad `extra`, and seeds the draft
      // inside the provider) — but it IS the cubit's initial state, so any
      // future caller that forgets `setDraft` strands the user here.
      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text(_titleEn), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      // …and none of the populated surface.
      expect(find.byType(Card), findsNothing);
      expect(find.text(_submitCta), findsNothing);
    });
  });

  group('RequestSummaryScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // UPDATES the host element rather than replacing it, so the first
    // preview's cubit — and any submit already driven through it — survives
    // into the second.

    testWidgets('the review is READ-ONLY: no input control anywhere', (
      WidgetTester tester,
    ) async {
      // Every value on this screen is a bare `Text`. That is fine for a draft
      // assembled upstream and fatal for the one entry point that assembles
      // nothing — see the next test.
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(TextField), findsNothing);
      // The CTA is the only control in the body.
      expect(find.text(_submitCta), findsOneWidget);
    });

    testWidgets('DEFECT: a tier-card tap arrives with an EMPTY description, '
        'and Send request is live anyway', (WidgetTester tester) async {
      // `app_router.dart` builds `RequestDraft(description: '', tierId:
      // tier.id.name, tierName: tier.id.name)` for `onTierSelected`, with the
      // comment "the user fills it on the summary screen". There is nothing to
      // fill it with, so the Description card is a title over a blank line and
      // the CTA submits the empty string.
      await pumpAtBox(tester, requestSummaryScreenTierCardEntry);

      expect(find.text('Description'), findsOneWidget);
      expect(
        find.text(''),
        findsOneWidget,
        reason: 'the blank description line',
      );
      expect(find.byType(EditableText), findsNothing);

      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byType(OmdsLoadingButton),
      );
      expect(cta.isLoading, isFalse);
      expect(cta.isEnabled, isTrue);

      // The ARB has carried the placeholder for this all along —
      // `requestSummaryDescriptionEmpty` ("No description provided"), described
      // as "Placeholder body shown when the description is empty on the summary
      // screen", translated in EN and AR and referenced by NO Dart file.
      expect(find.text('No description provided'), findsNothing);
    });

    testWidgets('DEFECT: the same tap shows the raw enum id as the Speed', (
      WidgetTester tester,
    ) async {
      // `tierName: tier.id.name` — so the Speed card reads `express`,
      // lowercase and untranslated, where the localized tier label belongs. In
      // AR that is latin text in an RTL paragraph.
      await pumpAtBox(
        tester,
        requestSummaryScreenTierCardEntry,
        locale: const Locale('ar'),
      );

      expect(
        find.text('السرعة'),
        findsOneWidget,
        reason: 'the card TITLE is localized',
      );
      expect(find.text(_rawTierId), findsOneWidget, reason: 'its value is not');
      expect(
        Directionality.of(tester.element(find.byType(RequestSummaryScreen))),
        TextDirection.rtl,
      );
    });

    testWidgets('DEFECT: recipientPhone is on the draft and off the screen', (
      WidgetTester tester,
    ) async {
      // The number the at-door handover OTP is dispatched to (T-BE-019 /
      // JEB-55) and the one field on a review screen a client would most want
      // to check before committing. `_RequestSummaryBody` has no card for it.
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      expect(find.textContaining('+96170123456'), findsNothing);
      // The six cards that DO render, so the omission reads as a gap in a list
      // that is otherwise complete.
      for (final String title in _cardTitles) {
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('DEFECT: the photo card counts files it never shows, in copy '
        'that never pluralizes', (WidgetTester tester) async {
      // `requestSummaryPhotosAttached` is a plain `{count}` placeholder, not an
      // ICU plural — so ONE photo reads "1 photo(s) attached" — and no
      // thumbnail is rendered, so a client cannot check WHICH photos are
      // attached.
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      expect(find.text('1 photo(s) attached'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(RequestSummaryScreen),
          matching: find.byType(Image),
        ),
        findsNothing,
      );
    });

    testWidgets('the longest draft grows the review instead of truncating it', (
      WidgetTester tester,
    ) async {
      // Nothing on this screen sets `maxLines`, so the review simply gets
      // longer and the `ListView` scrolls. That is the right behaviour, and it
      // is why the two card titles below are the ones this preview is pinned
      // by: on the phone box they are already past the fold (see the canvas-box
      // group), so this assertion is made on the wider harness surface.
      await pumpPreview(tester, requestSummaryScreenLongest);

      expect(find.text(_twelvePhotos), findsOneWidget);
      expect(find.text('Scheduled — tomorrow, before 9:00 am'), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DEFECT: the failure surface is an English snackbar in Arabic '
        'too', (WidgetTester tester) async {
      // `RequestSummaryCubit._messageFor` returns literals, so the AR user gets
      // English on a red bar — while `requestSummaryErrorNetwork` IS translated
      // in both ARBs and is rendered by three OTHER screens (tier_selection,
      // request_type, client_location).
      await pumpAtBox(
        tester,
        requestSummaryScreenErrorNetwork,
        locale: const Locale('ar'),
      );

      expect(
        find.text(_titleAr),
        findsOneWidget,
        reason: 'the screen itself IS localized',
      );
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(_networkErrorEn), findsOneWidget);
      expect(find.text(_networkErrorAr), findsNothing);
    });

    testWidgets('DEFECT: the snackbar is the ONLY trace of a failed submit', (
      WidgetTester tester,
    ) async {
      // `state.error` stays set but is never rendered in the body, the card
      // list returns to exactly its idle rendering, and `requestSummaryRetry`
      // ("Try again") is unused here. Four seconds later this screen is
      // indistinguishable from one that was never submitted.
      await pumpAtBox(tester, requestSummaryScreenErrorNetwork);

      expect(find.text(_networkErrorEn), findsOneWidget);
      // Idle again: the CTA is back and tappable, with no record of a failure.
      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byType(OmdsLoadingButton),
      );
      expect(cta.isLoading, isFalse);
      expect(cta.isEnabled, isTrue);
      expect(find.text(_submitCta), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      // The failure is not in the body at all — only in the transient bar.
      expect(
        find.descendant(
          of: find.byType(RequestSummaryScreen),
          matching: find.text(_networkErrorEn),
        ),
        findsNothing,
      );
    });

    testWidgets('the snackbar lands on the PAGE, not inside the screen', (
      WidgetTester tester,
    ) async {
      // `showOmdsErrorSnackbar` resolves the nearest `ScaffoldMessenger`, which
      // is the host `MaterialApp`'s — not this screen's own `Scaffold`. Worth
      // pinning because it is what the canvas draws, and because a screen that
      // later gains its own messenger would move the bar with no change here.
      await pumpAtBox(tester, requestSummaryScreenErrorNetwork);

      expect(
        find.descendant(
          of: find.byType(RequestSummaryScreen),
          matching: find.byType(SnackBar),
        ),
        findsNothing,
      );
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('DEFECT: success leaves nothing behind', (
      WidgetTester tester,
    ) async {
      // `context.go('/')` fires on the `isSubmitted` edge and the screen is
      // gone. `RequestSummaryState.requestId` — the id the gateway just minted,
      // `REQ-9001` here — is read by no widget in the app, so the client lands
      // back on a list with no confirmation that anything was created.
      await pumpAtBox(tester, requestSummaryScreenSubmitted);

      expect(find.byType(RequestSummaryScreen), findsNothing);
      expect(
        find.text(RequestSummaryScreenPreviewHost.requestsTabCaption),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(
        find.textContaining(
          RequestSummaryScreenFakeSubmissionService.mintedRequestId,
        ),
        findsNothing,
      );
    });

    testWidgets('the fixtures are network-free by construction', (
      WidgetTester tester,
    ) async {
      // The guard in `jeebPreviewHost` is the net, not the plan: the only
      // collaborator any of these previews builds is the local fake, so no
      // preview can reach `DioRequestSubmissionService`. This is the assertion
      // that fails if someone later "simplifies" the host onto the DI graph.
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      expect(find.byType(RequestSummaryScreenPreviewHost), findsOneWidget);
      expect(
        tester
            .widget<RequestSummaryScreenPreviewHost>(
              find.byType(RequestSummaryScreenPreviewHost),
            )
            .service,
        isA<RequestSummaryScreenFakeSubmissionService>(),
      );
    });
  });

  group('RequestSummaryScreen previews · at the declared canvas box', () {
    const Map<String, Widget Function()> settled = <String, Widget Function()>{
      'Full draft · every section': requestSummaryScreenFullDraft,
      'Description only · optionals absent': requestSummaryScreenDescriptionOnly,
      'Tier-card entry · empty description': requestSummaryScreenTierCardEntry,
      'Longest content': requestSummaryScreenLongest,
    };

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      for (final MapEntry<String, Widget Function()> entry in settled.entries) {
        testWidgets('${entry.key} · ${locale.languageCode} · 390x844', (
          WidgetTester tester,
        ) async {
          await pumpAtBox(tester, entry.value, locale: locale);

          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('at 100% the full review just fits: six cards and the CTA', (
      WidgetTester tester,
    ) async {
      // The reference measurement. Measured: the CTA occupies y 748–796 of an
      // 844 pt window, i.e. 48 pt of slack under it. It is the last child of a
      // scrolling `ListView`, not a pinned footer, so this is a near miss
      // rather than a guarantee — one more card, or one more line in any of
      // the six, pushes the control that commits the request off the screen.
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      final Rect cta = tester.getRect(find.byType(OmdsLoadingButton));
      expect(cta.bottom, lessThan(_phoneBox.height));
      for (final String title in _cardTitles) {
        expect(find.text(title), findsOneWidget);
      }
    });

    // The two previews the canvas draws as a matrix (EN light / AR RTL dark /
    // EN 200% text) are the two whose length swings by locale and by scaler, so
    // those are the renderings pinned at 200%. The body is a `ListView`, so
    // content cannot clip — it scrolls — and what 200% really costs is the CTA.
    for (final MapEntry<String, Widget Function()> entry
        in <String, Widget Function()>{
      'Full draft · every section': requestSummaryScreenFullDraft,
      'Longest content': requestSummaryScreenLongest,
    }.entries) {
      for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
        testWidgets(
          '${entry.key} scrolls rather than clips at 200% text · '
          '${locale.languageCode}',
          (WidgetTester tester) async {
            await pumpAtBox(
              tester,
              entry.value,
              locale: locale,
              textScale: 2.0,
            );

            expect(tester.takeException(), isNull);
            expect(find.byType(ListView), findsOneWidget);
          },
        );
      }
    }

    testWidgets('at 200% text the submit CTA is not on the screen at all', (
      WidgetTester tester,
    ) async {
      // The accessibility ceiling, and the reason the 48 pt of slack above
      // matters. At 200% only three of the six cards are laid out and the CTA
      // is not even built — a client at that setting has to scroll a review
      // screen to find the button that sends the request, with nothing on the
      // surface indicating there is more below.
      await pumpAtBox(
        tester,
        requestSummaryScreenFullDraft,
        textScale: 2.0,
      );

      expect(find.byType(OmdsLoadingButton), findsNothing);
      expect(find.text(_submitCta), findsNothing);
      expect(find.text(_fullDescription), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
