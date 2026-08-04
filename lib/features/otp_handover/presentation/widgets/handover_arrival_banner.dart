import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/money_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/handover_arrival.dart';

/// Board `width/height:10px` on the live dot (`tpl 803`).
const double _kLiveDotSize = 10;

/// Board `0 0 12px rgba(255,255,255,.9)` — the dot's own halo, and the one
/// glow on this screen that is white rather than orange.
const double _kLiveDotGlowBlur = 12;
const double _kLiveDotGlowAlpha = 0.9;

/// Board `rgba(255,255,255,.85)` on the subtitle (`tpl 802`).
const double _kSubtitleAlpha = 0.85;

/// MIDNIGHT R13's orange arrival banner (`tpl 799-804`) — the caption's "one
/// solid block", and this screen's entire orange-surface budget.
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
    final l10n = AppLocalizations.of(context);
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
                      ? l10n.otpArrivalAtDoor(arrival.name)
                      : l10n.otpArrivalOnTheWay(arrival.name),
                  style: text.cardTitle.copyWith(color: onAccent),
                ),
                Text(
                  _subtitle(l10n),
                  style: text.bodySmall.copyWith(
                    color: onAccent.withValues(alpha: _kSubtitleAlpha),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.small),
          ExcludeSemantics(
            // Decorative "live" dot — it repeats nothing a screen reader needs.
            child: SizedBox.square(
              dimension: _kLiveDotSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: onAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: onAccent.withValues(alpha: _kLiveDotGlowAlpha),
                      blurRadius: _kLiveDotGlowBlur,
                    ),
                  ],
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
  String _subtitle(AppLocalizations l10n) {
    final amount = arrival.cashAmount;
    if (amount == null) return arrival.vehicleLabel;
    return l10n.otpArrivalSubtitle(
      arrival.vehicleLabel,
      MoneyFormat.format(amount, currency: arrival.currency ?? 'USD'),
    );
  }
}
