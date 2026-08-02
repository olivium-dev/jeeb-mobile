import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

class CustomerRegisterPill extends StatelessWidget {
  const CustomerRegisterPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
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
