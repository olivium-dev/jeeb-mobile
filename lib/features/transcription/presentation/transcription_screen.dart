import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../domain/voice_clip.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
// Deviation note: router call-site passes a `clip` (VoiceClip extra); the
// field is retained but unused so the import-graph stays green.
class TranscriptionScreen extends StatefulWidget {
  const TranscriptionScreen({super.key, required this.clip});

  final VoiceClip clip;

  @override
  State<TranscriptionScreen> createState() => _TranscriptionScreenState();
}

class _TranscriptionScreenState extends State<TranscriptionScreen> {
  static const _featureId = 'transcription';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Transcription coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Transcription coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
