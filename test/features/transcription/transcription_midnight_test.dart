import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_shadows.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_meter.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_waveform.dart';
import 'package:jeeb_mobile/features/transcription/domain/transcript_audio_player.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/features/transcription/presentation/widgets/transcription_audio_card.dart';
import 'package:jeeb_mobile/features/transcription/presentation/widgets/transcription_text_panel.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// M2-24 · R8 MIDNIGHT adoption guards.
///
/// Every assertion reads the painted colour or the geometry off the widget
/// tree, not a golden: the comparator tolerates 5% pixel diff, so a token
/// re-point on a small element passes three goldens unchanged.
class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final String en = File('lib/l10n/app_en.arb').readAsStringSync();
  final String ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

const VoiceClip _readyClip = VoiceClip(
  audioPath: 'audio-1',
  localAudioPath: 'audio-1',
  durationMs: 7000,
  language: 'ar-LB',
  transcript: 'جيب لي دوا من الفرماشية يلي حد البيت',
);

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: <LocalizationsDelegate<Object?>>[
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

Finder _byIdentifier(String identifier) => find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.identifier == identifier,
      description: 'Semantics(identifier: $identifier)',
    );

/// The first painted [BoxDecoration] under [ancestor] — the fill/stroke/lift a
/// user actually sees, rather than the constructor argument that produced it.
BoxDecoration _decorationUnder(WidgetTester tester, Finder ancestor) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.descendant(of: ancestor, matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

Future<void> _pumpScreen(WidgetTester tester,
    {Locale locale = const Locale('en')}) async {
  await tester.pumpWidget(
    _harness(
      const TranscriptionScreen(
        clip: _readyClip,
        audioPlayer: NoopTranscriptAudioPlayer(),
      ),
      locale: locale,
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(_loadArbs);

  group('R8 — the scrubber row draws no waveform', () {
    testWidgets('no Lottie and no JeebWaveform anywhere on the screen',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      // 03-MOTION-NOTES §R8: zero animated elements, "including the scrubber
      // row". The injected voice-waveform.json film is removed, not re-pointed.
      expect(find.byType(LottieBuilder), findsNothing);
      expect(find.byType(JeebWaveform), findsNothing);
    });

    testWidgets('the replay row is exactly disc + scrubber',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final Finder card = find.byType(TranscriptionAudioCard);
      expect(find.descendant(of: card, matching: _byIdentifier(
        TranscriptionKeys.audioToggle,
      )), findsOneWidget);
      expect(find.descendant(of: card, matching: _byIdentifier(
        TranscriptionKeys.scrubber,
      )), findsOneWidget);
      expect(find.descendant(of: card, matching: find.byType(LottieBuilder)),
          findsNothing);
    });
  });

  group('R8 — the field', () {
    testWidgets('content variant, top-end glow, decor held still',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final JeebMidnightField field =
          tester.widget<JeebMidnightField>(find.byType(JeebMidnightField));
      expect(field.variant, JeebFieldVariant.content);
      // Board `radial-gradient(500px 400px at 85% 8%, rgba(215,59,0,.22))`.
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      // R8 declares NO periwinkle wash — only the one orange radial.
      expect(field.washPlacement, isNull);
      expect(field.animateDecor, isFalse);
    });
  });

  group('R8 — orange is spent only where the tile draws it', () {
    testWidgets('the confirm CTA paints accent + the ctaOrange lift',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final BuildContext context =
          tester.element(find.byType(TranscriptionScreen));
      final BoxDecoration pill = _decorationUnder(
        tester,
        _byIdentifier(TranscriptionKeys.confirmButton),
      );

      expect(pill.color, context.jeebRoles.accent);
      expect(pill.color, isNot(Theme.of(context).colorScheme.secondary));
      expect(pill.boxShadow, JeebShadows.ctaOrange);
    });

    testWidgets('the play disc paints accent + the small orange lift',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final BuildContext context =
          tester.element(find.byType(TranscriptionScreen));
      final BoxDecoration disc = _decorationUnder(
        tester,
        _byIdentifier(TranscriptionKeys.audioToggle),
      );

      expect(disc.color, context.jeebRoles.accent);
      expect(disc.shape, BoxShape.circle);
      expect(disc.boxShadow, JeebShadows.ctaOrangeSmall);
    });

    testWidgets('the quick-add + glyph spends no orange',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final BuildContext context =
          tester.element(find.byType(TranscriptionScreen));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final Icon plus = tester.widget<Icon>(find.byIcon(Icons.add).first);

      // Board `tpl 502-504`: the `+` is part of the white 13/w600 label run.
      expect(plus.color, scheme.onSurface);
      expect(plus.color, isNot(context.jeebRoles.accent));
    });

    testWidgets('the hint glyph is the alert disc, not the info i',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final BuildContext context =
          tester.element(find.byType(TranscriptionScreen));
      // Board `tpl 495` draws a bar-above-dot exclamation, in orange.
      final Icon glyph = tester.widget<Icon>(find.byIcon(Icons.error));
      expect(glyph.color, context.jeebRoles.accent);
      expect(find.byIcon(Icons.info_rounded), findsNothing);
    });
  });

  group('R8 — glass surfaces', () {
    testWidgets('the scrubber track is white-alpha glass, not opaque navy',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final BuildContext context =
          tester.element(find.byType(TranscriptionScreen));
      final JeebSemanticColors semantics =
          Theme.of(context).extension<JeebSemanticColors>()!;
      final JeebMeter meter = tester.widget<JeebMeter>(find.byType(JeebMeter));

      // Board `rgba(255,255,255,.15)`; the tone default is `#151C69`, which is
      // DARKER than the glass panel the track sits on.
      expect(meter.trackColor, semantics.glassFillPressed);
      expect(
        meter.trackColor,
        isNot(Theme.of(context).colorScheme.surfaceContainerHighest),
      );
    });

    testWidgets('the replay card and the transcript panel are glass on '
        'different radii rungs', (WidgetTester tester) async {
      await _pumpScreen(tester);

      final BuildContext context =
          tester.element(find.byType(TranscriptionScreen));
      final JeebSemanticColors semantics =
          Theme.of(context).extension<JeebSemanticColors>()!;

      final JeebOutlinedCard replay = tester.widget<JeebOutlinedCard>(
        find
            .descendant(
              of: find.byType(TranscriptionAudioCard),
              matching: find.byType(JeebOutlinedCard),
            )
            .first,
      );
      final JeebOutlinedCard panel = tester.widget<JeebOutlinedCard>(
        find
            .descendant(
              of: find.byType(TranscriptionTextPanel),
              matching: find.byType(JeebOutlinedCard),
            )
            .first,
      );

      // Board draws 18 on the replay card and 20 on the panel — two rungs.
      expect(replay.radius, JeebRadii.lg);
      expect(panel.radius, JeebRadii.xl);
      expect(replay.radius, isNot(panel.radius));
      // Board stroke `rgba(255,255,255,.15)` on the replay card.
      expect(replay.borderColor, semantics.glassBorderStrong);

      final BoxDecoration panelBox = _decorationUnder(
        tester,
        find.byType(TranscriptionTextPanel),
      );
      expect(panelBox.color, semantics.glassFill);
    });

    testWidgets('the language chip is a glass pill, not a navy slab',
        (WidgetTester tester) async {
      await _pumpScreen(tester);

      final BuildContext context =
          tester.element(find.byType(TranscriptionScreen));
      final JeebSemanticColors semantics =
          Theme.of(context).extension<JeebSemanticColors>()!;
      final Finder chip = _byIdentifier(TranscriptionKeys.languageChip);
      final JeebOutlinedCard card = tester.widget<JeebOutlinedCard>(
        find.descendant(of: chip, matching: find.byType(JeebOutlinedCard)).first,
      );
      final BoxDecoration painted = _decorationUnder(tester, chip);

      expect(card.radius, JeebRadii.pill);
      expect(card.borderColor, semantics.glassBorderStrong);
      expect(painted.color, semantics.glassFill);
      expect(
        painted.color,
        isNot(Theme.of(context).colorScheme.surfaceContainerHigh),
      );
    });
  });
}
