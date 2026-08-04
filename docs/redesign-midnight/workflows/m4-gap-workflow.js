export const meta = {
  name: 'midnight-m4-gap',
  description: 'M4 gap lane — the 3 feature dirs my hardcoded sweep grouping missed',
  phases: [{ title: 'Gap', detail: 'delivery_status · tier_selection · prohibited_acknowledgment' }],
}
const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'

phase('Gap')
const r = await agent(`You are the M4 GAP lane in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: code comments max 2 lines, only when super necessary.

**Why you exist:** the M4 inventory found non-conforming states in three feature dirs, and the orchestrator (me) fanned the sweep out over a HARDCODED directory list written before reading the inventory — so these three got no lane. That was my mistake, not the inventory's. Your job is to close them.

YOU OWN exactly: lib/features/delivery_status/, lib/features/tier_selection/, lib/features/prohibited_acknowledgment/ and their tests.

The inventory items in your dirs:
- \`delivery_status/presentation/delivery_status_screen.dart:197\` loading — \`OmdsLoadingState(message:)\`
- \`delivery_status/presentation/delivery_status_screen.dart:220\` error — \`OmdsErrorState\` (comment claims "OMDS owns the visual layout")
- \`delivery_status/presentation/widgets/delivery_jeeber_card.dart:57\` loading (awaiting match) — \`OmdsLoadingState\`
- \`tier_selection/presentation/tier_selection_screen.dart:114\` loading — untinted \`OmdsLoadingState\` → **inks colorScheme.primary, which IS brand orange on Midnight**
- \`tier_selection/presentation/tier_selection_screen.dart:117\` error — \`OmdsErrorState\`
- \`prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart:106\` loading — untinted \`OmdsLoadingState\`
- \`prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart:255-272\` \`_ErrorBody\` — bare Text on \`Theme.of(context).textTheme.bodyMedium\` (light-theme residue)

**FIRST, for delivery_status only:** the inventory tagged it *(ORPHAN)*. It is NOT in the ratified ORPHAN list (02-STUDY-NOTES §ORPHAN rulings covers settlement, rating_prompt, the location placeholder, and five KEEPs). So before restyling it, grep for inbound references across lib/, test/ and .maestro/ and report whether it is reachable. **If it is genuinely unreachable, STOP and report it as a NEW orphan candidate with your evidence — do not delete it yourself** (deletions need a ratified ruling), and do not restyle dead code either. If it IS reachable, restyle it.

For the rest: §2.7 — loading = the illustration skeleton breathing, error = the danger-tinted variant, empty = the lit illustration, all through JeebEmptyState. Pick the variant whose SUBJECT matches and say why; do not default to e1. **The kit's \`_skeleton()\` now follows its variant's own geometry** (fixed this wave), so a skeleton no longer paints E1's 4-disc shape for every variant.

Note prohibited_acknowledgment is a DIALOG, not a screen — a full-bleed illustration may be wrong inside it. Use judgement and say what you chose; a compact treatment is legitimate there.

CONSTRAINTS: tokens/kit only; ZERO raw hex, ZERO Colors.* (transparent ok); do NOT modify lib/core/** (FROZEN). Preserve frozen test identifiers by re-homing onto the kit's own \`identifier:\` slot, then delete chrome that existed only to host them. RTL-safe. Missing wire data → designed slot + TODO(midnight): omitted, not faked.
**GREP YOUR DIRS for two known defect signatures:** (a) any \`colorScheme.primary\` on a non-CTA — under Midnight primary IS #D73B00, found on 8+ screens; (b) \`Theme.of(context).extension<...>()!\` — a bang there throws under any theme lacking the extension and cost us 9 latent crashes; use \`?? JeebSemanticColors.midnight()\`.
**Goldens are evidence, NOT gates** (5% tolerance). Land per-element assertions read off the widget and PROVE each discriminates by reverting the value and confirming red.
A state with no catalog entry is invisible to every capture — if one of yours is uncaptured, ADD the catalog state.

VERIFY: flutter analyze --no-pub on your three dirs → 0 errors · targeted tests before/after · re-capture into docs/redesign-midnight/captures/M4/gap/.
RETURN: delivery_status reachability verdict + evidence · items handled · variant per state + why · primary-leaks and extension-bangs fixed · catalog states added · before/after counts · discrimination proof · anything left.`,
  { label: 'gap: 3 missed dirs', phase: 'Gap', model: 'opus' })
return { gap: r }
