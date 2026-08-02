import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/notifications/application/badge_count_cubit.dart';
import '../../shell/tab_visibility.dart';
import '../cubit/request_feed_cubit.dart';






























class FeedResumeRefetcher extends StatefulWidget {
  const FeedResumeRefetcher({super.key, required this.child});

  final Widget child;

  @override
  State<FeedResumeRefetcher> createState() => _FeedResumeRefetcherState();
}

class _FeedResumeRefetcherState extends State<FeedResumeRefetcher>
    with ResumeRefetchMixin {
  
  
  
  
  bool? _wasVisible;

  
  
  
  
  
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
