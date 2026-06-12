import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

/// Deliveryman home empty state matching the Figma "Delivery Screen - Empty
/// State [Delivery Man]" frame (file ZOi3kKtw7sd42ssSVX3Kn4, node 56559:930,
/// screen 23).
///
/// Layout: greeting header (avatar + "Hello, {name}" + tagline) → an inline
/// "Accept orders" availability switch → a hero illustration → a centered
/// "No Requests yet" / "All requests will show up here" block. Distinct from
/// the availability-toggle-heavy [JeeberNoRequestsView]: this is the lean
/// Figma-parity surface a registered, available Jeeber sees with zero
/// incoming requests.
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
        const SizedBox(height: Spacing.large),
        const _EmptyHero(),
        const SizedBox(height: Spacing.large),
        const _EmptyText(),
        const SizedBox(height: Spacing.large),
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
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
      ),
      child: Semantics(
        identifier: 'jeeber_home_accept_orders_switch',
        toggled: value,
        child: OmdsSwitchTile(
          key: const Key('jeeber-home-accept-orders-switch'),
          title: AppLocalizations.of(context).jeeberFeedAcceptOrdersLabel,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
      ),
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(
            'assets/illustrations/empty_orders.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _EmptyTitle(text: l10n.jeeberFeedEmptyTitle),
        const SizedBox(height: Spacing.xSmall),
        _EmptySubtitle(text: l10n.jeeberFeedEmptySubtitle),
      ],
    );
  }
}

class _EmptyTitle extends StatelessWidget {
  const _EmptyTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.secondaryContainer,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptySubtitle extends StatelessWidget {
  const _EmptySubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }
}
