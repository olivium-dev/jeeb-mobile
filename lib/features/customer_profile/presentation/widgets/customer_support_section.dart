import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import 'customer_profile_row.dart';
import 'customer_profile_section_header.dart';

/// "Support" section of the customer profile: Contact us + Rate the app rows
/// (design §1). Actions injected by the screen.
class CustomerSupportSection extends StatelessWidget {
  const CustomerSupportSection({
    super.key,
    required this.onContactUs,
    required this.onRateApp,
  });

  final VoidCallback onContactUs;
  final VoidCallback onRateApp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerProfileSectionHeader(title: l10n.customerProfileSectionSupport),
        CustomerProfileRow(
          icon: Icons.call_outlined,
          label: l10n.customerProfileContactUs,
          semanticsId: 'customer_profile_contact_us_row',
          onTap: onContactUs,
        ),
        CustomerProfileRow(
          icon: Icons.star_outline,
          label: l10n.customerProfileRateApp,
          semanticsId: 'customer_profile_rate_app_row',
          onTap: onRateApp,
        ),
      ],
    );
  }
}
