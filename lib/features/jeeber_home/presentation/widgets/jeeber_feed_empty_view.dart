import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

/// Deliveryman home empty state (Figma "Delivery Screen - Empty State
/// [Delivery Man]", file ZOi3kKtw7sd42ssSVX3Kn4, node 56559:930, screen 23),
/// re-skinned onto the redesign-2026-08 language.
///
/// Layout: greeting header → the "Accept orders" availability row, now carried
/// on a `JeebOutlinedCard` at the board's 24px gutter → the same start-aligned
/// two-line empty block its live siblings use ([JeeberNoRequestsView] and the
/// feed's own `_EmptyTabState`). Distinct from the availability-toggle-heavy
/// [JeeberNoRequestsView]: this is the lean surface a registered, available
/// Jeeber sees with zero incoming requests.
class JeeberFeedEmptyView extends StatelessWidget {
  const JeeberFeedEmptyView({
    super.key,
    this.profileName,
    this.profileAvatarUrl,
    this.acceptOrders = true,
    this.onAcceptOrdersChanged,
  });

  static const Key rootKey = Key('jeeber-feed-empty-view-root');

  /// Greeting display name.
  final String? profileName;

  /// Greeting avatar URL (cdn-service).
  final String? profileAvatarUrl;

  /// Whether the "Accept orders" availability switch is ON.
  final bool acceptOrders;

  /// Toggle handler for the availability switch.
  final ValueChanged<bool>? onAcceptOrdersChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: rootKey,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _EmptyColumn(
              profileName: profileName,
              profileAvatarUrl: profileAvatarUrl,
              acceptOrders: acceptOrders,
              onAcceptOrdersChanged: onAcceptOrdersChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({
    required this.profileName,
    required this.profileAvatarUrl,
    required this.acceptOrders,
    required this.onAcceptOrdersChanged,
  });

  final String? profileName;
  final String? profileAvatarUrl;
  final bool acceptOrders;
  final ValueChanged<bool>? onAcceptOrdersChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeeberHomeGreeting(name: profileName, avatarUrl: profileAvatarUrl),
        _AcceptOrdersRow(
          value: acceptOrders,
          onChanged: onAcceptOrdersChanged,
        ),
        // No extra gap: the empty block owns its own top inset, matching the
        // band rhythm JeeberNoRequestsView already ships.
        const _EmptyText(),
      ],
    );
  }
}

class _AcceptOrdersRow extends StatelessWidget {
  const _AcceptOrdersRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        0,
      ),
      child: Semantics(
        identifier: 'jeeber_home_accept_orders_switch',
        toggled: value,
        // The live dashboard carries availability on a card, not on a bare
        // tile. This surface cannot use the navy AvailabilityCard (the OMDS
        // tile paints its own onSurface ink), so it takes the outlined card —
        // outline over shadow, same 16 radius and 24px gutter.
        child: JeebOutlinedCard(
          padding: EdgeInsetsDirectional.zero,
          child: OmdsSwitchTile(
            key: const Key('jeeber-home-accept-orders-switch'),
            title: AppLocalizations.of(context).jeeberFeedAcceptOrdersLabel,
            value: value,
            onChanged: onChanged,
            // The same success ROLE the AvailabilityCard switch uses, so
            // "online" reads green on both jeeber-home surfaces.
            activeColor: context.jeebRoles.success,
            contentPadding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.medium,
              vertical: Spacing.small,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Empty ≠ dead" — E3's night street, the block every no-requests surface on
/// the jeeber home already draws ([JeeberFeedEmptyBlock], the feed's own
/// `_EmptyTabState`). One condition, one rendering.
class _EmptyText extends StatelessWidget {
  const _EmptyText();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.xLarge),
      child: JeebEmptyState(
        identifier: 'jeeber_feed_empty_view_empty_state',
        variant: JeebEmptyStateVariant.street,
        headline: l10n.jeeberFeedEmptyTitle,
        body: l10n.jeeberFeedEmptySubtitle,
      ),
    );
  }
}
