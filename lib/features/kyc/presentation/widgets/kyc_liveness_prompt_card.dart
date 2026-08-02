import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../l10n/app_localizations.dart';
import '../../../../core/previews/jeeb_preview.dart';

class KycLivenessPrompt {
  const KycLivenessPrompt({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class KycLivenessPromptCard extends StatelessWidget {
  const KycLivenessPromptCard({
    super.key,
    required this.title,
    required this.prompts,
    this.cardKey,
  });

  final String title;
  final List<KycLivenessPrompt> prompts;

  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.small),
          for (var i = 0; i < prompts.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.xSmall),
            _PromptRow(
              prompt: prompts[i],
              foreground: scheme.onPrimaryContainer,
              textStyle: theme.textTheme.bodyMedium,
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
    required this.textStyle,
  });

  final KycLivenessPrompt prompt;
  final Color foreground;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(prompt.icon, color: foreground, size: Sizes.large),
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The card at its production width: a 390 dp phone minus the
/// `EdgeInsets.all(Spacing.large)` the wizard step wraps its scroll view in.
const Size _kycLivenessPromptCardTwoCueBox = Size(390, 180);
const Size _kycLivenessPromptCardOneCueBox = Size(390, 200);
const Size _kycLivenessPromptCardEmptyBox = Size(390, 130);
const Size _kycLivenessPromptCardWrappingBox = Size(390, 320);
const Size _kycLivenessPromptCardChecklistBox = Size(390, 360);

/// Mounts the card the way `KycIdentityStep` does: 20 dp of screen padding and
/// a **stretching** column, so the card is full-bleed inside that padding.
Widget _kycLivenessPromptCardHosted({
  required String title,
  required List<KycLivenessPrompt> prompts,
}) {
  return Padding(
    padding: const EdgeInsets.all(Spacing.large),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        KycLivenessPromptCard(title: title, prompts: prompts),
      ],
    ),
  );
}

/// Reads the ARB the way the wizard step does, so the AR rendering of a
/// localized state shows real shipping copy.
Widget _kycLivenessPromptCardLocalized(
  Widget Function(AppLocalizations l10n) build,
) =>
    Builder(builder: (BuildContext context) => build(AppLocalizations.of(context)));

/// The state the app actually ships: the two cues `KycIdentityStep` hardcodes,
/// blink then smile, over the ARB title.
@JeebPreview(
  group: 'kyc',
  name: 'Wizard default · blink + smile',
  size: _kycLivenessPromptCardTwoCueBox,
)
Widget kycLivenessPromptCardDefault() => _kycLivenessPromptCardLocalized(
      (AppLocalizations l10n) => _kycLivenessPromptCardHosted(
        title: l10n.kycSelfieLivenessPrompt,
        prompts: <KycLivenessPrompt>[
          KycLivenessPrompt(
            icon: Icons.remove_red_eye_outlined,
            text: l10n.kycSelfieLivenessBlink,
          ),
          KycLivenessPrompt(
            icon: Icons.sentiment_satisfied_alt_rounded,
            text: l10n.kycSelfieLivenessSmile,
          ),
        ],
      ),
    );

/// One cue: the `if (i > 0)` guard on the inter-row gap, exercised at its
/// boundary.
@JeebPreview(
  group: 'kyc',
  name: 'Single cue · no inter-row gap',
  size: _kycLivenessPromptCardOneCueBox,
)
Widget kycLivenessPromptCardSingleCue() => _kycLivenessPromptCardLocalized(
      (AppLocalizations l10n) => _kycLivenessPromptCardHosted(
        title: l10n.kycSelfieLivenessPrompt,
        prompts: <KycLivenessPrompt>[
          KycLivenessPrompt(
            icon: Icons.wb_sunny_outlined,
            text: l10n.kycSelfieStepSubtitle,
          ),
        ],
      ),
    );

/// The empty list. `prompts` is a plain `List` with no `assert` and no
/// non-empty precondition, so this is a shape the type permits and any future
@JeebPreview(
  group: 'kyc',
  name: 'No cues · title only',
  size: _kycLivenessPromptCardEmptyBox,
)
Widget kycLivenessPromptCardEmpty() => _kycLivenessPromptCardLocalized(
      (AppLocalizations l10n) => _kycLivenessPromptCardHosted(
        title: l10n.kycSelfieStepTitle,
        prompts: const <KycLivenessPrompt>[],
      ),
    );

/// The wrapping ceiling: a title that takes two lines and a cue that takes four
/// or five.
@JeebPreview(
  group: 'kyc',
  name: 'Longest plausible copy · multi-line cue',
  size: _kycLivenessPromptCardWrappingBox,
)
Widget kycLivenessPromptCardLongCopy() => _kycLivenessPromptCardHosted(
      title: 'Quick liveness check before your selfie is uploaded for review',
      prompts: const <KycLivenessPrompt>[
        KycLivenessPrompt(
          icon: Icons.remove_red_eye_outlined,
          text: 'Look straight into the camera and blink twice, slowly, keeping '
              'your whole face inside the oval and your glasses off until the '
              'capture button turns solid and the shutter fires on its own.',
        ),
        KycLivenessPrompt(
          icon: Icons.sentiment_satisfied_alt_rounded,
          text: 'Then smile gently, without covering your mouth.',
        ),
      ],
    );

/// Five cues. The list is unbounded and the card has no scroll view of its own,
/// so its height is entirely the caller's to spend — this is what a longer
@JeebPreview(
  group: 'kyc',
  name: 'Extended checklist · five cues',
  size: _kycLivenessPromptCardChecklistBox,
)
Widget kycLivenessPromptCardChecklist() => _kycLivenessPromptCardHosted(
      title: 'Liveness checklist',
      prompts: const <KycLivenessPrompt>[
        KycLivenessPrompt(
          icon: Icons.light_mode_outlined,
          text: 'Find even lighting, with no window behind you.',
        ),
        KycLivenessPrompt(
          icon: Icons.face_retouching_natural_outlined,
          text: 'Take off hats, sunglasses and face coverings.',
        ),
        KycLivenessPrompt(
          icon: Icons.remove_red_eye_outlined,
          text: 'Blink twice while looking at the lens.',
        ),
        KycLivenessPrompt(
          icon: Icons.rotate_right_outlined,
          text: 'Turn your head slowly to the left, then back.',
        ),
        KycLivenessPrompt(
          icon: Icons.sentiment_satisfied_alt_rounded,
          text: 'Finish with a small smile and hold it.',
        ),
      ],
    );
