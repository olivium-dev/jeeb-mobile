// Render tests for the TranscriptionAudioCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// The card renders no copy of its own — every glyph on it is either an icon or
// the `mm:ss / mm:ss` read-out — so a suite that only asked "did something
// render" would pass with all six previews showing the same clip. The
// `expectedText` pins below therefore key on the read-out, which is unique per
// state by construction.
//
// The specifics group pins the three things the preview matrix surfaced that no
// other test in the repo asserts: the card does not shrink-wrap, the progress
// track is invisible at 0%, and the RTL mirroring is half-done.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/features/transcription/presentation/widgets/transcription_audio_card.dart';

import '../preview_test_harness.dart';

/// A phone-width canvas, so the measurements below are the ones a 390 pt device
/// produces rather than the 800x600 test default.
void _usePhone(WidgetTester tester, {double height = 400}) {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

RenderBox _box(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderBox>(finder);

Offset _topLeft(WidgetTester tester, Finder finder) =>
    _box(tester, finder).localToGlobal(Offset.zero);

/// WCAG 2.x relative luminance / contrast ratio, so the §1.4.11 claim in the
/// preview's doc comment is asserted rather than asserted-in-prose.
double _luminance(Color c) {
  double channel(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Finder _toggle() => find.byWidgetPredicate(
      (Widget w) =>
          w is Semantics &&
          w.properties.identifier == TranscriptionKeys.audioToggle,
      description: 'Semantics(identifier: voice_transcript_audio_toggle)',
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TranscriptionAudioCard',
    const <String, Widget Function()>{
      'Idle at start': transcriptionAudioCardIdle,
      'Playing mid-clip': transcriptionAudioCardPlaying,
      'Finished': transcriptionAudioCardFinished,
      'Recorder cap': transcriptionAudioCardRecorderCap,
      'Unknown duration': transcriptionAudioCardUnknownDuration,
      'Bounded slot': transcriptionAudioCardBoundedSlot,
    },
    expectedText: const <String, String>{
      // One read-out per state; no pin can be satisfied by another's state.
      'Idle at start': '00:00 / 00:42',
      'Playing mid-clip': '00:17 / 00:42',
      'Finished': '00:42 / 00:42',
      'Recorder cap': '00:59 / 01:00',
      'Unknown duration': '00:00 / 00:00',
      'Bounded slot': '00:30 / 00:42',
    },
  );

  group('TranscriptionAudioCard preview specifics', () {
    testWidgets('the icon tracks isPlaying, and Finished shows PLAY not pause',
        (WidgetTester tester) async {
      Future<IconData?> iconOf(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return tester.widget<Icon>(find.byType(Icon)).icon;
      }

      expect(await iconOf(transcriptionAudioCardIdle),
          Icons.play_circle_filled);
      expect(await iconOf(transcriptionAudioCardPlaying),
          Icons.pause_circle_filled);
      // A spent clip is NOT paused — togglePlayback restarts from zero, so the
      // play glyph is the honest one even though the bar reads 100%.
      expect(await iconOf(transcriptionAudioCardFinished),
          Icons.play_circle_filled);
      expect(await iconOf(transcriptionAudioCardUnknownDuration),
          Icons.play_circle_filled);
    });

    testWidgets('progress is derived from the playhead, and zero duration does '
        'not divide by zero', (WidgetTester tester) async {
      Future<double?> progressOf(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value;
      }

      expect(await progressOf(transcriptionAudioCardIdle), 0.0);
      expect(await progressOf(transcriptionAudioCardPlaying),
          closeTo(17 / 42, 0.001));
      expect(await progressOf(transcriptionAudioCardFinished), 1.0);
      expect(await progressOf(transcriptionAudioCardRecorderCap),
          closeTo(59 / 60, 0.001));
      // The `total.inMilliseconds == 0` guard: a determinate 0.0, never NaN.
      final double? unknown =
          await progressOf(transcriptionAudioCardUnknownDuration);
      expect(unknown, 0.0);
      expect(unknown!.isNaN, isFalse);
    });

    testWidgets('the card shrink-wraps to 96 pt only because its parent hands '
        'it an unbounded main axis', (WidgetTester tester) async {
      _usePhone(tester);

      // Production geometry: `_hosted`'s MainAxisSize.min Column reproduces the
      // unbounded main axis the real ListView parent supplies.
      await pumpPreview(tester, transcriptionAudioCardPlaying);
      expect(
        _box(tester, find.byType(TranscriptionAudioCard)).size,
        const Size(390, 96),
      );
      // 16 pt of padding, then the 64 pt icon; the bar centres beside it.
      expect(_topLeft(tester, find.byType(IconButton)).dy, 16);
      expect(_topLeft(tester, find.byType(LinearProgressIndicator)).dy, 32);
    });

    testWidgets('in a height-bounded slot the card stretches and the control '
        'comes apart', (WidgetTester tester) async {
      _usePhone(tester);

      await pumpPreview(tester, transcriptionAudioCardBoundedSlot);
      final RenderBox card = _box(tester, find.byType(TranscriptionAudioCard));
      final Offset bar =
          _topLeft(tester, find.byType(LinearProgressIndicator));
      final Offset icon = _topLeft(tester, find.byType(IconButton));

      // _PlaybackProgress's Column is MainAxisSize.max, so the card takes the
      // whole 400 pt slot instead of its 96 pt of content...
      expect(card.size.height, 400);
      // ...leaving the bar pinned near the top while the Row centres the icon
      // 150 pt below it. No exception, no overflow stripe — it just separates.
      expect(bar.dy, lessThan(32));
      expect(icon.dy, greaterThan(150));
      expect(icon.dy - bar.dy, greaterThan(100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('RTL mirrors the bar AND the read-out, in step',
        (WidgetTester tester) async {
      _usePhone(tester);

      // English: icon leads, bar trails.
      await pumpPreview(tester, transcriptionAudioCardPlaying);
      final double barLeftEn =
          _topLeft(tester, find.byType(LinearProgressIndicator)).dx;
      final double iconLeftEn = _topLeft(tester, find.byType(IconButton)).dx;
      expect(iconLeftEn, lessThan(barLeftEn));

      // Arabic: the Row mirrors, so the icon is now on the trailing edge.
      await pumpPreview(
        tester,
        transcriptionAudioCardPlaying,
        locale: const Locale('ar'),
      );
      final double barLeftAr =
          _topLeft(tester, find.byType(LinearProgressIndicator)).dx;
      final double iconLeftAr = _topLeft(tester, find.byType(IconButton)).dx;
      expect(barLeftAr, lessThan(iconLeftAr));

      // And the unpinned '$position / $total' string reorders with it: elapsed
      // paints to the RIGHT of total, which is what keeps it in step with a bar
      // that now fills from the right. If someone ever pins this Text to LTR,
      // this expectation flips and the numbers stop matching the fill.
      final RenderParagraph readOut =
          tester.renderObject<RenderParagraph>(find.text('00:17 / 00:42'));
      final Rect elapsed = readOut
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 5),
          )
          .first
          .toRect();
      final Rect total = readOut
          .getBoxesForSelection(
            const TextSelection(baseOffset: 8, extentOffset: 13),
          )
          .first
          .toRect();
      expect(elapsed.left, greaterThan(total.left));
    });

    testWidgets('the play/pause glyph does NOT mirror, unlike everything else '
        'in the card', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        transcriptionAudioCardPlaying,
        locale: const Locale('ar'),
      );

      // Icons.play_circle_filled / pause_circle_filled carry no
      // matchTextDirection, so the triangle keeps pointing right in Arabic
      // while the playhead it controls now travels leftwards.
      final Icon icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon!.matchTextDirection, isFalse);
      // `Icon.build` only inserts the flipping Transform when the IconData opts
      // in AND the ambient direction is RTL. Directionality here IS rtl (the
      // bar mirrored), so the absence of that Transform is the mirroring not
      // happening, not the locale failing to apply.
      expect(
        Directionality.of(tester.element(find.byType(Icon))),
        TextDirection.rtl,
      );
      expect(
        find.descendant(of: find.byType(Icon), matching: find.byType(Transform)),
        findsNothing,
      );
    });

    testWidgets('the toggle is localized, addressable, and never disabled',
        (WidgetTester tester) async {
      await pumpPreview(tester, transcriptionAudioCardPlaying);
      expect(_toggle(), findsOneWidget);
      expect(
        tester.widget<Semantics>(_toggle()).properties.label,
        'Pause',
      );
      // Enabled even in the state whose audio cannot actually be played: the
      // card offers no disabled treatment at all (JEBV4-13 — togglePlayback
      // swallows the failure and resets the toggle, so the tap looks dead).
      await pumpPreview(tester, transcriptionAudioCardUnknownDuration);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<Semantics>(_toggle()).properties.label,
        'Play original',
      );

      await pumpPreview(
        tester,
        transcriptionAudioCardPlaying,
        locale: const Locale('ar'),
      );
      expect(
        tester.widget<Semantics>(_toggle()).properties.label,
        'إيقاف مؤقت',
      );
    });

    testWidgets('the read-out wraps rather than clipping at 200% text',
        (WidgetTester tester) async {
      _usePhone(tester);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(
            transcriptionAudioCardRecorderCap,
            const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final RenderParagraph readOut =
          tester.renderObject<RenderParagraph>(find.text('00:59 / 01:00'));
      // The Text has no maxLines and no overflow, so it soft-wraps around the
      // ' / ' and grows the card. NOTE: `flutter test` substitutes a
      // one-em-per-glyph font, so the wrap is a worst case — with the shipping
      // Inter face this 13-character read-out fits on one line at 2.0.
      expect(readOut.size.height, greaterThan(16));
      expect(readOut.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);

      // The toggle, by contrast, is pinned: iconSize is a fixed 48 pt at every
      // scale, so the button stays 64x64 while the read-out doubles.
      expect(_box(tester, find.byType(IconButton)).size, const Size(64, 64));
    });

    test('the progress track fails WCAG 2.2 §1.4.11 against the card surface',
        () {
      for (final MapEntry<String, ThemeData> entry
          in <String, ThemeData>{
        'light': AppTheme.light(),
        'dark': AppTheme.dark(),
      }.entries) {
        final ColorScheme scheme = entry.value.colorScheme;
        final Color surface = scheme.surfaceContainerHigh;
        final Color track = Color.alphaBlend(
          scheme.outline.withValues(alpha: 0.2),
          surface,
        );

        // The FILLED portion is fine — this is not a "the bar is unreadable"
        // claim, it is a "the empty part of the bar is invisible" claim, which
        // is what makes the Idle preview (progress 0.0) a blank 8 pt strip.
        expect(
          _contrast(scheme.primary, track),
          greaterThan(3.0),
          reason: '${entry.key}: fill vs track should stay distinguishable',
        );
        expect(
          _contrast(track, surface),
          lessThan(3.0),
          reason: '${entry.key}: the 20%-alpha outline track is under 3:1 on '
              'surfaceContainerHigh — if this ever passes, the contrast was '
              'fixed and this expectation should be inverted, not deleted',
        );
      }
    });
  });
}
