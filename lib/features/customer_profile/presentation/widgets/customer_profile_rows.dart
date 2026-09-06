import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';
import 'customer_profile_register_card.dart';

/// The full set of customer-profile navigation rows (JM-035 AC2).
///
/// Renders the 8 affordances the AC enumerates, each carrying the EXACT
/// `Semantics(identifier:)` from `63_W1_TEST_PLAN.md §2.15`:
///   register-delivery / password / notifications / language / contact /
///   rate-app / logout / addresses.
///
/// redesign-2026-08 (re-skin only — same actions, same order, same targets):
///   * the bespoke navy-icon-disc rows become kit [JeebListRow]s inside
///     [JeebOutlinedCard.grouped] cards, so the dividers, the chevron and the
///     ink all come from the system;
///   * the section headers become the periwinkle uppercase [JeebSectionLabel]
///     the whole board uses, instead of navy `titleMedium`;
///   * register-as-delivery is lifted out of the ACCOUNT group into the
///     orange-framed [CustomerProfileRegisterCard] (a bordered card cannot live
///     inside a grouped card) — it is still the first action on the screen;
///   * sign out gets its own card and drops its chevron: it acts in place
///     rather than navigating (the same call the Settings footer makes).
///
/// Every row's action is injected so the screen owns navigation (this widget
/// stays pure + testable; widgets under `widgets/` never touch `context.go`).
/// The "Register as a delivery" card is hidden once the account is a Jeeber
/// (design §8.2) — its target is the onboarding wizard, NOT `/register`
/// (JM-035 AC2 / JM-039).
class CustomerProfileRows extends StatelessWidget {
  const CustomerProfileRows({
    super.key,
    required this.showRegister,
    required this.onRegisterDelivery,
    required this.onPassword,
    required this.onNotifications,
    required this.onLanguage,
    required this.onAddresses,
    required this.onContact,
    required this.onRateApp,
    required this.onLogout,
  }) : signOutOnly = false;

  /// The failed-cold-read rung: the sign-out escape hatch alone, with no row
  /// that would assert an account fact the read never returned (F4).
  const CustomerProfileRows.signOutOnly({super.key, required this.onLogout})
    : signOutOnly = true,
      showRegister = false,
      onRegisterDelivery = _unreachable,
      onPassword = _unreachable,
      onNotifications = _unreachable,
      onLanguage = _unreachable,
      onAddresses = _unreachable,
      onContact = _unreachable,
      onRateApp = _unreachable;

  /// Exit-glyph size on the sign-out row (board `20-settings` `tpl 1217`).
  static const double signOutGlyphSize = 18;

  final bool signOutOnly;
  final bool showRegister;
  final VoidCallback onRegisterDelivery;
  final VoidCallback onPassword;
  final VoidCallback onNotifications;
  final VoidCallback onLanguage;
  final VoidCallback onAddresses;
  final VoidCallback onContact;
  final VoidCallback onRateApp;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (signOutOnly) return _signOutCard(l10n);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // R22 opens each labelled band with 20 (`tpl 1370`/`1377`), not the 16
        // that separates the two cards above the first label.
        if (showRegister) ...[
          CustomerProfileRegisterCard(onTap: onRegisterDelivery),
          const SizedBox(height: Spacing.large),
        ],

        // ── Account ──────────────────────────────────────────────────────
        JeebSectionLabel(l10n.customerProfileSectionAccount),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            // Filled glyphs only (R10) — no `_outlined` variants on this board.
            JeebListRow(
              identifier: 'customer_profile_password_row',
              icon: Icons.lock,
              title: l10n.customerProfilePasswordSecurity,
              onTap: onPassword,
            ),
            JeebListRow(
              identifier: 'customer_profile_notifications_row',
              icon: Icons.notifications,
              title: l10n.customerProfileNotification,
              onTap: onNotifications,
            ),
            JeebListRow(
              identifier: 'customer_profile_language_row',
              // Reuses `settingsLanguage` ("Language") — no new ARB key (l10n is
              // integrator-owned). Dedicated `customerProfileLanguage` requested
              // in 50_ROUTE_REQUESTS.md; Maestro keys on the id, not the text.
              icon: Icons.language,
              title: l10n.settingsLanguage,
              onTap: onLanguage,
            ),
            JeebListRow(
              identifier: 'customer_profile_addresses_row',
              // Reuses `savedAddressesTitle` ("Saved addresses").
              icon: Icons.location_on,
              title: l10n.savedAddressesTitle,
              onTap: onAddresses,
            ),
          ],
        ),
        const SizedBox(height: Spacing.large),

        // ── Support ──────────────────────────────────────────────────────
        JeebSectionLabel(l10n.customerProfileSectionSupport),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
          children: [
            JeebListRow(
              identifier: 'customer_profile_contact_row',
              icon: Icons.call,
              title: l10n.customerProfileContactUs,
              onTap: onContact,
            ),
            JeebListRow(
              identifier: 'customer_profile_rate_app_row',
              icon: Icons.star,
              title: l10n.customerProfileRateApp,
              onTap: onRateApp,
            ),
          ],
        ),
        const SizedBox(height: Spacing.large),

        // ── Sign out — its own card, no chevron: it opens the confirm sheet
        //    in place instead of navigating (board `tpl 1216`).
        _signOutCard(l10n),
      ],
    );
  }

  Widget _signOutCard(AppLocalizations l10n) => JeebOutlinedCard.grouped(
    children: [
      JeebListRow(
        identifier: 'customer_profile_logout_row',
        // Reuses `appBarSignOut` ("Sign out").
        icon: _signOutGlyph,
        iconSize: signOutGlyphSize,
        title: l10n.appBarSignOut,
        showChevron: false,
        padding: JeebOutlinedCard.defaultPadding,
        onTap: onLogout,
      ),
    ],
  );
}

/// Placeholder for the actions [CustomerProfileRows.signOutOnly] never draws.
void _unreachable() {}

/// `Icons.logout` ships with `matchTextDirection: false`, so its arrow keeps
/// pointing at the LTR end edge inside an Arabic layout. This is the same glyph
/// with the flag on, which is what `Icon` reads to mirror itself — and the same
/// constant `settings_footer.dart` declares for its own sign-out row (a shared
/// `DirectionalIcons.signOut` is requested in the wiring file).
const IconData _signOutGlyph = IconData(
  0xe3b3,
  fontFamily: 'MaterialIcons',
  matchTextDirection: true,
);
