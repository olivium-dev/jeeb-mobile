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

/// Stable Semantics identifiers for the transcription-review controls. Exposed
/// so Codex QA / uiautomator / integration tests can target the interactive
/// elements deterministically (DoD: every interactive widget addressable).
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
///
/// Reached from the voice composer via `/voice-request/transcription` once the
/// recording has been uploaded to `POST /transcribe` (JEBV4-209; the gateway
/// echoes `{ audioId, status, transcription, language, reason }`). The screen lets the
/// user review the machine transcription, edit it, replay the original audio,
/// or re-record, then confirm — which forwards a [RequestDraft]-shaped payload
/// to the next create-request step (`/request-summary`).
///
/// Navigation is injected via [onConfirm] / [onReRecord] so the widget stays
/// router-agnostic and unit-testable; the router (`app_router.dart`) supplies
/// the real `context.push` / `context.pop` closures.
///
/// Empty/failed transcriptions degrade gracefully: a `queued` upload (no text
/// yet) drops the user straight into a typeable field, and a failed call shows
/// a retry banner over the same manual-entry fallback.
class TranscriptionScreen extends StatelessWidget {
  const TranscriptionScreen({
    super.key,
    required this.clip,
    this.onConfirm,
    this.onReRecord,
    this.cubit,
    this.audioPlayer,
  });

  /// Clip handed over from the voice composer. Carries the audio path/id and an
  /// optional machine [VoiceClip.transcript].
  final VoiceClip clip;

  /// Fired when the user confirms. Receives the final (possibly edited) text
  /// plus the audio path so the caller can build the forward [RequestDraft].
  final void Function(String text, String audioPath)? onConfirm;

  /// Fired when the user taps Re-record — returns to the voice composer.
  final VoidCallback? onReRecord;

  /// Optional injected cubit (tests). Production builds one from the clip.
  final TranscriptionCubit? cubit;

  /// Optional audio player override (tests). Production defaults to the
  /// `audioplayers`-backed [AudioPlayersTranscriptAudioPlayer] (JEBV4-13 —
  /// this used to default to the inert no-op player, leaving the visible
  /// replay control dead). The real adapter is lazy: it only touches platform
  /// channels on first play, so route tables / widget tests stay safe.
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
    // OMDSOutlinedButton fills with colorScheme.secondaryContainer (deep navy
    // in the Jeeb theme) and defaults its label to colorScheme.onSecondaryContainer
    // (~#777FC0, muted lavender, ~3:1 contrast on navy — fails WCAG 2.2 AA).
    // We override with colorScheme.onPrimary (white, ~17:1 on navy) to match
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
