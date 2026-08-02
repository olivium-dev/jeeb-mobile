// Render tests for the TranscriptionScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// ## Pinning a state on this screen means pinning its TRANSCRIPT
//
// All six previews are the same widget behind the same app bar, and the header
// ("We turned your voice into text") plus the two action labels survive almost
// every one of them — so a suite pinned on chrome would pass with every preview
// wired to the same fixture. Each state is therefore pinned on a string only IT
// can produce: the transcript text for the three states that have one, and the
// banner/affordance copy that is unique to the other three.
//
// ## Fonts
//
// `preview_test_harness.dart` deliberately does NOT load the real faces, so
// every glyph there is a 1-em square — Latin measures ~2x and Arabic ~2.4x what
// it does on a device. That is fine for "did this build and show its own
// state", which is all the shared suite claims. It is NOT fine for any claim
// about fitting, so every geometry assertion below goes through
// [_transcriptionScreenCanvas], the same canvas with `withGoldenTestFonts`
// applied: real Inter for Latin, a deterministic Noto subset for Arabic. The
// 320 pt overflow numbers were measured there and nowhere else.
//
// ## Why the geometry group forces a TALL box
//
// The screen's body is a `ListView`, which lays out only what is visible. At
// 320x568 with 200% text the transcript panel's label row is below the fold in
// English, so no overflow is reported — the row is never laid out, not fitted.
// [_pumpAtBox] defaults to an 844 pt height for that reason: the assertion is
// about the WIDTH, and the row has to be on screen for the width to mean
// anything. Scrolling to it in the canvas produces the same stripes.

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
/// and no other does.
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
///
/// The shared canvas builds `AppTheme.light()` unmodified and the theme carries
/// no `fontFamilyFallback`, so Arabic falls back to the 1-em test face there.
/// `withGoldenTestFonts` is what adds the deterministic Noto family, and only
/// through it is a measurement on this screen worth anything.
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
///
/// `FlutterError.onError` is intercepted rather than left to `takeException`
/// because several states DO overflow at 200% text, and a pending exception
/// would fail assertions that are not about that.
///
/// One pump per box: `RenderFlex` reports an overflow only when the overflow
/// AMOUNT changes, so re-pumping a second configuration into the same element
/// tree silently swallows an identical second report. Every configuration
/// measured below therefore gets its own `testWidgets`.
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
/// target what uiautomator targets.
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
      // banner, but a banner is an absence and absences do not pin.
      'Ready · transcript to review': _kReadyTranscript,
      // `transcriptionQueuedTitle`, reachable from no other state here: the
      // failed states render `transcriptionFailedTitle` instead.
      'Queued · no transcript yet': 'Transcription is queued',
      // The network branch of `_bannerBody` — one of four mutually exclusive
      // strings, and the only one this fixture's `TranscriptionFailure` picks.
      'Failed · network': _kFailedNetworkBody,
      // `transcriptionSaveEdit`. The editor is the only surface that renders
      // it, and it is the only control the editing state has.
      'Editing · text field open': 'Done',
      // 59 s of speech in one `Text`.
      'Longest content · compact 320': _kLongestTranscript,
      // A distinct transcript, so this state cannot be confused with `Ready`
      // even though both are `status: ready`.
      'No audio · transcript only': _kNoAudioTranscript,
    },
  );

  group('TranscriptionScreen previews · surfaces', () {
    // Each state gets its own test: these previews differ by cubit state, and
    // pumping a second one into the same tester reuses the first's element.

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
      // copy anywhere telling the user the recording did not survive.
      expect(_byIdentifier(TranscriptionKeys.audioToggle), findsNothing);
      expect(find.textContaining(' / 00:'), findsNothing);
      // Everything else is a normal ready surface, including an enabled Send
      // that will fire `onConfirm` with an EMPTY audioPath.
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
      // the user wants to abandon has nowhere to go.
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('TranscriptionScreen previews · KNOWN DEFECTS', () {
    // Every test in this group asserts a defect. If one starts FAILING, the
    // screen has been fixed — delete the test and strike the matching bullet
    // from the JEEB PREVIEWS section of
    // `lib/features/transcription/presentation/transcription_screen.dart`.

    // The finding. `_TranscriptionLabelRow` gates the "Edit text" action on
    // `showEdit: state.text.trim().isNotEmpty`, and `startEditing()` has no
    // other caller — so the editor is unreachable exactly when the transcript
    // is empty, which is the only time the user MUST type. The queued banner
    // asks them to; the placeholder is a `Container`, not a field; Send is
    // disabled because `canConfirm` is false. Nothing on the screen accepts
    // text.
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
      // Re-record is the only live control on the screen.
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.reRecordButton), findsOneWidget);
    });

    // The same dead end on the error path, where it matters more: the failure
    // copy explicitly says "Type your request below".
    testWidgets('KNOWN DEFECT: Failed says "type your request below" and '
        'offers no field', (WidgetTester tester) async {
      await _pumpAtBox(tester, transcriptionScreenFailedNetwork);

      expect(find.text(_kFailedNetworkBody), findsOneWidget);
      expect(find.text(_kTypeHint), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.editButton), findsNothing);
      expect(find.byType(EditableText), findsNothing);
    });

    // The finding. `_TranscriptionBody` builds `TranscriptionStatusBanner(state:
    // state)` with no `onRetry`, and the banner gates Retry on
    // `isFailed && onRetry != null`. The copy's "…or retry" points at nothing.
    testWidgets('KNOWN DEFECT: the failed banner promises a retry the screen '
        'never wires', (WidgetTester tester) async {
      await _pumpAtBox(tester, transcriptionScreenFailedNetwork);

      expect(find.text(_kFailedNetworkBody), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.retryButton), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    // The finding. `_ReRecordButton` hardcodes `textColor: onPrimary` onto an
    // `OMDSOutlinedButton`, whose background is `secondaryContainer`. That
    // pairing is a deliberate workaround in the light theme and it works; in
    // dark it puts #252B61 on #444559.
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
    // children are neither Flexible nor ellipsized, so both are laid out at
    // their full intrinsic width. Measured with real fonts on 288 pt of usable
    // width (320 pt minus `Spacing.medium` either side): EN 178.4 + 141.9 =
    // 320.3, AR 177.7 + 162.0 = 339.7.
    //
    // The box is 320x844, not the preview's 320x568: the ListView lays out only
    // what is visible, and at 568 pt the label row is below the fold in
    // English. The claim is about the width.
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
    // the overflow hid for so long: the two states a reviewer opens first to
    // check "does the error look right" are exactly the two that cannot show
    // it.
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
