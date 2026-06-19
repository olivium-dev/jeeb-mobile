import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';
import 'customer_profile_section_header.dart';
import 'customer_register_pill.dart';

/// The full set of customer-profile navigation rows (JM-035 AC2).
///
/// Renders the 8 rows the AC enumerates, each carrying the EXACT
/// `Semantics(identifier:)` from `63_W1_TEST_PLAN.md §2.15`:
///   register-delivery / password / notifications / language / contact /
///   rate-app / logout / addresses.
///
/// Every row's action is injected so the screen owns navigation (this widget
/// stays pure + testable; widgets under `widgets/` never touch `context.go`).
/// The "Register as a delivery" row is hidden once the account is a Jeeber
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
  });

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Account ──────────────────────────────────────────────────────
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionAccount),
        if (showRegister)
          CustomerProfileRow(
            icon: Icons.delivery_dining_outlined,
            label: l10n.customerProfileRegisterAsDelivery,
            semanticsId: 'customer_profile_register_delivery_row',
            onTap: onRegisterDelivery,
            trailing: CustomerRegisterPill(onTap: onRegisterDelivery),
          ),
        CustomerProfileRow(
          icon: Icons.lock_outline,
          label: l10n.customerProfilePasswordSecurity,
          semanticsId: 'customer_profile_password_row',
          onTap: onPassword,
        ),
        CustomerProfileRow(
          icon: Icons.notifications_none,
          label: l10n.customerProfileNotification,
          semanticsId: 'customer_profile_notifications_row',
          onTap: onNotifications,
        ),
        CustomerProfileRow(
          icon: Icons.language_outlined,
          // Reuses `settingsLanguage` ("Language") — no new ARB key (l10n is
          // integrator-owned). Dedicated `customerProfileLanguage` requested in
          // 50_ROUTE_REQUESTS.md; Maestro keys on the id, not the text.
          label: l10n.settingsLanguage,
          semanticsId: 'customer_profile_language_row',
          onTap: onLanguage,
        ),
        CustomerProfileRow(
          icon: Icons.location_on_outlined,
          // Reuses `savedAddressesTitle` ("Saved addresses").
          label: l10n.savedAddressesTitle,
          semanticsId: 'customer_profile_addresses_row',
          onTap: onAddresses,
        ),
        // ── Support ──────────────────────────────────────────────────────
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionSupport),
        CustomerProfileRow(
          icon: Icons.call_outlined,
          label: l10n.customerProfileContactUs,
          semanticsId: 'customer_profile_contact_row',
          onTap: onContact,
        ),
        CustomerProfileRow(
          icon: Icons.star_outline,
          label: l10n.customerProfileRateApp,
          semanticsId: 'customer_profile_rate_app_row',
          onTap: onRateApp,
        ),
        CustomerProfileRow(
          icon: Icons.logout_outlined,
          // Reuses `appBarSignOut` ("Sign out").
          label: l10n.appBarSignOut,
          semanticsId: 'customer_profile_logout_row',
          onTap: onLogout,
        ),
      ],
    );
  }
}
