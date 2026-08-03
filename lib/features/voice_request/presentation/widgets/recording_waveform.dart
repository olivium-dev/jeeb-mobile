import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/widgets/jeeb/jeeb_waveform.dart';

/// The live recording mark above 05's timer readout.
///
/// Motion spec §2.2: `voice-waveform.json` is the moving counterpart of the
/// kit's [JeebWaveform.live]. The kit mark is frozen on purpose (the cubit
/// exposes `elapsed`, never amplitude), so the illustrative motion lives here
/// and only while audio is actually being captured — the film is never shown
/// on an idle composer, which would claim the mic is listening when it is not.
///
/// The film is radially symmetric about its centre bar (09-MOTION-VALIDATION §8
/// `RTL: none`), so it is deliberately **not** wrapped in a directional flip.
class RecordingWaveform extends StatelessWidget {
  const RecordingWaveform({
    super.key,
    required this.identifier,
    required this.semanticLabel,
  });

  /// 320×96 canvas, 90f, seamless loop, reads on white and on navy.
  static const String asset = 'assets/animations/voice-waveform.json';

  /// The composition's canvas aspect. The mark renders at the kit's
  /// [JeebWaveform.liveHeight], so swapping the static mark for the film
  /// shifts nothing in the docked cluster's vertical rhythm.
  static const double aspectRatio = 320 / 96;

  /// Maestro/`find.bySemanticsIdentifier` id — the frozen
  /// `voice_request_recording_waveform`.
  final String identifier;

  /// Spoken label; the mark *is* the recording indicator on 05.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Reduce-motion rests on the kit's measured static mark rather than frame 0
    // of the film: same height, same accent ink, and no asset decode at all.
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      identifier: identifier,
      label: semanticLabel,
      // Mandatory pair: without them this node merges into the readout column
      // and the identifier disappears from the tree.
      container: true,
      explicitChildNodes: true,
      child: SizedBox(
        height: JeebWaveform.liveHeight,
        child: reduceMotion
            ? const JeebWaveform.live()
            : Lottie.asset(
                asset,
                height: JeebWaveform.liveHeight,
                width: JeebWaveform.liveHeight * aspectRatio,
                fit: BoxFit.contain,
                addRepaintBoundary: true,
              ),
      ),
    );
  }
}
