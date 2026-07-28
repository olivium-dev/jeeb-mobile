import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/notifications/application/badge_count_cubit.dart';
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
/// It also owns the G3 badge-clear side of the contract: while the feed is
/// actually on screen, the Dashboard-tab badge ([BadgeCounts.newRequests])
/// has nothing unseen to count — so it is cleared on first view, on refocus,
/// and whenever a push lands mid-view. [BadgeCountCubit] is resolved with a
/// nullable read; a harness without it simply renders badge-less.
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
    with ResumeRefetchMixin {
  /// Last-observed shell-tab visibility, used to detect the off-screen →
  /// on-screen transition. `null` until the first [didChangeDependencies]
  /// so the very first frame never double-fetches ([RequestFeedCubit.start]
  /// owns the initial snapshot).
  bool? _wasVisible;

  /// b02 P0 — this used to be `didChangeAppLifecycleState(resumed)` with its own
  /// binding observer. It was one of the three surfaces measured issuing 20
  /// unthrottled reads in 2.08 s (`/v1/jeebers/me/feed`, seq 58..115, the last
  /// one a 429). [ResumeRefetchMixin] applies the genuine-resume filter and the
  /// coalescing floor; the refetch body below is unchanged.
  @override
  void onAppResumed() => _refetch();

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
  /// When the feed is the VISIBLE tab, regaining it also clears the request
  /// badge — the open requests are (about to be) on screen. An app resume
  /// with another tab selected refetches (warms the feed) but keeps the
  /// badge: the jeeber has not looked yet.
  void _refetch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RequestFeedCubit>().refresh();
      if (_wasVisible ?? true) {
        context.read<BadgeCountCubit?>()?.clearNewRequests();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // G3 badge-clear: while the feed is on screen the request badge counts
    // nothing unseen. Nullable watch (same idiom as the shell) so bare
    // harnesses stay wiring-free; the post-frame guard keeps the emit out
    // of the build phase; clearNewRequests no-ops at zero so this settles
    // after one extra frame instead of looping.
    final badgeCubit = context.watch<BadgeCountCubit?>();
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    if (badgeCubit != null && isVisible && badgeCubit.state.newRequests > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        badgeCubit.clearNewRequests();
      });
    }
    return widget.child;
  }
}
