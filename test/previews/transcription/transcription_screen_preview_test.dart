// Render tests for the TranscriptionScreen previews.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// The ready fixture's transcript, verbatim
/// (`transcription_screen_fixtures.dart`). The only string that state renders
const String _kReadyTranscript =
    'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.';

/// The longest fixture's transcript, verbatim — 59 s of speech, one second
/// under the recorder's cap.
const String _kLongestTranscript =
    'Please go to the Spinneys on Verdun street and pick up two bags of '
    'basmati rice, a five litre water gallon, one kilo of tomatoes, half a '
    'kilo of green beans, a pack of pita bread and two boxes of laban. If '
    'the green beans do not look fresh please take zucchini instead, and '
    'call me before you pay so I can confirm the total.';

/// The no-audio fixture's transcript, verbatim.
const String _kNoAudioTranscript =
    'Bring me bread from the bakery on the corner.';

/// `transcriptionFieldHint` — the placeholder the queued and failed states show
/// INSTEAD of a field.
const String _kTypeHint = 'Type your request here';

/// `transcriptionFailedNetwork`. Note the tail: the copy promises a retry the
/// screen does not wire.
const String _kFailedNetworkBody =
    "We couldn't reach the server. Type your request below or retry.";

/// `transcriptionQueuedBody`. Note the tail: the copy promises typing the
/// screen does not offer.
const String _kQueuedBody =
    "Your audio is saved and we'll transcribe it shortly. You can type your "
    'request now to keep moving.';

/// `transcriptionReRecord` / `transcriptionSubmit` / `transcriptionEdit`.
const String _kReRecord = 'Re-record';
const String _kSend = 'Send to Jeeb';
const String _kEdit = 'Edit text';

