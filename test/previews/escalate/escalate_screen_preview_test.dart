import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The screen's subtitle — rendered THREE times by one form. De
const String _kSubtitle =
    "Describe what went wrong and we'll connect you with our support team "
    'within 24 hours.';

/// The evidence panel's not-loaded placeholder. It is `escalate
const String _kSubmitting = 'Submitting…';

/// [previewCanvas] with the real font faces installed on the th
Widget _escalateScreenCanvas(Widget Function() preview, Locale locale) {
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

Future<void> _pumpWithRealFonts(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(_escalateScreenCanvas(preview, locale));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'EscalateScreen',
    const <String, Widget Function()>{
      'Reason picker · evidence loaded': escalateScreenReasonPicker,
      'Evidence pending · auto-attach in flight':
          escalateScreenEvidencePending,
      'Evidence degraded · empty panel': escalateScreenEvidenceDegraded,
      'Evidence complete · photo cap reached': escalateScreenEvidenceComplete,
      'Error · network': escalateScreenErrorNetwork,
      'Error · already open (no retry)': escalateScreenErrorAlreadyOpen,
      'Longest content · compact 320': escalateScreenCompactCeiling,
    },
    expectedText: const <String, String>{
      'Reason picker · evidence loaded': 'Conversations (12)',
      'Evidence pending · auto-attach in flight': _kSubmitting,
      'Evidence degraded · empty panel': 'Live tracking',
      'Evidence complete · photo cap reached': 'Photo 5',
      'Error · network':
          'No internet connection. Your report will be retried automatically.',
      'Error · already open (no retry)':
          'A report for this delivery is already open.',
      'Longest content · compact 320': 'Conversations (248)',
    },
  );

  group('EscalateScreen previews · Submitting', () {
    Future<void> pumpSubmitting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(escalateScreenSubmitting, locale));
      await tester.pump(); // the pre-driven submit() emit
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Submitting · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSubmitting(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Submitting renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSubmitting(tester);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.text(_kSubmitting), findsOneWidget);
      expect(find.text('Damaged item'), findsNothing);
      expect(find.text('Submit Report'), findsNothing);
      expect(find.text('Back to chat'), findsNothing);
    });
  });

  group('EscalateScreen preview specifics', () {

    testWidgets('the pending panel is the EVIDENCE read, not a submit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenEvidencePending);

      expect(find.text(_kSubmitting), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
      expect(find.text('Damaged item'), findsOneWidget);
      expect(find.textContaining('Conversations'), findsNothing);
      expect(find.text('Live tracking'), findsNothing);
      expect(find.text('Ordered'), findsNothing);
    });

    testWidgets('a resolved panel lists the timeline; a degraded one lists '
        'nothing', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenReasonPicker);

      expect(find.text('Ordered'), findsOneWidget);
      expect(find.text('Picked'), findsOneWidget);
      expect(find.text('In transit'), findsOneWidget);
      expect(find.text('Live tracking'), findsNothing);
    });

    testWidgets('the degraded panel is indistinguishable from "no evidence '
        'exists"', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenEvidenceDegraded);

      expect(find.text('Conversations'), findsOneWidget);
      expect(find.textContaining('Conversations ('), findsNothing);
      expect(find.text('Live tracking'), findsOneWidget);
      expect(find.text('Ordered'), findsNothing);
    });

    testWidgets('the subtitle string is rendered THREE times by one form', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenReasonPicker);

      expect(find.text(_kSubtitle), findsNWidgets(3));
    });

    testWidgets('reaching the photo cap REMOVES the only add-photo control', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenEvidenceComplete);

      expect(find.byType(OmdsChip), findsNWidgets(5));
      expect(find.text('Photo 1'), findsOneWidget);
      expect(find.text('Photo 5'), findsOneWidget);
      expect(find.textContaining('of 5 attached'), findsNothing);
      expect(find.text('Recording ready'), findsOneWidget);
      expect(
        tester
            .widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isTrue,
      );
    });

    testWidgets('the untouched form offers the CTA and disables Submit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, escalateScreenReasonPicker);

      expect(find.text('0 of 5 attached'), findsOneWidget);
      expect(find.byType(OmdsChip), findsNothing);
      expect(
        tester
            .widget<OmdsPrimaryButton>(find.byType(OmdsPrimaryButton))
            .isEnabled,
        isFalse,
        reason: 'canSubmit is reason != null',
      );
    });

    testWidgets('a network failure keeps a retry', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenErrorNetwork);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Submit Report'), findsNothing);
    });

    testWidgets('an already-open dispute is a dead end — no retry, no link to '
        'the dispute that exists', (WidgetTester tester) async {
      await pumpPreview(tester, escalateScreenErrorAlreadyOpen);

      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Contact support'), findsNothing);
    });
  });

  group('EscalateScreen preview geometry · real fonts', () {
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      await _pumpWithRealFonts(tester, escalateScreenReasonPicker);

      expect(tester.getSize(find.byType(EscalateScreen)).width, 390);
    });

    testWidgets('the ceiling preview pins the 320 pt floor', (
      WidgetTester tester,
    ) async {
      await _pumpWithRealFonts(tester, escalateScreenCompactCeiling);

      expect(tester.getSize(find.byType(EscalateScreen)).width, 320);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the 320 pt ceiling lays out clean in '
          '${locale.languageCode}', (WidgetTester tester) async {
        await _pumpWithRealFonts(
          tester,
          escalateScreenCompactCeiling,
          locale: locale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
