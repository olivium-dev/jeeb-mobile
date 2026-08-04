export const meta = {
  name: 'midnight-glow-anchor-fixup',
  description: 'Add JeebFieldGlowPlacement.topStart, adopt on R4/R9/R17, and tint both R16 banner twins',
  phases: [
    { title: 'Kit+Banner', detail: 'glow anchor · R16 banner pair tint' },
    { title: 'Adopt', detail: 'R4 wallet · R9 request type · R17 composer' },
  ],
}

const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'
const TILES = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens'
const BOARD = '/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/Jeeb Rich UI.dc.html'

const COMMON = `
Repo ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch — leave changes in the working tree.
GOLDEN RULE (user mandate): code comments max 2 lines, only when super necessary.
Read 02-STUDY-NOTES.md section "Wave-C FIXUP outcomes + round-4 rulings" FIRST — it authorises this work.
STANDING RULE from that section: **goldens are evidence, not gates.** Our comparator tolerates 5% pixel diff, so a token re-point on a small element passes a golden unchanged (an R18 ink swap moved 0.097% and three goldens stayed green carrying the wrong ink). You must land a per-element assertion that reads the actual colour/geometry off the widget. Do NOT cite a green golden as proof your change took.
PROVE every new test discriminates: revert the value, confirm the test goes red, restore.
Analyze baseline: 0 errors / 30 known infos. Known-red and NOT yours: test/features/chat/chat_header_contrast_test.dart (5 pre-existing, Q-022).
Touch ONLY your files. If an error appears in a file that is not yours, re-run ONCE; report only if it reproduces.
RETURN: what changed per file · exact signatures · before/after test counts · discrimination proof · what you could not close.`

const KIT_GLOW = `YOU OWN lib/core/widgets/jeeb/jeeb_midnight_field.dart and test/core/widgets/jeeb/jeeb_midnight_field_test.dart.

Add **\`JeebFieldGlowPlacement.topStart\`**. This is sanctioned and it fixes three live screens.
Background: the existing \`JeebFieldWashPlacement.topStart\` (added last round) paints \`JeebMidnight.periwinkleWash\` unconditionally — it is a WASH anchor. R4/R9/R17 draw an orange **GLOW** top-start and declare zero periwinkle, so they cannot use it. What is missing is the *glow* twin.

Measure it yourself from ${BOARD} (canvas 440x956; the two lengths before \`at\` in a radial-gradient are RADII). The three declarations are:
  R4  wallet       line ~258  \`560px 420px at 20% -8%, rgba(215,59,0,.26)\`
  R9  request type line ~520  \`500px 420px at 10% -8%, rgba(215,59,0,.24)\`
  R17 composer     line ~1016 \`500px 400px at 12% -8%, rgba(215,59,0,.24)\`
Expected anchor ≈ (0.12, -0.08) — but derive it and say what you actually used. Note fy is NEGATIVE (above the canvas); an earlier ruling of mine had the sign wrong, so do not trust a positive fy. Mirror the existing \`topEnd\` entry's construction and keep enum indices stable by APPENDING.
Existing callers must not move: \`topEnd\`, \`centerUpper\` and \`bottom\` keep their values and remain the defaults they are today.

Also, one hardening task: the previous lane found its own first anchor test asserted only WHICH CORNER blooms, so it still passed with the anchor 9 points out of place. Make your new test assert the falloff, not just the corner.
VERIFY: flutter analyze --no-pub lib/core → 0 errors · flutter test test/core/widgets/jeeb test/core/theme → all green (783 + 634 territory before this wave).`

