import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';

/// Single coaching cue inside a [KycLivenessPromptCard].
class KycLivenessPrompt {
  const KycLivenessPrompt({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

/// Coaching card rendered above the selfie capture tile. Lists the liveness
/// motions the reviewer expects (blink + smile). Pure presentation — the cubit
/// doesn't react to any input here; the actual liveness verification is a
/// server-side check on the captured frame.
class KycLivenessPromptCard extends StatelessWidget {
  const KycLivenessPromptCard({
    super.key,
    required this.title,
    required this.prompts,
    this.cardKey,
  });

  final String title;
  final List<KycLivenessPrompt> prompts;

  /// Optional key forwarded to the outer container so widget tests can find
  /// the card without relying on text content.
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // MIDNIGHT: coaching is never orange, and an opaque navy slab vanishes
    // against the field — this is rest glass, the same surface as the rows it
    // sits under. The board does not draw this card at all.
    final semantic = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    final jeebText = context.jeebText;
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: semantic.glassFill,
        border: Border.all(color: semantic.glassBorder),
        borderRadius: BorderRadius.circular(JeebRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: jeebText.bodySmall.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.small),
          for (var i = 0; i < prompts.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.xSmall),
            _PromptRow(
              prompt: prompts[i],
              foreground: semantic.inkSoft,
              iconColor: semantic.mutedText,
              textStyle: jeebText.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  const _PromptRow({
    required this.prompt,
    required this.foreground,
    required this.iconColor,
    required this.textStyle,
  });

  final KycLivenessPrompt prompt;
  final Color foreground;
  final Color iconColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(prompt.icon, color: iconColor, size: Sizes.large),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Text(
            prompt.text,
            style: textStyle?.copyWith(color: foreground),
          ),
        ),
      ],
    );
  }
}
