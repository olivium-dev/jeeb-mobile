// Render tests for SupportTicketScreen previews.

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

/// Preview canvas with test fonts.
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

/// Check if submit CTA is enabled.
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

/// Get text from all editable fields.
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
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
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

      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.text('Earnings'), findsNothing);
      expect(find.text('Appeal via support'), findsNothing);

      expect(_submitEnabled(tester), isFalse);
      expect(_fieldTexts(tester), <String>['', '']);
    });

    testWidgets('four of the six category labels are borrowed from other '
        'screens', (WidgetTester tester) async {
      await pumpPreview(tester, supportTicketScreenFormEmpty);

      expect(find.text('Support'), findsNWidgets(2));
      expect(find.text('Contact support'), findsNWidgets(2));
      expect(find.text('Delivery'), findsOneWidget);
    });

    testWidgets('the required details field is labelled "(optional)" and the '
        'order field is labelled "Your Orders"', (WidgetTester tester) async {
      await pumpPreview(tester, supportTicketScreenFormEmpty);

      expect(find.text('Additional details (optional)'), findsOneWidget);
      expect(find.text('Your Orders'), findsOneWidget);
    });

    testWidgets('"ready to submit" renders an EMPTY details box over a live '
        'Submit', (WidgetTester tester) async {
      await pumpPreview(tester, supportTicketScreenReadyToSubmit);

      expect(_submitEnabled(tester), isTrue);
      expect(find.text('Delivery'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);

      expect(
        find.textContaining('My delivery never arrived'),
        findsNothing,
        reason: 'the seeded body reaches no pixel of the form',
      );
      expect(_fieldTexts(tester), <String>['', '']);
    });

    testWidgets('a category the role cannot SEE leaves no radio filled and the '
        'CTA live', (WidgetTester tester) async {
      await pumpPreview(tester, supportTicketScreenHiddenCategory);

      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(find.text('Earnings'), findsNothing);
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

      expect(_fieldTexts(tester), contains('REQ-4821'));
    });

    testWidgets('five attachments read as five different counters, and the '
        'add button vanishes', (WidgetTester tester) async {
      await pumpPreview(tester, supportTicketScreenAttachmentsAtCap);

      for (int i = 1; i <= 5; i++) {
        expect(find.text('$i of 5 attached'), findsOneWidget);
      }
      expect(find.bySemanticsIdentifier('support_attach'), findsNothing);
      expect(find.text('Add photo'), findsNothing);
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
      expect(find.bySemanticsIdentifier('support_submit_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('support_dispute_link'), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('the confirmation never shows the ticket reference', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, supportTicketScreenSuccess);

      expect(find.bySemanticsIdentifier('support_success'), findsOneWidget);
      expect(find.text('Report submitted'), findsOneWidget);
      expect(
        find.text(
          'Our team will review your case and respond within 24 hours.',
        ),
        findsOneWidget,
      );
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
      await pumpPreview(tester, supportTicketScreenNetworkError);

      expect(find.bySemanticsIdentifier('support_error'), findsOneWidget);
      expect(
        find.text(
          'No internet connection. Your report will be retried automatically.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('support_retry_cta'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('an expired session is told only that something went wrong', (
      WidgetTester tester,
    ) async {
      // The finding, pinned. `_ErrorView._message` folds `unauthorized` in with
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
      await pumpPreview(tester, supportTicketScreenSessionExpired);
      expect(find.bySemanticsIdentifier('support_error'), findsOneWidget);

      final Finder retry = find.bySemanticsIdentifier('support_retry_cta');
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('support_submit_cta'), findsOneWidget);
      expect(find.bySemanticsIdentifier('support_error'), findsNothing);

      expect(_fieldTexts(tester), contains('REQ-4821'));
      expect(
        _fieldTexts(tester),
        isNot(contains(kSupportTicketScreenSessionExpiredBody)),
      );
      expect(
        find.textContaining('the jeeber stopped'),
        findsNothing,
        reason: 'the typed body reaches no pixel of the returning form',
      );
      expect(_submitEnabled(tester), isTrue);
    });

    testWidgets('the longest content wraps rather than clipping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, supportTicketScreenLongestContent);

      expect(
        _fieldTexts(tester),
        contains(kSupportTicketScreenLongOrderRef),
      );
      expect(find.text('Appeal via support'), findsOneWidget);
      expect(find.text('5 of 5 attached'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('concierge'), findsNothing);
    });

    testWidgets('the compact frame survives the ceiling in EN and AR, measured '
        'through the real faces', (WidgetTester tester) async {
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
