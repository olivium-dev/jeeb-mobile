import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
    final textTheme = Theme.of(context).textTheme;
    final (label, bg, fg, icon) = _decoration(state.status, scheme, l10n);
    return Container(
      key: const Key('chat-connection-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      color: bg,
      child: Row(
        children: [
          Icon(icon, size: Sizes.medium, color: fg),
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (state.pendingCount > 0)
            Text(
              l10n.chatPendingMessages(state.pendingCount),
              key: const Key('chat-pending-badge'),
              style: textTheme.labelMedium?.copyWith(color: fg),
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
