import 'package:flutter/widgets.dart';

import 'voice_recording_screen.dart';

/// Entry point for the voice-request flow at route `/voice-request`.
///
/// Delegates to [VoiceRecordingScreen] which wires the press-and-hold mic
/// button, recording timer, playback row, discard/send actions, and the
/// post-send broadcast confirmation (T-MOB-011).
///
/// The [VoiceRecordingScreen] uses [MockGatewayClient.createDio] internally
/// so it always targets the gateway-shaped mock at :3055 in debug builds.
class VoiceRequestScreen extends StatelessWidget {
  const VoiceRequestScreen({super.key, this.onSent, this.onSwitchToTyping});

  /// Optional callback fired once the request is sent. Receives the upload id
  /// and the optional machine transcript (null when resolved asynchronously),
  /// so the transcription-result step can show the transcript on the happy
  /// path. JEBV4-13: also carries the recorder's on-device file path +
  /// duration so the review step can actually replay the clip (the upload id
  /// is a gateway audioId, not a playable path).
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
