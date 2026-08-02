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
// DEV-ONLY, NOT SHIPPED.

/// Label row + a short card: phone width, enough height for two or three lines.
const Size _transcriptionTextPanelBox = Size(390, 220);

/// The empty/placeholder state is one line shorter and has no Edit button.
const Size _transcriptionTextPanelShortBox = Size(390, 170);

/// The long-transcript ceiling needs room before the clipping starts telling
const Size _transcriptionTextPanelTallBox = Size(390, 420);

/// Edit mode: a `minLines: 4` field plus the Done button underneath.
const Size _transcriptionTextPanelEditorBox = Size(390, 320);

/// Reused from `lib/devtool/catalog/entries/batch_11_entries.dart` — the
const String _transcriptionTextPanelReadyTranscript =
    'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.';

/// Reused from `test/transcription_screen_test.dart` — the Arabic machine
const String _transcriptionTextPanelArabicTranscript = 'كيلو بندورة من السوق';

/// Reused from the catalog's "Editing — text field open" fixture.
const String _transcriptionTextPanelEditDraft = 'Two bags of rice';

/// A single dictated run-on request. People do not speak in sentences into a
const String _transcriptionTextPanelLongTranscriptText =
    'I need someone to go to the Spinneys in Achrafieh and pick up two bags of '
    'rice, a gallon of water, four tomatoes, a kilo of chicken breast and one '
    'box of the green tea I usually get, then bring everything to the building '
    'behind the pharmacy on Independence street, second floor, and please call '
    'me when you are downstairs because the doorbell has been broken since '
    'last month.';

Widget _transcriptionTextPanelHosted(TranscriptionState state) {
  return BlocProvider<TranscriptionCubit>(
    create: (_) =>
        TranscriptionCubit(player: const NoopTranscriptAudioPlayer()),
    child: TranscriptionTextPanel(state: state),
  );
}

@JeebPreview(
  group: 'transcription',
  name: 'Ready · machine transcript',
  size: _transcriptionTextPanelBox,
)
Widget transcriptionTextPanelReady() => _transcriptionTextPanelHosted(
      const TranscriptionState(text: _transcriptionTextPanelReadyTranscript),
    );

@JeebPreview(
  group: 'transcription',
  name: 'Empty · queued placeholder',
  size: _transcriptionTextPanelShortBox,
)
Widget transcriptionTextPanelEmpty() =>
    _transcriptionTextPanelHosted(const TranscriptionState());

@JeebPreview(
  group: 'transcription',
  name: 'Whitespace · treated as empty',
  size: _transcriptionTextPanelShortBox,
)
Widget transcriptionTextPanelWhitespace() =>
    _transcriptionTextPanelHosted(const TranscriptionState(text: '   \n  '));

@JeebPreview(
  group: 'transcription',
  name: 'Arabic transcript · English UI',
  size: _transcriptionTextPanelBox,
)
Widget transcriptionTextPanelArabicContent() => _transcriptionTextPanelHosted(
      const TranscriptionState(text: _transcriptionTextPanelArabicTranscript),
    );

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
