import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../application/transcription_cubit.dart';

class TranscriptionDisplayScreen extends StatelessWidget {
  const TranscriptionDisplayScreen({super.key, required this.initialText});

  final String initialText;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TranscriptionCubit()..setTranscription(initialText),
      child: const _TranscriptionDisplayScaffold(),
    );
  }
}

class _TranscriptionDisplayScaffold extends StatelessWidget {
  const _TranscriptionDisplayScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionCubit, TranscriptionState>(
      builder: (context, state) => Scaffold(
        appBar: OMDSAppBar(
          title: 'Transcription',
          centerTitle: false,
          actions: [
            if (!state.isEditing)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    context.read<TranscriptionCubit>().startEditing(),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: state.isEditing
              ? _EditView(state: state)
              : _DisplayView(text: state.text),
        ),
      ),
    );
  }
}

class _DisplayView extends StatelessWidget {
  const _DisplayView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _EditView extends StatefulWidget {
  const _EditView({required this.state});

  final TranscriptionState state;

  @override
  State<_EditView> createState() => _EditViewState();
}

class _EditViewState extends State<_EditView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // OmdsTextField grows with content (maxLines: null). The original
        // raw TextField used `expands: true` to fill the parent vertically;
        // OmdsTextField doesn't expose `expands`, so the editor now grows
        // from min to whatever content height it needs, scrolling the
        // SingleChildScrollView once it overflows.
        Expanded(
          child: SingleChildScrollView(
            child: OmdsTextField(
              controller: _controller,
              maxLines: null,
              minLines: 8,
            ),
          ),
        ),
        const SizedBox(height: Spacing.medium),
        OmdsPrimaryButton(
          text: 'Save Changes',
          onTap: () {
            context.read<TranscriptionCubit>()
              ..updateText(_controller.text)
              ..confirmEdit();
          },
        ),
      ],
    );
  }
}
