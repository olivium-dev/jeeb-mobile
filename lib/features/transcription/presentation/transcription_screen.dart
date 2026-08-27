import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/transcription_cubit.dart';
import '../domain/audioplayers_transcript_audio_player.dart';
import '../domain/transcript_audio_player.dart';
import '../domain/voice_clip.dart';
import 'widgets/transcription_audio_card.dart';
import 'widgets/transcription_language_chip.dart';
import 'widgets/transcription_quick_add_row.dart';
import 'widgets/transcription_status_banner.dart';
import 'widgets/transcription_text_panel.dart';

/// Stable Semantics identifiers for the transcription-review controls. Exposed
/// so Codex QA / uiautomator / integration tests can target the interactive
/// elements deterministically (DoD: every interactive widget addressable).
class TranscriptionKeys {
  const TranscriptionKeys._();

  static const String root = 'voice_transcript_root';
  static const String back = 'voice_transcript_back';
  static const String audioToggle = 'voice_transcript_audio_toggle';
  static const String scrubber = 'voice_transcript_scrubber';
  static const String languageChip = 'voice_transcript_language_chip';
  static const String transcriptText = 'voice_transcript_transcript_text';
  static const String editButton = 'voice_transcript_edit_button';
  static const String textField = 'voice_transcript_text_field';
  static const String saveEditButton = 'voice_transcript_save_edit_button';
  static const String quickAddQuantity = 'voice_transcript_quick_add_quantity';
  static const String quickAddBrand = 'voice_transcript_quick_add_brand';
  static const String quickAddBudget = 'voice_transcript_quick_add_budget';
  static const String confirmButton = 'voice_transcript_confirm_button';
  static const String reRecordButton = 'voice_transcript_re_record_button';
  static const String retryButton = 'voice_transcript_retry_button';
}

/// The voice TRANSCRIPTION-RESULT screen.
///
/// Reached from the voice composer via `/voice-request/transcription` once the
/// recording has been uploaded to `POST /transcribe` (JEBV4-209; the gateway
/// echoes `{ audioId, status, transcription, language, reason }`). The screen lets the
/// user review the machine transcription, edit it (whole text, or one tapped
/// word), replay the original audio, or re-record, then confirm — which
/// forwards a [RequestDraft]-shaped payload to the next create-request step
/// (`/request-summary`).
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
    // No Material app bar: the board's header is a body row (JeebTopBar).
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: JeebMidnightField(
        // R8 declares one radial (orange .22, no periwinkle) and 03-MOTION-NOTES
        // lists zero animated elements, so the decor is still.
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
        animateDecor: false,
        child: SafeArea(
          child: BlocBuilder<TranscriptionCubit, TranscriptionState>(
            builder: (context, state) => Semantics(
              identifier: TranscriptionKeys.root,
              container: true,
              explicitChildNodes: true,
              child: _TranscriptionBody(
                state: state,
                onConfirm: onConfirm,
                onReRecord: onReRecord,
              ),
            ),
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
    final l10n = AppLocalizations.of(context);
    final showQuickAdds =
        state.status == TranscriptionStatus.ready && !state.isEditing;
    return Column(
      children: [
        JeebTopBar.back(
          title: l10n.transcriptionTitle,
          identifier: TranscriptionKeys.back,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Spacing.xLarge,
              Spacing.large,
              Spacing.xLarge,
              Spacing.large,
            ),
            // Top-aligned and nothing stretches vertically: the lower half of
            // the board is real emptiness, not a gap to fill.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TranscriptionHeader(),
                const SizedBox(height: Spacing.large),
                if (state.hasAudio) ...[
                  TranscriptionAudioCard(state: state),
                  const SizedBox(height: Spacing.medium),
                ],
                if (TranscriptionLanguageChip.isSupported(state.language)) ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TranscriptionLanguageChip(
                      languageCode: state.language,
                    ),
                  ),
                  const SizedBox(height: Spacing.small),
                ],
                if (state.status != TranscriptionStatus.ready) ...[
                  TranscriptionStatusBanner(
                    state: state,
                    onRetry: state.status == TranscriptionStatus.failed
                        ? onReRecord
                        : null,
                  ),
                  const SizedBox(height: Spacing.medium),
                ],
                TranscriptionTextPanel(state: state),
                if (showQuickAdds) ...[
                  const SizedBox(height: Spacing.medium),
                  TranscriptionQuickAddRow(state: state),
                ],
              ],
            ),
          ),
        ),
        if (!state.isEditing)
          _TranscriptionFooter(
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.transcriptionHeader,
          style: context.jeebText.h1.copyWith(color: colorScheme.onSurface),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.transcriptionSubtitle,
          style: context.jeebText.body.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TranscriptionFooter extends StatelessWidget {
  const _TranscriptionFooter({
    required this.state,
    this.onConfirm,
    this.onReRecord,
  });

  final TranscriptionState state;
  final void Function(String text, String audioPath)? onConfirm;
  final VoidCallback? onReRecord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        0,
        Spacing.xLarge,
        Spacing.twoXLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            identifier: TranscriptionKeys.confirmButton,
            container: true,
            // Tile draws #D73B00 + `0 14 32 rgba(215,59,0,.45)` = ctaOrange.
            child: JeebCtaButton.accent(
              label: l10n.transcriptionSubmit,
              isEnabled: state.canConfirm,
              onTap: () =>
                  onConfirm?.call(state.text.trim(), state.audioPath ?? ''),
            ),
          ),
          const SizedBox(height: Spacing.small),
          Semantics(
            identifier: TranscriptionKeys.reRecordButton,
            container: true,
            child: JeebCtaButton.text(
              label: l10n.transcriptionReRecord,
              labelStyle: context.jeebText.cardTitle.copyWith(
                fontWeight: FontWeight.w600,
              ),
              onTap: () => onReRecord?.call(),
            ),
          ),
        ],
      ),
    );
  }
}
