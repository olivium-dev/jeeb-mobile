import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

import '../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
const Size _jeeberTabEmptyStatePhoneBody = Size(390, 680);

/// The narrowest device the app still supports.
const Size _jeeberTabEmptyStateCompactBox = Size(320, 600);

/// A short body — a small phone in a locale with a tall system 
const Size _jeeberTabEmptyStateShortBody = Size(390, 420);

/// One state, optionally pinned to a device width. `height: dou
Widget _jeeberTabEmptyStateHosted(Widget state, {double? width}) {
  if (width == null) return state;
  return Center(
    child: SizedBox(width: width, height: double.infinity, child: state),
  );
}

/// The `title` / `subtitle` overrides take raw [String]s, not A
Widget _jeeberTabEmptyStateWithCopy({
  required String identifier,
  required IconData icon,
  required String Function(AppLocalizations) title,
  required String Function(AppLocalizations) subtitle,
}) {
  return Builder(
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return JeeberTabEmptyState(
        identifier: identifier,
        icon: icon,
        title: title(l10n),
        subtitle: subtitle(l10n),
      );
    },
  );
}

/// Exactly how `shell_screen.dart` builds the Dashboard tab for
@JeebPreview(
  group: 'shell',
  name: 'Dashboard tab · non-jeeber',
  size: _jeeberTabEmptyStatePhoneBody,
)
Widget jeeberTabEmptyStateDashboard() =>
    _jeeberTabEmptyStateHosted(const JeeberTabEmptyState.dashboard());

/// The Earnings tab for the same user — the SAME invitation, de
@JeebPreview(
  group: 'shell',
  name: 'Earnings tab · non-jeeber',
  size: _jeeberTabEmptyStatePhoneBody,
)
Widget jeeberTabEmptyStateEarnings() =>
    _jeeberTabEmptyStateHosted(const JeeberTabEmptyState.earnings());

/// **The state that breaks.** The production invitation on a 32
@JeebPreview(
  group: 'shell',
  name: 'Compact 320pt phone',
  size: _jeeberTabEmptyStateCompactBox,
)
Widget jeeberTabEmptyStateCompactPhone() => _jeeberTabEmptyStateHosted(
      const JeeberTabEmptyState.dashboard(),
      width: 320,
    );

/// The override API, driven with real ARB copy: a KYC applicant
@JeebPreview(
  group: 'shell',
  name: 'KYC resubmit copy',
  size: _jeeberTabEmptyStatePhoneBody,
)
Widget jeeberTabEmptyStateKycResubmit() => _jeeberTabEmptyStateWithCopy(
      identifier: JeeberTabEmptyState.earningsIdentifier,
      icon: Icons.upload_file_outlined,
      title: (AppLocalizations l10n) => l10n.kycStatusResubmitTitle,
      subtitle: (AppLocalizations l10n) => l10n.kycStatusResubmitBody,
    );

/// The longest ARB copy in a 420pt body — the only state that c
@JeebPreview(
  group: 'shell',
  name: 'KYC pending · short body',
  size: _jeeberTabEmptyStateShortBody,
)
Widget jeeberTabEmptyStateKycPendingShortBody() =>
    _jeeberTabEmptyStateWithCopy(
      identifier: JeeberTabEmptyState.dashboardIdentifier,
      icon: Icons.hourglass_top_outlined,
      title: (AppLocalizations l10n) => l10n.kycStatusPendingTitle,
      subtitle: (AppLocalizations l10n) => l10n.kycStatusPendingBody,
    );
