/// Widget previews for [ChatConnectionBanner] — run with
/// `flutter widget-preview start`.
///
/// The banner is a pure function of one value object: it takes a
/// [ChatConnectionState] and renders a strip. No cubit, no repository, no
/// socket — so every state below is a hand-built [ChatConnectionState] literal
/// and these previews are network-free by construction, not just by the guard
/// in [jeebPreviewHost]. (The production owner of that state,
/// `ChatConnectionCubit`, opens a socket in `start()`; a preview must never
/// build one.)
///
/// The states mirror the four [ConnectionStatus] values plus the outbox badge,
/// using the same fixture shape as `test/chat_connection_cubit_test.dart`
/// (conversation `conv-1`, sender `me`, clock 2026-05-17). The previews exist
/// so the *visual* half of that contract — the Row's behaviour when the label
/// is a full sentence and the badge is wide, RTL mirroring of icon/label/badge,
/// and the fg/bg colour pairing in dark mode — is reviewable without booting
/// the app and opening a chat.
library;

import 'package:flutter/material.dart';

import '../../features/chat/application/chat_connection_state.dart';
import '../../features/chat/domain/chat_message.dart';
import '../../features/chat/domain/connection_status.dart';
import '../../features/chat/presentation/chat_connection_banner.dart';
import '../harness/jeeb_preview.dart';

/// Canvas box for the short-label states: phone width, one strip tall with
/// room for the 200%-text rendering to grow into.
const Size _stripBox = Size(390, 96);

/// Canvas box for the offline states. Their label is a full sentence
/// ("You're offline. Messages will send when you reconnect."), which wraps to
/// three lines at 200% text; a 96px box would clip the evidence.
const Size _tallStripBox = Size(390, 190);

/// Fixed clock, matching `test/chat_connection_cubit_test.dart`.
final DateTime _enqueuedAt = DateTime.utc(2026, 5, 17, 12, 0);

/// [count] outbox entries, oldest-first, in the wire shape the cubit enqueues.
///
/// Only `pending.length` reaches the banner (via `pendingCount`), but the
/// previews build real [ChatMessage]s rather than a stub list so the fixture
/// stays honest if the badge ever starts reading message content.
List<ChatMessage> _outbox(int count) => List<ChatMessage>.generate(
      count,
      (int i) => ChatMessage(
        clientId: 'c-${i + 1}',
        conversationId: 'conv-1',
        senderId: 'me',
        body: 'queued message ${i + 1}',
        createdAt: _enqueuedAt,
      ),
    );

Widget _hosted(
  ConnectionStatus status, {
  int pending = 0,
  int reconnectAttempt = 0,
  String? lastError,
}) =>
    ChatConnectionBanner(
      state: ChatConnectionState(
        status: status,
        reconnectAttempt: reconnectAttempt,
        pending: _outbox(pending),
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
@JeebPreview(name: 'Connected', size: _stripBox)
Widget chatConnectionBannerConnected() => _hosted(ConnectionStatus.connected);

/// Cold start: the first `connect()` is in flight and nothing has been queued
/// yet. Distinct copy from `reconnecting` on purpose (see the doc comment on
/// [ConnectionStatus]) — this is the first-time spinner, not a retry.
@JeebPreview(name: 'Connecting', size: _stripBox)
Widget chatConnectionBannerConnecting() => _hosted(ConnectionStatus.connecting);

/// Connected, but two sends are still awaiting their ack.
///
/// This is the state `sendMessage` leaves behind while connected (the cubit
/// test asserts `pending.length == 1` immediately after a flush), and it is the
/// only way the badge is ever seen on the connected fill. If the badge is
/// illegible here, users see "Connected" with an invisible badge beside it
/// every time they type.
@JeebPreview(name: 'Connected + in-flight', size: _stripBox)
Widget chatConnectionBannerConnectedPending() =>
    _hosted(ConnectionStatus.connected, pending: 2);

/// Backoff is running after a drop, with the outbox holding three messages.
///
/// `reconnectAttempt` is carried in the state but never rendered — the strip
/// shows the same copy on attempt 1 and attempt 9, which is deliberate.
@JeebPreview(name: 'Reconnecting + outbox', size: _stripBox)
Widget chatConnectionBannerReconnecting() => _hosted(
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
@JeebPreview(name: 'Offline + full outbox', size: _tallStripBox)
Widget chatConnectionBannerOfflineFullOutbox() => _hosted(
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
@JeebPreview(name: 'Offline + one pending', size: _tallStripBox)
Widget chatConnectionBannerOfflineOnePending() =>
    _hosted(ConnectionStatus.disconnected, pending: 1);
