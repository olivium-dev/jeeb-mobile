// Isolated native UI test — TranscriptionScreen (voice transcription-result,
// /voice-request/transcription). The screen owns its own BlocProvider and, when
// no cubit is injected, builds a TranscriptionCubit that seeds from the clip and
// falls back to the inert NoopTranscriptAudioPlayer (no timers, no platform
// audio), so we pump the widget directly with a fixed VoiceClip. Covers the
// machine-transcript ready state, the queued/empty fallback, and Arabic (RTL).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';

import '../support/screen_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('transcription: machine transcript ready (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const TranscriptionScreen(
        clip: VoiceClip(
          audioPath: 'audio-99',
          durationMs: 4200,
          transcript: 'Bring me bread from the bakery',
        ),
      ),
      'transcription__review',
    );
  });

  testWidgets('transcription: queued / empty transcript (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const TranscriptionScreen(
        clip: VoiceClip(audioPath: 'audio-1', durationMs: 3000),
      ),
      'transcription__queued',
    );
  });

  testWidgets('transcription: machine transcript ready (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      const TranscriptionScreen(
        clip: VoiceClip(
          audioPath: 'audio-99',
          durationMs: 4200,
          transcript: 'كيلو بندورة من السوق',
        ),
      ),
      'transcription__ar',
      locale: const Locale('ar'),
    );
  });
}
