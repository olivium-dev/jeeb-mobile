import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';
import 'customer_profile_section_header.dart';
import 'customer_register_pill.dart';

/// "Account" section of the customer profile: optional Register-as-delivery
/// row (hidden once the customer is a Jeeber) followed by password, notification
/// and reset-location rows. Each row's action is injected so the screen owns
/// navigation (keeps this widget pure + testable).
class CustomerAccountSection extends StatelessWidget {
  const CustomerAccountSection({
    super.key,
    required this.showRegister,
    required this.onRegister,
    required this.onPasswordSecurity,
    required this.onNotification,
    required this.onResetLocation,
  });

  final bool showRegister;
  final VoidCallback onRegister;
  final VoidCallback onPasswordSecurity;
  final VoidCallback onNotification;
  final VoidCallback onResetLocation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionAccount),
        if (showRegister) _registerRow(l10n),
        CustomerProfileRow(
          icon: Icons.lock_outline,
          label: l10n.customerProfilePasswordSecurity,
          semanticsId: 'customer_profile_password_security_row',
          onTap: onPasswordSecurity,
        ),
        CustomerProfileRow(
          icon: Icons.notifications_none,
          label: l10n.customerProfileNotification,
          semanticsId: 'customer_profile_notification_row',
          onTap: onNotification,
        ),
        CustomerProfileRow(
          icon: Icons.location_on_outlined,
          label: l10n.customerProfileResetLocation,
          semanticsId: 'customer_profile_reset_location_row',
          onTap: onResetLocation,
        ),
      ],
    );
  }

  Widget _registerRow(AppLocalizations l10n) {
    return CustomerProfileRow(
      icon: Icons.delivery_dining_outlined,
      label: l10n.customerProfileRegisterAsDelivery,
      semanticsId: 'customer_profile_register_delivery_row',
      onTap: onRegister,
      trailing: CustomerRegisterPill(onTap: onRegister),
    );
  }
}
