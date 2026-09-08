import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../l10n/app_localizations.dart';

/// "Reviews" heading + (count · View all) row above the review list
/// (design §2).
///
/// redesign-2026-08: the heading is the board's navy `h2`, the count the
/// 12/w600 periwinkle meta line, and "View all" the kit's [JeebCtaButton]
/// `accentText` link — the same inline orange affordance the board uses for
/// "Edit" / "Change" / "Top up" / "How fees work". It is the ONE orange
/// element on this screen, which is exactly how the accent is rationed.
class DeliveryReviewsHeader extends StatelessWidget {
  const DeliveryReviewsHeader({
    super.key,
    required this.reviewCount,
    required this.onViewAll,
    this.showCount = true,
  });

  final int reviewCount;

  /// DMP-01: the count is a claim about loaded data — suppress it while the
  /// band is loading, failed, or genuinely empty.
  final bool showCount;

  /// Null renders "View all" non-interactive (DMP-02: no jeeberId, no route).
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The board's 24px side gutter (§4.3).
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ReviewsTitle(),
          _CountAndViewAll(
            reviewCount: reviewCount,
            onViewAll: onViewAll,
            showCount: showCount,
          ),
        ],
      ),
    );
  }
}

class _ReviewsTitle extends StatelessWidget {
  const _ReviewsTitle();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      l10n.deliveryManProfileReviewsTitle,
      // NOT `JeebSectionLabel`: that widget uppercases, and both the widget
      // test and the Maestro flow read the natural-cased "Reviews".
      style: context.jeebText.h2.copyWith(color: theme.colorScheme.onSurface),
    );
  }
}

class _CountAndViewAll extends StatelessWidget {
  const _CountAndViewAll({
    required this.reviewCount,
    required this.onViewAll,
    required this.showCount,
  });

  final int reviewCount;
  final VoidCallback? onViewAll;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantic = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showCount && reviewCount > 0)
          Flexible(
            child: Text(
              l10n.deliveryManProfileReviewsCount(reviewCount),
              style: context.jeebText.bodySmall.copyWith(
                color: semantic.mutedText,
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        _ViewAllButton(
          label: l10n.deliveryManProfileViewAllReviews,
          onTap: onViewAll,
        ),
      ],
    );
  }
}

class _ViewAllButton extends StatelessWidget {
  const _ViewAllButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return JeebCtaButton.accentText(
      key: const Key('delivery-man-profile-view-all'),
      label: label,
      onTap: onTap,
      // Canonical id per JM-067 AC + seam harness W4
      // (`profile_view_all_reviews`); the kit applies it via its own explicit
      // `Semantics` wrapper, so no second wrapper here (two would double the
      // node and break `findsOneWidget`).
      identifier: 'profile_view_all_reviews',
      // The link sits on the gutter, not inside a pill — drop the pill's
      // internal inset so it aligns with the count beside it.
      contentPadding: EdgeInsetsDirectional.zero,
    );
  }
}
