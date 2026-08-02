import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/chat_cubit.dart';
import '../../application/chat_state.dart';
import 'chat_composer_icon_button.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/chat_gateway.dart';
import '../../domain/delivery_chat_message.dart';
import '../../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// Text + attachment input pinned to chat bottom. Matches Figma (56535:6659 / 56546:2382):
/// leading attach, rounded field, voice affordance (hidden B-04), send pill.
/// Text field feeds ChatCubit.composerChanged; controller is local mirror re-synced post-send.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    this.hintText,
    this.onVoiceRecordingComplete,
    this.inputIdentifier = 'chat_detail_message_input',
    this.sendIdentifier = 'chat_detail_send_button',
  });

  /// Optional composer hint override. Jeeber variant passes `chatComposerHintPriceTime`.
  final String? hintText;

  /// Voice notes seam (reserved, not yet invoked; B-04: mic hidden, ChatComposerVoiceControl never built).
  final void Function(List<int>, String, int)? onVoiceRecordingComplete;

  /// Semantics identifier for text field. Defaults to `chat_detail_message_input`
  /// (active-delivery chat); order-chat overrides to `order_chat_composer_input` (JM-025).
  final String inputIdentifier;

  /// Semantics identifier for send button. Defaults to `chat_detail_send_button`;
  /// order-chat overrides to `order_chat_composer_send` (JM-025, first send broadcasts).
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
    // `photoIcon` / `videoIcon` / `subtitle` (they exist on constructor but helper never forwards them).
    // Mount OMDS component directly to pass them. `'video'` is OMDS's slot for gallery row, not recorder.
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

/// Composer surface: hairline top border, attach + field + send row.
/// B-04: mic affordance hidden until real voice-note capture lands.
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Color topBorderColor;
  final String? hintText;
  final VoidCallback onSend;
  final Future<void> Function() onAttach;
  final String inputIdentifier;
  final String sendIdentifier;

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
              // B-04: mic affordance NOT rendered. press-to-record (ChatComposerVoiceControl, T-MOB-016)
              // was never built, so button was permanent no-op on highest-traffic surface. Hidden until real
              // voice-note capture lands (send path, ChatCubit.sendVoiceNote, onVoiceRecordingComplete seam remain).
              _SendButton(onSend: onSend, sendIdentifier: sendIdentifier),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leading attach (+) affordance; shows spinner while pick in flight.
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

/// Navy circular send pill; enabled only when composer text non-empty.
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/chat_composer_preview_test.dart
// ===========================================================================

// Widget previews for [ChatComposer] — run with
// `flutter widget-preview start`.
//
// The composer is driven the way the chat screen drives it: an ambient
// [ChatCubit] is the single source of truth for the composer value and for
// `isAttaching` / `canSendText`. A cubit built with an inert gateway and never
// `load()`ed performs no I/O — nothing subscribes, nothing fetches — so these
// previews are network-free by construction, not just by the guard in
// [jeebPreviewHost].
//
// Two things about this widget shape the file:
//
// * **Typed text has to be TYPED.** The field's controller is a local mirror
//   that only re-syncs from a `BlocListener` on a `composerText` *change*
//   (`chat_composer.dart:121`). Seeding a cubit whose state already carries
//   text therefore renders an EMPTY field. States that need text in the field
//   emit it after the first frame ([_TypeOnMount]) — i.e. they simulate the
//   user typing, which is the only path production has.
// * **The mic is gone (B-04).** `test/features/chat/chat_composer_no_mic_b04_test.dart`
//   pins its absence; these previews are where you *see* that the row is
//   attach + field + send and nothing else.
//
// Fixture strings are reused from the existing composer tests
// (`order_chat_jm025_test.dart`, `chat_screen_test.dart`) rather than invented,
// so a preview and its test talk about the same message a real flow sends.

/// One composed line: phone width, a bar's worth of height.
const Size _chatComposerComposerBox = Size(390, 140);

/// The multi-line ceiling (`maxLines: 5`) needs room to show the growth.
const Size _chatComposerTallComposerBox = Size(390, 260);

/// Reused from `order_chat_jm025_test.dart` — the real W1 first message.
const String _chatComposerOrderDraft = 'I need standard delivery from downtown to airport';

/// Reused from `chat_screen_test.dart`'s mixed RTL/LTR conversation.
const String _chatComposerBidiDraft = 'OK شكراً';

/// A long, entirely plausible drop-off instruction: the state that finds the
/// `maxLines: 5` ceiling and the send pill's alignment.
const String _chatComposerLongDraft =
    'Please leave the parcel with the concierge at the main entrance, tell him '
    'it is for apartment 12B, and if nobody answers call me before you leave '
    'the building.';

