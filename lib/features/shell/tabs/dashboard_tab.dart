import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../jeeber_home/domain/entities/feed_request.dart';
import '../../jeeber_home/presentation/jeeber_home_screen.dart';

/// Jeeber-side "Home" tab in the role-aware bottom-nav shell. Delegates to
/// [JeeberHomeScreen] so the availability toggle is the first thing the
/// Jeeber sees on cold-start.
///
/// Wires the feed card → request-detail route (T-mobile-033) and the "Register
/// now" upsell CTA → the delivery-man onboarding wizard (screen 19 → 20).
class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final unregistered = _devSeamUnregistered();
    return JeeberHomeScreen(
      key: const Key('dashboard-tab-root'),
      isRegistered: !unregistered,
      profileName: unregistered ? 'Kamal' : null,
      onRegister: () => context.pushNamed('jeeber-onboarding'),
      onOpenFeedRequest: (FeedRequest request) {
        context.pushNamed(
          'jeeber-request-detail',
          pathParameters: {'id': request.id},
          extra: request,
        );
      },
    );
  }

  /// Debug-only: when the dev seam requests the `unregistered` home-tab state,
  /// render screen 19 (the Delivery-tab upsell) deterministically with the
  /// Figma mock name. Always `false` in release builds.
  bool _devSeamUnregistered() =>
      kDebugMode && DevSeam.current.homeTab == 'unregistered';
}
