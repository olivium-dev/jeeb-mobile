import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../features/chat/application/chat_connection_cubit.dart';
import '../../../features/chat/application/chat_connection_state.dart';
import '../../../features/chat/presentation/chat_connection_banner.dart';
import '../../../l10n/app_localizations.dart';

/// Conversation list tab.
///
/// Pre T-mobile-017 this was a static empty state; now the tab also surfaces
/// the live WebSocket [ChatConnectionState] so the user always knows whether
/// their messages are going through. A [BlocProvider] for [ChatConnectionCubit]
/// must be installed above this widget; if it isn't (e.g. legacy widget
/// tests), the tab falls back to the original empty state.
class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `ChatConnectionCubit` is wired by the host (jeeb-app DI) when the chat
    // feature is live. Widget tests of the shell that don't care about the
    // chat WS path just don't install it; fall back to the original empty
    // state in that case so legacy tests keep passing.
    ChatConnectionCubit? cubit;
    try {
      cubit = BlocProvider.of<ChatConnectionCubit>(context, listen: false);
    } on Object {
      cubit = null;
    }
    if (cubit == null) {
      return _ChatEmptyContent(l10n: l10n);
    }
    return BlocBuilder<ChatConnectionCubit, ChatConnectionState>(
      bloc: cubit,
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChatConnectionBanner(state: state),
            Expanded(child: _ChatEmptyContent(l10n: l10n)),
          ],
        );
      },
    );
  }
}

class _ChatEmptyContent extends StatelessWidget {
  const _ChatEmptyContent({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: OmdsEmptyState(
        key: const Key('chat-tab-empty'),
        icon: Icons.chat_bubble_outline,
        title: l10n.chatTitle,
        subtitle: l10n.chatEmpty,
      ),
    );
  }
}
