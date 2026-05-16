import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../jeeber_home/domain/entities/feed_request.dart';
import '../../jeeber_home/presentation/jeeber_home_screen.dart';

/// Jeeber-side "Home" tab in the role-aware bottom-nav shell. Delegates to
/// [JeeberHomeScreen] so the availability toggle is the first thing the
/// Jeeber sees on cold-start.
///
/// Wires the feed card → request-detail route (T-mobile-033) so tapping a
/// candidate from the feed opens the detail screen where the Jeeber can
/// review the request and, if needed, file a prohibited-item report.
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return JeeberHomeScreen(
      key: const Key('dashboard-tab-root'),
      onOpenFeedRequest: (FeedRequest request) {
        context.pushNamed(
          'jeeber-request-detail',
          pathParameters: {'id': request.id},
          extra: request,
        );
      },
    );
  }
}
