import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/chat_cubit.dart';
import '../../application/chat_state.dart';

/// Text + attachment input pinned to the bottom of the chat screen.
///
/// The text field directly feeds [ChatCubit.composerChanged] so the cubit
/// stays the single source of truth for the composer value; the controller
/// here is a thin local mirror that re-syncs whenever the cubit clears the
/// text post-send.
class ChatComposer extends StatefulWidget {
  const ChatComposer({super.key});

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
    final choice = await showModalBottomSheet<_AttachmentChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _AttachmentSheet(l10n: l10n),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AttachmentChoice.camera:
        await context.read<ChatCubit>().sendPhotoFromCamera();
      case _AttachmentChoice.gallery:
        await context.read<ChatCubit>().sendPhotoFromGallery();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (prev, curr) =>
          prev.composerText != curr.composerText &&
          curr.composerText != _controller.text,
      listener: (_, state) {
        _controller.value = TextEditingValue(
          text: state.composerText,
          selection: TextSelection.collapsed(offset: state.composerText.length),
        );
      },
      child: SafeArea(
        top: false,
        child: Container(
          color: colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(
            Spacing.small,
            Spacing.twoXSmall,
            Spacing.small,
            Spacing.small,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BlocBuilder<ChatCubit, ChatState>(
                buildWhen: (p, c) => p.isAttaching != c.isAttaching,
                builder: (context, state) {
                  return IconButton(
                    key: ChatComposer.attachButtonKey,
                    icon: state.isAttaching
                        ? const OmdsButtonLoading(
                            size: Sizes.large,
                            strokeWidth: UIConstants.strokeWidthNormal,
                          )
                        : const Icon(Icons.attach_file),
                    tooltip: l10n.chatAttachTooltip,
                    onPressed: state.isAttaching ? null : _openAttachmentSheet,
                  );
                },
              ),
              Expanded(
                child: OmdsTextField(
                  key: ChatComposer.textFieldKey,
                  controller: _controller,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  hintText: l10n.chatComposerHint,
                  borderRadius: UIConstants.borderRadiusXLarge,
                  onChanged: (v) =>
                      context.read<ChatCubit>().composerChanged(v),
                ),
              ),
              BlocBuilder<ChatCubit, ChatState>(
                buildWhen: (p, c) => p.canSendText != c.canSendText,
                builder: (context, state) {
                  return IconButton.filled(
                    key: ChatComposer.sendButtonKey,
                    icon: const Icon(Icons.send),
                    tooltip: l10n.chatSendTooltip,
                    onPressed: state.canSendText ? _send : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AttachmentChoice { camera, gallery }

class _AttachmentSheet extends StatelessWidget {
  const _AttachmentSheet({required this.l10n});

  final AppLocalizations l10n;

  static const Key cameraKey = Key('chat-attachment-camera');
  static const Key galleryKey = Key('chat-attachment-gallery');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.medium),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: OmdsBorderRadius.topXLarge,
        ),
        padding: const EdgeInsets.all(Spacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: Spacing.threeXLarge,
              height: Spacing.twoXSmall,
              decoration: BoxDecoration(
                color: colorScheme.outline,
                borderRadius: const BorderRadius.all(
                  Radius.circular(Sizes.threeXSmall),
                ),
              ),
            ),
            const SizedBox(height: Spacing.large),
            Text(
              l10n.chatAttachmentSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.medium),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  key: cameraKey,
                  icon: Icons.photo_camera,
                  label: l10n.chatAttachmentCamera,
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentChoice.camera),
                ),
                _AttachmentOption(
                  key: galleryKey,
                  icon: Icons.photo_library,
                  label: l10n.chatAttachmentGallery,
                  onTap: () =>
                      Navigator.of(context).pop(_AttachmentChoice.gallery),
                ),
              ],
            ),
            const SizedBox(height: Spacing.medium),
            OmdsPrimaryButton(
              text: l10n.chatAttachmentCancel,
              variant: OmdsButtonVariant.text,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: OmdsBorderRadius.medium,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.large,
          vertical: Spacing.medium,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: Sizes.fiveXLarge,
              height: Sizes.fiveXLarge,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.onPrimary, size: 28),
            ),
            const SizedBox(height: Spacing.small),
            Text(label, style: textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
