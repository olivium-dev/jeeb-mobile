import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/chat_connection_state.dart';
import '../domain/connection_status.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../domain/chat_message.dart';
import '../../../core/previews/jeeb_preview.dart';

/// Uses raw Material colors (Theme.of(context).colorScheme, not Colors.X) to stay inside OMDS M3 tokens.
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
          scheme.onPrimary,
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [ChatConnectionBanner] — run with

/// Canvas box for the short-label states: phone width, one strip tall with
/// room for the 200%-text rendering to grow into.
const Size _chatConnectionBannerStripBox = Size(390, 96);

/// Canvas box for the offline states. Their label is a full sentence
/// ("You're offline. Messages will send when you reconnect."), which wraps to
const Size _chatConnectionBannerTallStripBox = Size(390, 190);

/// Fixed clock, matching `test/chat_connection_cubit_test.dart`.
final DateTime _chatConnectionBannerEnqueuedAt = DateTime.utc(2026, 5, 17, 12, 0);

/// [count] outbox entries, oldest-first, in the wire shape the cubit enqueues.
/// Only `pending.length` reaches the banner (via `pendingCount`), but the
List<ChatMessage> _chatConnectionBannerOutbox(int count) => List<ChatMessage>.generate(
      count,
      (int i) => ChatMessage(
        clientId: 'c-${i + 1}',
        conversationId: 'conv-1',
        senderId: 'me',
        body: 'queued message ${i + 1}',
        createdAt: _chatConnectionBannerEnqueuedAt,
      ),
    );

Widget _chatConnectionBannerHosted(
  ConnectionStatus status, {
  int pending = 0,
  int reconnectAttempt = 0,
  String? lastError,
}) =>
    ChatConnectionBanner(
      state: ChatConnectionState(
        status: status,
        reconnectAttempt: reconnectAttempt,
        pending: _chatConnectionBannerOutbox(pending),
        lastError: lastError,
      ),
    );

/// The happy path: socket up, outbox empty. The strip is still rendered (it is
/// not hidden when healthy), so this is what sits above the message list for
@JeebPreview(group: 'chat', name: 'Connected', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerConnected() => _chatConnectionBannerHosted(ConnectionStatus.connected);

/// Cold start: the first `connect()` is in flight and nothing has been queued
/// yet. Distinct copy from `reconnecting` on purpose (see the doc comment on
@JeebPreview(group: 'chat', name: 'Connecting', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerConnecting() => _chatConnectionBannerHosted(ConnectionStatus.connecting);

/// Connected, but two sends are still awaiting their ack.
/// This is the state `sendMessage` leaves behind while connected (the cubit
@JeebPreview(group: 'chat', name: 'Connected + in-flight', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerConnectedPending() =>
    _chatConnectionBannerHosted(ConnectionStatus.connected, pending: 2);

/// Backoff is running after a drop, with the outbox holding three messages.
/// `reconnectAttempt` is carried in the state but never rendered — the strip
@JeebPreview(group: 'chat', name: 'Reconnecting + outbox', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerReconnecting() => _chatConnectionBannerHosted(
      ConnectionStatus.reconnecting,
      pending: 3,
      reconnectAttempt: 3,
      lastError: 'WebSocketChannelException: connection closed',
    );

/// Layout ceiling: the longest label the widget can show, next to the widest
/// badge a real outbox produces.
@JeebPreview(group: 'chat', name: 'Offline + full outbox', size: _chatConnectionBannerTallStripBox)
Widget chatConnectionBannerOfflineFullOutbox() => _chatConnectionBannerHosted(
      ConnectionStatus.disconnected,
      pending: 12,
      lastError: 'SocketException: Network is unreachable',
    );

/// The singular plural branch, which no other preview reaches.
/// EN collapses 1 to "1 pending message"; Arabic uses a dedicated word form
@JeebPreview(group: 'chat', name: 'Offline + one pending', size: _chatConnectionBannerTallStripBox)
Widget chatConnectionBannerOfflineOnePending() =>
    _chatConnectionBannerHosted(ConnectionStatus.disconnected, pending: 1);