/// [previewCanvas] with the real font faces installed on the theme.
/// The shared canvas builds `AppTheme.light()` unmodified and the theme carries
Widget _transcriptionScreenCanvas(
  Widget Function() preview,
  Locale locale, {
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
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

/// Pumps [preview] at a real device box with real fonts and returns any
/// overflow reports.
Future<List<String>> _pumpAtBox(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  Size box = const Size(390, 844),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  await tester.binding.setSurfaceSize(box);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final List<String> seen = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    seen.add(details.exceptionAsString());
  };
  await tester.pumpWidget(
    _transcriptionScreenCanvas(preview, locale, brightness: brightness),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  FlutterError.onError = previous;

  return seen
      .where((String s) => s.contains('overflowed'))
      .toList(growable: false);
}

/// Finds a widget carrying the given `Semantics` identifier — the same
/// resolution `test/transcription_screen_test.dart` uses, so these assertions
Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
  (Widget w) => w is Semantics && w.properties.identifier == identifier,
  description: 'Semantics(identifier: $identifier)',
);

/// WCAG 2.x relative luminance.
double _relativeLuminance(Color c) {
  double channel(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG 2.x contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The Re-record button's own background/label pair, as laid out.
({Color background, Color label}) _reRecordColors(WidgetTester tester) {
  final Finder button = _byIdentifier(TranscriptionKeys.reRecordButton);
  final Container container = tester.widget<Container>(
    find.descendant(of: button, matching: find.byType(Container)).first,
  );
  final Text label = tester.widget<Text>(
    find.descendant(of: button, matching: find.byType(Text)).first,
  );
  return (
    background: (container.decoration! as BoxDecoration).color!,
    label: label.style!.color!,
  );
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'TranscriptionScreen',
    const <String, Widget Function()>{
      'Ready · transcript to review': transcriptionScreenReady,
      'Queued · no transcript yet': transcriptionScreenQueued,
      'Failed · network': transcriptionScreenFailedNetwork,
      'Editing · text field open': transcriptionScreenEditing,
      'Longest content · compact 320': transcriptionScreenLongestCompact,
      'No audio · transcript only': transcriptionScreenNoAudio,
    },
    expectedText: const <String, String>{
      // The machine transcript itself. `Ready` is also the only state with no
      'Ready · transcript to review': _kReadyTranscript,
      // `transcriptionQueuedTitle`, reachable from no other state here: the
      'Queued · no transcript yet': 'Transcription is queued',
      // The network branch of `_bannerBody` — one of four mutually exclusive
      'Failed · network': _kFailedNetworkBody,
      // `transcriptionSaveEdit`. The editor is the only surface that renders
      'Editing · text field open': 'Done',
      // 59 s of speech in one `Text`.
      'Longest content · compact 320': _kLongestTranscript,
      // A distinct transcript, so this state cannot be confused with `Ready`
      'No audio · transcript only': _kNoAudioTranscript,
    },
  );

  group('TranscriptionScreen previews · surfaces', () {
    // Each state gets its own test: these previews differ by cubit state, and

    testWidgets('Ready renders the full review surface', (
      WidgetTester tester,
    ) async {
      await _pumpAtBox(tester, transcriptionScreenReady);

      expect(find.text(_kReadyTranscript), findsOneWidget);
      // Audio replay, the edit affordance, and both actions.
      expect(_byIdentifier(TranscriptionKeys.audioToggle), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.editButton), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.reRecordButton), findsOneWidget);
      // `_TranscriptionBody` mounts the banner only while status != ready.
      expect(find.text('Transcription is queued'), findsNothing);
      expect(find.text('Transcription unavailable'), findsNothing);
      // The 42 s fixture clip, unplayed.
      expect(find.text('00:00 / 00:42'), findsOneWidget);
    });

    testWidgets('No audio drops the replay card and nothing explains it', (
      WidgetTester tester,
    ) async {
      await _pumpAtBox(tester, transcriptionScreenNoAudio);

      expect(find.text(_kNoAudioTranscript), findsOneWidget);
      // `hasAudio` is false, so the whole card is gone — silently. There is no
      expect(_byIdentifier(TranscriptionKeys.audioToggle), findsNothing);
      expect(find.textContaining(' / 00:'), findsNothing);
      // Everything else is a normal ready surface, including an enabled Send
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.editButton), findsOneWidget);
    });

    testWidgets('Editing empties the bottom bar and offers no discard', (
      WidgetTester tester,
    ) async {
      await _pumpAtBox(tester, transcriptionScreenEditing);

      expect(_byIdentifier(TranscriptionKeys.textField), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      // `_TranscriptionActions` returns SizedBox.shrink() while editing.
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsNothing);
      expect(_byIdentifier(TranscriptionKeys.reRecordButton), findsNothing);
      expect(find.text(_kSend), findsNothing);
      expect(find.text(_kReRecord), findsNothing);
      // No Cancel either: `confirmEdit` commits the field verbatim, so an edit
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('TranscriptionScreen previews · KNOWN DEFECTS', () {
    // Every test in this group asserts a defect. If one starts FAILING, the

    // The finding. `_TranscriptionLabelRow` gates the "Edit text" action on
    testWidgets('KNOWN DEFECT: Queued asks the user to type and offers no '
        'field', (WidgetTester tester) async {
      await _pumpAtBox(tester, transcriptionScreenQueued);

      // The copy asking for input, twice over.
      expect(find.text(_kQueuedBody), findsOneWidget);
      expect(find.text(_kTypeHint), findsOneWidget);
      // And nothing to type into.
      expect(_byIdentifier(TranscriptionKeys.editButton), findsNothing);
      expect(_byIdentifier(TranscriptionKeys.textField), findsNothing);
      expect(find.byType(EditableText), findsNothing);
      expect(find.text(_kEdit), findsNothing);
      // Send is present but inert (`canConfirm` is false on empty text), so
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.reRecordButton), findsOneWidget);
    });

    // The same dead end on the error path, where it matters more: the failure
    testWidgets('KNOWN DEFECT: Failed says "type your request below" and '
        'offers no field', (WidgetTester tester) async {
      await _pumpAtBox(tester, transcriptionScreenFailedNetwork);

      expect(find.text(_kFailedNetworkBody), findsOneWidget);
      expect(find.text(_kTypeHint), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.editButton), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });

    // The finding. `_TranscriptionBody` builds `TranscriptionStatusBanner(state:
    testWidgets('KNOWN DEFECT: the failed banner promises a retry the screen '
        'never wires', (WidgetTester tester) async {
      await _pumpAtBox(tester, transcriptionScreenFailedNetwork);

      expect(find.text(_kFailedNetworkBody), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.retryButton), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    // The finding. `_ReRecordButton` hardcodes `textColor: onPrimary` onto an
    testWidgets('KNOWN DEFECT: the Re-record label is 1.4:1 in dark mode', (
      WidgetTester tester,
    ) async {
      await _pumpAtBox(
        tester,
        transcriptionScreenReady,
        brightness: Brightness.dark,
      );

      final ({Color background, Color label}) colors = _reRecordColors(tester);
      final double ratio = _contrastRatio(colors.background, colors.label);
      expect(
        ratio,
        lessThan(3.0),
        reason:
            'onPrimary (${colors.label}) on secondaryContainer '
            '(${colors.background}) measured ${ratio.toStringAsFixed(2)}:1 — '
            'WCAG 2.2 §1.4.3 asks 4.5:1 for body text',
      );
    });

    testWidgets('the same pairing is fine in light — which is why it shipped', (
      WidgetTester tester,
    ) async {
      await _pumpAtBox(tester, transcriptionScreenReady);

      final ({Color background, Color label}) colors = _reRecordColors(tester);
      expect(_contrastRatio(colors.background, colors.label),
          greaterThan(4.5));
    });

    // The finding. `_TranscriptionLabelRow` is a spaceBetween `Row` whose two
    for (final ({String locale, int pixels}) probe in const <({
      String locale,
      int pixels
    })>[
      (locale: 'en', pixels: 32),
      (locale: 'ar', pixels: 52),
    ]) {
      testWidgets('KNOWN DEFECT: the transcript label row overflows by '
          '${probe.pixels}px at 320pt/200% in ${probe.locale}', (
        WidgetTester tester,
      ) async {
        final List<String> overflows = await _pumpAtBox(
          tester,
          transcriptionScreenReady,
          locale: Locale(probe.locale),
          box: const Size(320, 844),
          textScale: 2.0,
        );

        expect(overflows, isNotEmpty);
        expect(overflows.first, contains('${probe.pixels} pixels'));
        expect(overflows.first, contains('on the right'));
      });
    }

    testWidgets('the same row is clean at 390pt/200% — it is a WIDTH defect', (
      WidgetTester tester,
    ) async {
      final List<String> overflows = await _pumpAtBox(
        tester,
        transcriptionScreenReady,
        locale: const Locale('ar'),
        box: const Size(390, 844),
        textScale: 2.0,
      );

      expect(overflows, isEmpty);
    });

    testWidgets('and clean at the compact box at 100% text — it is a SCALE '
        'defect too', (WidgetTester tester) async {
      final List<String> overflows = await _pumpAtBox(
        tester,
        transcriptionScreenLongestCompact,
        locale: const Locale('ar'),
        box: const Size(320, 568),
      );

      expect(overflows, isEmpty);
    });

    // The states with no transcript never render the row at all, which is why
    testWidgets('Queued cannot reproduce the overflow — it has no label row '
        'to overflow', (WidgetTester tester) async {
      final List<String> overflows = await _pumpAtBox(
        tester,
        transcriptionScreenQueued,
        locale: const Locale('ar'),
        box: const Size(320, 844),
        textScale: 2.0,
      );

      expect(overflows, isEmpty);
      expect(find.text(_kEdit), findsNothing);
    });
  });
}
