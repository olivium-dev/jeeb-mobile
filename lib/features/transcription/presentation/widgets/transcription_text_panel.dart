import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/transcript_audio_player.dart';

class TranscriptionTextPanel extends StatelessWidget {
  const TranscriptionTextPanel({super.key, required this.state});

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    if (state.isEditing) return _TranscriptionEditor(initialText: state.text);
    return _TranscriptionDisplay(state: state);
  }
}

class _TranscriptionDisplay extends StatelessWidget {
  const _TranscriptionDisplay({required this.state});

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TranscriptionLabelRow(showEdit: state.text.trim().isNotEmpty),
        const SizedBox(height: Spacing.xSmall),
        _TranscriptionTextCard(
          text: state.text.trim().isEmpty ? l10n.transcriptionFieldHint : state.text,
          isPlaceholder: state.text.trim().isEmpty,
        ),
      ],
    );
  }
}

class _TranscriptionLabelRow extends StatelessWidget {
  const _TranscriptionLabelRow({required this.showEdit});

  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.transcriptionFieldLabel,
            style: Theme.of(context).textTheme.titleSmall),
        if (showEdit) _EditAction(label: l10n.transcriptionEdit),
      ],
    );
  }
}

class _EditAction extends StatelessWidget {
  const _EditAction({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: TranscriptionKeys.editButton,
      button: true,
      child: TextButton.icon(
        onPressed: () => context.read<TranscriptionCubit>().startEditing(),
        icon: const Icon(Icons.edit_outlined, size: Sizes.large),
        label: Text(label),
      ),
    );
  }
}

class _TranscriptionTextCard extends StatelessWidget {
  const _TranscriptionTextCard({
    required this.text,
    required this.isPlaceholder,
  });

  final String text;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isPlaceholder
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
      ),
    );
  }
}

class _TranscriptionEditor extends StatefulWidget {
  const _TranscriptionEditor({required this.initialText});

  final String initialText;

  @override
  State<_TranscriptionEditor> createState() => _TranscriptionEditorState();
}

class _TranscriptionEditorState extends State<_TranscriptionEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() =>
      context.read<TranscriptionCubit>().confirmEdit(_controller.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          identifier: TranscriptionKeys.textField,
          textField: true,
          child: OmdsTextField(
            controller: _controller,
            labelText: l10n.transcriptionFieldLabel,
            hintText: l10n.transcriptionFieldHint,
            maxLines: null,
            minLines: 4,
            autofocus: true,
            onChanged: context.read<TranscriptionCubit>().updateText,
          ),
        ),
        const SizedBox(height: Spacing.medium),
        _SaveEditButton(label: l10n.transcriptionSaveEdit, onTap: _save),
      ],
    );
  }
}

