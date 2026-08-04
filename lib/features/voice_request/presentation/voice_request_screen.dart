import 'package:flutter/widgets.dart';

import 'voice_recording_screen.dart';

class VoiceRequestScreen extends StatelessWidget {
  const VoiceRequestScreen({super.key, this.onSent, this.onSwitchToTyping});

  final VoiceSentCallback? onSent;

  /// Hands off to typed input from the keyboard satellite. Null hides it —
  /// `/voice-request` pushes the transcription review, `/compose-dictation`
  /// pops back to the compose field it was launched from.
  final VoidCallback? onSwitchToTyping;

  @override
  Widget build(BuildContext context) {
    return VoiceRecordingScreen(
      onSent: onSent,
      onSwitchToTyping: onSwitchToTyping,
    );
  }
}
