// PURE Dart. No Flutter / Firebase imports (40_GUARDRAILS_ARCH §1 layer rules)
// — this is the domain-side record of "which chat thread is on screen". The
// widget-side wiring that keeps it honest lives in
// `features/deep_link_targets/chat_detail_screen.dart` (a `RouteAware`
// subscription on `appRouteObserver`), and the read side lives in
// `data/firebase_messaging_transport.dart`.
library;

/// The chat thread the user is CURRENTLY LOOKING AT, or nothing.
///
/// Owner requirement (b02, verbatim): *"in case the user is not on the right
/// chat session, user should see the notification whether the app is in
/// forground or background or even closed"*. The contrapositive is the only
/// thing this class exists to answer: when the user IS on the right chat
/// session, a foreground push for that same thread must not buzz the shade.
///
/// ## Why a registry and not a route sniff
///
/// The push arrives on a platform-channel callback with no `BuildContext` and
/// no navigator, so the reader cannot walk the widget tree. `Diag.currentScreen`
/// already tracks the top route, but it is gated on `Diag.enabled`
/// (`diag_nav_observer.dart:43` early-returns) — i.e. it is dev/debug-only and
/// is `null` in a production build, so a production suppression built on it
/// would silently never fire. It also records the route PATTERN (`/chat/:id`),
/// never the id, so it could not tell one thread from another.
///
/// ## Why a SET of ids
///
/// `/chat/:id`'s route param may be a conversation id **or** a delivery/request
/// id — `ChatDetailScreen`'s doc comment and its
/// `GET /v1/conversations?correlationKey={requestId}` resolution both say so —
/// and the live chat push carries BOTH `conversationId` and `requestId`
/// (`notification_deep_link.dart:56-67`). Matching on a single id would
/// therefore miss whenever the screen was opened by one flavour of id and the
/// push was stamped with the other. The screen registers every id it knows for
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
  Set<String> _ids = const <String>{};

  /// The ids of the on-screen chat thread. Empty when no chat is on screen.
  Set<String> get openIds => _ids;

  /// Records [ids] as the on-screen thread, owned by [owner].
  ///
  /// Idempotent and re-callable: the screen calls this again once the async
  /// conversation resolution lands more ids, and again on `didPopNext` when it
  /// comes back to the top of the stack.
  void enter(Object owner, Iterable<String> ids) {
    _owner = owner;
    _ids = _clean(ids);
  }

  /// Clears the registration IF [owner] still owns it.
  ///
  /// Guarded on purpose — see the ownership-discipline note above.
  void leave(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _ids = const <String>{};
  }

  /// Whether any of [candidateIds] identifies the on-screen thread.
  ///
  /// Returns `false` for an empty candidate list, so a chat push carrying no
  /// usable id can never be suppressed by accident — it renders, which is the
  /// safe direction (a spurious banner is recoverable; a swallowed message is
  /// the failure the owner called out).
  bool isOpen(Iterable<String> candidateIds) {
    if (_ids.isEmpty) return false;
    for (final id in candidateIds) {
      if (id.isNotEmpty && _ids.contains(id)) return true;
    }
    return false;
  }

  /// Test seam: drop any registration regardless of owner. Never called from
  /// production code — `leave` is the production path and is owner-guarded.
  void resetForTest() {
    _owner = null;
    _ids = const <String>{};
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
