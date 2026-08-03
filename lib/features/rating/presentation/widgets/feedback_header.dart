import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';

/// Title + audience-aware subtitle block on the feedback screen
/// (Figma 56614:20132). The subtitle swaps between "evaluate the delivery man"
/// and "evaluate the client" depending on who is rating.
///
/// redesign-24: start-aligned, matching the board's opening headline on screen
/// 15 (the identity hero, the prompt and the stars below it stay centred).
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeedbackTitle(text: l10n.feedbackScreenTitle),
        const SizedBox(height: Spacing.xSmall),
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
    // `h2` carries no ink, so the ambient onSurface navy applies — the old
    // `secondaryContainer` foreground was a fill role used as text.
    return Text(text, style: context.jeebText.h2);
  }
}

class _FeedbackSubtitle extends StatelessWidget {
  const _FeedbackSubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `onSurfaceVariant`, NOT the periwinkle `onSecondaryContainer` this used
    // to carry: `color_role_contrast_test` pins periwinkle-on-white as below
    // AA, and this is a two-sentence paragraph, not a metadata line.
    return Text(
      text,
      style: context.jeebText.body.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
