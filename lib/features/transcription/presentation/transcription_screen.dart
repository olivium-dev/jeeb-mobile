import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/transcription_cubit.dart';
import '../domain/audioplayers_transcript_audio_player.dart';
import '../domain/transcript_audio_player.dart';
import '../domain/voice_clip.dart';
import 'widgets/transcription_audio_card.dart';
import 'widgets/transcription_status_banner.dart';
import 'widgets/transcription_text_panel.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/transcription_screen_fixtures.dart';

class TranscriptionKeys {
  const TranscriptionKeys._();

  static const String audioToggle = 'voice_transcript_audio_toggle';
  static const String editButton = 'voice_transcript_edit_button';
  static const String textField = 'voice_transcript_text_field';
  static const String saveEditButton = 'voice_transcript_save_edit_button';
  static const String confirmButton = 'voice_transcript_confirm_button';
  static const String reRecordButton = 'voice_transcript_re_record_button';
  static const String retryButton = 'voice_transcript_retry_button';
}

/// The voice TRANSCRIPTION-RESULT screen.
class TranscriptionScreen extends StatelessWidget {
  const TranscriptionScreen({
    super.key,
    required this.clip,
    this.onConfirm,
    this.onReRecord,
    this.cubit,
    this.audioPlayer,
  });

  final VoiceClip clip;

  final void Function(String text, String audioPath)? onConfirm;

  final VoidCallback? onReRecord;

  final TranscriptionCubit? cubit;

  final TranscriptAudioPlayer? audioPlayer;

  @override
  Widget build(BuildContext context) {
    final view = _TranscriptionView(onConfirm: onConfirm, onReRecord: onReRecord);
    if (cubit != null) {
      return BlocProvider<TranscriptionCubit>.value(value: cubit!, child: view);
    }
    return BlocProvider<TranscriptionCubit>(
      create: (_) => TranscriptionCubit(
        player: audioPlayer ?? AudioPlayersTranscriptAudioPlayer(),
      )..seedFromClip(clip),
      child: view,
    );
  }
}

class _TranscriptionView extends StatelessWidget {
  const _TranscriptionView({this.onConfirm, this.onReRecord});

  final void Function(String text, String audioPath)? onConfirm;
  final VoidCallback? onReRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.transcriptionTitle, centerTitle: false),
      body: SafeArea(
        child: BlocBuilder<TranscriptionCubit, TranscriptionState>(
          builder: (context, state) => _TranscriptionBody(
            state: state,
            onConfirm: onConfirm,
            onReRecord: onReRecord,
          ),
        ),
      ),
    );
  }
}

class _TranscriptionBody extends StatelessWidget {
  const _TranscriptionBody({
    required this.state,
    this.onConfirm,
    this.onReRecord,
  });

  final TranscriptionState state;
  final void Function(String text, String audioPath)? onConfirm;
  final VoidCallback? onReRecord;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.medium),
            children: [
              const _TranscriptionHeader(),
              const SizedBox(height: Spacing.medium),
              if (state.hasAudio) ...[
                TranscriptionAudioCard(state: state),
                const SizedBox(height: Spacing.medium),
              ],
              if (state.status != TranscriptionStatus.ready) ...[
                TranscriptionStatusBanner(state: state),
                const SizedBox(height: Spacing.medium),
              ],
              TranscriptionTextPanel(state: state),
            ],
          ),
        ),
        _TranscriptionActions(
          state: state,
          onConfirm: onConfirm,
          onReRecord: onReRecord,
        ),
      ],
    );
  }
}

class _TranscriptionHeader extends StatelessWidget {
  const _TranscriptionHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.transcriptionHeader, style: textTheme.titleLarge),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.transcriptionSubtitle,
          style: textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TranscriptionActions extends StatelessWidget {
  const _TranscriptionActions({
    required this.state,
    this.onConfirm,
    this.onReRecord,
  });

  final TranscriptionState state;
  final void Function(String text, String audioPath)? onConfirm;
  final VoidCallback? onReRecord;

  @override
  Widget build(BuildContext context) {
    if (state.isEditing) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ConfirmButton(
            label: l10n.transcriptionSubmit,
            enabled: state.canConfirm,
            onTap: () => onConfirm?.call(state.text.trim(), state.audioPath ?? ''),
          ),
          const SizedBox(height: Spacing.small),
          _ReRecordButton(label: l10n.transcriptionReRecord, onTap: onReRecord),
        ],
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: TranscriptionKeys.confirmButton,
      container: true,
      child: OmdsPrimaryButton(
        text: label,
        isEnabled: enabled,
        onTap: onTap,
      ),
    );
  }
}

