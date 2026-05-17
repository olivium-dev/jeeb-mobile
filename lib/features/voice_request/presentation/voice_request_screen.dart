import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
class VoiceRequestScreen extends StatefulWidget {
  const VoiceRequestScreen({super.key});

  @override
  State<VoiceRequestScreen> createState() => _VoiceRequestScreenState();
}

class _VoiceRequestScreenState extends State<VoiceRequestScreen> {
  static const _featureId = 'voice-request';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Voice Request coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Voice Request coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
