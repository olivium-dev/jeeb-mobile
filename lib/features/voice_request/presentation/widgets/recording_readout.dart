import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../cubit/voice_recording_state.dart';
import 'recording_waveform.dart';

/// The waveform + `00:07 / 1:00` + status stack that sits directly above the
/// mic cluster.
///
/// Idle renders the readout alone at rest (`00:00 / 1:00` in muted ink, no
/// waveform, no status line) — the board only draws the recording state, and
/// the timer is what tells an idle user the cap exists.
class RecordingReadout extends StatelessWidget {
  const RecordingReadout({
    super.key,
    required this.state,
    required this.waveformKey,
  });

  final VoiceRecordingState state;

  /// The frozen QA key for the live mark
  /// (`VoiceRecordingKeys.recordingWaveform`).
  final Key waveformKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final text = context.jeebText;
    final semantic =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    final recording = state.isRecording;
    final elapsed = recording ? state.elapsed : Duration.zero;
    final formatted = formatClock(elapsed);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (recording) ...<Widget>[
          // The live mark moves while audio is being captured (motion spec
          // §2.2); it falls back to the kit's static bars under reduce-motion.
          RecordingWaveform(
            key: waveformKey,
            identifier: 'voice_request_recording_waveform',
            semanticLabel: l10n.voiceRecordingReleaseToStop,
          ),
          const SizedBox(height: Spacing.small),
        ],
        Semantics(
          identifier: 'voice_request_timer',
          label: l10n.voiceRecordingTimerLabel(formatted),
          container: true,
          child: ExcludeSemantics(
            // Already a 38px hero numeral; riding a 200% system scale
            // unclamped pushes the docked cluster off the viewport. 1.5x still
            // lifts it to 57px, and the spoken label above is unaffected.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.5,
              child: Directionality(
                // Digit isolate: elapsed / cap is a clock reading and never
                // reorders under Arabic.
                textDirection: TextDirection.ltr,
                child: Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: formatted,
                        style: text.statHero.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: recording
                              ? Theme.of(context).colorScheme.primary
                              : semantic.mutedText,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' / '
                            '${formatClock(VoiceRecordingState.maxDuration, padMinutes: false)}',
                        style: text.cardTitle.copyWith(
                          fontWeight: FontWeight.w600,
                          color: semantic.mutedText,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        if (recording) ...<Widget>[
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            l10n.voiceRecordingStatusRecording,
            textAlign: TextAlign.center,
            style: text.body.copyWith(
              fontWeight: FontWeight.w600,
              color: context.jeebRoles.accent,
            ),
          ),
        ],
      ],
    );
  }
}

/// `mm:ss`, or `m:ss` when [padMinutes] is false — the board writes the cap as
/// `1:00`, not `01:00`.
String formatClock(Duration duration, {bool padMinutes = true}) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final rawMinutes = clamped.inMinutes.remainder(60).toString();
  final minutes = padMinutes ? rawMinutes.padLeft(2, '0') : rawMinutes;
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