const BANNER_TINT = `YOU OWN lib/features/jeeber_active_deliveries/ and lib/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart, plus their tests.

R16's accent-framed active-delivery banner must take the round-4 orange tint at **BOTH** call sites:
  1. lib/features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart:221 — the banner a registered jeeber ACTUALLY sees (injected by shell/tabs/dashboard_tab.dart:147).
  2. lib/features/jeeber_home/presentation/widgets/jeeber_active_deliveries_banner.dart:135 — the \`??\` fallback, reached only when unregistered.
The exact patch at each site is one named argument: \`fill: JeebAccentFrameFill.accentTint\` (confirm the enum's real name in lib/core/widgets/jeeb/jeeb_accent_frame_card.dart before using it — read the source; a sibling lane added it last round).
Board evidence: R21's in-motion row measures orange 10-12% inside the frame; \`accentTint\` (.12) is inside the board's frame-fill range [.08,.16] while \`accentSelected\` (.20) is outside every one of them. Tile: ${TILES}/16-r16-jeeber-home.png.

Tinting only ONE of the pair is a rejected outcome: the fallback's own doc says it is "kept visually identical to the shell-injected banner (W-3) so this \`??\` fallback cannot drift away from the surface the jeeber actually sees."
**That identity is currently guarded by a source comment and NOTHING ELSE.** Add a test that actually pins the pair — assert the two banners resolve the same frame fill / surface treatment, so a future one-sided edit fails.
VERIFY: flutter analyze --no-pub lib/features/jeeber_active_deliveries lib/features/jeeber_home → 0 errors · flutter test test/features/jeeber_home test/features/shell test/jeeber_home_screen_test.dart → green, before/after counts · re-capture jeeber-home if the visible banner changed: --plain-name "jeeber-home__" --tags capture, PNGs to docs/redesign-midnight/captures/M2-12-r16-e3/.`

phase('Kit+Banner')
const p1 = await parallel([
  () => agent(`${KIT_GLOW}\n${COMMON}`, { label: 'kit:glow-topStart', phase: 'Kit+Banner', model: 'opus' }),
  () => agent(`${BANNER_TINT}\n${COMMON}`, { label: 'fix:R16-banner-pair', phase: 'Kit+Banner', model: 'opus' }),
])

const glowApi = p1[0] || '(glow lane returned nothing — read jeeb_midnight_field.dart before adopting)'

phase('Adopt')
const p2 = await agent(`YOU OWN lib/features/wallet/, lib/features/request_type/, lib/features/offers/ and their tests.
Adopt the new \`JeebFieldGlowPlacement.topStart\` on the three screens whose tiles draw an orange glow top-start. All three are CURRENTLY WRONG:
- **R9 request type** (${TILES}/09-r9-request-type.png) — \`request_type_screen.dart:130\` draws \`glowPlacement: bottom\` (0.50, 0.94), the OPPOSITE end of the screen. Its tile declares exactly one radial, top-start, and its bottom band measures flat navy. This is the worst of the three.
- **R17 offer composer** (${TILES}/17-r17-offer-composer.png) — \`offer_submission_screen.dart:306\`, currently at the hero default \`topEnd\`, i.e. mirrored.
- **R4 wallet** (${TILES}/04-r4-wallet.png) — \`wallet_hub_screen.dart:157\`, also mirrored. NOTE R4 additionally declares a SECOND radial: periwinkle at \`110% 65%\` (end-side, mid-height) — that is not top-start and is not what you are fixing; leave its wash placement alone unless you can measure a better ratified anchor, and say what you decided.
MEASURE each tile before changing it and report the measured anchor + the alpha, the same way the R14 lane did (a per-channel fit against the candidate ink beats an eyeball). Change only what your measurement supports.
Do not re-open anything else on these screens — M2-04, M2-13 and M2-18 are committed and accepted.

Kit lane report for the new anchor:
--- GLOW LANE ---
${glowApi}
--- END ---

GOLDEN RULE: comments max 2 lines, only when super necessary. NEVER run git commit/checkout/stash/branch. Do NOT modify lib/core/** — it is re-frozen. Tokens/kit only, zero raw hex, RTL-safe.
STANDING RULE: goldens tolerate 5% pixel diff, so they will NOT catch this — land a per-element assertion reading the resolved glow placement off the widget, and prove it discriminates by reverting.
VERIFY: flutter analyze --no-pub on your three dirs → 0 errors · flutter test test/features/wallet test/features/request_type test/features/offers → green, before/after · re-capture each changed screen (--plain-name per screen, --tags capture) and copy PNGs into the matching docs/redesign-midnight/captures/ dir.
RETURN: measured anchor per tile · what changed · before/after counts · discrimination proof · anything left.`,
  { label: 'adopt:R4+R9+R17-glow', phase: 'Adopt', model: 'opus' })

return { kitGlow: p1[0], bannerPair: p1[1], adoptGlow: p2 }
