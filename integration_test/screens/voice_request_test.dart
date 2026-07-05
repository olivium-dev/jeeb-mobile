// Isolated native UI test — voice-request (VoiceRecordingScreen). The route
// widget VoiceRequestScreen delegates to VoiceRecordingScreen, which builds a
// production cubit over the real platform recorder/player. To capture the idle
// "hold to record" surface deterministically we inject a VoiceRecordingCubit
// wired to the in-repo fakes (FakeVoiceRecorder / FakeVoicePlayer /
// FakeVoiceRecordingRepository) and a non-firing ticker — exactly as
// test/voice_recording_screen_test.dart does — so no plugin is touched and no
// timer is left pending.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';
import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';

import '../support/screen_harness.dart';

VoiceRecordingCubit _idleCubit() => VoiceRecordingCubit(
      recorder: FakeVoiceRecorder(),
      player: FakeVoicePlayer(),
      repository: FakeVoiceRecordingRepository(),
      // Empty stream — no ticks, so no pending timers after the pump.
      tickerFactory: (_) => const Stream.empty(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('voice-request: idle hold-to-record (en)', (tester) async {
    final cubit = _idleCubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      VoiceRecordingScreen(cubit: cubit),
      'voice-request__idle',
    );
  });

  testWidgets('voice-request: idle hold-to-record (ar)', (tester) async {
    final cubit = _idleCubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      VoiceRecordingScreen(cubit: cubit),
      'voice-request__idle-ar',
      locale: const Locale('ar'),
    );
  });
}
