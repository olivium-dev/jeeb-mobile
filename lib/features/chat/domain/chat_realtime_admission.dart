import 'delivery_chat_message.dart';

/// Machine-readable reason stamped on the `chat_realtime_unavailable` diagnostic
/// when [realtimeChatAdmitted] refuses. Kept as a constant so a device capture
/// and a test assert on the SAME literal.
const String kRealtimeRefusedAuctionPhase = 'auction_phase';

/// Whether a conversation is far enough along its lifecycle that opening a
/// Firestore `.snapshots()` listener on its `Messages` subcollection is safe.
///
/// # This is a privacy gate, not a readiness check
///
/// The released Firestore ruleset (`be2ddaaf-31e3-4470-8eda-e043478205ce`,
/// 2026-07-28) authorises a read purely on membership: `request.auth.uid` must
/// match some `Participants[].UserId` whose `RemovedAt` is null. It does NOT
/// reproduce `MessageVisibilityResolver`'s author/audience matrix, so it cannot
/// tell an offer card addressed to the client from one addressed to nobody else.
///
/// During [ConversationPhase.broadcasting] EVERY bidding Jeeber is a member with
/// `RemovedAt == null`. A listener opened in that window therefore streams every
/// rival's offer card — fee, ETA, name — to every other bidder. That is a live
/// competing-bid leak, and it is invisible from the client's own screen because
/// the CLIENT is supposed to see all the cards. Only the accept saga closes it:
/// it stamps `RemovedAt` on the losers, leaving the conversation 1:1.
///
/// # Why this predicate, value by value
///
///  * [ConversationPhase.accepted] — **admitted.** The saga has run; the losers
///    carry `RemovedAt` and the membership rule now resolves to exactly the two
///    parties who are allowed to read the thread.
///  * [ConversationPhase.broadcasting] — **refused.** The auction above.
///  * [ConversationPhase.unknown] — **refused.** It is the `fromWire` default for
///    a phase string this client does not recognise, i.e. "we did not find out".
///    `DioChatGateway.loadPhase` already degrades every unknown/failed read to
///    `broadcasting`, "the safe compose/waiting state — NEVER accepted"
///    (`dio_chat_gateway.dart:284`); admitting here would make this the one place
///    that reads ignorance as consent.
///  * [ConversationPhase.closed] — **not a licence on its own.** A thread that
///    terminated AFTER an accept still carries its seated winner, so it is
///    admitted through [hasWinner] below. A thread that terminated WITHOUT one
///    (the client cancelled, or the request expired mid-auction) never removed
///    the bidders, so it is exactly as leaky as `broadcasting` — and a closed
///    thread is read-only, so there is nothing live to subscribe to anyway.
///
/// [hasWinner] is the second admission arm and it is not redundant. The live
/// conversation row can still report `phase: "broadcasting"` AFTER the accept,
/// with the winner seated as an active `jeeber_winner` participant — that exact
/// wire is reproduced in `chat_detail_screen_resolution_test.dart`'s
/// `_LiveSnakeCaseDio`, and `DioChatGateway._hasActiveWinner`
/// (`dio_chat_gateway.dart:305-307`) exists for the same reason. A seated,
/// non-removed winner is direct evidence the saga ran, which is the fact this
/// gate actually cares about; the phase string is only its usual proxy.
///
/// Note the deliberate asymmetry with `DioChatGateway.loadPhase`, which requires
/// an active winner *before* it will BELIEVE an `accepted` phase. Here `accepted`
/// alone is enough, because a roster is not always in hand at this call site
/// (the messages-probe resolution returns a row with no `participants`), and the
/// failure modes point opposite ways: there, trusting `accepted` too readily
/// paints a false "Offer accepted!"; here, the only phase that leaks is
/// `broadcasting`, and a server that says `accepted` has, by its own account,
/// ended the auction.
///
/// The predicate is intentionally the same one the screen already uses to decide
/// `shouldTrackSummary` (`chat_detail_screen.dart:809-811`) — "the auction is
/// over" is one fact, and it should not have two definitions on one screen.
bool realtimeChatAdmitted({
  required ConversationPhase phase,
  required bool hasWinner,
}) =>
    phase == ConversationPhase.accepted || hasWinner;
