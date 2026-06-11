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
        if (showRegister) _RegisterRow(onRegister: onRegister),
        _AccountRows(
          onPasswordSecurity: onPasswordSecurity,
          onNotification: onNotification,
          onResetLocation: onResetLocation,
        ),
      ],
    );
  }
}

class _RegisterRow extends StatelessWidget {
  const _RegisterRow({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CustomerProfileRow(
      icon: Icons.delivery_dining_outlined,
      label: l10n.customerProfileRegisterAsDelivery,
      semanticsId: 'customer_profile_register_delivery_row',
      onTap: onRegister,
      trailing: CustomerRegisterPill(onTap: onRegister),
    );
  }
}

class _AccountRows extends StatelessWidget {
  const _AccountRows({
    required this.onPasswordSecurity,
    required this.onNotification,
    required this.onResetLocation,
  });

  final VoidCallback onPasswordSecurity;
  final VoidCallback onNotification;
  final VoidCallback onResetLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PasswordSecurityRow(onTap: onPasswordSecurity),
        _NotificationRow(onTap: onNotification),
        _ResetLocationRow(onTap: onResetLocation),
      ],
    );
  }
}

class _PasswordSecurityRow extends StatelessWidget {
  const _PasswordSecurityRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomerProfileRow(
      icon: Icons.lock_outline,
      label: AppLocalizations.of(context).customerProfilePasswordSecurity,
      semanticsId: 'customer_profile_password_security_row',
      onTap: onTap,
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomerProfileRow(
      icon: Icons.notifications_none,
      label: AppLocalizations.of(context).customerProfileNotification,
      semanticsId: 'customer_profile_notification_row',
      onTap: onTap,
    );
  }
}

class _ResetLocationRow extends StatelessWidget {
  const _ResetLocationRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomerProfileRow(
      icon: Icons.location_on_outlined,
      label: AppLocalizations.of(context).customerProfileResetLocation,
      semanticsId: 'customer_profile_reset_location_row',
      onTap: onTap,
    );
  }
}
