import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/request_summary_screen_fixtures.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';

import '../preview_test_harness.dart';

/// The full draft's description — the string the Screen Catalog's three states
const String _fullDescription =
    'Pick up my prescription from Pharmacie Beshara.';

/// The floor state's description.
const String _descriptionOnly = 'Two bags of ice from the corner shop, please.';

/// The Speed card of a tier-CARD tap: the raw `TierId` enum name, lowercase and
const String _rawTierId = 'express';

/// The longest draft's photo line — twelve files the client cannot look at,
const String _twelvePhotos = '12 photo(s) attached';

/// The submit CTA, and the whole of what changes between idle and in-flight.
const String _submitCta = 'Send request';

/// `RequestSummaryCubit._messageFor(network)` — a literal in the cubit, not an
const String _networkErrorEn =
    'No connection. Check your network and try again.';

/// `requestSummaryErrorNetwork` as it is really translated. Three OTHER screens
const String _networkErrorAr =
    'تعذّر الاتصال بجيب. تحقق من الإنترنت وحاول مجددًا.';

/// The app-bar title in both shipped locales.
const String _titleEn = 'Review & submit';
const String _titleAr = 'مراجعة وإرسال';

/// The canvas box every preview in this file declares — a real phone, because
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
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

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
    expectedText: const <String, String>{
      'Full draft · every section': _fullDescription,
      'Description only · optionals absent': _descriptionOnly,
      'Tier-card entry · empty description': _rawTierId,
      'Longest content': _twelvePhotos,
      'Error · network': _networkErrorEn,
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

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text(_titleEn), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.text(_submitCta), findsNothing);
    });
  });

  group('RequestSummaryScreen preview specifics', () {
    testWidgets('the review is READ-ONLY: no input control anywhere', (
      WidgetTester tester,
    ) async {
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(_submitCta), findsOneWidget);
    });

    testWidgets('DEFECT: a tier-card tap arrives with an EMPTY description, '
        'and Send request is live anyway', (WidgetTester tester) async {
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

      expect(find.text('No description provided'), findsNothing);
    });

    testWidgets('DEFECT: the same tap shows the raw enum id as the Speed', (
      WidgetTester tester,
    ) async {
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
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      expect(find.textContaining('+96170123456'), findsNothing);
      for (final String title in _cardTitles) {
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('DEFECT: the photo card counts files it never shows, in copy '
        'that never pluralizes', (WidgetTester tester) async {
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
      await pumpPreview(tester, requestSummaryScreenLongest);

      expect(find.text(_twelvePhotos), findsOneWidget);
      expect(find.text('Scheduled — tomorrow, before 9:00 am'), findsOneWidget);
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DEFECT: the failure surface is an English snackbar in Arabic '
        'too', (WidgetTester tester) async {
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
      await pumpAtBox(tester, requestSummaryScreenErrorNetwork);

      expect(find.text(_networkErrorEn), findsOneWidget);
      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byType(OmdsLoadingButton),
      );
      expect(cta.isLoading, isFalse);
      expect(cta.isEnabled, isTrue);
      expect(find.text(_submitCta), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
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
      await pumpAtBox(tester, requestSummaryScreenFullDraft);

      final Rect cta = tester.getRect(find.byType(OmdsLoadingButton));
      expect(cta.bottom, lessThan(_phoneBox.height));
      for (final String title in _cardTitles) {
        expect(find.text(title), findsOneWidget);
      }
    });

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
