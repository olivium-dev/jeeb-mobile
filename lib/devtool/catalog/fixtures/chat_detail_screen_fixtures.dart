// Designed states for the `/chat/:id` deep-link target — ONE source of truth,

import 'package:flutter/foundation.dart';

import '../../../core/network/app_failure.dart';
import '../../../features/chat/data/dev_chat_fixture_gateway.dart';
import '../../../features/chat/domain/chat_gateway.dart';
import '../../../features/chat/domain/delivery_chat_message.dart'
    show ConversationPhase;
import '../../../features/chat/domain/order_chat_summary.dart';
import 'chat_screen_fixtures.dart';

/// One designed state of `ChatDetailScreen`, expressed as the `debug*` seam
/// arguments that produce it.
@immutable
class ChatDetailScreenPreviewState {
  const ChatDetailScreenPreviewState({
    required this.chatId,
    required this.gateway,
    this.phase = ConversationPhase.unknown,
    this.hasWinner = false,
    this.counterpartName = '',
    this.summary,
    this.summaryFailure,
  });

  /// The `/chat/:id` route param. Reaches the header through
  /// `friendlyReference` whenever no counterpart name resolves.
  final String chatId;

  /// Builds the offline gateway this state answers from.
  final ChatGateway Function() gateway;

  /// Conversation phase the screen resolves to. `broadcasting`/`unknown` with
  /// no winner is the COMPOSE branch; `accepted` is the 1:1 thread.
  final ConversationPhase phase;

  /// Whether a winning Jeeber is seated. Together with [phase] this is what
  /// decides compose vs accepted, and therefore whether the pinned strip and
  final bool hasWinner;

  /// The counterpart name the resolution produced. May deliberately be a
  /// synthetic handle — see [ChatDetailScreenPreviewFixtures.acceptedUnnamed].
  final String counterpartName;

  /// The locked pinned summary, or null when the strip must not render.
  final OrderChatSummary? summary;

  /// F44: why [summary] is missing. Non-null mounts the unavailable strip.
  final AppFailure? summaryFailure;
}

/// The designed states of `ChatDetailScreen`.
class ChatDetailScreenPreviewFixtures {
  const ChatDetailScreenPreviewFixtures._();

  // ─────────────────────────── canned values ───────────────────────────

  /// Route params. Not UUIDs on purpose: the catalog has shipped these exact
  /// three since DT-04, and they are what the header shortens into a reference.
  static const String composeChatId = 'chat-sending-1';
  static const String broadcastingChatId = 'chat-broadcasting-1';
  static const String acceptedChatId = 'chat-accepted-1';

  /// A synthetic account handle of the shape the gateway mints for phone-only
  /// accounts. The header must NEVER render it — see [acceptedUnnamed].
  static const String syntheticHandle = 'jeeb-e1a35ea8a520';

  /// The counterpart name the accepted thread resolves.
  static const String counterpartName = 'Kamal Hajj';

  /// The locked summary the accepted states pin. Every optional field is
  /// populated — P3 (b01-20260725) added the initial-requirement row, which is
  static const OrderChatSummary acceptedSummary = OrderChatSummary(
    deliveryId: acceptedChatId,
    requestId: acceptedChatId,
    priceLabel: r'$35.00',
    jeeberName: counterpartName,
    rating: 4.6,
    etaMinutes: 120,
    tierId: 'standard',
    orderRef: 'ORD-4821',
    statusId: 'matched',
    description: '2 kilos apples from Spinneys',
  );

  // ─────────────────── the three states the catalog names ───────────────────

  /// JM-025 AC1 — the customer's request is out and nothing has answered.
  /// `broadcasting` + no winner is what makes the screen treat this as the
  static const ChatDetailScreenPreviewState compose =
      ChatDetailScreenPreviewState(
    chatId: composeChatId,
    gateway: _composeGateway,
    phase: ConversationPhase.broadcasting,
  );

  static ChatGateway _composeGateway() => DevChatFixtureGateway(
        phase: ConversationPhase.broadcasting,
        sending: true,
      );

  /// The same request once offers start landing — the auction, still open.
  static const ChatDetailScreenPreviewState broadcasting =
      ChatDetailScreenPreviewState(
    chatId: broadcastingChatId,
    gateway: _broadcastingGateway,
    phase: ConversationPhase.broadcasting,
  );

  static ChatGateway _broadcastingGateway() =>
      DevChatFixtureGateway(phase: ConversationPhase.broadcasting);

  /// JM-025 AC2 — an offer was accepted: the 1:1 thread plus the pinned
  /// locked-price strip, the view-summary link and the dispute affordance.
  static const ChatDetailScreenPreviewState accepted =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: _acceptedGateway,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: counterpartName,
    summary: acceptedSummary,
  );

  // ──────────────────── the six states that break ────────────────────

  /// Run-22 §T5, made visible: the accepted counterpart's only "name" on file
  /// is a SYNTHETIC HANDLE (`jeeb-<hash>`), which is what a phone-only account
  static const ChatDetailScreenPreviewState acceptedUnnamed =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: _acceptedGateway,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: syntheticHandle,
    summary: acceptedSummary,
  );

  /// Fresh compose (Fix 5): the route param is the `new` sentinel, so there is
  /// no backend conversation and both resolution probes are skipped entirely.
  static const ChatDetailScreenPreviewState freshCompose =
      ChatDetailScreenPreviewState(
    chatId: kComposeConversationSentinel,
    gateway: _freshComposeGateway,
  );

  /// The accepted 1:1 thread every accepted state answers from.
  static ChatGateway _acceptedGateway() =>
      DevChatFixtureGateway(phase: ConversationPhase.accepted);

  /// A successful read with zero rows on a conversation that does not exist
  /// yet — `unknown` phase, which is what selects the "No conversation yet"
  static ChatGateway _freshComposeGateway() =>
      SeededChatGateway(phase: ConversationPhase.unknown);

  /// A read that SUCCEEDED and came back with zero rows on an accepted thread —
  /// "Say hello". The honest empty state, and the one the failure below must
  static const ChatDetailScreenPreviewState emptyAccepted =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: ChatScreenPreviewFixtures.emptyAccepted,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: counterpartName,
  );

  /// The cold history read THREW (a 500, a dropped transport, the chat store
  /// down): error copy plus a retry, never an empty thread.
  static const ChatDetailScreenPreviewState historyFailed =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: ChatScreenPreviewFixtures.failingHistory,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: counterpartName,
    summary: acceptedSummary,
  );

  /// The cold history read in flight — the shimmer, under a fully resolved
  /// header. This is what the customer looks at for as long as the read takes,
  static const ChatDetailScreenPreviewState loadingHistory =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: ChatScreenPreviewFixtures.stalledHistory,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: counterpartName,
    summary: acceptedSummary,
  );

  /// F44: the summary read failed, so the slot carries the unavailable strip
  /// with its reload — never a strip that silently vanished.
  static const ChatDetailScreenPreviewState summaryUnavailable =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: ChatScreenPreviewFixtures.emptyAccepted,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: counterpartName,
    summaryFailure: ServerFailure(status: 503),
  );

  /// Layout ceiling: the longest message a customer types, under the tallest
  /// header this screen can stack — the full pinned strip plus a counterpart
  static const ChatDetailScreenPreviewState longestContent =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: ChatScreenPreviewFixtures.longestContent,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: ChatScreenPreviewFixtures.longCounterpartName,
    summary: acceptedSummary,
  );
}
