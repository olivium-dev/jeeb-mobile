import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../mixed_direction/presentation/mixed_direction_text.dart';
import '../../domain/jeeber_summary.dart';

/// Shows the matched Jeeber's avatar, display name, vehicle, and rating.
///
/// Renders a `looking for…` placeholder while [jeeber] is null. The card
/// intentionally does not embed the Contact CTA — that's owned by the
/// screen's action bar so the layout stays uniform across lifecycle states.
///
/// redesign-2026-08: same information, the courier shape 12 already ships —
/// [JeebOutlinedCard] with a Ø42 [JeebAvatar], the name in `cardTitle` navy and
/// ONE qualifier line beneath it. The rating left its peach `tertiaryContainer`
/// chip and joined that line (`4.8 ★ · Scooter`), which is how the board draws
/// a courier's meta run.
class DeliveryJeeberCard extends StatelessWidget {
  const DeliveryJeeberCard({super.key, required this.jeeber});

  static const Key rootKey = Key('delivery-status-jeeber-card');

  final JeeberSummary? jeeber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matched = jeeber;
    return Column(
      key: rootKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.deliveryJeeberCardTitle),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard(
          child:
              matched == null ? const _Waiting() : _JeeberRow(jeeber: matched),
        ),
      ],
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox.square(
          dimension: Sizes.xLarge,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            AppLocalizations.of(context).deliveryJeeberWaiting,
            style: context.jeebText.bodySmall
                .copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _JeeberRow extends StatelessWidget {
  const _JeeberRow({required this.jeeber});

  final JeeberSummary jeeber;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final ramp = context.jeebText;
    final rating = jeeber.rating;
    final subtitle = rating == null
        ? jeeber.vehicleLabel
        : '${l10n.deliveryJeeberRating(rating.toStringAsFixed(1))} · '
            '${jeeber.vehicleLabel}';
    return Row(
      children: [
        // Photo when the gateway signed one, initial disc otherwise — the kit
        // normalises the initial, so no name is ever fabricated.
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
                jeeber.displayName,
                style: ramp.cardTitle.copyWith(color: scheme.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Latin rating beside Arabic copy: isolate it so the number
              // cannot be reordered by the surrounding bidi context.
              MixedDirectionText(
                subtitle,
                // Facts, not qualifiers (R4) — and the board's periwinkle
                // fails AA on white at this size by the repo's own pinned
                // contrast guard, so this line is `onSurfaceVariant`.
                style: ramp.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
