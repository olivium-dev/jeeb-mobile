/// The Firebase identity a Firestore chat read runs as.
///
/// # Why this port exists, and what it is guarding
///
/// Reading `Conversations/{id}/Messages` straight from the device moves the
/// message-visibility decision OUT of the chat-service and INTO Firestore
/// security rules. That decision is not a formality on this product — the
/// server-side predicate is
/// `chat-service/ChatService.Application/Service/MessageVisibilityResolver.cs`,
/// and it is a five-input matrix:
///
///   * role (`MapRole`, `:76-108`) — `client*` → Client, anything containing
///     `winner` → Participant, every other participant → **Restricted**,
///     blank/unknown → **deny, fail-closed**;
///   * `audience` (`AudienceToken`, `:134-155`) — the bare token `all`, a
///     JSON-quoted `"all"`, or a structured per-recipient object that is
///     deliberately NOT a broadcast;
///   * broadcast kinds (`:57-63`) — `offer_accepted`, `system_notice`, `system`;
///   * `KindToken` (`:118-129`) — the trailing segment of a dotted subtype
///     (`x.offer_accepted` → `offer_accepted`), else the bare kind;
///   * author (`:190`) — a Restricted participant otherwise sees ONLY messages
///     they wrote themselves.
///
/// That last line is the one with teeth. During the `broadcasting` phase several
/// Jeebers drop competing offer cards into the SAME conversation, and
/// `Restricted` is what keeps each bidder from seeing the others' prices. A
/// client that subscribes to the raw subcollection sees every document in it.
/// **So an unauthenticated — or merely under-specified — Firestore read is not a
/// missing feature, it is a competing-bid leak.**
///
/// Equivalence therefore requires BOTH of:
///
///   1. `request.auth.uid` equal to the **Jeeb user id** (the JWT `sub` the
///      chat-service stamps into `AuthorId`), so a rule can compare a document's
///      author and the parent conversation's `Participants[].UserId` against the
///      caller. Only a **custom token** gives that: it is minted server-side from
///      the Jeeb JWT and carries the same subject.
///      `signInAnonymously()` deliberately does NOT satisfy this — it mints a
///      random uid unrelated to the Jeeb user, so the only rule that could admit
///      it is `request.auth != null`, which admits every anonymous caller on the
///      internet to every Jeeb conversation. This client never calls it.
///   2. Security rules on `jeeb-5a293` that replicate the matrix above.
///
/// # Status (b03): both halves now exist, and (1) is fully satisfied
///
///   * **Mint endpoint: live.** `POST /v1/chat/firebase-token` on jeeb-gateway
///     returns a custom token whose `uid` is derived from the validated bearer's
///     own claims — never from a client-supplied header.
///     `GatewayChatFirebaseTokenMinter` is the production implementation of
///     [ChatFirebaseTokenMinter], and `ChatDetailScreen._wrapRealtime` is the
///     one place that builds it.
///   * **Rules: MEMBERSHIP-ONLY, and that is still the LIVE state.** The
///     released ruleset on `jeeb-5a293` is
///     `be2ddaaf-31e3-4470-8eda-e043478205ce` (the `cloud.firestore` release
///     pointed at it on 2026-07-28, and it is the project's only ruleset). It
///     authorises a read of `Conversations/{cid}/Messages` on MEMBERSHIP alone —
///     the caller's uid appears in the parent conversation's
///     `Participants[].UserId` with `RemovedAt` null — plus
///     `sign_in_provider == 'custom'`, with `allow write: if false` and a
///     default-deny `match /{document=**}`.
///
/// **Where the LIVE rule is WEAKER than the REST path, and it matters.**
/// Membership is the whole predicate: the released rule does NOT reproduce the
/// author/audience half of `MessageVisibilityResolver` described above, and
/// `FirestoreChatMessageMapper` does not read `Audience` either. So a direct
/// Firestore read by a participant returns documents the chat-service would have
/// withheld from that same viewer — proven live, not hypothesised. For the shape
/// this client actually subscribes to the gap is closed by construction:
/// `_wrapRealtime` refuses anything but a settled roster
/// (`realtimeChatAdmitted`, `chat_realtime_admission.dart` — read its 4 x 3
/// truth table), so there are no competing bidders left in the room to leak
/// between. Widening the subscription to the pre-accept phase requires the RULES
/// to grow the audience/author predicate FIRST; doing it in this client alone
/// would be the competing-bid leak this doc-comment exists to prevent.
///
/// # What is PENDING, and why this file already filters on it
///
/// The approved replacement is an **additive `VisibleTo` array** written by
/// chat-service at message-write time using that same `MessageVisibilityResolver`
/// (see `kChatMessageVisibleToField`), with the rule authorising on that array
/// instead of on membership. This client's LIST already carries the matching
/// `arrayContains` filter, because the new rule reads `resource.data` and
/// Firestore refuses a LIST it cannot prove.
///
/// **Neither half of that has shipped yet**, and the ORDER is load-bearing. The
/// filter is inert today only because the gateway mint ships disabled
/// (`Firebase:Chat:ServiceAccountKeyPath` unset ⇒ 503 ⇒ [ensureSignedIn] returns
/// null ⇒ no channel opens). Enabling the mint before chat-service writes
/// `VisibleTo` would NOT fail loudly: the filtered query would be authorised by
/// the membership rule, return ZERO documents, and still report itself LIVE on
/// its first empty snapshot — which suppresses the push-driven HTTP refetch in
/// `ChatCubit` and leaves the thread silently receiving nothing. So: chat-service
/// writes `VisibleTo`, the composite index exists, the rule ships — and only
/// THEN is the mint enabled.
abstract class ChatFirebaseIdentity {
  /// Signs the app in to Firebase so a Firestore read carries an identity the
  /// rules can key on.
  ///
  /// Returns the uid the Firebase session is signed in as, or null — it must
  /// NEVER throw a raw plugin error at a caller — when no identity could be
  /// established. The LIST query must filter on exactly the uid that
  /// `request.auth.uid` will carry. Returning it from the one method that
  /// establishes the identity makes those values the same by construction
  /// rather than by convention. The caller's only correct response to null is
  /// to not open the channel.
  Future<String?> ensureSignedIn();

  /// The identity that is never signed in. Reading Firestore with this is
  /// impossible by construction, which is the point: the absence of a token
  /// mint must degrade to "no realtime", never to "read it unauthenticated".
  static const ChatFirebaseIdentity absent = _AbsentChatFirebaseIdentity();
}

class _AbsentChatFirebaseIdentity implements ChatFirebaseIdentity {
  const _AbsentChatFirebaseIdentity();

  @override
  Future<String?> ensureSignedIn() async => null;
}

/// Mints a Firebase custom token for the signed-in Jeeb user.
///
/// The ONLY acceptable shape: the backend validates the Jeeb JWT it already
/// issued and returns a Firebase custom token whose `uid` is the SAME subject,
/// so `request.auth.uid` in a security rule means exactly what `AuthorId` means
/// in a chat-service document. `GatewayChatFirebaseTokenMinter` implements this
/// against `POST /v1/chat/firebase-token` — see [ChatFirebaseIdentity].
abstract class ChatFirebaseTokenMinter {
  /// A Firebase custom token for the current user, or null when the backend has
  /// no such endpoint (or the user is not signed in to Jeeb).
  Future<String?> mintCustomToken();
}
