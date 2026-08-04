import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../l10n/app_localizations.dart';

/// E1 — "Empty ≠ dead" for the client Requests screen.
///
/// The composed kit illustration (mic on the route-dot ring, four medallions,
/// waveform ears, twinkles), the tile's white headline and its muted body. The
/// header, the segmented control and the voice capsule below stay owned by the
/// surrounding screen — the capsule IS this state's call to action, so the
/// separate "Create your first request" button the board never drew is gone and
/// its frozen identifier moved onto the capsule (doc-13 Pattern D).
class ClientHomeEmptyView extends StatelessWidget {
  const ClientHomeEmptyView({super.key, this.onNewOrder});

  /// Retained for API compatibility with the tabs that mount this view; the
  /// create affordance now lives on the screen's voice capsule.
  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      identifier: '_request_empty_state_root',
      headline: l10n.homeEmptyTitle,
      body: l10n.homePendingEmptyMidnight,
    );
  }
}
