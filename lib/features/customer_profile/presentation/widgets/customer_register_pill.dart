import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Compact navy stadium "Register" button shown as the trailing affordance of
/// the "Register as a delivery" row (design §5: ~40dp tall, hugs label). Uses
/// [OmdsPrimaryButton] (no raw Material button) sized to wrap its label.
class CustomerRegisterPill extends StatelessWidget {
  const CustomerRegisterPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'customer_profile_register_button',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('customer-profile-register-button'),
        text: AppLocalizations.of(context).customerProfileRegisterCta,
        onTap: onTap,
        height: Sizes.threeXLarge,
        borderRadius: OmdsBorderRadius.pill,
      ),
    );
  }
}
