import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';

/// Heading + supporting line shared by the onboarding steps that have one
/// (photo step 56591:5331/5332, service-area step).
///
/// Title is `jeebText.h1` (24/w700) in brand navy — the board's screen
/// headline. The supporting line is `jeebText.bodySmall` in the warm
/// `onSurfaceVariant` subtitle ink, **not** periwinkle: `#777FC0` is the muted
/// decorative voice and fails AA as body text on white. Both are start-aligned
/// so they mirror under RTL.
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
        Text(title, style: text.h1.copyWith(color: scheme.primary)),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          subtitle,
          style: text.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
