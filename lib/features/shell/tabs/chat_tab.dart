import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
