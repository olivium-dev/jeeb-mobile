import 'package:flutter/widgets.dart';

import 'voice_recording_screen.dart';

class VoiceRequestScreen extends StatelessWidget {
  const VoiceRequestScreen({super.key, this.onSent});

  final VoiceSentCallback? onSent;

  @override
  Widget build(BuildContext context) {
    return VoiceRecordingScreen(onSent: onSent);
  }
}
