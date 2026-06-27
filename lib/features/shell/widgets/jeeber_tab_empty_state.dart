import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// Empty-state scaffolding shown on the additive jeeber tabs (Dashboard /
/// Earnings) to a regular user who is NOT (yet) a jeeber.
///
/// UX LAW (consolidated-lessons §12): a jeeber is also a user — EVERY user
/// sees the full jeeber-tab scaffolding, but a non-jeeber sees the tab's
/// EMPTY STATE inviting them to become a jeeber, NOT a role switch. There is
/// no mode-switch: the tabs are additive and always present; only their body
/// differs based on whether the signed-in user already has the `jeeber` role
/// (resolved from getMe `available_roles`, never an in-app role flip).
///
/// The CTA routes to the become-a-jeeber / KYC flow (the same `kyc-status`
/// target the Profile-tab `BecomeJeeberCard` uses), guarded by
/// [GoRouter.maybeOf] so it degrades to a no-op in a router-less widget test.
class JeeberTabEmptyState extends StatelessWidget {
  const JeeberTabEmptyState({
    super.key,
    required this.identifier,
    required this.icon,
    this.title,
    this.subtitle,
  });

  /// Empty state for the additive jeeber DASHBOARD tab (availability + feed).
  /// A non-jeeber sees a "Become a Jeeber" invitation instead of the live
  /// availability toggle + request feed.
  const JeeberTabEmptyState.dashboard({super.key})
      : identifier = dashboardIdentifier,
        icon = Icons.two_wheeler_outlined,
        title = null,
        subtitle = null;

  /// Empty state for the additive jeeber EARNINGS tab. A non-jeeber sees the
  /// same "Become a Jeeber" invitation instead of an empty earnings dashboard.
  const JeeberTabEmptyState.earnings({super.key})
      : identifier = earningsIdentifier,
        icon = Icons.payments_outlined,
        title = null,
        subtitle = null;

  /// Stable screen-level Semantics id for the dashboard-tab empty state so QA
  /// (Maestro / adb ui-tree) can assert a non-jeeber lands here.
  static const String dashboardIdentifier = 'jeeber_dashboard_empty_state';

  /// Stable screen-level Semantics id for the earnings-tab empty state.
  static const String earningsIdentifier = 'jeeber_earnings_empty_state';

  /// Screen-level Semantics identifier for this empty state.
  final String identifier;

  /// Leading icon for the invitation card.
  final IconData icon;

  /// Optional explicit title override; defaults to the become-a-jeeber title.
  final String? title;

  /// Optional explicit subtitle override; defaults to the become-a-jeeber copy.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: identifier,
      child: Center(
        child: OmdsEmptyState(
          icon: icon,
          title: title ?? l10n.becomeJeeberCardTitle,
          subtitle: subtitle ?? l10n.becomeJeeberCardSubtitle,
          buttonText: l10n.becomeJeeberCardCta,
          onButtonTap: () => _openBecomeJeeber(context),
        ),
      ),
    );
  }

  void _openBecomeJeeber(BuildContext context) {
    GoRouter.maybeOf(context)?.goNamed('kyc-status');
  }
}
