import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/jeeb/jeeb_quick_reply_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/chat_cubit.dart';

/// Screen-local consumer of the kit's [JeebQuickReplyRow]: three client-voice
/// canned replies, sent in one tap via [ChatCubit.sendQuickReply].
///
/// The pill LABEL is the message that gets sent, which is why the gating lives
/// at the mount site (`chat_screen.dart`) rather than here: these lines are
/// client-voice, and in the compose state the first outgoing message becomes
/// the request's own description — a quick-tapped "I'm home" would create a
/// request described "I'm home".
///
/// Layout (padding, pill geometry, horizontal scroll, and the deliberate
/// no-forced-LTR rule that lets the Arabic pill shape itself inside an English
/// thread) is kit-owned. Do not wrap this in a second scroll view.
class ChatQuickReplyBar extends StatelessWidget {
  const ChatQuickReplyBar({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ChatCubit cubit = context.read<ChatCubit>();
    return JeebQuickReplyRow(
      identifier: 'order_chat_quick_reply_row',
      semanticLabel: l10n.chatQuickReplyRowA11y,
      replies: <JeebQuickReply>[
        JeebQuickReply(
          label: l10n.chatQuickReplyImHome,
          identifier: 'order_chat_quick_reply_home',
          onTap: () => cubit.sendQuickReply(l10n.chatQuickReplyImHome),
        ),
        JeebQuickReply(
          label: l10n.chatQuickReplyCallAtDoor,
          identifier: 'order_chat_quick_reply_door',
          onTap: () => cubit.sendQuickReply(l10n.chatQuickReplyCallAtDoor),
        ),
        JeebQuickReply(
          label: l10n.chatQuickReplyThanks,
          identifier: 'order_chat_quick_reply_thanks',
          onTap: () => cubit.sendQuickReply(l10n.chatQuickReplyThanks),
        ),
      ],
    );
  }
}
