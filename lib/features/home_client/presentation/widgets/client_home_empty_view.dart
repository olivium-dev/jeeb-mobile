import 'package:flutter/material.dart';

import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../l10n/app_localizations.dart';

/// E1 — "Empty ≠ dead" for the client Requests screen.
///
/// The composed kit illustration (mic on the route-dot ring, four medallions,
/// waveform ears, twinkles), the tile's white headline and its muted body. The
/// header, the segmented control and the pinned create capsule stay owned by
/// the surrounding screen — the capsule IS this state's call to action, so the
/// separate "Create your first request" button the board never drew is gone and
/// its frozen identifier moved onto the capsule (doc-13 Pattern D).
///
/// The headline is NOT `homeEmptyTitle`: the hero prompt above it is permanent
/// now, and both would ask the customer the same question on one screen.
class ClientHomeEmptyView extends StatelessWidget {
  const ClientHomeEmptyView({super.key});

  /// D4: 60dp under the kit default so the unscrolled rest position of a
  /// three-line body clears the pinned create capsule. Still well above 150.
  static const double illustrationSize = 240;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      identifier: '_request_empty_state_root',
      headline: l10n.homePendingEmptyTitle,
      body: l10n.homePendingEmptyMidnight,
      illustrationSize: illustrationSize,
    );
  }
}
