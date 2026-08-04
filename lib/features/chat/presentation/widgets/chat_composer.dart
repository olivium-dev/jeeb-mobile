import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_chat_composer.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/chat_cubit.dart';
import '../../application/chat_state.dart';

/// Text + attachment input pinned to the bottom of the chat screen.
///
/// The pill itself is the kit's [JeebChatComposer] (redesign-2026-08 §5 #18):
/// one `surfaceContainerHigh` stadium holding the field, the 19px photo attach
/// glyph and the Ø38 navy send circle, with 48 dp tap targets, the `.38`
/// disabled fade and the SafeArea inset all kit-owned. The send circle is
/// enabled only when the trimmed composer text is non-empty.
///
/// **B-04 — the circle is SEND, not a mic.** The board draws a mic occupying
/// the send slot and no send button at all, so shipping it would be "replace
/// send with a mic" on the highest-traffic coordination surface. Refused; the
/// kit enforces it structurally and `chat_composer_no_mic_b04_test` guards it.
///
/// The text field feeds [ChatCubit.composerChanged] so the cubit stays the
/// single source of truth for the composer value; the controller here is a
/// thin local mirror that re-syncs whenever the cubit clears the text
/// post-send.
///
/// [onVoiceRecordingComplete] is called when the user finishes recording a
/// voice note. The callback receives the raw audio bytes, MIME type, and
/// duration so the caller (ChatScreen) can delegate to the cubit.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    this.hintText,
    this.onVoiceRecordingComplete,
    this.inputIdentifier = 'chat_detail_message_input',
    this.sendIdentifier = 'chat_detail_send_button',
  });

  /// Optional composer hint override. The Jeeber (delivery-man) variant passes
  /// `chatComposerHintPriceTime` ("Price / time"); the client variant leaves
  /// this null so the default `chatComposerHint` ("Type a message") shows.
  final String? hintText;

  /// Reserved seam for voice notes: called with (audioBytes, mimeType,
  /// durationMs) once real capture lands. B-04: the mic affordance is currently
  /// hidden (its press-to-record gesture, ChatComposerVoiceControl, was never
  /// built), so this callback is not yet invoked — kept so callers
  /// (ChatCubit.sendVoiceNote wiring) survive and re-enabling is a one-liner.
  final void Function(List<int>, String, int)? onVoiceRecordingComplete;

  /// Semantics identifier for the text field. Defaults to the legacy
  /// `chat_detail_message_input` (the 1:1 active-delivery chat); the order-chat
  /// (client compose) surface overrides it to `order_chat_composer_input`
  /// (JM-025, 63_W1_TEST_PLAN §2.5) so the W1 flow can drive the field.
  final String inputIdentifier;

  /// Semantics identifier for the send button. Defaults to the legacy
  /// `chat_detail_send_button`; the order-chat surface overrides it to
  /// `order_chat_composer_send` (JM-025) — the first send broadcasts.
  final String sendIdentifier;

  static const Key textFieldKey = Key('chat-composer-text-field');
  static const Key sendButtonKey = Key('chat-composer-send-button');
  static const Key attachButtonKey = Key('chat-composer-attach-button');

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    context.read<ChatCubit>().sendText();
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _openAttachmentSheet() async {
    final l10n = AppLocalizations.of(context);
    // P5 (b01-20260725): OMDS's static `OmdsMediaPickerSheet.show()` DROPS
    // `photoIcon` / `videoIcon` / `subtitle` (they exist on the widget's
    // constructor but the helper never forwards them), so the GALLERY row
    // rendered a CAMCORDER glyph (`Icons.videocam`) above an untranslated
    // English subtitle. Mount the SAME OMDS component directly to pass them —
    // still an OMDS component, no OMDS release needed. `'video'` is OMDS's slot
    // name for the SECOND option; here that slot IS the gallery row, not a
    // video recorder.
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => OmdsMediaPickerSheet(
        title: l10n.chatAttachmentSheetTitle,
        subtitle: l10n.chatAttachmentSheetSubtitle,
        photoLabel: l10n.chatAttachmentCamera,
        videoLabel: l10n.chatAttachmentGallery,
        cancelLabel: l10n.chatAttachmentCancel,
        photoIcon: Icons.photo_camera,
        videoIcon: Icons.photo_library,
        onPhotoSelected: () => Navigator.of(sheetContext).pop('photo'),
        onVideoSelected: () => Navigator.of(sheetContext).pop('video'),
        onCancel: () => Navigator.of(sheetContext).pop(),
      ),
    );
    if (!mounted || choice == null) return;
    final cubit = context.read<ChatCubit>();
    if (choice == 'photo') {
      await cubit.sendPhotoFromCamera();
    } else if (choice == 'video') {
      await cubit.sendPhotoFromGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (prev, curr) =>
          prev.composerText != curr.composerText &&
          curr.composerText != _controller.text,
      listener: (_, state) => _syncController(state.composerText),
      child: BlocBuilder<ChatCubit, ChatState>(
        buildWhen: (p, c) =>
            p.canSendText != c.canSendText || p.isAttaching != c.isAttaching,
        builder: (context, state) => JeebChatComposer(
          controller: _controller,
          focusNode: _focusNode,
          hintText: widget.hintText ?? l10n.chatComposerHint,
          onChanged: (v) => context.read<ChatCubit>().composerChanged(v),
          // Null → the kit fades the circle to .38 and reports
          // `Semantics(enabled: false)`, which is the assertion surface the
          // deleted `ChatComposerIconButton.onPressed` read used to be.
          onSend: state.canSendText ? _send : null,
          onAttach: _openAttachmentSheet,
          isAttaching: state.isAttaching,
          fieldKey: ChatComposer.textFieldKey,
          attachKey: ChatComposer.attachButtonKey,
          sendKey: ChatComposer.sendButtonKey,
          inputIdentifier: widget.inputIdentifier,
          attachIdentifier: 'chat_detail_attach_button',
          sendIdentifier: widget.sendIdentifier,
          attachSemanticLabel: l10n.chatAttachA11y,
          sendSemanticLabel: l10n.chatSendA11y,
        ),
      ),
    );
  }

  void _syncController(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
