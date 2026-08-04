import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';

/// The pre-auto-offline warning, as the availability strip's subtitle row.
///
/// It used to be a standalone warning-container banner below the card. The
/// board has no second banner here: the warning is one muted line on the navy
/// strip with `Extend` as its last, tappable word.
///
/// The CTA is a real widget (not a `TextSpan`) precisely because it carries a
/// frozen Key and a frozen Semantics identifier, and because a trailing span
/// inside an ellipsizing line would be truncated away on a narrow phone —
/// an invisible, untappable CTA. Being the row's LAST child is also what makes
/// it mirror correctly under RTL.
class InactivityWarningBanner extends StatelessWidget {
  const InactivityWarningBanner({super.key, required this.onExtend});

  static const Key rootKey = Key('availability-inactivity-banner-root');
  static const Key ctaKey = Key('availability-inactivity-banner-cta');

  final VoidCallback onExtend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roles = context.jeebRoles;
    final mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.midnight())
            .mutedText;
    return Row(
      key: rootKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            l10n.availabilityInactivityInlineWarning,
            style: context.jeebText.bodySmall.copyWith(color: mutedInk),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Semantics(
          identifier: 'availability_inactivity_extend_cta',
          container: true,
          button: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ctaKey,
              onTap: onExtend,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.twoXSmall),
                child: Text(
                  l10n.availabilityExtendAction,
                  // R16 draws `Extend` in the strip's own success ink.
                  style: context.jeebText.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: roles.success,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
