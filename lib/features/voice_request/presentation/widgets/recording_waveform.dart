import 'package:flutter/material.dart';

import '../../../../core/motion/jeeb_motion.dart';
import '../../../../core/widgets/jeeb/jeeb_waveform.dart';

/// The live recording mark above 05's timer readout.
///
/// `03-MOTION-NOTES` §R2: **one** `jWave` on the CONTAINER (1.2s ease-in-out,
/// `transform-origin: center bottom`) over ten static bars — never the per-bar
/// stagger, which the board draws nowhere. The bars are the kit's measured
/// [JeebWaveform.live]; reduce motion parks the row on the primitive's first
/// keyframe, and the Lottie film the pass-1 screen used is retired with it.
class RecordingWaveform extends StatelessWidget {
  const RecordingWaveform({
    super.key,
    required this.identifier,
    required this.semanticLabel,
  });

  /// R2's own period — the board runs this container at 1.2s, not the module's
  /// 1.3s default.
  static const Duration waveDuration = Duration(milliseconds: 1200);

  /// Maestro/`find.bySemanticsIdentifier` id — the frozen
  /// `voice_request_recording_waveform`.
  final String identifier;

  /// Spoken label; the mark *is* the recording indicator on 05.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: JeebWaveform.liveHeight,
      child: JWaveBar(
        duration: waveDuration,
        alignment: Alignment.bottomCenter,
        child: JeebWaveform.live(
          identifier: identifier,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}
