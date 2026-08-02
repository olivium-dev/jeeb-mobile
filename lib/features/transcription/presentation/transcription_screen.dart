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
///
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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/transcription/transcription_screen_preview_test.dart
// ===========================================================================
//
// Widget previews for [TranscriptionScreen] — the review step between
// recording a voice request and sending it.
//
// This is a SCREEN, and three things follow from that.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer only contributes a background.
//    The canvas box is therefore a real device
//    ([_transcriptionScreenPhoneBox], 390x844, and
//    [_transcriptionScreenCompactBox], 320x568) rather than the harness's
//    390x200 default — the body is `Expanded(ListView) + actions`, so in a
//    short box the actions eat the list and nothing about the layout is true.
//
// 2. It needs no `Router`. Every edge off this screen is a callback
//    (`onConfirm` / `onReRecord`), wired to no-ops below, so nothing here
//    reaches for GoRouter. Note this also means the previews have no app-bar
//    back button: `OMDSAppBar` only draws one when there is a route to pop.
//
// 3. Nothing on it animates forever. The playback bar is a *determinate*
//    `LinearProgressIndicator` and the editing state's caret settles, so
//    `pumpAndSettle` returns on every preview and none of them needs a
//    `TickerMode` mute or a hand-rolled pump loop.
//
// ## How the states are reached
//
// [TranscriptionCubit] has no `seed:` constructor and `emit` is not public, so
// a designed state is reached one of exactly two ways, and the screen already
// exposes a seam for each:
//
//   * `audioPlayer:` — the screen builds and seeds its OWN cubit from the clip
//     ([_transcriptionScreenFromClip]). `seedFromClip` derives the status from
//     whether the transcript is blank, so this reaches `ready` and `queued`.
//   * `cubit:` — a pre-driven cubit handed in whole
//     ([_transcriptionScreenFromCubit]), for the states only reachable by
//     CALLING something: `markFailed(...)` and `startEditing()`.
//
// Both seams are shipped production API; no preview here required a
// production change. Every cubit is built with [NoopTranscriptAudioPlayer], so
// `AudioPlayersTranscriptAudioPlayer` — the default, and the only
// platform-channel dependency on this screen — is never constructed and the
// play/pause toggle is an inert no-op. There is no repository on this screen
// at all. Network- and platform-free by construction, not by the guard in
// [jeebPreviewHost].
//
// The clips are shared verbatim with the Screen Catalog entry —
// `lib/devtool/catalog/fixtures/transcription_screen_fixtures.dart` — so the
// designer's four states and the first four here cannot describe different
// screens. `Longest content` and `No audio` are preview-only ceilings, declared
// in the same file so the catalog can adopt them without a second definition.
//
// ## What these previews surfaced in the screen
//
//  * **`Queued` and `Failed` are dead ends: both tell the user to type, and
//    neither offers anywhere to type.** `_TranscriptionLabelRow` gates the
//    "Edit text" action on `showEdit: state.text.trim().isNotEmpty`
//    (`transcription_text_panel.dart`), and `startEditing()` has no other
//    caller — so exactly when the transcript is EMPTY, which is the only time
//    the user has to write the request by hand, the editor is unreachable. The
//    queued banner says "You can type your request now to keep moving", the
//    panel shows the "Type your request here" placeholder, and the placeholder
//    is a plain `Container`, not a field. Send is disabled (`canConfirm` is
//    false on empty text), so the only live control left is Re-record. The same
//    is true of every `Failed` state, whose copy also ends "Type your request
//    below…". Reachable from the shipped flow in one step:
//    `test/transcription_screen_test.dart` already drives edit → clear → Done
//    and asserts the queued banner comes back — the user who does that has
//    locked themselves out of the field they were just using.
//  * **The failed banner tells the user to retry and gives them nothing to
//    tap.** `_TranscriptionBody` builds `TranscriptionStatusBanner(state:
//    state)` with no `onRetry`, and the banner gates its Retry button on
//    `isFailed && onRetry != null`, so `transcriptionFailedNetwork` ("…Type
//    your request below or retry.") renders with no retry affordance anywhere
//    on the screen. Same note from the other side of the boundary in the
//    JEEB PREVIEWS section of `transcription_status_banner.dart`.
//  * **The Re-record label is illegible in dark mode — 1.40:1.**
//    [_ReRecordButton] hardcodes `textColor: colorScheme.onPrimary` onto an
//    `OMDSOutlinedButton`, whose background is `colorScheme.secondaryContainer`.
//    In the light theme that pairing is a deliberate workaround and it works
//    (`#FFFFFF` on `#0B1351`, 17.13:1). In dark it is `#252B61` on `#444559` —
//    1.40:1, against the 4.5:1 WCAG 2.2 §1.4.3 asks of body text. `onPrimary`
//    is the wrong role for a `secondaryContainer` surface; the truncated
//    comment above it points at the queued banner, which fixed the same
//    problem by moving to a semantic role pair instead. Read the AR RTL **dark**
//    card of `Ready` — that is where it is visible.
//  * **The transcript panel's label row overflows at 200% text.**
//    `_TranscriptionLabelRow` is a `MainAxisAlignment.spaceBetween` `Row` whose
//    two children — the "Transcription" label and the "Edit text"
//    `TextButton.icon` — are neither `Flexible` nor ellipsized, so they are
//    measured at their full intrinsic width. At 320 pt with real fonts the row
//    has 288 pt: EN wants 178.4 + 141.9 = 320.3 (32 px over) and AR wants
//    177.7 + 162.0 = 339.7 (52 px over). AR starts breaking at 1.75x; EN clears
//    360 pt, AR needs 390. It only affects the states that HAVE a transcript —
//    which is to say, every state where the row renders at all.
//  * **Editing removes both bottom actions and offers no way back.**
//    `_TranscriptionActions` returns `SizedBox.shrink()` for `isEditing`, so
//    Send and Re-record disappear and "Done" is the only control; `confirmEdit`
//    commits whatever is in the field, so there is no discard path.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _transcriptionScreenPhoneBox = Size(390, 844);

