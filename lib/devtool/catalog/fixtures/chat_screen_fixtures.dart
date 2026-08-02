// Designed states for the chat screen — ONE source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_02_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/chat/presentation/chat_screen.dart     the JEEB PREVIEWS
//                                                       section at its bottom
//
// Two halves, and they got here by different routes.
//
// **The seven Figma states** were never hand-built in the catalog entry to
// begin with: the entry delegated to [DevChatPreviewScreen], the app's own
// debug-only host, which wires the real [ChatScreen] to [DevChatFixtureGateway]
// by selector string. Copying those seven strings into the preview section
// would have been the drift this file exists to prevent, so they are named
// once and both consumers call the same builder. The fixture DATA still
// lives in `dev_chat_fixture_gateway.dart` (it is dev-seam code the router also
// reaches, not catalog-private), and the chrome each state needs — counterpart
// name, fee amount, composer hint, the auto-opened confirm sheets — still lives
// in `dev_chat_preview_screen.dart`. Neither is duplicated here.
//
// The seven SELECTOR strings moved one level down, to
// `dev_chat_preview_screen_fixtures.dart`, when `DevChatPreviewScreen` got a
// preview section of its own: that section has to construct the screen itself
// (`tool/preview_inventory.dart` will not credit a section that delegates the
// construction), so a third consumer now needs the same vocabulary. Naming it
// there keeps ONE spelling of `dm-order-picked` in the repo — which matters
// more than it looks, because a mistyped selector silently renders a different
// designed state instead of failing.
//
// **The six states no Figma frame covers** — empty, cold-load failure, the load
// itself, the longest content, the stacked header, the losing Jeeber — are new,
// and their fakes are below. They are the states that break, and the catalog is
// welcome to them: that is why they live here rather than inside the preview
// section.
//
// NOTHING here touches the network. Every gateway below answers from a const
// list, throws, or never completes, and none of them opts into
// [ChatGateway.supportsPolling] — so no fixture can arm the cold-load retry
// timer either. The [CatalogNetworkGuard] both hosts install is a net, not the
// plan.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../features/chat/data/dev_chat_fixture_gateway.dart';
import '../../../features/chat/domain/chat_gateway.dart';
import '../../../features/chat/domain/delivery_chat_message.dart';
import '../../../features/chat/domain/order_chat_summary.dart';
import '../../../features/chat/presentation/dev_chat_preview_screen.dart';
import 'dev_chat_preview_screen_fixtures.dart';

/// Answers one canned thread + phase, with no latency and no inbound stream.
///
/// `subscribe` returns `const Stream.empty()` rather than a [StreamController]:
/// a controller nobody closes outlives the preview, and the fixture has no
/// events to push anyway — every state here is a still frame.
class SeededChatGateway extends ChatGateway {
  SeededChatGateway({
    required this.phase,
    this.history = const <DeliveryChatMessage>[],
  });

  final ConversationPhase phase;
  final List<DeliveryChatMessage> history;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async =>
      history;

  @override
  Future<ConversationPhase> loadPhase(String conversationId) async => phase;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.sent);

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

/// Gateway whose history read always throws — the b02 cold-load failure.
///
/// The COLD read is the only one that reaches the error body:
/// `ChatCubit.refresh` is non-destructive and keeps a rendered thread, so a
/// gateway that failed on the second read would still show the messages.
class FailingChatGateway extends ChatGateway {
  FailingChatGateway();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) async {
    throw StateError(
      'fixture: HTTP 500 from GET /v1/conversations/$conversationId/messages',
    );
  }

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) async =>
      message.copyWith(status: MessageStatus.failed);

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

/// Gateway whose reads never resolve, freezing the screen on
/// [ChatState.isLoadingHistory] for as long as the host is open.
///
/// A [Completer] that is never completed holds no timer and no subscription; it
/// simply never settles. Both reads stall on purpose — `ChatCubit.load` awaits
/// the history first, so a stalled history alone would be enough, but a
/// resolving phase read would make the fixture depend on that ordering.
class StalledChatGateway extends ChatGateway {
  StalledChatGateway();

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) =>
      Completer<List<DeliveryChatMessage>>().future;

  @override
  Future<ConversationPhase> loadPhase(String conversationId) =>
      Completer<ConversationPhase>().future;

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) =>
      Completer<DeliveryChatMessage>().future;

  @override
  Stream<ChatEvent> subscribe(String conversationId) =>
      const Stream<ChatEvent>.empty();
}

