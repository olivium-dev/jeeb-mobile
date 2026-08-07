import 'package:get_it/get_it.dart';

import '../../../core/di/injection_container.dart';
import '../../voice_request/cubit/voice_recording_cubit.dart';
import '../../voice_request/data/voice_recording_repository.dart';
import '../../voice_request/domain/voice_player.dart';
import '../../voice_request/domain/voice_recorder.dart';

/// Strict-DI resolution: `VoiceRecordingScreen`'s direct plugin fallbacks touch
/// platform channels in their constructors, which a bare widget test cannot.
VoiceRecordingCubit buildHomeVoiceCubit() {
  final GetIt di = sl;
  return VoiceRecordingCubit(
    recorder: di.isRegistered<VoiceRecorder>()
        ? di<VoiceRecorder>()
        : FakeVoiceRecorder(),
    player: di.isRegistered<VoicePlayer>()
        ? di<VoicePlayer>()
        : FakeVoicePlayer(),
    repository: di.isRegistered<VoiceRecordingRepository>()
        ? di<VoiceRecordingRepository>()
        : FakeVoiceRecordingRepository(),
  );
}