/// The compact ceiling — the smallest phone the app supports.
///
/// Everything this screen gets wrong about width gets wrong here first: the
/// label-row overflow above is measured at this width.
const Size _transcriptionScreenCompactBox = Size(320, 568);

/// The production path: the screen builds and seeds its OWN cubit from the
/// clip, with the platform audio player swapped for the inert one.
///
/// Reaches the two states `seedFromClip` can express — `ready` (non-blank
/// transcript) and `queued` (blank).
Widget _transcriptionScreenFromClip(VoiceClip clip) => TranscriptionScreen(
      clip: clip,
      audioPlayer: const NoopTranscriptAudioPlayer(),
      onConfirm: (_, _) {},
      onReRecord: () {},
    );

/// The pre-driven path, for the states only reachable by CALLING something.
///
/// [clip] is still passed because the constructor requires it; the screen
/// ignores it whenever a `cubit` is supplied, and the fixture seeds the cubit
/// from the SAME clip, so the two can never disagree.
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
///
/// The full surface — audio card, transcript panel with its "Edit text"
/// affordance, Send enabled, Re-record under it — and the only preview here
/// with no banner, because the banner is mounted only while
/// `status != ready`.
///
/// Matrixed because this is where two of the findings above are legible at a
/// glance: the **AR RTL dark** card shows the 1.40:1 Re-record label, and the
/// **EN 200%** card shows the label row running past the right edge once the
/// panel scrolls into view.
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
///
/// Read it as the dead end it is. The banner asks the user to type, the panel
/// shows the "Type your request here" placeholder — and there is no field, no
/// "Edit text" button, and a disabled Send. Every affordance the copy promises
/// is absent because `showEdit` is gated on the text being NON-empty.
@JeebPreview(
  group: 'transcription',
  name: 'Queued · no transcript yet',
  size: _transcriptionScreenPhoneBox,
)
Widget transcriptionScreenQueued() =>
    _transcriptionScreenFromClip(transcriptionScreenQueuedClip);

/// `markFailed(TranscriptionFailure.network)` — the error state, and the one a
/// user on a weak connection meets most.
///
/// The audio SURVIVES the failure (`markFailed` only flips status/failure), so
/// the replay card is still there. What is not there is a Retry button: the
/// screen builds the banner without `onRetry`, so the copy's "…or retry" points
/// at nothing. Combined with the missing editor above, this state's only live
/// control is Re-record.
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
///
/// The only state whose bottom bar is EMPTY: `_TranscriptionActions` shrinks to
/// nothing while editing, so Send and Re-record both vanish and "Done" is the
/// only control on screen. There is no Cancel, and `confirmEdit` commits the
/// field verbatim — including a cleared field, which drops the screen back into
/// the unreachable-editor `Queued` state above.
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
///
/// 59 s of speech is one second under the recorder's hard cap, so this is the
/// most text the screen can ever be handed. Matrixed because the compact box is
/// where the label-row overflow is measured (32 px EN / 52 px AR at 200% text,
/// 288 pt of usable width) and where the AR RTL rendering has the least room to
/// absorb the longer Arabic labels.
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
///
/// Reachable when the gateway returns a transcript without an `audioId`, and
/// the same condition `togglePlayback` guards on. Worth its own card because
/// the card's absence is silent — nothing explains that the recording is gone,
/// and `onConfirm` still fires with an empty `audioPath`.
@JeebPreview(
  group: 'transcription',
  name: 'No audio · transcript only',
  size: _transcriptionScreenPhoneBox,
)
Widget transcriptionScreenNoAudio() =>
    _transcriptionScreenFromClip(transcriptionScreenNoAudioClip);
