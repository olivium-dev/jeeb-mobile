import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import 'availability_card.dart';
import 'jeeber_home_greeting.dart';

/// State 2 of the Jeeber home: registered, availability strip visible, no
/// active requests on the feed yet.
///
/// Composes the profile header, the state-aware `AvailabilityCard` (which now
/// hosts the inactivity warning inline) and an optional compact active-work
/// disclosure, with a quiet start-aligned empty block underneath so the Jeeber
/// always knows the feed is live but empty rather than broken.
class JeeberNoRequestsView extends StatelessWidget {
  const JeeberNoRequestsView({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onExtendActivity,
    this.profileName,
    this.activeDeliveriesBanner,
  });

  static const Key rootKey = Key('jeeber-no-requests-view-root');

  /// Current availability snapshot from the cubit.
  final AvailabilityViewState view;

  /// Tap handler for the big online/offline toggle.
  final VoidCallback onToggle;

  /// Tap handler for the strip's inline `Extend` word (resets the idle timer).
  final VoidCallback onExtendActivity;

  /// Optional profile display name for the greeting.
  final String? profileName;

  /// Compact disclosure for accepted/active work. It self-hides when empty.
  final Widget? activeDeliveriesBanner;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: rootKey,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: Spacing.large),
        child: _NoRequestsColumn(
          view: view,
          profileName: profileName,
          activeDeliveriesBanner: activeDeliveriesBanner,
          onToggle: onToggle,
          onExtendActivity: onExtendActivity,
        ),
      ),
    );
  }
}

class _NoRequestsColumn extends StatelessWidget {
  const _NoRequestsColumn({
    required this.view,
    required this.profileName,
    required this.onToggle,
    required this.onExtendActivity,
    required this.activeDeliveriesBanner,
  });

  final AvailabilityViewState view;
  final String? profileName;
  final Widget? activeDeliveriesBanner;
  final VoidCallback onToggle;
  final VoidCallback onExtendActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeeberHomeGreeting(name: profileName),
        AvailabilityCard(
          view: view,
          onToggle: onToggle,
          onExtendActivity: onExtendActivity,
        ),
        ?activeDeliveriesBanner,
        // No extra gap: the empty block owns its own top inset, so the band
        // rhythm below the strip stays the board's 16/24 — not 44.
        const _NoRequestsEmpty(),
      ],
    );
  }
}

/// The empty feed is not an error, so it gets no centred icon slab: two
/// start-aligned lines at the top of the white body, exactly where the first
/// request card would appear (R1 — the page stays white below the strip).
class _NoRequestsEmpty extends StatelessWidget {
  const _NoRequestsEmpty();

  static const Key rootKey = Key('jeeber-no-requests-empty-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light())
            .mutedText;
    return Padding(
      key: rootKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.xLarge,
        Spacing.xLarge,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.requestFeedEmptyTitle,
            style: context.jeebText.titleProminent.copyWith(
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.requestFeedEmptySubtitle,
            style: context.jeebText.bodySmall.copyWith(color: mutedInk),
          ),
        ],
      ),
    );
  }
}
