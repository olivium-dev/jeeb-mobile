// Designed states for the `/chat/:id` deep-link target — ONE source of truth,
// two consumers.
//
//   lib/devtool/catalog/entries/batch_03_entries.dart      the designer-facing,
//                                                          on-device Screen
//                                                          Catalog
//   lib/features/deep_link_targets/chat_detail_screen.dart the JEEB PREVIEWS
//                                                          section at its bottom
//
// The three states the catalog already named — compose, broadcasting, accepted —
// were hand-built inline in the entry file. They are named here once instead, so
// the designer's in-app browser and the engineer's canvas cannot drift into
// showing two different "designed states" under the same label.
//
// **Why this file holds DESCRIPTIONS and not built widgets.** Both consumers
// construct [ChatDetailScreen] themselves, from the same
// [ChatDetailScreenPreviewState]. That is not a style preference: the coverage
// detector (`tool/preview_inventory.dart`, `SourceFile.constructs`) grades a
// preview section that names a widget but never builds it as MALFORMED — the
// half-finished-edit signal — so a section that only called a factory here
// would report the screen as broken. Keeping the DATA here and the two-line
// construction at each site puts the single source of truth on the half that
// actually drifts: which gateway answers, which phase, which winner flag,
// which counterpart name, which pinned summary.
//
// [ChatDetailScreen] takes a ROUTE PARAM, not a state: normally it resolves the
// param against the live gateway before it can render anything. Every state
// below is mounted through the screen's own `debugGateway` seam, which
// short-circuits that entire async GetIt/Dio resolution — so nothing here can
// reach the network, and no state depends on a backend answering.
//
// The FAKE GATEWAYS are not re-declared here either. [SeededChatGateway],
// [FailingChatGateway] and [StalledChatGateway] already exist in
// `chat_screen_fixtures.dart` for the inner [ChatScreen]'s own previews, and
// the six states this file adds beyond the catalog's three differ from them
// only in what the gateway answers. Reusing them is the same argument this file
// is making one level up. None of them opts into [ChatGateway.supportsPolling],
// so none can arm the cold-load retry timer either.
//
// WHAT IS DELIBERATELY ABSENT, because the screen offers no seam for it:
//
//   * the `_loading` spinner and the `_resolutionUnavailable` error body. Both
//     live on the async resolution path, and `debugGateway` is a seam AROUND
//     that path — it hands the screen an already-resolved conversation. There is
//     no offline host for either state, in the catalog or on the canvas.
//   * the JEEBER leg (the "Customer" header fallback, the Start-delivery CTA).
//     The role is read only from an ambient `RoleCubit`, which cannot be built
//     without a real `SharedPreferences` instance — an async, plugin-backed
//     dependency no preview function can await.

import 'package:flutter/foundation.dart';

import '../../../features/chat/data/dev_chat_fixture_gateway.dart';
import '../../../features/chat/domain/chat_gateway.dart';
import '../../../features/chat/domain/delivery_chat_message.dart'
    show ConversationPhase;
import '../../../features/chat/domain/order_chat_summary.dart';
import 'chat_screen_fixtures.dart';

/// One designed state of `ChatDetailScreen`, expressed as the `debug*` seam
/// arguments that produce it.
///
/// [gateway] is a FACTORY rather than an instance: each mount gets its own
/// fake, so re-opening a state in the catalog (or pumping the same preview in a
/// second test) never hands the screen a gateway whose stream a previous
/// `ChatCubit` already tore down.
@immutable
class ChatDetailScreenPreviewState {
  const ChatDetailScreenPreviewState({
    required this.chatId,
    required this.gateway,
    this.phase = ConversationPhase.unknown,
    this.hasWinner = false,
    this.counterpartName = '',
    this.summary,
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
  /// the dispute affordance exist at all.
  final bool hasWinner;

  /// The counterpart name the resolution produced. May deliberately be a
  /// synthetic handle — see [ChatDetailScreenPreviewFixtures.acceptedUnnamed].
  final String counterpartName;

  /// The locked pinned summary, or null when the strip must not render.
  final OrderChatSummary? summary;
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
  /// what makes this the tallest the strip gets.
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
  ///
  /// `broadcasting` + no winner is what makes the screen treat this as the
  /// COMPOSE state: the next message broadcasts the request and routes to
  /// `waiting-no-coverage`, rather than posting into an existing conversation.
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
  /// carries when it has no display name.
  ///
  /// `_headerTitle` suppresses it via `displayNameOrNull` and falls back to the
  /// role generic ("Your Jeeber"). If this state ever renders `jeeb-…` in the
  /// app bar, that suppression has broken — and it is the same code path an
  /// EMPTY name and a raw UUID take, so this one state guards all three.
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
  ///
  /// Two things are true only here — the header falls back to the Chat tab
  /// label instead of an order reference, because there is no real id to
  /// shorten; and the empty body reads "No conversation yet" rather than either
  /// phase-specific empty.
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
  /// copy over either phase-specific empty.
  static ChatGateway _freshComposeGateway() =>
      SeededChatGateway(phase: ConversationPhase.unknown);

  /// A read that SUCCEEDED and came back with zero rows on an accepted thread —
  /// "Say hello". The honest empty state, and the one the failure below must
  /// never be mistaken for.
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
  ///
  /// The same distinction the screen's own `_resolutionUnavailable` branch
  /// exists for one level up — a failed read is no evidence about the server's
  /// data, and rendering "No offers yet — sit tight." over an in-transit
  /// delivery is exactly how an outage reached users.
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
  /// and there is no composer on it.
  static const ChatDetailScreenPreviewState loadingHistory =
      ChatDetailScreenPreviewState(
    chatId: acceptedChatId,
    gateway: ChatScreenPreviewFixtures.stalledHistory,
    phase: ConversationPhase.accepted,
    hasWinner: true,
    counterpartName: counterpartName,
    summary: acceptedSummary,
  );

  /// Layout ceiling: the longest message a customer types, under the tallest
  /// header this screen can stack — the full pinned strip plus a counterpart
  /// name long enough to contest the app bar with the dispute action.
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
