// Render tests for the TranscriptionStatusBanner previews.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/features/transcription/presentation/widgets/transcription_status_banner.dart';

import '../preview_test_harness.dart';

/// Resolves a control through its Semantics identifier, the way the screen's
/// own test (`test/transcription_screen_test.dart`) targets it.
Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.identifier == identifier,
      description: 'Semantics(identifier: $identifier)',
    );

/// Pumps [preview] on a real phone-sized viewport instead of the 800x600 test
/// surface, optionally at a raised text scale. The banner is a Row whose text
Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview, {
  double width = 390,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TranscriptionStatusBanner',
    const <String, Widget Function()>{
      'Queued': transcriptionStatusBannerQueued,
      'Queued · retry ignored': transcriptionStatusBannerQueuedRetryIgnored,
      'Failed · network': transcriptionStatusBannerFailedNetwork,
      'Failed · payload too large':
          transcriptionStatusBannerFailedPayloadTooLarge,
      'Failed · generic, no retry':
          transcriptionStatusBannerFailedGenericNoRetry,
      'Failed · unclassified': transcriptionStatusBannerFailedUnclassified,
    },
    expectedText: const <String, String>{
      'Queued': 'Transcription is queued',
      'Queued · retry ignored': 'Your audio is saved and we\'ll transcribe it '
          'shortly. You can type your request now to keep moving.',
      'Failed · network':
          "We couldn't reach the server. Type your request below or retry.",
      'Failed · payload too large': 'The recording is too long. Type your '
          'request below or record a shorter clip.',
      'Failed · generic, no retry':
          'Something went wrong. Type your request below or retry.',
      'Failed · unclassified': 'Retry',
    },
  );

  group('TranscriptionStatusBanner preview specifics', () {
    testWidgets('queued is the info shape: schedule icon, no error copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transcriptionStatusBannerQueued);

      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.text('Transcription unavailable'), findsNothing);
    });

    testWidgets('queued never offers Retry, even when a handler is passed', (
      WidgetTester tester,
    ) async {
      // The gate is `isFailed && onRetry != null`. Loosening it to
      await pumpPreview(tester, transcriptionStatusBannerQueuedRetryIgnored);

      expect(find.text('Transcription is queued'), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.retryButton), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('failed + handler renders a tappable Retry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, transcriptionStatusBannerFailedNetwork);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.retryButton), findsOneWidget);

      await tester.tap(_byIdentifier(TranscriptionKeys.retryButton));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the screen-shaped failed banner renders no Retry button', (
      WidgetTester tester,
    ) async {
      // `TranscriptionScreen` builds `TranscriptionStatusBanner(state: state)`
      await pumpPreview(tester, transcriptionStatusBannerFailedGenericNoRetry);

      expect(find.textContaining('or retry.'), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.retryButton), findsNothing);
    });

    testWidgets('each failure reason picks its own body under one title', (
      WidgetTester tester,
    ) async {
      const String title = 'Transcription unavailable';
      const String network =
          "We couldn't reach the server. Type your request below or retry.";
      const String tooLarge = 'The recording is too long. Type your request '
          'below or record a shorter clip.';
      const String generic =
          'Something went wrong. Type your request below or retry.';

      await pumpPreview(tester, transcriptionStatusBannerFailedNetwork);
      expect(find.text(title), findsOneWidget);
      expect(find.text(network), findsOneWidget);
      expect(find.text(tooLarge), findsNothing);
      expect(find.text(generic), findsNothing);

      await pumpPreview(tester, transcriptionStatusBannerFailedPayloadTooLarge);
      expect(find.text(title), findsOneWidget);
      expect(find.text(tooLarge), findsOneWidget);
      expect(find.text(network), findsNothing);

      // `TranscriptionFailure.none` must fall through to the generic copy, not
      await pumpPreview(tester, transcriptionStatusBannerFailedUnclassified);
      expect(find.text(title), findsOneWidget);
      expect(find.text(generic), findsOneWidget);
      expect(find.text(network), findsNothing);
      expect(find.text(tooLarge), findsNothing);
    });

    testWidgets('Arabic localizes the banner and mirrors the icon/text row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        transcriptionStatusBannerQueued,
        locale: const Locale('ar'),
      );

      // No English leaks through in AR.
      expect(find.text('التحويل في قائمة الانتظار'), findsOneWidget);
      expect(find.text('Transcription is queued'), findsNothing);

      final Element icon = tester.element(find.byIcon(Icons.schedule));
      expect(Directionality.of(icon), TextDirection.rtl);

      // The icon leads the Row, so once mirrored it must sit to the RIGHT of
      final double iconX = tester.getCenter(find.byIcon(Icons.schedule)).dx;
      final double titleX =
          tester.getCenter(find.text('التحويل في قائمة الانتظار')).dx;
      expect(iconX, greaterThan(titleX));
    });

    testWidgets('Arabic localizes the Retry label too', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        transcriptionStatusBannerFailedNetwork,
        locale: const Locale('ar'),
      );

      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(_byIdentifier(TranscriptionKeys.retryButton), findsOneWidget);
    });

    testWidgets('the banner announces its title and body ONCE', (
      WidgetTester tester,
    ) async {
      // KNOWN DEFECT, pinned. `_BannerSurface` wraps the card in
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, transcriptionStatusBannerFailedNetwork);

      final SemanticsNode node = tester.getSemantics(
        find.byType(TranscriptionStatusBanner),
      );
      expect(node.label, contains('Transcription unavailable'));
      expect(node.label, contains("We couldn't reach the server"));

      final int titleCount =
          'Transcription unavailable'.allMatches(node.label).length;
      expect(
        titleCount,
        equals(2),
        reason: 'Expected the pinned duplicate announcement. 1 means the '
            'widget was fixed — flip this to equals(1). Anything else means '
            'the semantics container changed shape.',
      );

      // The handle must be disposed inside the test body — an `addTearDown`
      handle.dispose();
    });

    testWidgets('the longest English banner survives 390pt at 200% text', (
      WidgetTester tester,
    ) async {
      // The 200%-text rendering of the preview matrix, asserted. Title, body
      await _pumpOnPhone(
        tester,
        transcriptionStatusBannerFailedPayloadTooLarge,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      expect(_byIdentifier(TranscriptionKeys.retryButton), findsOneWidget);
    });

    testWidgets('the retry-less banner is clean at 320pt/200% in Arabic', (
      WidgetTester tester,
    ) async {
      // Isolates the defect pinned below: the same banner MINUS the Retry
      await _pumpOnPhone(
        tester,
        transcriptionStatusBannerFailedGenericNoRetry,
        width: 320,
        textScale: 2.0,
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('حدث خطأ ما. اكتب طلبك أدناه أو حاول مرة أخرى.'),
          findsOneWidget);
    });

    testWidgets('KNOWN DEFECT: the Arabic Retry label overflows its button', (
      WidgetTester tester,
    ) async {
      // `_RetryButton` hands the localized label to `OMDSOutlinedButton`, which
      await _pumpOnPhone(
        tester,
        transcriptionStatusBannerFailedPayloadTooLarge,
        width: 320,
        textScale: 1.3,
        locale: const Locale('ar'),
      );

      final Object? error = tester.takeException();
      expect(
        error,
        isA<FlutterError>(),
        reason: 'Expected the pinned RenderFlex overflow from the Arabic '
            'Retry label. No exception means the button now wraps its label — '
            'delete this test.',
      );
      expect(error.toString(), contains('overflowed'));
    });
  });
}
