/// Optional capability: "I own a periodic poll that MORE THAN ONE consumer may
/// want running, and you may declare or withdraw INTEREST in it — but you may
/// not own or dispose me."
///
/// ## When to implement this (and when NOT to)
/// Implement it **only** when the timer owner outlives, and is shared by, its
/// consumers. In this app that is exactly one object: the jeeber feed
/// repository, whose timer lives in `DioRequestFeedRepository`
/// (`dio_request_feed_repository.dart:107`), whose interface is
/// `RequestFeedRepository` (`request_feed_repository.dart:50`), and whose
/// instance is an app-lifetime DI lazy singleton
/// (`injection_container.dart:375-377`) shared across every mount.
///
/// A screen-scoped cubit that owns its own timer does **NOT** implement this.
/// It holds a [LifecyclePoller] field. Leases exist to make sharing safe, not
/// to make ownership expressive.
///
/// ## Why a SEPARATE interface rather than a member on the repository
/// `RequestFeedRepository` is implemented — via `implements`, which inherits no
/// bodies — by 9 classes (6 in `lib/`, 3 in `test/`), THREE of which live in
/// `lib/devtool/catalog/entries/batch_05_entries.dart` (`:376`, `:402`,
/// `:430`), outside every lane's fence, two of them with `const` constructors
/// (`:377`, `:403`). Adding a member to the base interface reds
/// `dart analyze lib` in a file no lane may legally edit.
///
/// ## Contract
///  * Interest is a **Set keyed by [owner] identity**, not a counter. Adding
///    the same owner twice, or removing one that never registered, is a no-op.
///    Counters get double-released; sets cannot. This is what makes a shell
///    role toggle safe: Flutter builds the new subtree before disposing the
///    old, so `newOwner` adds before `oldOwner` removes and the poll never
///    silently dies under a live consumer.
///  * The poll runs iff the interest set is non-empty AND the app is
///    foreground (the latter is [LifecyclePoller]'s job).
///  * Neither method disposes anything, ever. Interest is a lease. Disposal
///    belongs to whoever constructed the object.
///  * Both methods are safe to call after the source has been disposed.
///  * If the source emits anything on first interest (the feed emits
///    `FeedTransport.polling`), the consumer MUST have subscribed before it
///    declares interest. See §2.7.
abstract interface class PollingSource {
  void addPollInterest(Object owner);
  void removePollInterest(Object owner);
}
