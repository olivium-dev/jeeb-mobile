import 'package:flutter/widgets.dart';

/// Ambient "is this shell tab currently on-screen?" signal.
///
/// The shell hosts its tabs inside an [IndexedStack] (see [ShellScreen]), which
/// keeps every tab's element mounted across bottom-nav switches. A tab body
/// therefore never re-runs `initState`/`didChangeDependencies` from a plain
/// route push, so it has no built-in way to know it has just regained focus.
///
/// [ShellScreen] wraps each [IndexedStack] child in a [TabVisibility] carrying
/// `isVisible == (childIndex == selectedIndex)`. A tab body that needs to react
/// to (re)becoming visible — e.g. to silently re-pull a list so a freshly
/// created/accepted item surfaces without a manual pull-to-refresh — reads it
/// via [TabVisibility.maybeOf] and compares across `didChangeDependencies`.
///
/// Bodies rendered outside the shell (bare widget tests, deep-link routes) see
/// `maybeOf == null` and should treat themselves as always-visible, so the
/// affordance degrades to a no-op rather than a hard dependency.
class TabVisibility extends InheritedWidget {
  const TabVisibility({
    super.key,
    required this.isVisible,
    required super.child,
  });

  /// True when the wrapped tab is the selected [IndexedStack] child.
  final bool isVisible;

  /// The nearest [TabVisibility], or `null` when not hosted by the shell.
  /// Establishes a dependency so the caller's `didChangeDependencies` re-runs
  /// whenever [isVisible] flips.
  static TabVisibility? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabVisibility>();
  }

  @override
  bool updateShouldNotify(TabVisibility oldWidget) =>
      oldWidget.isVisible != isVisible;
}