/// The designed states of `ChatScreen`, as widget builders (the seven Figma
/// frames, which own their host chrome) plus gateways and canned data (the six
/// that do not).
///
/// The split is not an accident of style: the Figma states are only reachable
/// through [DevChatPreviewScreen], which supplies the fee banner, the composer
/// hint and the confirm sheets each frame needs, while the new states differ
/// only in what the gateway answers and are therefore wired by whichever host
/// is showing them.
class ChatScreenPreviewFixtures {
  const ChatScreenPreviewFixtures._();

  // ───────────────────────── the seven Figma frames ─────────────────────────

  /// Client's just-sent initial request, before any offer lands
  /// (Figma 56535:6469) — one outgoing bubble, no offer cards.
  static Widget clientSending() => const DevChatPreviewScreen(
        selector: DevChatPreviewScreenPreviewFixtures.clientSending,
      );

  /// Client's offers feed (Figma 56535:6659) — the same request plus the
  /// stacked offer cards that have started arriving.
  static Widget clientBroadcasting() => const DevChatPreviewScreen(
        selector: DevChatPreviewScreenPreviewFixtures.clientBroadcasting,
      );

  /// Client's accepted 1:1 thread (Figma 56546:2382).
  static Widget clientAccepted() => const DevChatPreviewScreen(
        selector: DevChatPreviewScreenPreviewFixtures.clientAccepted,
      );

  /// Jeeber's accepted thread (Figma 56539:906) — fee banner + price/time
  /// composer hint + the Start-delivery CTA.
  static Widget jeeberAccepted() => const DevChatPreviewScreen(
        selector: DevChatPreviewScreenPreviewFixtures.jeeberAccepted,
      );

  /// Jeeber's thread with the "Order picked" pill on the fee banner
  /// (Figma 56560:1605).
  static Widget jeeberOrderPicked() => const DevChatPreviewScreen(
        selector: DevChatPreviewScreenPreviewFixtures.jeeberOrderPicked,
      );

  /// Jeeber's thread with the confirm-picking sheet auto-opened
  /// (Figma 56618:2751).
  static Widget jeeberConfirmPicking() => const DevChatPreviewScreen(
        selector: DevChatPreviewScreenPreviewFixtures.jeeberConfirmPicking,
      );

  /// Jeeber's thread with the heading-off sheet auto-opened
  /// (Figma 56618:2852).
  static Widget jeeberConfirmHeadingOff() => const DevChatPreviewScreen(
        selector: DevChatPreviewScreenPreviewFixtures.jeeberConfirmHeadingOff,
      );

  // ──────────────────── canned data for the new states ─────────────────────

  /// Counterpart name on the client's accepted thread, as
  /// [DevChatPreviewScreen] passes it.
  static const String counterpartName = 'Kamal Hajj';

  /// A counterpart name long enough to contest the app bar with the avatar and
  /// the dispute action.
  static const String longCounterpartName =
      'Abdulrahman Al-Muhandis Al-Trabulsi';

  /// The longest plausible request a customer types into the thread. Wrapped in
  /// a bubble capped at ~72% of the viewport width, so on the 320 pt floor this
  /// is what pushes the message list against the header slot.
  static const String longestMessage =
      'Please get 3 kilos of potatoes, two water gallons and a bag of coffee '
      'from Blend on Rue Gouraud, then stop at the pharmacy next door for '
      'paracetamol and cough syrup, and call me before you head to the clinic '
      'on Independence Street because the gate closes at seven.';

  /// The one message on the compact chrome-stack state. Short on purpose: that
  /// state is about the header, and a long body would hide which of the two is
  /// starving the list.
  static const String compactMessage = 'I am at the gate, take your time.';

