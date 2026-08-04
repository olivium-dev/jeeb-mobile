import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/motion/jeeb_motion.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';

/// R2's LIVE TRANSCRIPT band — the glass card under the top bar (doc-13 P0-5).
///
/// The board draws `LIVE TRANSCRIPT` over a right-to-left transcript run with a
/// 2×20 orange caret at the run's logical end. There is no partial-transcript
/// source in the app (no on-device recognizer, `/transcribe` is post-upload), so
/// the words slot renders EMPTY at its designed height rather than faking a
/// sentence — the caret is the awaiting state.
class LiveTranscriptBand extends StatelessWidget {
  const LiveTranscriptBand({super.key, required this.isRecording});

  /// The caret blinks only while audio is actually being captured.
  final bool isRecording;

  /// Reserved height of the words row — the board's transcript line.
  static const double lineHeight = Sizes.xLarge;

  /// Caret geometry, measured on the tile: 2×20 at `#D73B00`.
  static const double caretWidth = Sizes.threeXSmall;
  static const double caretHeight = Sizes.large;

  /// `jBlink` 1.1s step-end is the module default; named here so the R2 motion
  /// row is greppable from the screen.
  static const Duration blinkDuration = JeebMotion.blinkDuration;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // TODO(midnight): l10n-queued — voiceRecordingLiveTranscriptLabel
    // ("Live transcript") + voiceRecordingTranscriptSemantic.
    final String label = l10n.transcriptionFieldLabel;
    return JeebGlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
      ),
      identifier: 'voice_request_live_transcript',
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          JeebSectionLabel(label, small: true),
          const SizedBox(height: Spacing.medium),
          SizedBox(
            height: lineHeight,
            width: double.infinity,
            child: Align(
              // TODO(midnight): omitted, not faked — the partial transcript
              // needs a streaming STT source; only the caret is drawn.
              alignment: AlignmentDirectional.centerStart,
              child: isRecording
                  ? const _TranscriptCaret()
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The blinking caret. Orange is tile-sanctioned here (measured `#D73B00`),
/// which is why it does not follow the app-wide periwinkle cursor ruling.
class _TranscriptCaret extends StatelessWidget {
  const _TranscriptCaret();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: JBlink(
        duration: LiveTranscriptBand.blinkDuration,
        child: SizedBox(
          width: LiveTranscriptBand.caretWidth,
          height: LiveTranscriptBand.caretHeight,
          child: ColoredBox(color: context.jeebRoles.accent),
        ),
      ),
    );
  }
}
