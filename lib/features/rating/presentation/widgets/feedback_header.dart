import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Title + audience-aware subtitle block on the feedback screen
/// (Figma 56614:20132). The subtitle swaps between "evaluate the delivery man"
/// and "evaluate the client" depending on who is rating.
class FeedbackHeader extends StatelessWidget {
  const FeedbackHeader({super.key, required this.isClient});

  final bool isClient;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = isClient
        ? l10n.feedbackScreenSubtitleJeeber
        : l10n.feedbackScreenSubtitleClient;
    return Column(
      children: [
        _FeedbackTitle(text: l10n.feedbackScreenTitle),
        const SizedBox(height: Spacing.small),
        _FeedbackSubtitle(text: subtitle),
      ],
    );
  }
}

class _FeedbackTitle extends StatelessWidget {
  const _FeedbackTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.secondaryContainer,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FeedbackSubtitle extends StatelessWidget {
  const _FeedbackSubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }
}
