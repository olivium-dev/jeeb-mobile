/// The Firebase identity a Firestore chat read runs as.
///
/// # Why this port exists at all, and why it has no live production wiring yet
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
/// Neither exists yet, and neither can be built from jeeb-mobile:
///
///   * **No mint endpoint.** Scanned `jeeb-gateway/src` (568 `.cs`/`.json` files)
///     for `CreateCustomToken` / `FirebaseAdmin` / `FirebaseAuth` — zero hits.
///   * **No rules in source.** Scanned `jeeb-mobile`, `jeeb-gateway` and
///     `chat-service` for `*.rules` / `firebase.json` / `firestore.indexes.json`
///     — zero. They live in the Firebase console and cannot be read, reviewed, or
///     changed from any repo.
///
/// So this port is deliberately left with **no production implementation
/// registered**. [ChatFirebaseIdentity.absent] is what the app resolves today,
/// the realtime source refuses to open a channel without an identity, and the
/// existing HTTP path keeps running unchanged. When the mint endpoint lands,
/// `FirebaseCustomTokenIdentity` below is the only thing that needs wiring.
abstract class ChatFirebaseIdentity {
  /// Signs the app in to Firebase so a Firestore read carries an identity the
  /// rules can key on, and reports whether it succeeded.
  ///
  /// Returns false — it must NEVER throw a raw plugin error at a caller — when
  /// no identity could be established. The caller's only correct response to
  /// false is to not open the channel.
  Future<bool> ensureSignedIn();

  /// The identity that is never signed in. Reading Firestore with this is
  /// impossible by construction, which is the point: the absence of a token
  /// mint must degrade to "no realtime", never to "read it unauthenticated".
  static const ChatFirebaseIdentity absent = _AbsentChatFirebaseIdentity();
}

class _AbsentChatFirebaseIdentity implements ChatFirebaseIdentity {
  const _AbsentChatFirebaseIdentity();

  @override
  Future<bool> ensureSignedIn() async => false;
}

/// Mints a Firebase custom token for the signed-in Jeeb user.
///
/// The ONLY acceptable shape: the backend validates the Jeeb JWT it already
/// issued and returns a Firebase custom token whose `uid` is the SAME subject,
/// so `request.auth.uid` in a security rule means exactly what `AuthorId` means
/// in a chat-service document. No endpoint implements this yet — see
/// [ChatFirebaseIdentity].
abstract class ChatFirebaseTokenMinter {
  /// A Firebase custom token for the current user, or null when the backend has
  /// no such endpoint (or the user is not signed in to Jeeb).
  Future<String?> mintCustomToken();
}
