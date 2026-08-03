import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/money_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../domain/handover_arrival.dart';
import '../otp_handover_l10n.dart';

/// Screen 13's orange arrival banner (`13-otp-handover.html` `tpl 799-804`) —
/// the one place on the whole board where orange is a *surface* rather than an
/// outline, and this screen's entire orange budget.
///
/// It says who is outside, on what, and how much cash to have in hand. It is
/// garnish over the code: the screen renders perfectly without it (the cubit
/// simply leaves `state.arrival` null), which is why nothing here can fail.
///
/// Privacy (C-13.4): name + vehicle only. No star, no call button, no avatar
/// photo — a terminal screen opens no CDN fetch, so the disc is the initial.
class HandoverArrivalBanner extends StatelessWidget {
  const HandoverArrivalBanner({super.key, required this.arrival});

  final HandoverArrival arrival;

  @override
  Widget build(BuildContext context) {
    final copy = OtpHandoverL10n.of(context);
    final text = context.jeebText;
    final onAccent = context.jeebRoles.onAccent;

    return JeebAccentFrameCard.filled(
      // QA: uiautomator-addressable handle for the arrival banner. NOT a live
      // region — the code display owns this screen's single announcement.
      identifier: 'otp_handover_arrival',
      child: Row(
        children: [
          JeebAvatar.thread(
            initial: arrival.name,
            fill: JeebAvatarFill.onAccent,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  arrival.atDoor
                      ? copy.arrivalAtDoor(arrival.name)
                      : copy.arrivalOnTheWay(arrival.name),
                  style: text.cardTitle.copyWith(color: onAccent),
                ),
                Text(
                  _subtitle(copy),
                  style: text.bodySmall.copyWith(
                    color: onAccent.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.small),
          ExcludeSemantics(
            // Decorative "live" dot — it repeats nothing a screen reader needs.
            child: SizedBox.square(
              dimension: Sizes.xSmall,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: onAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// `Scooter · $8.00 cash ready`, or the bare vehicle label when the delivery
  /// carries no price — the banner never invents an amount, and a vehicle-only
  /// sentence has nothing to translate (§A-4).
  String _subtitle(OtpHandoverL10n copy) {
    final amount = arrival.cashAmount;
    if (amount == null) return arrival.vehicleLabel;
    return copy.arrivalSubtitle(
      arrival.vehicleLabel,
      MoneyFormat.format(amount, currency: arrival.currency ?? 'USD'),
    );
  }
}