class _ReRecordButton extends StatelessWidget {
  const _ReRecordButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // the same fix applied to the queued banner in transcription_status_banner.dart.
    final textColor = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      identifier: TranscriptionKeys.reRecordButton,
      container: true,
      child: OMDSOutlinedButton(
        text: label,
        textColor: textColor,
        onTap: () => onTap?.call(),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _transcriptionScreenPhoneBox = Size(390, 844);

/// The compact ceiling — the smallest phone the app supports.
/// Everything this screen gets wrong about width gets wrong here first: the
const Size _transcriptionScreenCompactBox = Size(320, 568);

/// The production path: the screen builds and seeds its OWN cubit from the
/// clip, with the platform audio player swapped for the inert one.
Widget _transcriptionScreenFromClip(VoiceClip clip) => TranscriptionScreen(
      clip: clip,
      audioPlayer: const NoopTranscriptAudioPlayer(),
      onConfirm: (_, _) {},
      onReRecord: () {},
    );

/// The pre-driven path, for the states only reachable by CALLING something.
/// [clip] is still passed because the constructor requires it; the screen
Widget _transcriptionScreenFromCubit(
  VoiceClip clip,
  TranscriptionCubit cubit,
) =>
    TranscriptionScreen(
      clip: clip,
      cubit: cubit,
      onConfirm: (_, _) {},
      onReRecord: () {},
    );

/// The happy path: the machine transcript came back and is waiting for review.
/// The full surface — audio card, transcript panel with its "Edit text"
@JeebPreview(
  group: 'transcription',
  name: 'Ready · transcript to review',
  size: _transcriptionScreenPhoneBox,
  matrix: true,
)
Widget transcriptionScreenReady() =>
    _transcriptionScreenFromClip(transcriptionScreenReadyClip);

/// The EMPTY state, and the closest this screen has to a loading state: the
/// upload landed, the transcript has not.
@JeebPreview(
  group: 'transcription',
  name: 'Queued · no transcript yet',
  size: _transcriptionScreenPhoneBox,
)
Widget transcriptionScreenQueued() =>
    _transcriptionScreenFromClip(transcriptionScreenQueuedClip);

/// `markFailed(TranscriptionFailure.network)` — the error state, and the one a
/// user on a weak connection meets most.
@JeebPreview(
  group: 'transcription',
  name: 'Failed · network',
  size: _transcriptionScreenPhoneBox,
)
Widget transcriptionScreenFailedNetwork() => _transcriptionScreenFromCubit(
      transcriptionScreenFailedClip,
      transcriptionScreenFailedCubit(),
    );

/// `startEditing()` — the text field open over the transcript.
/// The only state whose bottom bar is EMPTY: `_TranscriptionActions` shrinks to
@JeebPreview(
  group: 'transcription',
  name: 'Editing · text field open',
  size: _transcriptionScreenPhoneBox,
)
Widget transcriptionScreenEditing() => _transcriptionScreenFromCubit(
      transcriptionScreenEditingClip,
      transcriptionScreenEditingCubit(),
    );

/// Layout ceiling: the longest transcript the recorder can produce, on the
/// smallest phone the app supports.
@JeebPreview(
  group: 'transcription',
  name: 'Longest content · compact 320',
  size: _transcriptionScreenCompactBox,
  matrix: true,
)
Widget transcriptionScreenLongestCompact() =>
    _transcriptionScreenFromClip(transcriptionScreenLongestClip);

/// A transcript with no audio behind it: `hasAudio` is false, so
/// `_TranscriptionBody` drops [TranscriptionAudioCard] entirely.
@JeebPreview(
  group: 'transcription',
  name: 'No audio · transcript only',
  size: _transcriptionScreenPhoneBox,
)
Widget transcriptionScreenNoAudio() =>
    _transcriptionScreenFromClip(transcriptionScreenNoAudioClip);
