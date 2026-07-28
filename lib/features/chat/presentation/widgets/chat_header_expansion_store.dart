import 'package:flutter/foundation.dart';

/// Session-scoped memory for the pinned chat header's expand/collapse choice.
///
/// The pinned summary is **collapsed by default** (b02 chat-header redesign):
/// while you are typing, the only order facts worth spending vertical space on
/// are the reference, the status and the amount. Everything else is one tap
/// away — and that tap must not have to be repeated every time the widget
/// rebuilds, every time a push-driven summary refetch swaps in a new
/// [OrderChatSummary] instance, or every time you leave the thread and come
/// back.
///
/// Local `State` would survive a rebuild but NOT a re-mount (navigating away
/// and back, or the host re-creating the subtree), which is exactly the case
/// that makes a disclosure control feel broken. This holder is a plain
/// in-memory map that lives as long as the app process — deliberately **not**
/// persisted to disk, because "for the session" is the stated requirement and a
/// disk-backed preference would also have to be migrated and cleared.
///
/// Keyed per order so two different threads do not share one toggle.
class ChatHeaderExpansionStore {
  ChatHeaderExpansionStore._();

  /// The process-wide instance. Injected nowhere: this is view state, not
  /// domain state, and giving it a DI seam would invite it into a repository.
  static final ChatHeaderExpansionStore instance = ChatHeaderExpansionStore._();

  final Map<String, bool> _expandedByKey = <String, bool>{};

  /// Whether the header for [key] is expanded. **Collapsed is the default** —
  /// an unknown key is not "no opinion", it is "collapsed".
  bool isExpanded(String key) => _expandedByKey[key] ?? false;

  /// Records the user's choice for [key] for the rest of the session.
  void setExpanded(String key, {required bool expanded}) {
    _expandedByKey[key] = expanded;
  }

  /// Test-only. Widget tests share one process, so without this a test that
  /// expands a header would leak that choice into the next test and quietly
  /// turn a collapsed-by-default assertion green for the wrong reason.
  @visibleForTesting
  void reset() => _expandedByKey.clear();
}