/// Inert transport. [ChatCubit.load] is never called in a preview, so none of
/// these run; they exist because [ChatGateway] declares them, and they are
/// deliberately empty rather than network-backed.
class _ChatComposerInertChatGateway extends ChatGateway {
  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      const <DeliveryChatMessage>[];

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async =>
      ConversationPhase.broadcasting;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

/// A [ChatCubit] parked on a fixed [ChatState]. No `load()`, no timers, no
/// push subscription (`refreshSignals` is null).
class _ChatComposerPreviewChatCubit extends ChatCubit {
  _ChatComposerPreviewChatCubit(ChatState seed)
      : super(
          deliveryId: 'preview-conversation',
          gateway: _ChatComposerInertChatGateway(),
          pickerService: StubPhotoPickerService(),
        ) {
    emit(seed);
  }
}

/// Types [text] into the ambient cubit one frame after mount.
///
/// Not a convenience: it is the only way to get text into the FIELD. See the
/// library doc — the controller mirrors `composerText` transitions only, so a
/// pre-seeded value would light the send pill while the field stayed blank.
class _ChatComposerTypeOnMount extends StatefulWidget {
  const _ChatComposerTypeOnMount({required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  State<_ChatComposerTypeOnMount> createState() => _ChatComposerTypeOnMountState();
}

class _ChatComposerTypeOnMountState extends State<_ChatComposerTypeOnMount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ChatCubit>().composerChanged(widget.text);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Hosts the composer the way the chat screen does: pinned to the bottom, with
/// a cubit above it.
///
/// [hint] is resolved from the ambient [AppLocalizations] rather than passed as
/// a literal so the Jeeber variant stays translated in the AR rendering.
Widget _chatComposerHosted({
  ChatState seed = const ChatState(),
  String Function(AppLocalizations l10n)? hint,
  String? typed,
}) {
  return BlocProvider<ChatCubit>(
    create: (_) => _ChatComposerPreviewChatCubit(seed),
    child: Builder(
      builder: (BuildContext context) {
        final Widget composer = ChatComposer(
          hintText: hint?.call(AppLocalizations.of(context)),
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: typed == null
              ? composer
              : _ChatComposerTypeOnMount(text: typed, child: composer),
        );
      },
    ),
  );
}

/// Blank composer — the state every thread opens in.
///
/// The send pill is DISABLED here (`canSendText` is false on empty/whitespace
/// text, matching the Figma "Disabled=True" blank state). If this ever renders
/// a navy, tappable send button, the empty-send guard has broken.
@JeebPreview(group: 'chat', name: 'Empty · send disabled', size: _chatComposerComposerBox)
Widget chatComposerEmpty() => _chatComposerHosted();

/// A draft ready to go: the send pill lights up only once trimmed text exists.
///
/// Same string the JM-025 order-chat test sends, so this is literally the
/// message that broadcasts a request on first send.
@JeebPreview(group: 'chat', name: 'Draft · send enabled', size: _chatComposerComposerBox)
Widget chatComposerDraft() => _chatComposerHosted(typed: _chatComposerOrderDraft);

/// The Jeeber (delivery-man) variant, which overrides the hint to
/// "Price / time" because the Jeeber's first message is a quote, not chit-chat.
///
/// Worth its own preview because the override is the one string on this widget
/// a caller can get wrong: pass a raw literal instead of an l10n key and the AR
/// rendering silently stays English.
@JeebPreview(group: 'chat', name: 'Jeeber hint · Price / time', size: _chatComposerComposerBox)
Widget chatComposerJeeberHint() =>
    _chatComposerHosted(hint: (AppLocalizations l10n) => l10n.chatComposerHintPriceTime);

/// A photo pick is in flight: the "+" is replaced by a spinner so a second tap
/// can't race the first.
///
/// The interesting part is the swap itself — [OmdsButtonLoading] sits in a
/// different padding box than [ChatComposerIconButton], so this is where the
/// row jumps if the two ever stop agreeing on size. A draft is left in the
/// field because that is the real sequence: people type, then attach.
@JeebPreview(group: 'chat', name: 'Attaching · spinner', size: _chatComposerComposerBox)
Widget chatComposerAttaching() => _chatComposerHosted(
      seed: const ChatState(isAttaching: true),
      typed: 'Photo of the gate coming now',
    );

/// Mixed Arabic/Latin in one draft — the app's actual conversation style
/// (`chat_screen_test.dart` sends exactly this).
///
/// Bidi text is where a composer breaks first: the paragraph direction the
/// field resolves comes from the LOCALE, so the same string renders with its
/// two runs in opposite order in the EN and AR renderings of this matrix.
/// Check the cursor and the trailing punctuation, not just the glyphs.
@JeebPreview(group: 'chat', name: 'Bidi draft', size: _chatComposerComposerBox)
Widget chatComposerBidiDraft() => _chatComposerHosted(typed: _chatComposerBidiDraft);

/// Layout ceiling: a long drop-off instruction against the `maxLines: 5` cap.
///
/// The field must grow and then scroll internally — it must never push the
/// attach or send affordance out of the row, and at 200% text this is the
/// rendering that shows whether the bar still fits above a keyboard.
@JeebPreview(group: 'chat', name: 'Long draft · maxLines cap', size: _chatComposerTallComposerBox)
Widget chatComposerLongDraft() => _chatComposerHosted(typed: _chatComposerLongDraft);
