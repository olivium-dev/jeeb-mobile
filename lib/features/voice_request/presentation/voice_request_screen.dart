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
  const VoiceRequestScreen({super.key, this.onSent});

  /// Optional callback fired once the request is sent (receives transcript id).
  final ValueChanged<String>? onSent;

  @override
  Widget build(BuildContext context) {
    return VoiceRecordingScreen(onSent: onSent);
  }
}
