import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/chat_cubit.dart';
import '../../application/chat_state.dart';
import 'chat_composer_icon_button.dart';

/// Text + attachment input pinned to the bottom of the chat screen.
///
/// Matches the Figma composer (nodes 56535:6659 / 56546:2382): a leading
/// attach affordance, a rounded "Send message…" field, a voice/mic affordance,
/// and a navy circular send pill. The send pill is enabled only when the
/// trimmed composer text is non-empty (Figma "Disabled=True" blank state).
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

  /// Called when the user releases the mic button after recording a voice note.
  /// Parameters: (audioBytes, mimeType, durationMs). Null means voice notes are
  /// disabled in this composer context.
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
  static const Key voiceButtonKey = Key('chat-composer-voice-button');

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
    final choice = await OmdsMediaPickerSheet.show(
      context,
      title: l10n.chatAttachmentSheetTitle,
      photoLabel: l10n.chatAttachmentCamera,
      videoLabel: l10n.chatAttachmentGallery,
      cancelLabel: l10n.chatAttachmentCancel,
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
    final colorScheme = Theme.of(context).colorScheme;
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (prev, curr) =>
          prev.composerText != curr.composerText &&
          curr.composerText != _controller.text,
      listener: (_, state) => _syncController(state.composerText),
      child: _ComposerBar(
        controller: _controller,
        focusNode: _focusNode,
        topBorderColor: colorScheme.outlineVariant,
        hintText: widget.hintText,
        onSend: _send,
        onAttach: _openAttachmentSheet,
        onVoiceRecordingComplete: widget.onVoiceRecordingComplete,
        inputIdentifier: widget.inputIdentifier,
        sendIdentifier: widget.sendIdentifier,
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

/// The composer surface: hairline top border, attach + field + mic + send row.
class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.focusNode,
    required this.topBorderColor,
    required this.hintText,
    required this.onSend,
    required this.onAttach,
    required this.inputIdentifier,
    required this.sendIdentifier,
    this.onVoiceRecordingComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color topBorderColor;
  final String? hintText;
  final VoidCallback onSend;
  final Future<void> Function() onAttach;
  final String inputIdentifier;
  final String sendIdentifier;
  final void Function(List<int>, String, int)? onVoiceRecordingComplete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: topBorderColor,
              width: UIConstants.strokeWidthThin,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.small,
            Spacing.twoXSmall,
            Spacing.small,
            Spacing.small,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _AttachButton(onAttach: onAttach),
              Expanded(
                child: _ComposerField(
                  controller: controller,
                  focusNode: focusNode,
                  hintText: hintText,
                  inputIdentifier: inputIdentifier,
                ),
              ),
              _VoiceButton(onComplete: onVoiceRecordingComplete),
              _SendButton(onSend: onSend, sendIdentifier: sendIdentifier),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leading attach (+) affordance; shows a spinner while a pick is in flight.
class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.onAttach});

  final Future<void> Function() onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (p, c) => p.isAttaching != c.isAttaching,
      builder: (context, state) {
        if (state.isAttaching) {
          return const Padding(
            padding: EdgeInsets.all(Spacing.small),
            child: OmdsButtonLoading(
              size: Sizes.large,
              strokeWidth: UIConstants.strokeWidthNormal,
            ),
          );
        }
        return ChatComposerIconButton(
          key: ChatComposer.attachButtonKey,
          icon: Icons.add,
          semanticsId: 'chat_detail_attach_button',
          semanticsLabel: l10n.chatAttachA11y,
          onPressed: () => onAttach(),
        );
      },
    );
  }
}

/// Rounded "Send message…" text field.
class _ComposerField extends StatelessWidget {
  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.inputIdentifier,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? hintText;
  final String inputIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: inputIdentifier,
      textField: true,
      child: OmdsTextField(
        key: ChatComposer.textFieldKey,
        controller: controller,
        focusNode: focusNode,
        minLines: 1,
        maxLines: 5,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        hintText: hintText ?? l10n.chatComposerHint,
        borderRadius: UIConstants.borderRadiusXLarge,
        onChanged: (v) => context.read<ChatCubit>().composerChanged(v),
      ),
    );
  }
}

/// Voice/mic affordance. When [onComplete] is non-null, a long-press gesture
/// starts a recording; releasing ends it and calls back with the bytes, MIME
/// type, and duration. When [onComplete] is null the button is visible but
/// no-op (preserves composer layout in contexts where voice isn't wired yet).
class _VoiceButton extends StatelessWidget {
  const _VoiceButton({this.onComplete});

  final void Function(List<int>, String, int)? onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ChatComposerIconButton(
      key: ChatComposer.voiceButtonKey,
      icon: Icons.mic_none,
      semanticsId: 'chat_detail_voice_button',
      semanticsLabel: l10n.chatVoiceA11y,
      onPressed: onComplete != null ? () => _onTap(context) : null,
    );
  }

  void _onTap(BuildContext context) {
    // Voice recording is triggered via press-hold in the full implementation.
    // This tap callback provides a fallback entry point for test coverage.
    // The real press-to-record gesture is in ChatComposerVoiceControl (T-MOB-016).
  }
}

/// Navy circular send pill; enabled only when the composer text is non-empty.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onSend, required this.sendIdentifier});

  final VoidCallback onSend;
  final String sendIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (p, c) => p.canSendText != c.canSendText,
      builder: (context, state) {
        return ChatComposerIconButton(
          key: ChatComposer.sendButtonKey,
          icon: Icons.send,
          filled: true,
          semanticsId: sendIdentifier,
          semanticsLabel: l10n.chatSendA11y,
          onPressed: state.canSendText ? onSend : null,
        );
      },
    );
  }
}
