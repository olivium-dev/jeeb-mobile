import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Heading + supporting line shared by the onboarding steps that have one
/// (photo step 56591:5331/5332, service-area step). Title is the brand-navy
/// extra-bold headline; subtitle is the light-indigo emphasis tint. Both are
/// start-aligned so they mirror under RTL.
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          subtitle,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ],
    );
  }
}
