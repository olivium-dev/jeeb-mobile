/// Widget previews for [ChatComposer] — run with
/// `flutter widget-preview start`.
///
/// The composer is driven the way the chat screen drives it: an ambient
/// [ChatCubit] is the single source of truth for the composer value and for
/// `isAttaching` / `canSendText`. A cubit built with an inert gateway and never
/// `load()`ed performs no I/O — nothing subscribes, nothing fetches — so these
/// previews are network-free by construction, not just by the guard in
/// [jeebPreviewHost].
///
/// Two things about this widget shape the file:
///
/// * **Typed text has to be TYPED.** The field's controller is a local mirror
///   that only re-syncs from a `BlocListener` on a `composerText` *change*
///   (`chat_composer.dart:121`). Seeding a cubit whose state already carries
///   text therefore renders an EMPTY field. States that need text in the field
///   emit it after the first frame ([_TypeOnMount]) — i.e. they simulate the
///   user typing, which is the only path production has.
/// * **The mic is gone (B-04).** `test/features/chat/chat_composer_no_mic_b04_test.dart`
///   pins its absence; these previews are where you *see* that the row is
///   attach + field + send and nothing else.
///
/// Fixture strings are reused from the existing composer tests
/// (`order_chat_jm025_test.dart`, `chat_screen_test.dart`) rather than invented,
/// so a preview and its test talk about the same message a real flow sends.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/chat/application/chat_cubit.dart';
import '../../features/chat/application/chat_state.dart';
import '../../features/chat/domain/chat_gateway.dart';
import '../../features/chat/domain/delivery_chat_message.dart';
import '../../features/chat/presentation/widgets/chat_composer.dart';
import '../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// One composed line: phone width, a bar's worth of height.
const Size _composerBox = Size(390, 140);

/// The multi-line ceiling (`maxLines: 5`) needs room to show the growth.
const Size _tallComposerBox = Size(390, 260);

/// Reused from `order_chat_jm025_test.dart` — the real W1 first message.
const String _kOrderDraft = 'I need standard delivery from downtown to airport';

/// Reused from `chat_screen_test.dart`'s mixed RTL/LTR conversation.
const String _kBidiDraft = 'OK شكراً';

/// A long, entirely plausible drop-off instruction: the state that finds the
/// `maxLines: 5` ceiling and the send pill's alignment.
const String _kLongDraft =
    'Please leave the parcel with the concierge at the main entrance, tell him '
    'it is for apartment 12B, and if nobody answers call me before you leave '
    'the building.';

/// Inert transport. [ChatCubit.load] is never called in a preview, so none of
/// these run; they exist because [ChatGateway] declares them, and they are
/// deliberately empty rather than network-backed.
class _InertChatGateway extends ChatGateway {
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
class _PreviewChatCubit extends ChatCubit {
  _PreviewChatCubit(ChatState seed)
      : super(
          deliveryId: 'preview-conversation',
          gateway: _InertChatGateway(),
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
class _TypeOnMount extends StatefulWidget {
  const _TypeOnMount({required this.text, required this.child});

  final String text;
  final Widget child;

  @override
  State<_TypeOnMount> createState() => _TypeOnMountState();
}

class _TypeOnMountState extends State<_TypeOnMount> {
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
Widget _hosted({
  ChatState seed = const ChatState(),
  String Function(AppLocalizations l10n)? hint,
  String? typed,
}) {
  return BlocProvider<ChatCubit>(
    create: (_) => _PreviewChatCubit(seed),
    child: Builder(
      builder: (BuildContext context) {
        final Widget composer = ChatComposer(
          hintText: hint?.call(AppLocalizations.of(context)),
        );
        return Align(
          alignment: Alignment.bottomCenter,
          child: typed == null
              ? composer
              : _TypeOnMount(text: typed, child: composer),
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
@JeebPreview(name: 'Empty · send disabled', size: _composerBox)
Widget chatComposerEmpty() => _hosted();

/// A draft ready to go: the send pill lights up only once trimmed text exists.
///
/// Same string the JM-025 order-chat test sends, so this is literally the
/// message that broadcasts a request on first send.
@JeebPreview(name: 'Draft · send enabled', size: _composerBox)
Widget chatComposerDraft() => _hosted(typed: _kOrderDraft);

/// The Jeeber (delivery-man) variant, which overrides the hint to
/// "Price / time" because the Jeeber's first message is a quote, not chit-chat.
///
/// Worth its own preview because the override is the one string on this widget
/// a caller can get wrong: pass a raw literal instead of an l10n key and the AR
/// rendering silently stays English.
@JeebPreview(name: 'Jeeber hint · Price / time', size: _composerBox)
Widget chatComposerJeeberHint() =>
    _hosted(hint: (AppLocalizations l10n) => l10n.chatComposerHintPriceTime);

/// A photo pick is in flight: the "+" is replaced by a spinner so a second tap
/// can't race the first.
///
/// The interesting part is the swap itself — [OmdsButtonLoading] sits in a
/// different padding box than [ChatComposerIconButton], so this is where the
/// row jumps if the two ever stop agreeing on size. A draft is left in the
/// field because that is the real sequence: people type, then attach.
@JeebPreview(name: 'Attaching · spinner', size: _composerBox)
Widget chatComposerAttaching() => _hosted(
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
@JeebPreview(name: 'Bidi draft', size: _composerBox)
Widget chatComposerBidiDraft() => _hosted(typed: _kBidiDraft);

/// Layout ceiling: a long drop-off instruction against the `maxLines: 5` cap.
///
/// The field must grow and then scroll internally — it must never push the
/// attach or send affordance out of the row, and at 200% text this is the
/// rendering that shows whether the bar still fits above a keyboard.
@JeebPreview(name: 'Long draft · maxLines cap', size: _tallComposerBox)
Widget chatComposerLongDraft() => _hosted(typed: _kLongDraft);
