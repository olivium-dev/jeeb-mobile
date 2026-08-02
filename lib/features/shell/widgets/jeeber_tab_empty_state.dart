import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

class JeeberTabEmptyState extends StatelessWidget {
  const JeeberTabEmptyState({
    super.key,
    required this.identifier,
    required this.icon,
    this.title,
    this.subtitle,
  });

  const JeeberTabEmptyState.dashboard({super.key})
      : identifier = dashboardIdentifier,
        icon = Icons.two_wheeler_outlined,
        title = null,
        subtitle = null;

  const JeeberTabEmptyState.earnings({super.key})
      : identifier = earningsIdentifier,
        icon = Icons.payments_outlined,
        title = null,
        subtitle = null;

  static const String dashboardIdentifier = 'jeeber_dashboard_empty_state';

  static const String earningsIdentifier = 'jeeber_earnings_empty_state';

  final String identifier;

  final IconData icon;

  final String? title;

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
