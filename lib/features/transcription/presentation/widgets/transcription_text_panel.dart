import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show Bidi;
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

/// Line height of the transcript run (`line-height: 1.6`, tpl 324).
const double _transcriptLineHeight = 1.6;

/// Word matcher for the tappable transcript. Runs of non-whitespace, so the
/// gaps between them can be re-emitted verbatim and the concatenated spans
/// stay byte-identical to the source text.
final RegExp _wordPattern = RegExp(r'\S+');

/// The transcription text, in either display (outlined card + tap-a-word +
/// `Edit all`) or edit (text field + Done) mode.
class TranscriptionTextPanel extends StatelessWidget {
  const TranscriptionTextPanel({super.key, required this.state});

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    if (state.isEditing) {
      return _TranscriptionEditor(
        initialText: state.text,
        editRange: state.editRange,
      );
    }
    return _TranscriptionDisplay(state: state);
  }
}

class _TranscriptionDisplay extends StatelessWidget {
  const _TranscriptionDisplay({required this.state});

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasText = state.text.trim().isNotEmpty;
    return JeebOutlinedCard(
      // Board draws this panel at 20 where the replay card is 18; snapping both
      // to `lg` would erase a distinction the tile makes on purpose.
      radius: JeebRadii.xl,
      padding: const EdgeInsetsDirectional.all(Spacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasText)
            _TappableTranscript(text: state.text)
          else
            Text(
              l10n.transcriptionFieldHint,
              style: context.jeebText.body.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          if (hasText) ...[
            const SizedBox(height: Spacing.small),
            const _TranscriptionHintRow(),
          ],
        ],
      ),
    );
  }
}

/// The transcript itself: one tappable [TextSpan] per word so a single wrong
/// word can be fixed without retyping the request.
///
/// **Invariant:** the concatenated span text equals the source text byte for
/// byte and only [TextSpan]s are used (a `WidgetSpan` injects U+FFFC), which
/// is what keeps `find.text(<transcript>)` resolving on this `Text.rich`.
class _TappableTranscript extends StatefulWidget {
  const _TappableTranscript({required this.text});

  final String text;

  @override
  State<_TappableTranscript> createState() => _TappableTranscriptState();
}

class _TappableTranscriptState extends State<_TappableTranscript> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  List<InlineSpan> _spans = const <InlineSpan>[];

  @override
  void initState() {
    super.initState();
    _buildSpans();
  }

  @override
  void didUpdateWidget(covariant _TappableTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _buildSpans();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _buildSpans() {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var cursor = 0;
    // TODO(midnight): omitted, not faked — the tile's 3px orange low-confidence
    // underline needs word offsets `/transcribe` does not return today.
    for (final match in _wordPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final range = TextRange(start: match.start, end: match.end);
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _editWord(range);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: match[0], recognizer: recognizer));
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    _spans = spans;
  }

  void _editWord(TextRange range) =>
      context.read<TranscriptionCubit>().startEditingWord(range);

  @override
  Widget build(BuildContext context) {
    final style = context.jeebText.h2.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      height: _transcriptLineHeight,
    );
    return Semantics(
      identifier: TranscriptionKeys.transcriptText,
      container: true,
      child: Directionality(
        // Content-derived, and only over the transcript: an Arabic request must
        // read RTL under `en` without flipping the screen around it.
        textDirection: Bidi.detectRtlDirectionality(widget.text)
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: Text.rich(TextSpan(style: style, children: _spans)),
      ),
    );
  }
}

/// Board `tpl 494-499`: orange alert glyph + the tap hint, with `Edit all`
/// pushed to the end edge of the same row, inside the panel.
class _TranscriptionHintRow extends StatelessWidget {
  const _TranscriptionHintRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        // The board glyph is a filled disc with an EXCLAMATION (bar above dot),
        // not the info `i` the pass-1 build shipped.
        Icon(
          Icons.error,
          size: Sizes.medium,
          color: context.jeebRoles.accent,
        ),
        const SizedBox(width: Spacing.xSmall),
        // TODO(midnight): omitted, not faked — transcriptionTapHintLowConfidence
        // has landed but stays unwired until word-confidence offsets do.
        Expanded(
          child: Text(
            l10n.transcriptionTapHint,
            style: context.jeebText.bodySmall.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Semantics(
          identifier: TranscriptionKeys.editButton,
          button: true,
          child: JeebCtaButton.accentText(
            label: l10n.transcriptionEdit,
            labelStyle:
                context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700),
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.twoXSmall,
            ),
            onTap: () => context.read<TranscriptionCubit>().startEditing(),
          ),
        ),
      ],
    );
  }
}

class _TranscriptionEditor extends StatefulWidget {
  const _TranscriptionEditor({required this.initialText, this.editRange});

  final String initialText;

  /// Slice to pre-select when the editor opens — the word the user tapped.
  final TextRange? editRange;

  @override
  State<_TranscriptionEditor> createState() => _TranscriptionEditorState();
}

class _TranscriptionEditorState extends State<_TranscriptionEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _applyEditRange();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Clamped against the live text: the range was computed on the previous
  /// build's string and a stale offset would throw inside the controller.
  void _applyEditRange() {
    final range = widget.editRange;
    if (range == null || !range.isValid) return;
    final length = widget.initialText.length;
    final start = range.start.clamp(0, length);
    final end = range.end.clamp(start, length);
    _controller.selection =
        TextSelection(baseOffset: start, extentOffset: end);
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
      child: JeebCtaButton.primary(label: label, onTap: onTap),
    );
  }
}
