import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../l10n/app_localizations.dart';

class DeliveryManMetaRow extends StatelessWidget {
  const DeliveryManMetaRow({
    super.key,
    required this.icon,
    required this.text,
    required this.semanticsId,
  });

  final IconData icon;
  final String text;
  final String semanticsId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      identifier: semanticsId,
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: Sizes.medium, color: theme.colorScheme.primary),
          const SizedBox(width: Spacing.xSmall),
          Flexible(child: _MetaText(text: text)),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [DeliveryManMetaRow] — run with

/// The width the row actually gets inside `DeliveryManProfileHeader` on a 390pt
/// phone: `Spacing.large` gutters on both sides of the header, an
const double _deliveryManMetaRowMetaWidth = 390 - 2 * Spacing.large - Sizes.nineXLarge -
    Spacing.small;

/// The same column on a 320pt phone (iPhone SE, small Android):
/// `320 - 20 - 20 - 88 - 12 = 180`. Used by the longest state, where the
const double _deliveryManMetaRowSmallMetaWidth = 320 - 2 * Spacing.large - Sizes.nineXLarge -
    Spacing.small;

/// Canvas box for a meta row: phone width, and tall enough for the 200%
/// rendering (a single 28sp line — this label truncates rather than wrapping).
const Size _deliveryManMetaRowBox = Size(390, 88);

/// Renders the row under the constraint the profile header really gives it,
/// leading-aligned the way `CrossAxisAlignment.start` places it in the details
Widget _deliveryManMetaRowHosted({
  required IconData icon,
  required String Function(AppLocalizations) text,
  required String semanticsId,
  double width = _deliveryManMetaRowMetaWidth,
}) =>
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Builder(
          builder: (BuildContext context) => DeliveryManMetaRow(
            icon: icon,
            text: text(AppLocalizations.of(context)),
            semanticsId: semanticsId,
          ),
        ),
      ),
    );

/// The state the widget was written for: an established jeeber with an
/// aggregate score, `_RatingRow`'s warm branch and its `profile_score`
@JeebPreview(group: 'delivery_man_profile', name: 'Rating summary', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowRatingSummary() => _deliveryManMetaRowHosted(
      icon: Icons.star,
      text: (AppLocalizations l10n) =>
          l10n.deliveryManProfileRatingSummary('4.3', 113),
      semanticsId: 'profile_score',
    );

/// D59 cold start: under five reviews the header hides the aggregate score and
/// shows the count alone, under a different icon and a *different* identifier
@JeebPreview(group: 'delivery_man_profile', name: 'Cold start (D59)', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowColdStart() => _deliveryManMetaRowHosted(
      icon: Icons.reviews_outlined,
      text: (AppLocalizations l10n) => l10n.deliveryManProfileReviewsCount(3),
      semanticsId: 'delivery_man_profile_rating_summary',
    );

/// The empty state, and the one every jeeber ships with on day one: zero
/// reviews (`rating: 0, reviewCount: 0`, the payload
@JeebPreview(group: 'delivery_man_profile', name: 'No reviews yet', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowNoReviews() => _deliveryManMetaRowHosted(
      icon: Icons.reviews_outlined,
      text: (AppLocalizations l10n) => l10n.deliveryManProfileReviewsCount(0),
      semanticsId: 'delivery_man_profile_rating_summary',
    );

/// `_AvailabilityRow`'s joined branch: a location and an availability label
/// through `deliveryManProfileLocationAvailability`.
@JeebPreview(group: 'delivery_man_profile', name: 'Location + availability', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowLocationAvailability() => _deliveryManMetaRowHosted(
      icon: Icons.location_on,
      text: (AppLocalizations l10n) =>
          l10n.deliveryManProfileLocationAvailability(
        'Lebanon',
        l10n.deliveryManProfileAvailable,
      ),
      semanticsId: 'delivery_man_profile_availability',
    );

/// F9 regression guard, made visible: a jeeber with no location on file.
/// `_AvailabilityRow` drops the template entirely when `location.trim()` is
@JeebPreview(group: 'delivery_man_profile', name: 'Availability only (F9)', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowAvailabilityOnly() => _deliveryManMetaRowHosted(
      icon: Icons.location_on,
      text: (AppLocalizations l10n) => l10n.deliveryManProfileUnavailable,
      semanticsId: 'delivery_man_profile_availability',
    );

/// Longest plausible content in the narrowest column: a real two-part Lebanese
/// location on a 320pt phone (180pt of column, 156pt of it left for the text).
@JeebPreview(group: 'delivery_man_profile', name: 'Longest location (small phone)', size: _deliveryManMetaRowBox)
Widget deliveryManMetaRowLongestLocation() => _deliveryManMetaRowHosted(
      icon: Icons.location_on,
      text: (AppLocalizations l10n) =>
          l10n.deliveryManProfileLocationAvailability(
        'Bourj Hammoud, Mount Lebanon',
        l10n.deliveryManProfileUnavailable,
      ),
      semanticsId: 'delivery_man_profile_availability',
      width: _deliveryManMetaRowSmallMetaWidth,
    );
