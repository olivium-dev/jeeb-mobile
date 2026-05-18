import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import 'availability_status_block.dart';
import 'availability_toggle.dart';
import 'inactivity_warning_banner.dart';
import 'jeeber_home_greeting.dart';

/// State 2 of the Jeeber home: registered, available toggle visible, no
/// active requests on the feed yet.
///
/// Composes the existing `AvailabilityToggle` + `AvailabilityStatusBlock` +
/// optional `InactivityWarningBanner` with an `OmdsEmptyState` underneath
/// so the Jeeber always knows the feed is live but empty rather than
/// broken. The shared `JeeberHomeGreeting` sits above the toggle so the
/// transition into State 3 only changes the band beneath the greeting.
class JeeberNoRequestsView extends StatelessWidget {
  const JeeberNoRequestsView({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onExtendActivity,
    this.profileName,
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: rootKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Spacing.large),
        child: _NoRequestsColumn(
          view: view,
          profileName: profileName,
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
  });

  final AvailabilityViewState view;
  final String? profileName;
  final VoidCallback onToggle;
  final VoidCallback onExtendActivity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeeberHomeGreeting(name: profileName),
        const _AvailabilityHeader(),
        const SizedBox(height: Spacing.large),
        _ToggleRow(view: view, onTap: onToggle),
        const SizedBox(height: Spacing.large),
        AvailabilityStatusBlock(view: view),
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

class _AvailabilityHeader extends StatelessWidget {
  const _AvailabilityHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: Text(
        l10n.availabilityCardTitle,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.view, required this.onTap});

  final AvailabilityViewState view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AvailabilityToggle(
        state: view.status.state,
        isInFlight: view.isToggleInFlight,
        onTap: onTap,
      ),
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
