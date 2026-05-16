import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../photo_attachment/data/stub_photo_picker_service.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../application/chat_cubit.dart';
import '../application/chat_state.dart';
import '../data/in_memory_chat_gateway.dart';
import '../domain/chat_gateway.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_message_bubble.dart';

/// WhatsApp-style 1:1 chat between the client and the Jeeber for an active
/// delivery (T-mobile-016 / JEEB-69).
///
/// The screen owns a [ChatCubit], wires it to a [ChatGateway] (the MVP
/// in-memory implementation by default) and a [PhotoPickerService] (the
/// stub picker until image_picker lands in a later mobile task), and
/// auto-scrolls to the latest message whenever the cubit emits.
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.deliveryId,
    required this.counterpartName,
    this.cubit,
    this.gateway,
    this.pickerService,
  }) : assert(
         cubit == null || (gateway == null && pickerService == null),
         'Provide either a cubit or the (gateway, pickerService) pair, not both.',
       );

  /// Backing delivery this chat thread belongs to. Used as the gateway
  /// channel id and as the prefix for outgoing message ids.
  final String deliveryId;

  /// Display name in the app bar — the Jeeber's name on the client side, the
  /// client's name on the Jeeber side.
  final String counterpartName;

  /// Pre-built cubit for widget tests / hosts that own the lifecycle.
  final ChatCubit? cubit;

  /// Optional gateway + picker overrides when [cubit] is not supplied.
  final ChatGateway? gateway;
  final PhotoPickerService? pickerService;

  static const Key rootKey = Key('chat-screen-root');
  static const Key messageListKey = Key('chat-screen-message-list');
  static const Key emptyStateKey = Key('chat-screen-empty');

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<ChatCubit>.value(
        value: provided,
        child: _ChatScaffold(counterpartName: counterpartName),
      );
    }
    return BlocProvider<ChatCubit>(
      create: (_) => ChatCubit(
        deliveryId: deliveryId,
        gateway: gateway ?? InMemoryChatGateway(),
        pickerService: pickerService ?? StubPhotoPickerService(),
      )..load(),
      child: _ChatScaffold(counterpartName: counterpartName),
    );
  }
}

class _ChatScaffold extends StatefulWidget {
  const _ChatScaffold({required this.counterpartName});

  final String counterpartName;

  @override
  State<_ChatScaffold> createState() => _ChatScaffoldState();
}

class _ChatScaffoldState extends State<_ChatScaffold> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToBottom() {
    // Defer the scroll until after the next frame so the list has actually
    // sized in the new entry before we try to jump.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: ChatScreen.rootKey,
      appBar: OMDSAppBar(title: widget.counterpartName, showBackButton: true),
      body: SafeArea(
        bottom: false,
        child: BlocConsumer<ChatCubit, ChatState>(
          listenWhen: (prev, curr) =>
              prev.messages.length != curr.messages.length ||
              prev.error != curr.error,
          listener: (context, state) {
            // Auto-scroll on any message-count change. The hasClients guard
            // inside the scheduler covers the empty-list / mid-dispose cases.
            _scheduleScrollToBottom();
            final error = state.error;
            if (error != null) {
              final message = _messageFor(l10n, error);
              if (message != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              context.read<ChatCubit>().acknowledgeError();
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                Expanded(child: _buildMessages(context, state, l10n)),
                const Divider(height: 1),
                const ChatComposer(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessages(
    BuildContext context,
    ChatState state,
    AppLocalizations l10n,
  ) {
    if (state.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.messages.isEmpty) {
      return Center(
        child: OmdsEmptyState(
          key: ChatScreen.emptyStateKey,
          icon: Icons.chat_bubble_outline,
          title: l10n.chatEmptyThreadTitle,
          subtitle: l10n.chatEmptyThreadSubtitle,
        ),
      );
    }
    return ListView.builder(
      key: ChatScreen.messageListKey,
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: Spacing.small),
      itemCount: state.messages.length,
      itemBuilder: (context, index) =>
          ChatMessageBubble(message: state.messages[index]),
    );
  }

  String? _messageFor(AppLocalizations l10n, ChatError error) {
    switch (error) {
      case ChatError.pickCancelled:
        return null;
      case ChatError.permissionDenied:
        return l10n.chatErrorPermissionDenied;
      case ChatError.pickUnavailable:
        return l10n.chatErrorPickUnavailable;
      case ChatError.sendFailed:
        return l10n.chatErrorSendFailed;
    }
  }
}
