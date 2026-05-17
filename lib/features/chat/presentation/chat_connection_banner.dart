import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../application/chat_connection_state.dart';
import '../domain/connection_status.dart';

/// Slim indicator strip rendered above the chat list. Shows live connection
/// state + outbox badge so the user understands why their messages may not
/// have shipped yet.
///
/// Built on raw Material colors via `Theme.of(context).colorScheme` to stay
/// inside the OMDS M3 token system. No raw `Colors.X` references.
class ChatConnectionBanner extends StatelessWidget {
  const ChatConnectionBanner({super.key, required this.state});

  final ChatConnectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg, icon) = _decoration(state.status, scheme, l10n);
    return Container(
      key: const Key('chat-connection-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: fg, fontWeight: FontWeight.w600),
            ),
          ),
          if (state.pendingCount > 0)
            Text(
              l10n.chatPendingMessages(state.pendingCount),
              key: const Key('chat-pending-badge'),
              style: TextStyle(color: fg),
            ),
        ],
      ),
    );
  }

  (String, Color, Color, IconData) _decoration(
    ConnectionStatus status,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    switch (status) {
      case ConnectionStatus.connected:
        return (
          l10n.chatStatusConnected,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Icons.cloud_done_outlined,
        );
      case ConnectionStatus.connecting:
        return (
          l10n.chatStatusConnecting,
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          Icons.cloud_sync_outlined,
        );
      case ConnectionStatus.reconnecting:
        return (
          l10n.chatStatusReconnecting,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          Icons.sync_problem_outlined,
        );
      case ConnectionStatus.disconnected:
        return (
          l10n.chatStatusOffline,
          scheme.errorContainer,
          scheme.onErrorContainer,
          Icons.cloud_off_outlined,
        );
    }
  }
}
