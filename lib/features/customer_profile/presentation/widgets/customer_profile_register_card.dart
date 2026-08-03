import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../l10n/app_localizations.dart';

/// "Register as a delivery" — the growth edge onto the Jeeber funnel, framed in
/// brand orange (redesign-2026-08 §5 #5; board `20-settings` `tpl 1178-1185`).
///
/// This is the SAME treatment the neighbouring Settings screen gives its
/// Become-a-Jeeber row, and it spends this screen's whole orange budget: the
/// Ø38 disc is the only accent fill and `Register` the only accent word, so
/// every other card stays outline-over-shadow.
///
/// It replaces the old navy `OmdsPrimaryButton` pill that used to be the
/// trailing affordance of a plain row. The tap target, the destination and the
/// `customer_profile_register_delivery_row` identifier are unchanged — the pill
/// was already `ExcludeSemantics`'d onto the row's single node, so nothing is
/// lost by folding it into the card's own accent label.
class CustomerProfileRegisterCard extends StatelessWidget {
  const CustomerProfileRegisterCard({super.key, required this.onTap});

  /// Ø38 accent disc + 19px glyph (board `tpl 1179-1181`).
  static const double discDiameter = 38;
  static const double discGlyphSize = 19;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final roles = context.jeebRoles;

    return JeebAccentFrameCard(
      identifier: 'customer_profile_register_delivery_row',
      semanticLabel: l10n.customerProfileRegisterAsDelivery,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: discDiameter,
            height: discDiameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: roles.accent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delivery_dining,
              size: discGlyphSize,
              color: roles.onAccent,
            ),
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              l10n.customerProfileRegisterAsDelivery,
              style: context.jeebText.cardTitle.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Text(
            l10n.customerProfileRegisterCta,
            key: const Key('customer-profile-register-button'),
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: roles.accent,
            ),
          ),
        ],
      ),
    );
  }
}
