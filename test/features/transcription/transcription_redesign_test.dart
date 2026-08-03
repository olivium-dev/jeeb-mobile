import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/transcription/application/transcription_cubit.dart';
import 'package:jeeb_mobile/features/transcription/domain/transcript_audio_player.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Redesign-2026-08 coverage for screen 06. The pre-existing behaviour lives in
/// `test/transcription_screen_test.dart` and stays untouched — this file only
/// pins what the rebuild added: tap-a-word editing, the plain-text identity of
/// the `Text.rich` transcript, the quick-add chips, the detected-language chip,
/// scrubber seeking and content-derived direction.
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
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, widget) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: widget ?? const SizedBox.shrink(),
    ),
    home: child,
  );
}

Finder _byIdentifier(String identifier) {
  return find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == identifier,
    description: 'Semantics(identifier: $identifier)',
  );
}

void main() {
  setUpAll(_loadArbs);

  group('06 — tap-a-word editing', () {
    testWidgets('tapping a word opens the editor with that word selected',
        (tester) async {
      const transcript = 'bring me bread';
      await tester.pumpWidget(
        _harness(
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: transcript,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tapOnText(find.textRange.ofSubstring('bread'));
      await tester.pump();

      expect(_byIdentifier(TranscriptionKeys.textField), findsOneWidget);
      final controller =
          tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, transcript);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 9, extentOffset: 14),
        reason: 'the tapped word must arrive pre-selected, not the whole text',
      );
    });

    testWidgets('the Text.rich transcript still answers find.text',
        (tester) async {
      const transcript = 'كيلو بندورة من السوق';
      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: transcript,
            ),
          ),
        ),
      );
      await tester.pump();

      // The per-word spans must concatenate byte-identically, or 3 pre-existing
      // find.text assertions across two suites go red.
      expect(find.text(transcript), findsOneWidget);
      expect(
        _byIdentifier(TranscriptionKeys.transcriptText),
        findsOneWidget,
      );
    });

    testWidgets(
        'an Arabic transcript under `en` renders RTL while the screen stays LTR',
        (tester) async {
      const transcript = 'جيب لي دوا من الفرماشية';
      await tester.pumpWidget(
        _harness(
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: transcript,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        Directionality.of(tester.element(find.byType(TranscriptionScreen))),
        TextDirection.ltr,
      );
      expect(
        Directionality.of(tester.element(find.text(transcript))),
        TextDirection.rtl,
        reason: 'direction is derived from the content, not the UI locale',
      );
    });
  });

  group('06 — quick-add chips', () {
    testWidgets('a chip appends its fragment once and then leaves the row',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: 'bring me bread',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(_byIdentifier(TranscriptionKeys.quickAddQuantity), findsOneWidget);
      await tester.tap(_byIdentifier(TranscriptionKeys.quickAddQuantity));
      await tester.pump();

      final controller =
          tester.widget<TextField>(find.byType(TextField)).controller!;
      expect(controller.text, 'bring me bread\nQuantity: ');

      await tester.tap(_byIdentifier(TranscriptionKeys.saveEditButton));
      await tester.pump();

      expect(
        _byIdentifier(TranscriptionKeys.quickAddQuantity),
        findsNothing,
        reason: 'a used chip must leave the row',
      );
      expect(_byIdentifier(TranscriptionKeys.quickAddBrand), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.quickAddBudget), findsOneWidget);
    });

    test('applyQuickAdd is idempotent per id', () {
      final cubit = TranscriptionCubit();
      addTearDown(cubit.close);
      cubit.seedFromClip(
        const VoiceClip(audioPath: 'a', durationMs: 1000, transcript: 'milk'),
      );

      cubit.applyQuickAdd('quantity', 'Quantity: ');
      cubit.applyQuickAdd('quantity', 'Quantity: ');

      expect(cubit.state.text, 'milk\nQuantity: ');
      expect(cubit.state.appliedQuickAdds, {'quantity'});
      expect(cubit.state.isEditing, isTrue);
      expect(cubit.state.editRange?.start, cubit.state.text.length);
    });
  });

  group('06 — detected-language chip', () {
    Future<void> pumpWithLanguage(WidgetTester tester, String? language) async {
      await tester.pumpWidget(
        _harness(
          TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: 'bring me bread',
              language: language,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders for ar-LB', (tester) async {
      await pumpWithLanguage(tester, 'ar-LB');
      expect(_byIdentifier(TranscriptionKeys.languageChip), findsOneWidget);
      expect(find.text('Lebanese Arabic · auto-detected'), findsOneWidget);
    });

    testWidgets('absent for a null code', (tester) async {
      await pumpWithLanguage(tester, null);
      expect(_byIdentifier(TranscriptionKeys.languageChip), findsNothing);
    });

    testWidgets('absent for an unknown code — never echoed raw', (tester) async {
      await pumpWithLanguage(tester, 'fr-CA');
      expect(_byIdentifier(TranscriptionKeys.languageChip), findsNothing);
      expect(find.textContaining('fr-CA'), findsNothing);
    });
  });

  group('06 — scrubber seeking', () {
    test('seekTo clamps and forwards to the player', () async {
      final player = FakeTranscriptAudioPlayer();
      final cubit = TranscriptionCubit(player: player);
      addTearDown(cubit.close);
      cubit.seedFromClip(
        const VoiceClip(
          audioPath: 'audio-id',
          durationMs: 4000,
          transcript: 'hi',
          localAudioPath: '/tmp/clip.m4a',
        ),
      );

      await cubit.seekTo(const Duration(seconds: 2));
      expect(cubit.state.playbackPosition, const Duration(seconds: 2));
      expect(player.seekCalls, 1);
      expect(player.lastSeek, const Duration(seconds: 2));

      await cubit.seekTo(const Duration(seconds: -5));
      expect(cubit.state.playbackPosition, Duration.zero);
      expect(player.lastSeek, Duration.zero);

      await cubit.seekTo(const Duration(seconds: 30));
      expect(cubit.state.playbackPosition, const Duration(milliseconds: 4000));
      expect(player.lastSeek, const Duration(milliseconds: 4000));
    });

    test('seekTo is a no-op without a playable source', () async {
      final player = FakeTranscriptAudioPlayer();
      final cubit = TranscriptionCubit(player: player);
      addTearDown(cubit.close);
      cubit.seedFromClip(
        const VoiceClip(audioPath: '', durationMs: 0, transcript: 'hi'),
      );

      await cubit.seekTo(const Duration(seconds: 1));
      expect(player.seekCalls, 0);
      expect(cubit.state.playbackPosition, Duration.zero);
    });

    testWidgets('the scrubber is addressable and dragging it seeks',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 8000,
              transcript: 'bring me bread',
              localAudioPath: '/tmp/clip.m4a',
            ),
          ),
        ),
      );
      await tester.pump();

      final scrubber = _byIdentifier(TranscriptionKeys.scrubber);
      expect(scrubber, findsOneWidget);
      await tester.tapAt(tester.getCenter(scrubber));
      await tester.pump();

      // Read from below the BlocProvider, not from the screen element above it.
      final cubit = tester.element(scrubber).read<TranscriptionCubit>();
      expect(
        cubit.state.playbackPosition.inMilliseconds,
        closeTo(4000, 400),
        reason: 'a tap at the track midpoint seeks to ~half the clip',
      );
    });
  });

  group('06 — accessibility', () {
    testWidgets('200% text scale does not overflow the screen', (tester) async {
      await tester.pumpWidget(
        _harness(
          textScale: 2,
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: 'bring me bread from the bakery near the school',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the frozen identifier inventory survives the rebuild',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: 'bring me bread',
            ),
          ),
        ),
      );
      await tester.pump();

      for (final identifier in <String>[
        TranscriptionKeys.root,
        TranscriptionKeys.back,
        TranscriptionKeys.audioToggle,
        TranscriptionKeys.scrubber,
        TranscriptionKeys.transcriptText,
        TranscriptionKeys.editButton,
        TranscriptionKeys.confirmButton,
        TranscriptionKeys.reRecordButton,
      ]) {
        expect(_byIdentifier(identifier), findsOneWidget, reason: identifier);
      }
    });
  });
}
