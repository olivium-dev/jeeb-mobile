import 'delivery_chat_message.dart';

/// Machine-readable reason stamped on the `chat_realtime_unavailable` diagnostic
/// when [realtimeChatAdmitted] refuses. Kept as a constant so a device capture
/// and a test assert on the SAME literal.
const String kRealtimeRefusedAuctionPhase = 'auction_phase';

/// What the conversation row's `participants` roster says about whether the
/// auction is OVER — as opposed to what the `phase` string claims.
///
/// The two are not the same fact, and the gap between them is a live defect,
/// not a hypothetical. `jeeb-gateway`'s post-accept saga
/// (`Controllers/V1/JeebOffersController.cs`) does four things in sequence:
/// ensure the conversation (1), stamp its id (2), **seat the winner** (3,
/// `:673-679`, `RoleInConvo = "jeeber_winner"`), then **advance the phase and
/// soft-remove the losers** (4, `:693-702`, `RemoveOthers = true`). Steps 3 and
/// 4 are separate calls, and the whole block is wrapped in a `catch` that logs a
/// warning and swallows it (`:704-710`) so the accept still returns 200. So
/// "step 3 succeeded, step 4 did not" is a DESIGNED, reachable outcome, and it
/// looks exactly like this on the wire:
///
///   phase: "broadcasting"  ·  winner seated  ·  every losing bidder still
///   `removed_at == null`
///
/// A `.snapshots()` listener opened on that row is authorised by the released
/// membership rule for EVERY one of those bidders, so it streams each rival's
/// offer card — fee, ETA, name — to all the others. [contested] is that state.
enum ChatRosterVerdict {
  /// A `jeeber_winner` is seated and NO other non-removed jeeber remains: the
  /// membership the Firestore rule authorises is the post-accept 1:1, and there
  /// is no competing bid left in the room to leak.
  settled,

  /// At least one non-removed participant is neither the client/admin/support
  /// nor the winner — i.e. chat-service's `Restricted` lane
  /// (`MessageVisibilityResolver.MapRole`, `:72-96`: `client*` → Client,
  /// contains `winner` → Participant, `admin`/`support` → privileged, **every
  /// other** participant → Restricted, blank → `Unknown`, fail-closed). Those
  /// are exactly the bidders the server-side resolver keeps apart and the
  /// Firestore membership rule does not. Refuses unconditionally, whatever the
  /// phase string says.
  contested,

  /// No roster in hand. A conversation row resolved by the messages-probe
  /// carries no `participants` at all, and the mock/legacy camelCase shape
  /// carries a top-level `winnerJeeberId` instead. This is "we did not find
  /// out", so it grants nothing on its own — the phase must carry the decision.
  unknown,
}

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
/// # THE COMPLETE TRUTH TABLE — every cell, no summary
///
/// This comment used to say "unknown → refused" flat, and that was FALSE:
/// `unknown` with a winner was admitted, and so was `closed` with one. A comment
/// that describes a gate more narrowly than the gate behaves is how a hole
/// survives review, so here is the whole 4 × 3 product and nothing else:
///
/// ```
///                 roster=settled   roster=contested   roster=unknown
/// accepted        ADMIT            REFUSE             ADMIT
/// broadcasting    ADMIT            REFUSE             REFUSE
/// closed          ADMIT            REFUSE             REFUSE
/// unknown         ADMIT            REFUSE             REFUSE
/// ```
///
/// Read it column-first, because the roster is the stronger evidence:
///
///  * **`contested` refuses in EVERY row, `accepted` included.** Both gateway
///    accept paths send `RemoveOthers = true`
///    (`JeebOffersController.cs:700`, `OffersController.cs:856`) and
///    chat-service applies the flip + promotion + loser-removal atomically
///    (`JeebConversationContracts.cs:342-346`), so `accepted` alongside a live
///    bidder should be unreachable. If we nevertheless SEE it, the roster we are
///    holding is the very thing the Firestore rule will be evaluated against and
///    it says a rival can read; believing the label over the roster there would
///    be trusting the weaker witness.
///  * **`settled` admits in every row, `broadcasting` included.** Not a
///    contradiction, and not belt-and-braces: it is the MAIN LIVE SHAPE.
///    Instrumented at `ChatDetailScreen`'s resolution across the chat /
///    deep-link / notification suites, 18 resolutions reach the wrap and 8 of
///    them carry `phase: "broadcasting"` with a seated winner and an empty
///    bench — post-accept rows the live gateway simply never re-labelled.
///    `DioChatGateway._hasActiveWinner` (`dio_chat_gateway.dart:305-307`) exists
///    for the same reason. Gating on the phase STRING alone would refuse all 8
///    and ship the feature dead.
///  * **`unknown` grants nothing.** It is the messages-probe row (no
///    `participants` key) and the legacy camelCase row. The decision falls back
///    to the phase, and only `accepted` carries it. `broadcasting` is the
///    auction itself. `unknown` is `fromWire`'s default for a phase string this
///    client does not recognise, and `DioChatGateway.loadPhase` already degrades
///    every unknown/failed read to `broadcasting`, "the safe compose/waiting
///    state — NEVER accepted" (`dio_chat_gateway.dart:284`), so admitting it
///    would make this the one place that reads ignorance as consent. `closed`
///    without a roster is a thread that terminated, possibly WITHOUT an accept
///    (the client cancelled, or the request expired mid-auction), which never
///    removed the bidders — and a closed thread is read-only, so there is
///    nothing live to subscribe to anyway.
///
/// # Why `accepted` is still a licence when the roster is unknown
///
/// Not because the phase is trustworthy in general — see the 8 stale
/// `broadcasting` rows above — but because the two errors point opposite ways.
/// The saga only ever advances the phase to `accepted` in the same call that
/// removes the losers, so a row that SAYS `accepted` has, by its own account,
/// already run the removal; the stale label points the other way (accepted in
/// fact, `broadcasting` on the wire). And the roster is genuinely not always in
/// hand: the messages-probe resolution returns a row with no `participants`.
/// Refusing that case outright would turn "the server did not send a roster"
/// into a permanent feature-off for every probe-resolved thread.
///
/// # Deliberately NOT the same predicate as the screen's `hasWinner`
///
/// `ChatDetailScreen` also computes a LOOSER "the auction produced a winner"
/// fact (`_hasSeatedWinner`) which drives the composer's accepted-vs-compose
/// state, the header title and the pinned-summary fetch. That one must stay
/// loose: on a `contested` row the client HAS accepted an offer, and flipping it
/// to compose would make their next message broadcast a brand-new request. So
/// the two facts are read off the same roster and kept apart on purpose — "is
/// there a winner" and "is it safe to read this thread straight from the device"
/// are different questions, and only the second is a privacy decision.
bool realtimeChatAdmitted({
  required ConversationPhase phase,
  required ChatRosterVerdict roster,
}) {
  // The roster outranks the label in BOTH directions; this line is the whole
  // reason `contested` is a value of its own rather than `!settled`.
  if (roster == ChatRosterVerdict.contested) return false;
  return roster == ChatRosterVerdict.settled ||
      phase == ConversationPhase.accepted;
}
