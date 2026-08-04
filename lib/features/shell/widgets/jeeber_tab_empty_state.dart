import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../l10n/app_localizations.dart';

import '../../../core/previews/jeeb_preview.dart';

/// M4 §2.7 `empty` on the LIT street tile: E3's parked scooter under a
/// streetlamp is the invitation. The old `IconData` slot is gone with OMDS.
class JeeberTabEmptyState extends StatelessWidget {
  const JeeberTabEmptyState({
    super.key,
    required this.identifier,
    this.variant = JeebEmptyStateVariant.street,
    this.title,
    this.subtitle,
  });

  const JeeberTabEmptyState.dashboard({super.key})
      : identifier = dashboardIdentifier,
        variant = JeebEmptyStateVariant.street,
        title = null,
        subtitle = null;

  const JeeberTabEmptyState.earnings({super.key})
      : identifier = earningsIdentifier,
        variant = JeebEmptyStateVariant.street,
        title = null,
        subtitle = null;

  static const String dashboardIdentifier = 'jeeber_dashboard_empty_state';

  static const String earningsIdentifier = 'jeeber_earnings_empty_state';

  /// Identifier on the CTA pill — the invitation's one act.
  static const String ctaIdentifier = 'jeeber_tab_empty_state_cta';

  final String identifier;

  /// Which §2.7 illustration composes the block. Defaults to the street.
  final JeebEmptyStateVariant variant;

  final String? title;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The shell paints no field of its own (`shell_screen.dart`), so the tab
    // body owns one — matching the live Dashboard/Earnings surfaces it replaces.
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      animateDecor: false,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: JeebEmptyState(
              variant: variant,
              headline: title ?? l10n.becomeJeeberCardTitle,
              body: subtitle ?? l10n.becomeJeeberCardSubtitle,
              medallions: const <JeebEmptyMedallion>[],
              identifier: identifier,
              action: JeebCtaButton.accent(
                label: l10n.becomeJeeberCardCta,
                identifier: ctaIdentifier,
                onTap: () => _openBecomeJeeber(context),
              ),
            ),
          ),
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
  required JeebEmptyStateVariant variant,
  required String Function(AppLocalizations) title,
  required String Function(AppLocalizations) subtitle,
}) {
  return Builder(
    builder: (BuildContext context) {
      final AppLocalizations l10n = AppLocalizations.of(context);
      return JeeberTabEmptyState(
        identifier: identifier,
        variant: variant,
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
      // Documents to send back — E4's open glass parcel box, not the street.
      variant: JeebEmptyStateVariant.parcel,
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
      // Waiting on a reviewer to answer — E2's radar, per §2.7.
      variant: JeebEmptyStateVariant.radar,
      title: (AppLocalizations l10n) => l10n.kycStatusPendingTitle,
      subtitle: (AppLocalizations l10n) => l10n.kycStatusPendingBody,
    );
