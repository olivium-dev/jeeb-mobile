import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../application/transcription_cubit.dart';

class TranscriptionDisplayScreen extends StatelessWidget {
  final String initialText;
  const TranscriptionDisplayScreen({super.key, required this.initialText});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TranscriptionCubit()..setTranscription(initialText),
      child: BlocBuilder<TranscriptionCubit, TranscriptionState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Transcription'),
              actions: [
                if (!state.isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.read<TranscriptionCubit>().startEditing(),
                  ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: state.isEditing
                  ? _EditView(state: state)
                  : _DisplayView(text: state.text),
            ),
          );
        },
      ),
    );
  }
}

class _DisplayView extends StatelessWidget {
  final String text;
  const _DisplayView({required this.text});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}

class _EditView extends StatefulWidget {
  final TranscriptionState state;
  const _EditView({required this.state});

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
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            context.read<TranscriptionCubit>()
              ..updateText(_controller.text)
              ..confirmEdit();
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
