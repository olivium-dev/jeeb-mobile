import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';
import 'customer_profile_section_header.dart';
import 'customer_register_pill.dart';

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
          label: l10n.settingsLanguage,
          semanticsId: 'customer_profile_language_row',
          onTap: onLanguage,
        ),
        CustomerProfileRow(
          icon: Icons.location_on_outlined,
          label: l10n.savedAddressesTitle,
          semanticsId: 'customer_profile_addresses_row',
          onTap: onAddresses,
        ),
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
          label: l10n.appBarSignOut,
          semanticsId: 'customer_profile_logout_row',
          onTap: onLogout,
        ),
      ],
    );
  }
}
