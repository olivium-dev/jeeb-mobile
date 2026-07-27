// PURE Dart. No Flutter / Firebase imports (40_GUARDRAILS_ARCH §1 layer rules)
// — this is the domain-side record of "which chat thread is on screen". The
// widget-side wiring that keeps it honest lives in
// `features/deep_link_targets/chat_detail_screen.dart` (a `RouteAware`
// subscription on `appRouteObserver`), and the read side lives in
// `data/firebase_messaging_transport.dart`.
library;

/// Supplies the ids of the on-screen chat thread, evaluated AT READ TIME.
typedef ChatThreadIdsReader = Set<String> Function();

/// The chat thread the user is CURRENTLY LOOKING AT, or nothing.
///
/// Owner requirement (b02, verbatim): *"in case the user is not on the right
/// chat session, user should see the notification whether the app is in
/// forground or background or even closed"*. The contrapositive is the only
/// thing this class exists to answer: when the user IS on the right chat
/// session, a foreground push for that same thread must not buzz the shade.
///
/// ## Why a PULL (a reader), not a PUSH (a snapshot)
///
/// The first cut of this class stored a `Set<String>` snapshot and required the
/// screen to re-publish every time its id set grew — on `didPush`, on
/// `didPopNext`, and again once the async `?correlationKey=` lookup resolved
/// the conversation id. That is a "publish moment" design, and every such
/// moment is a chance to miss one. A hardware run reported the registry holding
/// only the route param, with the resolved conversation id absent, so a chat
/// push stamped with the conversation id was NOT recognised as the open thread.
///
/// That specific ordering was NOT reproduced afterwards — a snapshot build that
/// republishes from `_finalize` passes every harness available here, including
/// one mounted under a real `GoRouter`. So this is not a fix for a diagnosed
/// defect. It removes the CLASS the report belongs to: holding a
/// [ChatThreadIdsReader] leaves exactly ONE thing the screen must get right
/// (am I visible?), and the ids are read from the live `State` at push time, so
/// a late resolution is picked up with no republish at all. The regression test
/// pins that — it reads the registry BEFORE resolution and again AFTER, with no
/// intervening [enter].
///
/// ## Why a SET of ids
///
/// `/chat/:id`'s route param may be a conversation id **or** a delivery/request
/// id — `ChatDetailScreen`'s doc comment and its
/// `GET /v1/conversations?correlationKey={requestId}` resolution both say so —
/// and the live chat push carries BOTH `conversationId` and `requestId`
/// (`notification_deep_link.dart:56-67`). Matching on a single id would
/// therefore miss whenever the screen was opened by one flavour of id and the
/// push was stamped with the other. The screen exposes every id it knows for
/// the open thread; a push matches if ANY of its own thread-id candidates is in
/// the set.
///
/// ## Ownership discipline
///
/// [enter] stamps an owner token (the `State` object). [leave] is a no-op
/// unless the caller is still the owner, so a late `dispose()` from a screen
/// that has already been superseded (chat A → chat B) cannot clear chat B's
/// registration. This is the ordering hazard that makes a naive
/// set-on-mount/clear-on-dispose registry wrong.
class ActiveChatThread {
  ActiveChatThread._();

  /// Process-wide instance. There is exactly one visible chat screen at a time,
  /// so a single slot is sufficient and a map would only add ways to leak.
  static final ActiveChatThread instance = ActiveChatThread._();

  Object? _owner;
  ChatThreadIdsReader? _reader;

  /// The ids of the on-screen chat thread. Empty when no chat is on screen.
  ///
  /// Evaluated on every read (see the PULL note above). Fails OPEN — an empty
  /// set means "suppress nothing" — if the reader throws, which is the safe
  /// direction: a spurious banner is recoverable, a swallowed message is the
  /// failure the owner called out.
  Set<String> get openIds {
    final reader = _reader;
    if (reader == null) return const <String>{};
    try {
      return _clean(reader());
    } catch (_) {
      return const <String>{};
    }
  }

  /// Records [reader] as the source of truth for the on-screen thread, owned by
  /// [owner].
  ///
  /// Idempotent and re-callable. The screen calls this when it becomes the
  /// visible route (`didPush` / `didPopNext`) and when its route param changes
  /// under a reused `State` (`didUpdateWidget`). It does NOT need to call it
  /// again when the async conversation resolution lands — that is the whole
  /// point of taking a reader.
  void enter(Object owner, ChatThreadIdsReader reader) {
    _owner = owner;
    _reader = reader;
  }

  /// Clears the registration IF [owner] still owns it.
  ///
  /// Guarded on purpose — see the ownership-discipline note above.
  void leave(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _reader = null;
  }

  /// Whether any of [candidateIds] identifies the on-screen thread.
  ///
  /// Returns `false` for an empty candidate list, so a chat push carrying no
  /// usable id can never be suppressed by accident — it renders.
  bool isOpen(Iterable<String> candidateIds) {
    final ids = openIds;
    if (ids.isEmpty) return false;
    for (final id in candidateIds) {
      if (id.isNotEmpty && ids.contains(id)) return true;
    }
    return false;
  }

  /// Test seam: drop any registration regardless of owner. Never called from
  /// production code — `leave` is the production path and is owner-guarded.
  void resetForTest() {
    _owner = null;
    _reader = null;
  }

  static Set<String> _clean(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) out.add(trimmed);
    }
    return out;
  }
}
