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
    // a11y (JEBV4-98 / F10-F11): this pill is the trailing affordance of the
    // "Register as a delivery" row, which already exposes ONE interactive
    // Semantics node (button + label) bound to the same [onTap]. A second
    // button node here made screen readers announce two focusable "Register"
    // targets for one action, so the pill's own semantics are excluded — the
    // row remains the single announced control.
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
