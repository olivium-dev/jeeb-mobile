// TRANS-01/TRANS-02 — an unplayable clip silently reset the toggle, so the
// user tapped forever with no signal; and `seekTo` emitted the clamped position
// optimistically, leaving the knob where the audio was not.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/transcription_screen_fixtures.dart';
import 'package:jeeb_mobile/features/transcription/application/transcription_cubit.dart';
import 'package:jeeb_mobile/features/transcription/domain/transcript_audio_player.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/transcription/presentation/widgets/transcription_audio_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const VoiceClip _clip = VoiceClip(
  audioPath: 'audio-1',
  localAudioPath: '/tmp/audio-1.m4a',
  durationMs: 7000,
  transcript: 'Two bags of ice, please.',
);

/// Fails only the acts the test drives; everything else is inert.
class _FailingPlayer implements TranscriptAudioPlayer {
  const _FailingPlayer({this.failPlay = true, this.failSeek = true});

  final bool failPlay;
  final bool failSeek;

  @override
  Future<void> play(
    String path, {
    required void Function(Duration) onPosition,
    required void Function() onCompleted,
  }) async {
    if (failPlay) throw StateError('unplayable');
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {
    if (failSeek) throw StateError('unseekable');
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

Widget _card(TranscriptionState state, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: TranscriptionAudioCard(state: state)),
    );

void main() {
  group('TranscriptionCubit · playback failure', () {
    test('a throwing play() sets playbackError and resets the toggle',
        () async {
      final cubit = TranscriptionCubit(player: const _FailingPlayer())
        ..seedFromClip(_clip);

      await cubit.togglePlayback();

      expect(cubit.state.isPlaying, isFalse);
      expect(cubit.state.playbackError, isTrue);
      await cubit.close();
    });

    test('a second togglePlayback clears the previous failure', () async {
      final cubit = TranscriptionCubit(player: const _FailingPlayer())
        ..seedFromClip(_clip);

      await cubit.togglePlayback();
      expect(cubit.state.playbackError, isTrue);

      // The optimistic emit that starts the second attempt clears the flag.
      final Future<void> second = cubit.togglePlayback();
      expect(cubit.state.playbackError, isFalse);
      await second;
      await cubit.close();
    });

    // TRANS-02: the knob must not move where the audio did not.
    test('a failing seek leaves playbackPosition UNMOVED', () async {
      final cubit = TranscriptionCubit(player: const _FailingPlayer())
        ..seedFromClip(_clip);
      final Duration before = cubit.state.playbackPosition;

      await cubit.seekTo(const Duration(seconds: 4));

      expect(cubit.state.playbackPosition, before);
      expect(cubit.state.playbackError, isTrue);
      await cubit.close();
    });

    test('a SUCCESSFUL seek commits the clamped position', () async {
      final cubit = TranscriptionCubit(
        player: const _FailingPlayer(failPlay: false, failSeek: false),
      )..seedFromClip(_clip);

      await cubit.seekTo(const Duration(seconds: 30));

      // Clamped to the clip's own duration.
      expect(cubit.state.playbackPosition, const Duration(seconds: 7));
      expect(cubit.state.playbackError, isFalse);
      await cubit.close();
    });
  });

  group('TranscriptionAudioCard · the failure rung', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('playbackError renders the announced note · '
          '${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        final cubit = TranscriptionCubit(player: const _FailingPlayer())
          ..seedFromClip(_clip);
        await cubit.togglePlayback();

        await tester.pumpWidget(_card(cubit.state, locale: locale));
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('voice_transcript_playback_error'),
          findsOneWidget,
        );
        await cubit.close();
      });
    }

    testWidgets('a healthy clip renders NO failure note', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      final cubit = transcriptionScreenCubit(_clip);

      await tester.pumpWidget(_card(cubit.state));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('voice_transcript_playback_error'),
        findsNothing,
      );
      await cubit.close();
    });
  });
}