class _SaveEditButton extends StatelessWidget {
  const _SaveEditButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: TranscriptionKeys.saveEditButton,
      container: true,
      child: OmdsPrimaryButton(text: label, onTap: onTap),
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
// test/previews/transcription/transcription_text_panel_preview_test.dart
// ===========================================================================
//
// Widget previews for [TranscriptionTextPanel] — run with
// `flutter widget-preview start`.
//
// The panel is a pure function of the [TranscriptionState] it is handed, so
// every state below is a literal state object — no repository, no cubit
// stream, nothing to load. The ambient [TranscriptionCubit] exists only
// because the panel's own children reach for it: the display mode's "Edit
// text" button calls `startEditing()` on tap, and the editor wires
// `onChanged: context.read<TranscriptionCubit>().updateText` **during build**,
// so edit mode does not render at all without a provider above it.
//
// That cubit is inert by construction: built with the shipped
// [NoopTranscriptAudioPlayer], never `seedFromClip`ed, never played. It cannot
// perform I/O even if a preview is clicked in the canvas.
//
// Two things about this widget shape the states below:
//
// * **`trim()` is the switch.** `state.text.trim().isEmpty` decides BOTH the
//   placeholder copy and whether the Edit affordance exists
//   (`transcription_text_panel.dart:35,38`). A machine transcription that
//   comes back as whitespace is therefore a real, reachable state — and
//   `TranscriptionCubit.confirmEdit` deliberately routes empty edits back to
//   `queued`, so it is reachable from the UI too.
// * **Content direction is inherited, not detected.** The class doc promises
//   "an Arabic transcription renders right-aligned automatically", but that is
//   only true when the ambient [Directionality] is already RTL. Lebanese users
//   dictate Arabic with the app in English every day, which is exactly the
//   `Arabic transcript · English UI` preview.
//
// Fixture strings are reused rather than invented: the ready transcript is the
// Screen Catalog's `transcription` entry (`batch_11_entries.dart`), the Arabic
// one is from `test/transcription_screen_test.dart`, and the edit draft is the
// catalog's "Editing — text field open" state.

/// Label row + a short card: phone width, enough height for two or three lines.
const Size _transcriptionTextPanelBox = Size(390, 220);

/// The empty/placeholder state is one line shorter and has no Edit button.
const Size _transcriptionTextPanelShortBox = Size(390, 170);

/// The long-transcript ceiling needs room before the clipping starts telling
/// you something the widget is not doing wrong.
const Size _transcriptionTextPanelTallBox = Size(390, 420);

/// Edit mode: a `minLines: 4` field plus the Done button underneath.
const Size _transcriptionTextPanelEditorBox = Size(390, 320);

/// Reused from `lib/devtool/catalog/entries/batch_11_entries.dart` — the
/// catalog's "Ready — machine transcript to review" fixture.
const String _transcriptionTextPanelReadyTranscript =
    'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.';

/// Reused from `test/transcription_screen_test.dart` — the Arabic machine
/// transcription that test pins.
const String _transcriptionTextPanelArabicTranscript = 'كيلو بندورة من السوق';

/// Reused from the catalog's "Editing — text field open" fixture.
const String _transcriptionTextPanelEditDraft = 'Two bags of rice';

/// A single dictated run-on request. People do not speak in sentences into a
/// voice recorder, and the transcriber does not add paragraph breaks, so this
/// is what "long" actually looks like in production: one unbroken block.
const String _transcriptionTextPanelLongTranscriptText =
    'I need someone to go to the Spinneys in Achrafieh and pick up two bags of '
    'rice, a gallon of water, four tomatoes, a kilo of chicken breast and one '
    'box of the green tea I usually get, then bring everything to the building '
    'behind the pharmacy on Independence street, second floor, and please call '
    'me when you are downstairs because the doorbell has been broken since '
    'last month.';

/// Hosts the panel the way [TranscriptionScreen] does — a [TranscriptionCubit]
/// above it — with the inert player so nothing can touch audio or the network.
Widget _transcriptionTextPanelHosted(TranscriptionState state) {
  return BlocProvider<TranscriptionCubit>(
    create: (_) =>
        TranscriptionCubit(player: const NoopTranscriptAudioPlayer()),
    child: TranscriptionTextPanel(state: state),
  );
}

/// The happy path: a machine transcription good enough to send as-is.
///
/// This is the only state where the Edit affordance is meant to be visible, so
/// it is the reference for the label-row layout — a title on the leading edge
/// and a `TextButton.icon` on the trailing edge, which is the arrangement the
/// AR RTL rendering has to mirror.
@JeebPreview(
  group: 'transcription',
  name: 'Ready · machine transcript',
  size: _transcriptionTextPanelBox,
)
Widget transcriptionTextPanelReady() => _transcriptionTextPanelHosted(
      const TranscriptionState(text: _transcriptionTextPanelReadyTranscript),
    );

/// Queued: the upload landed but no transcript came back, so the card shows the
/// localized hint as a placeholder and the Edit button is GONE.
///
/// The missing button is the point. There is nothing to edit yet, and the
/// screen's own CTA is what moves the user forward; an Edit affordance next to
/// an empty card reads as a dead control. If this preview ever grows one, the
/// `showEdit` guard has broken.
@JeebPreview(
  group: 'transcription',
  name: 'Empty · queued placeholder',
  size: _transcriptionTextPanelShortBox,
)
Widget transcriptionTextPanelEmpty() =>
    _transcriptionTextPanelHosted(const TranscriptionState());

/// Whitespace-only transcript — the state a silent or unintelligible clip
/// actually produces, and the one an empty edit lands back on
/// (`TranscriptionCubit.confirmEdit` re-emits `queued` for a blank save).
///
/// Visually identical to the empty state on purpose: the panel `trim()`s before
/// deciding. If this preview ever renders a tall, blank grey card with an Edit
/// button above it, the widget has started treating "\n  " as content.
@JeebPreview(
  group: 'transcription',
  name: 'Whitespace · treated as empty',
  size: _transcriptionTextPanelShortBox,
)
Widget transcriptionTextPanelWhitespace() =>
    _transcriptionTextPanelHosted(const TranscriptionState(text: '   \n  '));

/// Arabic dictation with the app in English — the everyday Lebanese case.
///
/// The panel does not detect the content's direction; it inherits the ambient
/// [Directionality]. So in the EN renderings of this matrix the Arabic sits
/// LEFT-aligned in an LTR card, and only the AR rendering right-aligns it. Both
/// are worth looking at side by side before deciding the widget is fine.
@JeebPreview(
  group: 'transcription',
  name: 'Arabic transcript · English UI',
  size: _transcriptionTextPanelBox,
)
Widget transcriptionTextPanelArabicContent() => _transcriptionTextPanelHosted(
      const TranscriptionState(text: _transcriptionTextPanelArabicTranscript),
    );

/// The layout ceiling: one long dictated request, unwrapped by the transcriber.
///
/// The card has no `maxLines` and no scroll of its own — it grows until its
/// parent runs out of room, and on the real screen that parent is a
/// `SingleChildScrollView`. This is the preview to open at 200% text: the card
/// there is roughly twice as tall again, which is where a caller that forgets
/// to make its column scrollable gets a yellow-and-black overflow bar.
@JeebPreview(
  group: 'transcription',
  name: 'Long transcript · overflow ceiling',
  size: _transcriptionTextPanelTallBox,
)
Widget transcriptionTextPanelLongTranscript() => _transcriptionTextPanelHosted(
      const TranscriptionState(
        text: _transcriptionTextPanelLongTranscriptText,
      ),
    );

/// Edit mode: the read-only card is replaced by an autofocused field plus Done.
///
/// A completely different subtree from every state above — a `minLines: 4`
/// field and a full-width primary button — so it is the state where the panel's
/// height changes most, and the one that cannot render at all without the
/// ambient cubit ([_transcriptionTextPanelHosted]).
@JeebPreview(
  group: 'transcription',
  name: 'Editing · field + Done',
  size: _transcriptionTextPanelEditorBox,
)
Widget transcriptionTextPanelEditing() => _transcriptionTextPanelHosted(
      const TranscriptionState(
        text: _transcriptionTextPanelEditDraft,
        isEditing: true,
      ),
    );
