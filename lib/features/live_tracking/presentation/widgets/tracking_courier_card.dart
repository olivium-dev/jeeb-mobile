import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../delivery_status/domain/jeeber_summary.dart';
import '../../../mixed_direction/presentation/mixed_direction_text.dart';
import '../live_tracking_l10n.dart';
import 'order_summary_pinned_header.dart' show formatTrackingPrice;

/// redesign-2026-08 §C task 10 — the matched-courier card on the customer's
/// live-tracking surface (`12-live-tracking.html` tpl 765-773).
///
/// A white [JeebOutlinedCard]: Ø42 avatar, `<name> is on the way` in
/// `cardTitle`, and one qualifier line carrying the vehicle and the
/// cash-on-delivery amount.
///
/// ## What this card deliberately does NOT render
///
/// The board draws a `★ 4.9` run and a Ø40 phone circle. **Neither ships**, and
/// that is a privacy contract rather than a data gap:
/// `DeliveryTrackingInfo._parseJeeber` never reads `rating` or `phoneE164` off
/// the wire — `delivery_tracking_jeeber_parse_test.dart` pins the withholding
/// even when the gateway leaks them — because the blind-reveal rule keeps a
/// courier's rating and number out of the customer's hands until completion.
/// Rendering either would mean inventing data the app refuses to hold, so there
/// is no TODO here either: nothing is pending.
class TrackingCourierCard extends StatelessWidget {
  const TrackingCourierCard({
    super.key,
    required this.jeeber,
    this.price,
    this.currency,
  });

  /// The public in-flight slice of the matched courier.
  final JeeberSummary jeeber;

  /// Accepted price. Null degrades the subtitle to the vehicle label alone —
  /// never a fabricated `0.00`.
  final double? price;

  /// ISO currency code that goes with [price].
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final theme = Theme.of(context);
    final ramp = context.jeebText;
    final amount = price;
    final mutedInk =
        (theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.light())
            .mutedText;
    final subtitle = amount == null
        ? jeeber.vehicleLabel
        : '${jeeber.vehicleLabel} · '
            '${l10n.cashOnDelivery(formatTrackingPrice(amount, currency))}';

    return Semantics(
      identifier: 'tracking_courier_card',
      container: true,
      explicitChildNodes: true,
      child: JeebOutlinedCard(
        child: Row(
          children: [
            // Photo when the gateway signed one, initial disc otherwise —
            // `order_tracking_jeeber_card_test.dart` asserts the real Image.
            JeebAvatar(
              initial: jeeber.displayName,
              imageUrl: jeeber.avatarUrl,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.courierOnTheWay(jeeber.displayName),
                    style: ramp.cardTitle
                        .copyWith(color: theme.colorScheme.primary),
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
          ],
        ),
      ),
    );
  }
}
