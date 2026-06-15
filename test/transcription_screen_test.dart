import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/transcription/application/transcription_cubit.dart';
import 'package:jeeb_mobile/features/transcription/domain/transcript_audio_player.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/features/transcription/presentation/widgets/transcription_status_banner.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Synchronous ARB-backed delegate so tests render the real EN/AR strings
/// (mirrors test/l10n/runtime_parity_test.dart harness).
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

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
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
    home: child,
  );
}

/// Finds a widget carrying the given Semantics identifier. We resolve the
/// identifier through the merged semantics node so uiautomator-style targeting
/// is exercised exactly as Codex QA will use it.
Finder _byIdentifier(String identifier) {
  return find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.identifier == identifier,
    description: 'Semantics(identifier: $identifier)',
  );
}

void main() {
  setUpAll(_loadArbs);

  group('TranscriptionScreen — render', () {
    testWidgets('renders the Arabic machine transcription (RTL)',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          locale: const Locale('ar'),
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: '9b1d3f7a2c',
              durationMs: 5000,
              transcript: 'كيلو بندورة من السوق',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('كيلو بندورة من السوق'), findsOneWidget);
      // The screen renders under an RTL directionality for Arabic.
      final dir = Directionality.of(
        tester.element(find.byType(TranscriptionScreen)),
      );
      expect(dir, TextDirection.rtl);
      // Every interactive control is addressable by its voice_transcript_* id.
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.reRecordButton), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.audioToggle), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.editButton), findsOneWidget);
    });

    testWidgets('shows the queued/empty state when transcript is empty',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const TranscriptionScreen(
            clip: VoiceClip(audioPath: 'audio-1', durationMs: 3000),
          ),
        ),
      );
      await tester.pump();

      // Queued banner is shown (audio saved, no transcript yet).
      expect(find.byType(TranscriptionStatusBanner), findsOneWidget);
      expect(find.text('Transcription is queued'), findsOneWidget);
      // The empty field hint is shown so the user can type.
      expect(find.text('Type your request here'), findsOneWidget);
      // Confirm is disabled (no text yet) but still addressable.
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsOneWidget);
    });
  });

  group('TranscriptionScreen — confirm navigates', () {
    testWidgets('confirm fires onConfirm with text + audio path',
        (tester) async {
      String? confirmedText;
      String? confirmedAudio;
      await tester.pumpWidget(
        _harness(
          TranscriptionScreen(
            clip: const VoiceClip(
              audioPath: 'audio-99',
              durationMs: 4200,
              transcript: 'Bring me bread from the bakery',
            ),
            onConfirm: (text, audio) {
              confirmedText = text;
              confirmedAudio = audio;
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(_byIdentifier(TranscriptionKeys.confirmButton));
      await tester.pump();

      expect(confirmedText, 'Bring me bread from the bakery');
      expect(confirmedAudio, 'audio-99');
    });

    testWidgets('confirm is a no-op while transcript is empty', (tester) async {
      var confirmCalls = 0;
      await tester.pumpWidget(
        _harness(
          TranscriptionScreen(
            clip: const VoiceClip(audioPath: 'audio-1', durationMs: 3000),
            onConfirm: (_, _) => confirmCalls++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(_byIdentifier(TranscriptionKeys.confirmButton));
      await tester.pump();

      expect(confirmCalls, 0, reason: 'empty transcript must not advance');
    });
  });

  group('TranscriptionScreen — edit', () {
    testWidgets('edit → type → save updates the displayed transcription',
        (tester) async {
      await tester.pumpWidget(
        _harness(
          const TranscriptionScreen(
            clip: VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: 'original text',
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(_byIdentifier(TranscriptionKeys.editButton));
      await tester.pump();

      // The editable field appears.
      expect(_byIdentifier(TranscriptionKeys.textField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'edited text');
      await tester.pump();

      await tester.tap(_byIdentifier(TranscriptionKeys.saveEditButton));
      await tester.pump();

      // Back to display mode showing the edited copy.
      expect(find.text('edited text'), findsOneWidget);
      expect(_byIdentifier(TranscriptionKeys.confirmButton), findsOneWidget);
    });

    testWidgets('editing to empty drops back to the queued/empty state',
        (tester) async {
      var confirmCalls = 0;
      await tester.pumpWidget(
        _harness(
          TranscriptionScreen(
            clip: const VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: 'will be cleared',
            ),
            onConfirm: (_, _) => confirmCalls++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(_byIdentifier(TranscriptionKeys.editButton));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(_byIdentifier(TranscriptionKeys.saveEditButton));
      await tester.pump();

      // Queued banner returns; confirm is inert again.
      expect(find.byType(TranscriptionStatusBanner), findsOneWidget);
      await tester.tap(_byIdentifier(TranscriptionKeys.confirmButton));
      await tester.pump();
      expect(confirmCalls, 0);
    });
  });

  group('TranscriptionScreen — re-record', () {
    testWidgets('re-record fires onReRecord', (tester) async {
      var reRecordCalls = 0;
      await tester.pumpWidget(
        _harness(
          TranscriptionScreen(
            clip: const VoiceClip(
              audioPath: 'audio-1',
              durationMs: 4000,
              transcript: 'something',
            ),
            onReRecord: () => reRecordCalls++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(_byIdentifier(TranscriptionKeys.reRecordButton));
      await tester.pump();

      expect(reRecordCalls, 1);
    });
  });

  group('TranscriptionScreen — failed/retry', () {
    testWidgets('failed status shows retry banner + retry fires handler',
        (tester) async {
      final cubit = TranscriptionCubit()
        ..seedFromClip(
          const VoiceClip(
            audioPath: 'audio-1',
            durationMs: 4000,
            transcript: '',
          ),
        )
        ..markFailed(TranscriptionFailure.network);
      addTearDown(cubit.close);

      // Inject the cubit AND a status banner with a retry handler by rendering
      // the banner directly with the failed state (the screen wires onRetry to
      // a follow-up; here we assert the banner contract).
      var retryCalls = 0;
      await tester.pumpWidget(
        _harness(
          Scaffold(
            body: TranscriptionStatusBanner(
              state: cubit.state,
              onRetry: () => retryCalls++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Transcription unavailable'), findsOneWidget);
      expect(
        find.text("We couldn't reach the server. "
            'Type your request below or retry.'),
        findsOneWidget,
      );
      await tester.tap(_byIdentifier(TranscriptionKeys.retryButton));
      await tester.pump();
      expect(retryCalls, 1);
    });
  });

  group('TranscriptionCubit — playback', () {
    test('seedFromClip lands on ready for a non-empty transcript', () {
      final cubit = TranscriptionCubit();
      addTearDown(cubit.close);
      cubit.seedFromClip(
        const VoiceClip(audioPath: 'a', durationMs: 5000, transcript: 'hi'),
      );
      expect(cubit.state.status, TranscriptionStatus.ready);
      expect(cubit.state.text, 'hi');
      expect(cubit.state.hasAudio, isTrue);
      expect(cubit.state.canConfirm, isTrue);
    });

    test('seedFromClip lands on queued for an empty transcript', () {
      final cubit = TranscriptionCubit();
      addTearDown(cubit.close);
      cubit.seedFromClip(const VoiceClip(audioPath: 'a', durationMs: 5000));
      expect(cubit.state.status, TranscriptionStatus.queued);
      expect(cubit.state.canConfirm, isFalse);
    });

    test('togglePlayback drives play → position → completed', () async {
      final player = FakeTranscriptAudioPlayer();
      final cubit = TranscriptionCubit(player: player);
      addTearDown(cubit.close);
      cubit.seedFromClip(
        const VoiceClip(audioPath: 'a', durationMs: 4000, transcript: 'hi'),
      );

      await cubit.togglePlayback();
      expect(cubit.state.isPlaying, isTrue);
      expect(player.playCalls, 1);

      player.emitPosition(const Duration(seconds: 2));
      expect(cubit.state.playbackPosition, const Duration(seconds: 2));

      player.emitCompleted();
      expect(cubit.state.isPlaying, isFalse);
      expect(cubit.state.playbackPosition, const Duration(milliseconds: 4000));
    });

    test('togglePlayback is a no-op without audio', () async {
      final player = FakeTranscriptAudioPlayer();
      final cubit = TranscriptionCubit(player: player);
      addTearDown(cubit.close);
      cubit.seedFromClip(
        const VoiceClip(audioPath: '', durationMs: 0, transcript: 'hi'),
      );
      await cubit.togglePlayback();
      expect(player.playCalls, 0);
      expect(cubit.state.isPlaying, isFalse);
    });
  });
}
