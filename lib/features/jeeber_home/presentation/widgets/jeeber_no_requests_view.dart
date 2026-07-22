import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import 'availability_card.dart';
import 'inactivity_warning_banner.dart';
import 'jeeber_home_greeting.dart';

/// State 2 of the Jeeber home: registered, availability card visible, no
/// active requests on the feed yet.
///
/// Composes the state-aware `AvailabilityCard`, an optional compact active-work
/// disclosure, and `InactivityWarningBanner` with an `OmdsEmptyState` underneath
/// so the Jeeber always knows the feed is live but empty rather than
/// broken. The single-line `JeeberHomeGreeting` sits above availability so the
/// transition into State 3 only changes the band beneath the greeting.
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

  /// CTA tap handler for the inactivity warning banner.
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
        AvailabilityCard(view: view, onToggle: onToggle),
        ?activeDeliveriesBanner,
        if (view.warningVisible) ...[
          const SizedBox(height: Spacing.large),
          InactivityWarningBanner(onExtend: onExtendActivity),
        ],
        const SizedBox(height: Spacing.large),
        const _NoRequestsEmpty(),
      ],
    );
  }
}

class _NoRequestsEmpty extends StatelessWidget {
  const _NoRequestsEmpty();

  static const Key rootKey = Key('jeeber-no-requests-empty-state');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsEmptyState(
      key: rootKey,
      icon: Icons.inbox_outlined,
      title: l10n.requestFeedEmptyTitle,
      subtitle: l10n.requestFeedEmptySubtitle,
    );
  }
}
