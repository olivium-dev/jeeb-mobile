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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/chat_connection_banner_preview_test.dart
// ===========================================================================

// Widget previews for [ChatConnectionBanner] — run with
// `flutter widget-preview start`.
//
// The banner is a pure function of one value object: it takes a
// [ChatConnectionState] and renders a strip. No cubit, no repository, no
// socket — so every state below is a hand-built [ChatConnectionState] literal
// and these previews are network-free by construction, not just by the guard
// in [jeebPreviewHost]. (The production owner of that state,
// `ChatConnectionCubit`, opens a socket in `start()`; a preview must never
// build one.)
//
// The states mirror the four [ConnectionStatus] values plus the outbox badge,
// using the same fixture shape as `test/chat_connection_cubit_test.dart`
// (conversation `conv-1`, sender `me`, clock 2026-05-17). The previews exist
// so the *visual* half of that contract — the Row's behaviour when the label
// is a full sentence and the badge is wide, RTL mirroring of icon/label/badge,
// and the fg/bg colour pairing in dark mode — is reviewable without booting
// the app and opening a chat.

/// Canvas box for the short-label states: phone width, one strip tall with
/// room for the 200%-text rendering to grow into.
const Size _chatConnectionBannerStripBox = Size(390, 96);

/// Canvas box for the offline states. Their label is a full sentence
/// ("You're offline. Messages will send when you reconnect."), which wraps to
/// three lines at 200% text; a 96px box would clip the evidence.
const Size _chatConnectionBannerTallStripBox = Size(390, 190);

/// Fixed clock, matching `test/chat_connection_cubit_test.dart`.
final DateTime _chatConnectionBannerEnqueuedAt = DateTime.utc(2026, 5, 17, 12, 0);

/// [count] outbox entries, oldest-first, in the wire shape the cubit enqueues.
///
/// Only `pending.length` reaches the banner (via `pendingCount`), but the
/// previews build real [ChatMessage]s rather than a stub list so the fixture
/// stays honest if the badge ever starts reading message content.
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
/// most of a conversation's life.
///
/// Worth reviewing in the AR RTL **dark** rendering specifically: this is the
/// only status whose foreground is not the `on*` partner of its background —
/// it fills with `secondaryContainer` and inks with `onPrimary`.
@JeebPreview(group: 'chat', name: 'Connected', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerConnected() => _chatConnectionBannerHosted(ConnectionStatus.connected);

/// Cold start: the first `connect()` is in flight and nothing has been queued
/// yet. Distinct copy from `reconnecting` on purpose (see the doc comment on
/// [ConnectionStatus]) — this is the first-time spinner, not a retry.
@JeebPreview(group: 'chat', name: 'Connecting', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerConnecting() => _chatConnectionBannerHosted(ConnectionStatus.connecting);

/// Connected, but two sends are still awaiting their ack.
///
/// This is the state `sendMessage` leaves behind while connected (the cubit
/// test asserts `pending.length == 1` immediately after a flush), and it is the
/// only way the badge is ever seen on the connected fill. If the badge is
/// illegible here, users see "Connected" with an invisible badge beside it
/// every time they type.
@JeebPreview(group: 'chat', name: 'Connected + in-flight', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerConnectedPending() =>
    _chatConnectionBannerHosted(ConnectionStatus.connected, pending: 2);

/// Backoff is running after a drop, with the outbox holding three messages.
///
/// `reconnectAttempt` is carried in the state but never rendered — the strip
/// shows the same copy on attempt 1 and attempt 9, which is deliberate.
@JeebPreview(group: 'chat', name: 'Reconnecting + outbox', size: _chatConnectionBannerStripBox)
Widget chatConnectionBannerReconnecting() => _chatConnectionBannerHosted(
      ConnectionStatus.reconnecting,
      pending: 3,
      reconnectAttempt: 3,
      lastError: 'WebSocketChannelException: connection closed',
    );

/// Layout ceiling: the longest label the widget can show, next to the widest
/// badge a real outbox produces.
///
/// The offline copy is a full sentence, and 12 lands on the `Many` plural
/// branch, so the `Expanded` label and the unconstrained badge compete for one
/// 390px row. This is the state the AR RTL and 200%-text renderings of the
/// matrix exist for — the EN light rendering looks fine long after the other
/// two have broken.
@JeebPreview(group: 'chat', name: 'Offline + full outbox', size: _chatConnectionBannerTallStripBox)
Widget chatConnectionBannerOfflineFullOutbox() => _chatConnectionBannerHosted(
      ConnectionStatus.disconnected,
      pending: 12,
      lastError: 'SocketException: Network is unreachable',
    );

/// The singular plural branch, which no other preview reaches.
///
/// EN collapses 1 to "1 pending message"; Arabic uses a dedicated word form
/// (`رسالة معلّقة واحدة`) with no digit at all, and 2 uses a *dual* form. A
/// badge built by interpolating a count into one template would look correct
/// here in English and wrong in Arabic, so both locales are worth a look.
@JeebPreview(group: 'chat', name: 'Offline + one pending', size: _chatConnectionBannerTallStripBox)
Widget chatConnectionBannerOfflineOnePending() =>
    _chatConnectionBannerHosted(ConnectionStatus.disconnected, pending: 1);
