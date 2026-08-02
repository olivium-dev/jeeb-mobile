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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/kyc/kyc_liveness_prompt_card_preview_test.dart
// ===========================================================================
//
// The card is the coaching block above the selfie tile in the KYC wizard
// (`KycIdentityStep`, lines 375-388): a title plus an ordered list of liveness
// cues. It is pure presentation — it takes a `String` and a
// `List<KycLivenessPrompt>` and owns no state — so there is nothing to seed and
// nothing to fake. **No cubit, no repository, no network by construction**; the
// guard in `jeebPreviewHost` never has anything to reject.
//
// **Every state is really a list-length or a string-length.** That is the whole
// contract, and it is where the widget can break: the inter-row gap is emitted
// by an `if (i > 0)` guard, the gap under the title is emitted unconditionally,
// and each cue is an `Icon` + `Expanded(Text)` row with
// `CrossAxisAlignment.start`. So the previews below walk the list from zero to
// five and the copy from one line to four.
//
// **Where the copy comes from.** The production state and the single-cue state
// pull their strings from the ARB (`kycSelfieLiveness*`), so the AR rendering
// of the matrix shows the shipping Arabic copy rather than English sitting in
// an RTL box. The three stress states use fixture copy, because the shapes they
// exercise — an empty list, a four-line cue, a five-item checklist — do not
// exist in the ARB. The empty card's title is deliberately a *different* ARB
// string from the other two so the render test can tell those states apart;
// see the note in `test/previews/kyc/kyc_liveness_prompt_card_preview_test.dart`.
//
// **What to look at.** The card fill is `primaryContainer` at 60% alpha with no
// border and no elevation, which leaves it barely separated from the surface it
// sits on (1.16:1 in light) — the numbers are pinned in the test. Note also
// that the cue icon is a fixed `Sizes.large` (20 dp) and does not grow with the
// text, so the 200% rendering is where the row's optical alignment goes.

/// The card at its production width: a 390 dp phone minus the
/// `EdgeInsets.all(Spacing.large)` the wizard step wraps its scroll view in.
/// Heights are per-state — the card has no intrinsic height, only the one its
/// list length and its line wrapping produce.
const Size _kycLivenessPromptCardTwoCueBox = Size(390, 180);
const Size _kycLivenessPromptCardOneCueBox = Size(390, 200);
const Size _kycLivenessPromptCardEmptyBox = Size(390, 130);
const Size _kycLivenessPromptCardWrappingBox = Size(390, 320);
const Size _kycLivenessPromptCardChecklistBox = Size(390, 360);

/// Mounts the card the way `KycIdentityStep` does: 20 dp of screen padding and
/// a **stretching** column, so the card is full-bleed inside that padding.
///
/// The `mainAxisSize: MainAxisSize.min` is not cosmetic. In the wizard the card
/// lives inside a `SingleChildScrollView`, so its own `Column` is laid out
/// against an unbounded height and shrink-wraps. Dropped straight into the
/// preview host's `Scaffold` it would instead be laid out against a *bounded*
/// height and its `Column` — `MainAxisSize.max` by default — would stretch to
/// fill the canvas, showing a card the app never draws. A `Column` hands its
/// non-flex children unbounded main-axis constraints, so this one restores the
/// production measurement.
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
///
/// This is the only preview whose every string is production copy, so it is the
/// one whose AR rendering is a real review of the Arabic — the other four carry
/// fixture text for shapes the ARB has no string for.
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
///
/// A single-item list must produce a card with NO 8 dp gap in it — an
/// off-by-one in that guard is invisible at two cues (the gap looks intentional)
/// and only shows here, as a card with dead space under its only row.
///
/// The cue is the selfie step's own ARB subtitle, which is long enough to wrap
/// at phone width and longer still in Arabic, so this doubles as the shortest
/// state where `CrossAxisAlignment.start` has a multi-line paragraph to align
/// its icon against.
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
/// caller that builds its cues from a remote liveness spec can hand over.
///
/// The gap under the title is emitted unconditionally, so an empty card is not
/// "title + padding" — it is title + 12 dp of dead space + padding. That is the
/// state to look at here.
///
/// The title is `kycSelfieStepTitle` rather than the liveness title the other
/// two localized states use, purely so the render test can pin a string unique
/// to this preview; a title-only card otherwise renders nothing that tells it
/// apart from its siblings.
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
///
/// Neither `Text` in this widget sets `maxLines` or an `overflow`, so nothing
/// here truncates — the card simply grows, which is safe inside the wizard's
/// scroll view and is what this preview confirms. What it is really for is the
/// icon: with `CrossAxisAlignment.start` the 20 dp glyph pins to the TOP of a
/// multi-line paragraph, and this is the state where that reads as a defect or
/// as intended.
///
/// Fixture copy, not ARB — the shipping cues are one line each. The length is
/// the plausible ceiling for a reviewer-authored liveness instruction.
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
/// server-driven liveness spec would cost the selfie step, which already has a
/// capture tile and a ToS block below it.
///
/// Fixture copy: today's spec is two cues, hardcoded at the call site.
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