  /// Pre-formatted fee the Jeeber's balance-deduction banner shows, as
  /// [DevChatPreviewScreen] passes it.
  static const String jeeberFeeAmount = r'$0.5';

  /// Today at 09:41, so the date separator reads "Today" (Figma parity) while
  /// the per-message clock stays fixed. Same anchor [DevChatFixtureGateway]
  /// uses, for the same reason.
  static DateTime get at0941 {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 9, 41);
  }

  // ───────────────────────── gateways · new states ─────────────────────────

  /// A successful read that came back with ZERO rows on a thread still waiting
  /// for offers — the honest empty state.
  ///
  /// Note the phase: `broadcasting`, which is also `ChatState`'s default, so
  /// this is what a cold mount paints before any read resolves (NEW-BUG-01 —
  /// the default must never be `accepted`, which would claim a winner).
  static ChatGateway emptyBroadcasting() =>
      SeededChatGateway(phase: ConversationPhase.broadcasting);

  /// A successful read with zero rows on an ACCEPTED thread — "Say hello".
  static ChatGateway emptyAccepted() =>
      SeededChatGateway(phase: ConversationPhase.accepted);

  /// The cold history read throws — error body + retry, never the empty state.
  static ChatGateway failingHistory() => FailingChatGateway();

  /// The cold history read never returns — the shimmer.
  static ChatGateway stalledHistory() => StalledChatGateway();

  /// One accepted thread carrying [longestMessage].
  static ChatGateway longestContent() => SeededChatGateway(
        phase: ConversationPhase.accepted,
        history: <DeliveryChatMessage>[
          DeliveryChatMessage.text(
            id: 'fix-long-out-1',
            author: ChatAuthor.me,
            sentAt: at0941,
            status: MessageStatus.read,
            text: longestMessage,
          ),
        ],
      );

  /// One short message on an accepted thread — the body under the compact
  /// chrome stack.
  static ChatGateway compactThread() => SeededChatGateway(
        phase: ConversationPhase.accepted,
        history: <DeliveryChatMessage>[
          DeliveryChatMessage.text(
            id: 'fix-compact-in-1',
            author: ChatAuthor.them,
            sentAt: at0941,
            status: MessageStatus.delivered,
            text: compactMessage,
          ),
        ],
      );

  /// The losing Jeeber's view: the conversation is `closed` and carries an
  /// `offerRejected` system row, which is what mounts [JeeberRemovedBanner] and
  /// hides the composer.
  static ChatGateway removedJeeber() => SeededChatGateway(
        phase: ConversationPhase.closed,
        history: <DeliveryChatMessage>[
          DeliveryChatMessage.text(
            id: 'fix-closed-in-1',
            author: ChatAuthor.them,
            sentAt: at0941,
            status: MessageStatus.delivered,
            text: 'I need 3 kilos of potatoes and a water gallon.',
          ),
          DeliveryChatMessage.text(
            id: 'fix-closed-out-1',
            author: ChatAuthor.me,
            sentAt: at0941,
            status: MessageStatus.read,
            text: 'I can bring it in 2 hours for 35\$',
          ),
          DeliveryChatMessage.offerRejected(
            id: 'fix-closed-sys-1',
            sentAt: at0941,
            payload: const SystemOfferPayload(
              offerId: 'offer-lost',
              jeeberId: 'jeeber-rana',
              jeeberName: 'Rana Ahmad',
            ),
          ),
        ],
      );

  /// The locked price snapshot the accepted order-chat pins above the thread
  /// (JM-025 AC2). Every optional field is populated on purpose — this is the
  /// TALLEST the strip gets, which is what the header slot has to bound.
  static OrderChatSummary lockedSummary() => const OrderChatSummary(
        deliveryId: 'del-preview-1',
        requestId: 'req-preview-1',
        priceLabel: r'$35.00',
        jeeberName: counterpartName,
        rating: 4.5,
        etaMinutes: 120,
        tierId: 'express',
        orderRef: 'ORD-58001',
        statusId: 'InTransit',
        description: 'Potatoes, water and coffee from Blend.',
      );
}
