// Render tests for the TranscriptionStatusBanner previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`: build every state in both locales,
// and pin a DISTINCT string per state so the suite cannot pass while every
// preview renders the same banner.
//
// The banner has exactly two visual shapes (info/queued and error/failed) and
// four copy branches, so "it rendered" is a weak signal here — the specifics
// group below pins the branch each preview is supposed to be exercising.

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
/// column is `Expanded`; at 800pt wide the body never wraps and a broken
/// layout stays invisible.
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
      // `onRetry != null` would let a user re-fire a transcription that is
      // already queued.
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
      // with no `onRetry` (transcription_screen.dart:141), so the affordance
      // the class doc advertises is unreachable in the shipped flow — while the
      // copy still ends "…or retry". Pinned so a future wiring of `onRetry`
      // is a deliberate, visible change rather than an accident.
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
      // to an empty body: an unlabelled error card is worse than a vague one.
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
      // the title it labels.
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
      // `Semantics(container: true, label: '$title. $body')` while leaving the
      // two `Text` children to contribute their own labels, so the merged node
      // reads:
      //
      //   "Transcription unavailable. We couldn't reach the server. …
      //    Transcription unavailable
      //    We couldn't reach the server. …"
      //
      // i.e. TalkBack/VoiceOver say the whole banner twice. The fix is on the
      // widget (drop the explicit label, or add `excludeSemantics: true`),
      // which is out of scope for a preview-only change — this test is the
      // tripwire. When the widget is fixed, `titleCount` drops to 1 and this
      // expectation should be flipped to `equals(1)`.
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
      // runs after the framework's end-of-test handle verification.
      handle.dispose();
    });

    testWidgets('the longest English banner survives 390pt at 200% text', (
      WidgetTester tester,
    ) async {
      // The 200%-text rendering of the preview matrix, asserted. Title, body
      // and the Retry button share one `Expanded` column, so this is where a
      // fixed-height container would blow out. English is clean at every
      // width/scale combination probed (320/360/390 × 1.0–2.0).
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
      // button survives the narrowest phone at the accessibility ceiling in
      // Arabic. The title/body column wraps correctly; only the button does
      // not.
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
      // lays it out in `Row(mainAxisSize: MainAxisSize.min)` with the `Text`
      // unwrapped by any `Flexible` — so a label wider than the available
      // column overflows instead of wrapping or ellipsizing. Arabic
      // ("إعادة المحاولة") is far wider than "Retry", so only AR trips it:
      //
      //   width  first bad scale   overflow @2.0x
      //   320pt  1.15x (17px)      184px
      //   360pt  1.30x (6.8px)     144px
      //   390pt  1.50x (16px)      114px
      //
      // English is clean at every combination. The fix belongs to the button
      // (wrap the label in `Flexible`) or to `_RetryButton` (constrain it), so
      // it is out of scope for a preview-only change — this is the tripwire.
      // When the overflow is fixed this test starts failing: delete it and
      // fold the case into the clean-render tests above.
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
