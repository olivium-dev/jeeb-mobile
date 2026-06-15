import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

/// The transcription text, in either display (read + Edit affordance) or edit
/// (text field + Done) mode. RTL is inherited from the ambient [Directionality]
/// so an Arabic transcription renders right-aligned automatically.
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
