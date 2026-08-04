import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import 'availability_card.dart';
import 'jeeber_home_greeting.dart';

/// State 2 of the Jeeber home: registered, availability strip visible, no
/// requests on the feed yet — MIDNIGHT **E3** (`29-e3-empty-no-requests
/// -nearby.png`).
///
/// E3 is R16 with the feed replaced by the "Empty ≠ dead" block: the same
/// profile header and availability strip, then the drawn night-street scene,
/// the white headline, the muted body and a glass CTA. The field belongs to the
/// screen, so this view paints none.
class JeeberNoRequestsView extends StatelessWidget {
  const JeeberNoRequestsView({
    super.key,
    required this.view,
    required this.onToggle,
    required this.onExtendActivity,
    this.profileName,
    this.activeDeliveriesBanner,
    this.onRefresh,
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

  /// Refetches the feed from E3's `Pull to refresh` pill. Null where the host
  /// has no feed contract to refresh (offline / no cubit) — the pill is then
  /// omitted rather than shipped inert.
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    // ONE scroll surface for the whole page: the host wraps this view in
    // `OmdsPullToRefresh`, and a second scrollable over the empty block would
    // swallow the pull (JEBV4-13 P2-6).
    return SafeArea(
      key: rootKey,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: JeeberHomeGreeting(name: profileName)),
          SliverToBoxAdapter(
            child: AvailabilityCard(
              view: view,
              onToggle: onToggle,
              onExtendActivity: onExtendActivity,
            ),
          ),
          if (activeDeliveriesBanner != null)
            SliverToBoxAdapter(child: activeDeliveriesBanner!),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(
                top: Spacing.twoXLarge,
                bottom: Spacing.large + context.scrollBodyBottomInset,
              ),
              child: JeeberFeedEmptyBlock(onRefresh: onRefresh),
            ),
          ),
        ],
      ),
    );
  }
}

/// E3's empty block, centred in the space it is given and scrollable when that
/// space is shorter than the drawn scene — for hosts that mount it as the
/// remaining sliver of their own scroll view.
class JeeberFeedEmptyPanel extends StatelessWidget {
  const JeeberFeedEmptyPanel({super.key, this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
            child: Center(child: JeeberFeedEmptyBlock(onRefresh: onRefresh)),
          ),
        ),
      ),
    );
  }
}

/// E3's "Empty ≠ dead" block, shared by every no-requests surface on this
/// screen so the jeeber never meets two different empties for one condition.
class JeeberFeedEmptyBlock extends StatelessWidget {
  const JeeberFeedEmptyBlock({super.key, this.onRefresh});

  static const Key rootKey = Key('jeeber-no-requests-empty-state');

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      key: rootKey,
      identifier: 'jeeber_feed_empty_state',
      variant: JeebEmptyStateVariant.street,
      // The zoned body (`jeeberFeedQuietStreetBodyZoned`) stays unwired — the
      // gateway returns no zone.
      headline: l10n.jeeberFeedQuietStreetTitle,
      body: l10n.jeeberFeedQuietStreetBody,
      // TODO(midnight): omitted — E3's second pill "Widen my zone": the app has
      // no service-zone surface and the gateway parses no zone back.
      action: onRefresh == null ? null : _RefreshPill(onRefresh: onRefresh!),
    );
  }
}

class _RefreshPill extends StatelessWidget {
  const _RefreshPill({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: JeebCtaButton.outline(
        label: AppLocalizations.of(context).jeeberFeedPullToRefreshAction,
        identifier: 'jeeber_feed_empty_refresh_cta',
        expand: false,
        onTap: onRefresh,
      ),
    );
  }
}
