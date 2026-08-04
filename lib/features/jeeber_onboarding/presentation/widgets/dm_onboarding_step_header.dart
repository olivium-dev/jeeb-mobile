import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';

/// Heading + supporting line shared by the onboarding steps that have one
/// (photo step 56591:5331/5332, service-area step).
///
/// MIDNIGHT: R5/R6 both draw the intro run as a WHITE `h1` over a periwinkle
/// `body` — the `primary` ink this carried was navy in pass 1 and is `#D73B00`
/// now, i.e. an orange-budget leak on a heading. Both start-aligned so they
/// mirror under RTL.
class DmOnboardingStepHeader extends StatelessWidget {
  const DmOnboardingStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = context.jeebText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.h1.copyWith(color: scheme.onSurface)),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          subtitle,
          style: text.body.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
