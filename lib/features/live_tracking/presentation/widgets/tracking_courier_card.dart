import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../delivery_status/domain/jeeber_summary.dart';
import '../../../mixed_direction/presentation/mixed_direction_text.dart';
import '../live_tracking_l10n.dart';

/// Formats the accepted price for display. Deliberately NOT a currency-symbol
/// mapper: the gateway sends an ISO code and inventing `$` would be a second
/// source of truth.
String formatTrackingPrice(double price, String? currency) {
  final amount = price.toStringAsFixed(2);
  return currency == null ? amount : '$amount $currency';
}

/// MIDNIGHT R3 — the matched-courier row inside the tracking sheet.
///
/// A BARE row on the sheet (the board draws no card behind it): Ø46 avatar,
/// `<name> is on the way` in white `titleProminent`, and one periwinkle
/// qualifier line carrying the vehicle and the cash-on-delivery amount.
///
/// ## What this row deliberately does NOT render
///
/// The board draws a `★ 4.9` run and a Ø48 phone circle beside the chat one.
/// **Neither ships**, and that is a privacy contract rather than a data gap:
/// `DeliveryTrackingInfo._parseJeeber` never reads `rating` or `phoneE164` off
/// the wire — `delivery_tracking_jeeber_parse_test.dart` pins the withholding
/// even when the gateway leaks them — because the blind-reveal rule keeps a
/// courier's rating and number out of the customer's hands until completion.
// TODO(midnight): omitted, not faked — R3's ★ rating run and call circle need
// `rating`/`phoneE164` released by the blind-reveal policy first (doc-13 §A).
class TrackingCourierCard extends StatelessWidget {
  const TrackingCourierCard({
    super.key,
    required this.jeeber,
    this.price,
    this.currency,
    this.trailing,
  });

  /// R3's identity disc — the ladder's `header` rung (board 51 px at the
  /// tile's 1.1x export scale = 46 dp).
  static const double avatarDiameter = JeebAvatar.headerDiameter;

  /// The public in-flight slice of the matched courier.
  final JeeberSummary jeeber;

  /// Accepted price. Null degrades the subtitle to the vehicle label alone —
  /// never a fabricated `0.00`.
  final double? price;

  /// ISO currency code that goes with [price].
  final String? currency;

  /// End-of-row action slot — the board's chat circle. Null renders none.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final theme = Theme.of(context);
    final ramp = context.jeebText;
    final amount = price;
    final mutedInk =
        (theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight())
            .mutedText;
    final subtitle = amount == null
        ? jeeber.vehicleLabel
        : '${jeeber.vehicleLabel} · '
            '${l10n.cashOnDelivery(formatTrackingPrice(amount, currency))}';
    final action = trailing;

    return Semantics(
      identifier: 'tracking_courier_card',
      container: true,
      explicitChildNodes: true,
      child: Row(
        children: [
          // Photo when the gateway signed one, initial disc otherwise —
          // `order_tracking_jeeber_card_test.dart` asserts the real Image.
          JeebAvatar(
            initial: jeeber.displayName,
            imageUrl: jeeber.avatarUrl,
            diameter: avatarDiameter,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.courierOnTheWay(jeeber.displayName),
                  style: ramp.titleProminent
                      .copyWith(color: theme.colorScheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Latin money beside Arabic copy: isolate so the amount
                // cannot be reordered by the surrounding bidi context.
                MixedDirectionText(
                  subtitle,
                  style: ramp.bodySmall.copyWith(color: mutedInk),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: Spacing.small),
            action,
          ],
        ],
      ),
    );
  }
}
