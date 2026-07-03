import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shell/tab_visibility.dart';
import '../cubit/request_feed_cubit.dart';

/// G3 recovery triggers for the jeeber request feed.
///
/// The feed is WS/polling-driven while on screen, but before this widget
/// existed it NEVER refetched on app resume or shell-tab refocus — the
/// customer home had the [TabVisibility] re-pull affordance
/// (`client_home_screen.dart` S13) while the jeeber side had none, so a
/// jeeber who dismissed the push and reopened the app later could stare at
/// a stale "No requests right now" for a request still live server-side.
///
/// Mounted by `DashboardTab` between the feed's [RequestFeedCubit] provider
/// and the jeeber home body, it silently re-pulls the snapshot
/// ([RequestFeedCubit.refresh] — no loading flash, re-entrant safe) when:
///
///  * the app returns to the foreground ([AppLifecycleState.resumed]) —
///    the tab stays mounted in the shell's [IndexedStack] even while
///    another tab is selected, so this also warms the feed for the next
///    tab switch; and
///  * the Dashboard tab flips off-screen → on-screen (the shell's
///    [TabVisibility] signal), mirroring the customer-home pattern.
///
/// Outside the shell (bare widget tests, deep-link routes)
/// [TabVisibility.maybeOf] is null → treated as always-visible → the
/// refocus trigger degrades to a no-op, exactly like the customer home.
class FeedResumeRefetcher extends StatefulWidget {
  const FeedResumeRefetcher({super.key, required this.child});

  final Widget child;

  @override
  State<FeedResumeRefetcher> createState() => _FeedResumeRefetcherState();
}

class _FeedResumeRefetcherState extends State<FeedResumeRefetcher>
    with WidgetsBindingObserver {
  /// Last-observed shell-tab visibility, used to detect the off-screen →
  /// on-screen transition. `null` until the first [didChangeDependencies]
  /// so the very first frame never double-fetches ([RequestFeedCubit.start]
  /// owns the initial snapshot).
  bool? _wasVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refetch();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    final becameVisible = _wasVisible == false && isVisible;
    _wasVisible = isVisible;
    if (!becameVisible) return;
    _refetch();
  }

  /// Post-frame + mounted-guarded so a refetch scheduled mid-build (the
  /// dependency change) or during teardown never touches a defunct element.
  void _refetch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestFeedCubit>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
