# Redesign 2026-08 — Migration Plan (the spine document)

Branch: `feat/redesign-24-migration` (already checked out — never create/switch branches, never commit/push).
Spec: `docs/redesign-2026-08/screens/NN-slug.{png,html,note.md}` + `_ds/tokens/*` + `_ds/readme.md`.
Audience: every per-screen agent. Act from this document; do not re-derive decisions made here.

**Read `02-PLAN-ENHANCED.md` alongside this.** It carries the measured visual-language rules (R1–R14)
derived from the renders themselves — density, the five pill scales, the ink ranking, where orange is
allowed — plus the per-screen conflict findings. This document has been corrected against it;
02 is the evidence and the detail.

---

## 🛑 STOP — three things that override your prompt

**1. THE FILE PATH IN YOUR PROMPT MAY BE WRONG.** The source map (`github.md`) points three of its 24
entries at files the app does not run, and those errors were copied into the agent prompts. Before
your first edit, check your screen against **`screen-repo-map.md`** — it is corrected and it wins.

| # | Prompt says (WRONG) | Actually edit |
|---|---|---|
| **08** Tier catalog | `tier_selection/…/tier_selection_screen.dart` — **dead code**, devtool-only importer | `request_type/…/request_type_screen.dart` (the live tier picker is a section of it) |
| **09** Location picker | `location/…/location_picker_screen.dart` — **devtool-only copy**; the one at `/location` is a 36-LOC "coming soon" placeholder | `location/…/client_location_screen.dart` **+** `location/…/capture_location_screen.dart` |
| **21** Order chat | `chat/…/chat_screen.dart` alone | `deep_link_targets/chat_detail_screen.dart` (the `/chat/:id` container) **+** `chat/…/chat_screen.dart` |

Sanity rule: **confirm your file is reachable from `lib/main.dart` before editing it.** A class-name
grep is not enough — `LocationPickerScreen` and `OnboardingScreen` are each declared in two files.

**2. THE BASELINE IN YOUR PROMPT IS SUPERSEDED.** See `_BASELINE.md`. Current: `flutter analyze` =
**5 issues, 0 errors** (not 11/6). `flutter test` = **−4**, not −155. All four remaining failures are
pre-existing and named there; three are red on `main` in CI too, and two of those sit inside
migration-scope screens (11 and 15). **Do not fix them and do not count them as your damage.**

**3. WAVE 0 IS ALREADY DONE — do not create theme tokens.** `context.jeebText` (16 styles),
`JeebShadows` (11 static consts), the `jeebRoles` accent quartet and 4 new semantic colors all exist.
Exact names and usage in **§4.6**. Inventing a parallel constant, or hardcoding a hex where one of
these exists, is a review defect.

**4. WAVE 1 IS ALSO DONE — the kit EXISTS. Import it; do not inline it.**
`lib/core/widgets/jeeb/` now holds **31 files / 32 widgets**, all 28 §5 rows, with 38 test files
(476 tests green, 0 raw hex literals, 0 RTL hazards). **Full API reference: `03-WAVE1-KIT.md`.**

⚠️ **Your revised instruction set may be out of date on this point.** Several were written while the
kit was still empty and tell you to *"build inline in this file as a private widget to the kit spec
and swap it in a later sweep"* — some even assert *"`lib/core/widgets/jeeb/` is empty today"*.
**That is no longer true and that instruction is void.** Import the real widget. Hand-rolling a
private copy of a kit widget is now a review defect — one agent already had three such copies
(`jeeb_cta_button.dart`, `jeeb_top_bar.dart`, `jeeb_tier_row.dart`) deleted from its feature
directory for exactly this reason.

Available: `JeebOutlinedCard` `JeebNavySurfaceCard` `JeebAccentFrameCard` `JeebSurfaceTone` ·
`JeebCtaButton` `JeebCtaFooter` · `JeebSelectChip` `JeebChipRow` `JeebTierChip` `JeebSystemChip`
`JeebStepperPill` `JeebPageDots` · `JeebTopBar` `JeebProfileHeader` · `JeebAvatar` `JeebAvatarStack` ·
`JeebSectionLabel` `JeebMeter` `JeebPriceMeter` · `JeebWaveform` `JeebMicHero` · `JeebStepper` ·
`JeebChatBubble` `JeebChatComposer` `JeebQuickReplyRow` · `JeebMoneyBreakdown` `JeebListRow` ·
`JeebCodeCells` `JeebNumericKeypad` · `JeebTierRow` `JeebInfoNote` `JeebSegmentedToggle`.

**Two API renames** landed in the audit for kit-wide consistency — screen 20 in particular:
`JeebListRow.enabled` → **`isEnabled`**, `JeebListRow.contentPadding` → **`padding`**.

**Zero new screen files are needed** — all 24 designed screens have a real implementation. And
**never build `L1 Log in` / `L2 Sign up`**: that funnel was removed in JEBV4-199 (Q-044 RATIFIED).

---

## 1. Goal

We are migrating the shipped Flutter app (Material 3 + OMDS + `lib/core/theme`, functional but
visually inconsistent — 8px chips next to pill buttons, peach selected-states, an unset error
family rendering legacy `#B00020` slabs) to the Jeeb redesign: navy-led, orange-rationed,
outline-over-shadow, pill-dominant, voice-first. Two decisions are already made by the owner and
are not open for relitigation: **(a)** the **base 24-screen redesign board**
(`Jeeb App Redesign.dc.html`, extracted to `docs/redesign-2026-08/screens/`) **is the spec** — the
"Midnight" Rich UI board is reference only, NOT the target; **(b)** depth is **full** — including
new screens and new routes where the design requires them, not a reskin. The palette is *not*
changing (the redesign tokens are a verbatim copy of `app_theme.dart` — verified byte-for-byte,
including all five tier colors); what changes is shape, type weight, elevation, component
structure, and a substantial amount of new in-screen functionality. Everything lands inside
`jeeb-mobile` — **nothing is added to OMDS** (CI checks out OMDS fresh from GitHub; local edits
there never reach CI).

---

## 2. Current state (honest picture)

Three-layer color stack, all real, unevenly used:

1. **Flutter M3 `ColorScheme`** — source of truth. Light is hand-written
   (`app_theme.dart:115-143`): `primary #0B1351` navy, `tertiary #D73B00` orange,
   `onSurface #0B0E53` ink, `onSecondaryContainer #777FC0` periwinkle, `outline #916F66` brown,
   `onSurfaceVariant #5C4038`, surfaces `#FAF8FA/#F5F3F6/#EAE7EB/#E5E1E5`.
   **Dark is `ColorScheme.fromSeed(navy)`** — no brand orange in dark at all, and
   `themeMode: ThemeMode.system` ships it.
2. **OMDS** (`../omds-flutter/omds_library`, path dep; CI pulls its `main` from GitHub).
   Owns `useMaterial3: true` and the component-theme baseline (stadium buttons, 12px cards,
   `OmdsColorTokens` for inputs/stars). 228 of 771 files import it; heavy on
   `Spacing`/`OmdsPrimaryButton`/`OMDSAppBar`; zero adoption of its card/chat/stat primitives.
   **No outlined-card primitive and no bottom-nav primitive exist** — the shell hand-rolls
   `_JeebBottomBar` (`shell_screen.dart:356-387`); `AppTheme.navigationBarTheme` is dead code.
3. **Jeeb extensions** — `JeebColorRoles` (contrast-gated success `#1B7A3D` / warning `#8A5A00` /
   info `#1D4ED8`, used in ~20 files), `JeebTierColors` (the 5-tier spectrum, used in only 2
   widgets), `JeebSemanticColors` (registered but dead — one field, `mutedText`).

Screens are **token-clean** (zero `Color(0x…)` literals in all 24 target screens) but
**shape-poor and widget-heavy**: styling lives in per-feature `presentation/widgets/` trees, not
in the screen files (chat_screen.dart has zero `Theme.of(context)` calls). Typography is bundled
Inter applied family-only — sizes/weights are stock `Typography.material2021`; every bold navy
headline today is an ad-hoc `copyWith(fontWeight)`.

**Known live defects this migration fixes deliberately:** `error`/`errorContainer` are unset, so
`errorContainer` falls through to solid `#B00020` with white ink at 12+18 call sites; the
`chipTheme` shape is an 8px rect while `OmdsChip` internally defaults to pill (the two disagree
today).

**Known trap — RESOLVED 2026-08-03, this paragraph is superseded.** The local OMDS clone *was* stale
(branch `iter5-flutter-blankscreen` @ b445bb4, 2026-06-21), missing the `identifier:` param CI's OMDS
has. It has since been fast-forwarded to `origin/main` @ `6f9c166`, and the local `dio` lock was
re-resolved 5.9.2 → 5.11.0. Do NOT edit OMDS and do NOT treat this as part of the diff (both changes
are outside the repo or gitignored).

**The analyze/test baseline in your prompt is therefore SUPERSEDED. Use these numbers instead:**

| | Old (stale env) | **Current — use this** |
|---|---|---|
| `flutter analyze` | 11 issues, 6 errors | **5 issues, 0 errors** (5 `containsSemantics` deprecation infos, local-Flutter-3.44-only, CI never sees them) |
| `flutter test` | −155 failures | **see `_BASELINE.md`** — the ~155 were compile-load failures, now cleared |

Pre-existing failures that are **red on `main` in CI** and are NOT this migration's to fix:
`client_offers_screen_test`, `mutual_rating_tag_chips_l10n_test`, `jeeber_feed_card_test`.
Two of those sit in migration-scope features (screens 11 and 15) — do not "fix" them, and do not
count them as regressions.

---

## 3. Target state

The Jeeb design system as `_ds/readme.md` + tokens define it, with the screens (not the token
files) as pixel truth where they disagree:

- **Navy is the brand** — selected/active fills, primary CTAs, headlines, hero "answer" cards.
  **Orange marks what is happening or expiring right now** — a live dot, a countdown, the mic, the
  active stepper node, the courier marker, a micro badge, the 2px accent frame, the 30% decorative
  ring. It is never chrome and never a container. **Corrected from the renders:** orange *is*
  permitted as a CTA fill exactly once per surface, on the one action that decays — 16's
  `Make offer` on the freshest feed card is a solid orange pill with an orange glow, while the
  older card gets the outline treatment. 18 of 24 screens carry an orange fill (04 carries seven).
  Periwinkle is the muted voice; warm brown `#916F66` is the default 1.5px card outline.
- **Shape:** pills everywhere (999px — 218 of ~300 radius declarations), cards 16–20px,
  outline-over-shadow. Shadows exist only on promoted navy/orange surfaces — **a white card with a
  shadow does not exist anywhere on this board.**
- **Type:** Inter, weight ramp 500→800 (400 never appears in the screens; 800 appears 54×).
  **Weight carries the hierarchy; size barely moves** — almost everything is 10–15.5px, and only
  four things on the spine exceed 20px (title 20, price 21, balance ~42, code display). Do not
  "make it bigger"; make it heavier and darker. Three inks, strictly ranked and often in one row:
  navy = the fact, periwinkle = its qualifier, brown = a secondary interactive word.
- **Structure:** every screen is a top-aligned column, `flex:1` spacer, docked footer (CTA pill or
  5-tab bar); 24px gutters; top app bar = 40px circle back button + title, in-body. **The spacer is
  real emptiness** — on 04, 08, 11, 12, 16, 17 and 23 the bottom 35–45% of the screen is plain
  white. Never fill it, never vertically centre, never let a list expand into it. The redesign is a
  **low-density** design and today's app is high-density; this is the single largest perceptual
  change on the board and it is stated in none of the designer notes.
- **Voice-first:** mic hero + waveform as the signature marks; bilingual AR/EN pairing; honest
  state copy ("released if you're not picked", "cash never passes through Jeeb").
- Roughly a third of the board is **new functionality** (reach counts, live fee math, per-word
  transcript correction, Jeeb-it-again…) — governed by the data-gap policy in §7.6. Note the
  offer-window countdown and the jeeber Extend action have since been **verified buildable today**
  (§7.6).

The measured rules behind these bullets — the five distinct pill scales, the ink ranking, avatar and
badge treatment, list rhythm, how the navy hero behaves — are written out as R1–R14 in
`02-PLAN-ENHANCED.md` §2. Lanes should read that section before laying out a screen.

Mock chrome that must NOT be built: the 440×956 device frame, 40px frame radius, `scale(0.55)`,
and the `9:41` status row. Dark mode is explicitly **out of scope** for visual redesign (§9).

---

## 4. The token bridge

This is the law. Downstream agents follow it literally. Homes, by name:

- **Existing M3 roles** stay in `lib/core/theme/app_theme.dart` (only the error family is added).
- **Brand-orange accessor + semantic roles** → `lib/core/theme/jeeb_color_roles.dart`
  (contrast-gated by `test/core/theme/color_role_contrast_test.dart`).
- **Decorative non-text tokens** → `lib/core/theme/jeeb_semantic_colors.dart` (revive the dead
  extension; NOT contrast-gated; never use these as body-text ink).
- **Type ramp** → NEW `lib/core/theme/jeeb_text_styles.dart` (a `ThemeExtension<JeebTextStyles>`,
  registered in `AppTheme._build`, accessor `context.jeebText`). The M3 `TextTheme` is NOT
  globally reshaped — zero drift for existing consumers.
- **Shadows/rings** → NEW `lib/core/theme/jeeb_shadows.dart` (static consts, no extension —
  values are brightness-independent in the light-only spec).
- **Star color** → `OmdsColorTokens` override at the provider (`lib/app/app.dart:616`).

### 4.1 Color bridge (`_ds/tokens/colors.css` → Dart)

| CSS token | Value | Dart destination | Action |
|---|---|---|---|
| `--jeeb-navy` | `#0B1351` | `colorScheme.primary` (also `secondary`, `secondaryContainer`) | exists — none |
| `--jeeb-ink` | `#0B0E53` | `colorScheme.onSurface` | exists — none |
| `--jeeb-orange` | `#D73B00` | `colorScheme.tertiary`; **NEW `JeebColorRoles.accent`** for the 18 gate-listed files (see §7.3) | **ADD** `accent #D73B00`, `onAccent #FFFFFF` (4.66:1 ✓), `accentContainer #FFDBD1`, `onAccentContainer #3A0B01` to `jeeb_color_roles.dart` + pairs to the contrast test |
| `--jeeb-white` | `#FFFFFF` | `colorScheme.surface` / `onPrimary` | exists — none |
| `--jeeb-periwinkle` | `#777FC0` | `colorScheme.onSecondaryContainer`; `JeebSemanticColors.mutedText` | exists — none. NEVER body text on white (a contrast test asserts it fails AA — that guard stays) |
| `--jeeb-brown-outline` | `#916F66` | `colorScheme.outline` | exists — none. This IS the 1.5px card border |
| `--jeeb-brown-subtitle` | `#5C4038` | `colorScheme.onSurfaceVariant` | exists — none |
| `--jeeb-surface-high` | `#EAE7EB` | `colorScheme.surfaceContainerHigh` | exists — fields, chips, keypad cells, incoming bubbles, back circles |
| `--jeeb-surface-highest` | `#E5E1E5` | `colorScheme.surfaceContainerHighest` (fills) / `outlineVariant` (1px dividers) | exists — none |
| `--jeeb-surface-muted` | `#F4F4F6` | **NEW `JeebSemanticColors.mutedSurface`** | **ADD** (light `#F4F4F6`; dark = dark scheme `surfaceContainerHigh`) |
| `--jeeb-tier-*` (5) | `#E53935 #FB8C00 #1E88E5 #43A047 #7CB342` | `JeebTierColors.standard()` | exists byte-for-byte — none |
| `--jeeb-success` | `#43A047` | **REFUSE as semantic.** Use `jeebRoles.success #1B7A3D` | none — the CSS trio is the tier palette reused; adopting it breaks the WCAG gate |
| `--jeeb-warning` | `#FB8C00` | **REFUSE.** `jeebRoles.warning #8A5A00` | none |
| `--jeeb-danger` | `#E53935` | **REFUSE.** `colorScheme.error` | none |
| `--jeeb-star` | `#FFC107` | `OmdsColorTokens.starRatingColor` | **ADD** override in `app.dart:616`: `OmdsColorTokensProvider(tokens: OmdsColorTokens(starRatingColor: Color(0xFFFFC107)), …)`. Hand-rolled stars must read `context.omdsColorTokens.starRatingColor` — never a literal. **Do NOT tint every ★:** the yellow appears on only 3 screens (11 ×3, 12 ×1, 15 ×1) — where a *specific person's rating drives a decision*. On 01, 16, 19, 21 and 24 the ★ is an unstyled glyph inheriting the surrounding periwinkle/navy ink. Tinting them all is a visible regression |
| `--jeeb-cyan-check` | `#20F0FF` | `JeebSemanticColors.readTick` — **shipped in Wave 0 but has NO consumer** | ⚠️ **DO NOT USE.** Measured: `#20F0FF` / `--jeeb-cyan-check` appears **zero times across all 24 screens**. It is a token-file leftover. Screen 21's read state is the literal text `9:25 · Read` at 10/w600 **periwinkle** inside the outgoing bubble's meta line. The token has already landed — leave it (churning Wave 0 costs more than it saves) but no lane may consume it, and `JeebChatBubble` renders the text form |
| presence green (screens) | `rgb(59,178,115)` | `jeebRoles.success` | map — sprint-009 §G2 forbids ad-hoc greens for presence; do NOT add `#3BB273` |
| positive tint (23) | `rgb(234,244,236)` | `jeebRoles.successContainer` | map |
| KYC quality green (22) | `rgb(46,125,50)` | `jeebRoles.success` | map |
| orange 12% tint (badges) | `rgba(215,59,0,.12)` | `JeebSemanticColors.accentTint` | Keep — but **it is not a badge family.** Measured: exactly **one** occurrence board-wide (07's "Most picked"). The dominant badge is the opposite treatment: **solid `--jeeb-orange` fill + white w800 ink** (08 `Recommended` 10/w800 pad `2/8`; 11 `Best value` 10.5/w800 pad `3/10`). Use `accentTint` only for 07 |
| orange 30% ring (hero décor) | `rgba(215,59,0,.30)` | **NEW `JeebSemanticColors.accentRing`** | **ADD** |
| error family | — | `ColorScheme.light(...)` in `app_theme.dart` | **ADD** `error: #B00020` (explicit — no visual change at 47 `.error` sites), `onError: #FFFFFF`, `errorContainer: #FFDAD6`, `onErrorContainer: #410002`. This intentionally re-tints 12+18 existing call sites from red-slab to soft tint — the desired outcome. Verify `color_role_contrast_test` still passes |

Not tokens: the fake map fill `#EDEDF2` (real map tiles are used), the `#E02020` destination pin
(existing marker assets), device-frame chrome.

### 4.2 Typography bridge → `lib/core/theme/jeeb_text_styles.dart` (NEW)

The screens, not `typography.css`, are the truth (the CSS ramp 12–28/400–700 does not match a
single screen; realized weights are 500–800, 400 never). All fields are Inter with explicit
`fontWeight` + `fontSize`; features may NOT write `fontSize:` literals
(`tool/check_design_tokens.sh` bans it in `lib/features`) — they read `context.jeebText.*`.

| Field | Spec | Used for |
|---|---|---|
| `statHero` | 38 / w800 / ls −1.0 | navy hero numbers (19, 23) |
| `statDisplay` | 42 / w800 | OTP display tiles (13) |
| `h1` | 24 / w700 | screen headlines |
| `h2` | 20 / w700 | top-bar titles, card headlines |
| `titleProminent` | 17 / w700 | two-line bar titles, statement lines |
| `cardTitle` | 15.5 / w700 | offer/tier card names |
| `body` | 13.5 / w500 / height 19px | bubbles, body copy |
| `bodySmall` | 12 / w600 | subtitles, meta rows |
| `caption` | 11.5 / w600 | ETA/cash lines |
| `label` | 10.5 / w700 | stepper labels, meter captions |
| `badge` | 10.5 / w800 | Best value, Most picked, VOICE REQUEST tab |
| `sectionLabel` | 11 / w700 / ls +1.2 | UPPERCASE section headers (uppercase applied at call site), color `mutedText`. ⚠️ **11px is the MINORITY reading** — see the correction below |
| `price` | 21 / w800 | offer prices |
| `button` | 17 / w600 | CTA pills |
| `keypadDigit` | 23 / w700 | in-screen keypad |
| `codeInput` | 29 / w800 | OTP entry cells |

**Corrections measured from the renders (Wave-1 owner applies these; Wave 0 stays closed):**

| Correction | Evidence | Action |
|---|---|---|
| `sectionLabel` shipped at **11px**, but 8 of the 9 realized labels are **12.5–13px** | 11px on 05 only; 12.5px on 19/20/23; 13px on 15/17/19 — all w700 / ls 1.2 / uppercase / periwinkle | `JeebSectionLabel` (§5 #10) defaults to a **12.5** override and exposes a `small` flag that uses the shipped 11px token. Do not reopen `jeeb_text_styles.dart` |
| The section label has an **inline non-uppercase hint** | 17: `PICKUP ETA` + `· Flash allows ≤ 60 min` (`text-transform: none`, `letter-spacing: 0`, w600) in the same line | `JeebSectionLabel` takes a `hint` slot — never a second `Text` beside it |
| No ramp entry for a **money input** | 17's price field: `$` 24/w800 periwinkle + `8.00` 26/w800 navy. `statHero` (38) and `price` (21) both miss | Kit-local const inside `JeebMoneyField`; `lib/core/widgets/jeeb/` is exempt from the `fontSize:` ban (§4.4) |
| Pill label sizes are **not one size** | filter 14.5/w600 · sort 12.5/w600–700 · choice 13.5/w600 · quick-reply 12/w600 · inline action 13/w600 · meta chip 12/w700 · micro badge 10–10.5/w800 | Baked into `JeebSelectChip`'s size enum (§5 #6). Lanes pass a role, never a size |

**Font asset decision:** bundle `Inter-ExtraBold.ttf` (w800, OFL-licensed) — one `pubspec.yaml`
`fonts:` entry under the existing Inter family. This is an asset, not a dependency; constraint 3
is about packages. Without it, w800 silently snaps to w700. Owned by the Wave-0 agent only.
**Arabic display face (Baloo Bhaijaan 2): NOT bundled** — the DS readme itself flags it as a
licensing placeholder. AR headlines render in Inter/system Arabic fallback; divergence accepted
(§9).

### 4.3 Spacing bridge (`spacing.css` → OMDS `Spacing`, exists — no new constants)

| CSS | px | Dart |
|---|---|---|
| `--space-1..3` | 4 / 8 / 12 | `Spacing.twoXSmall` / `Spacing.xSmall` / `Spacing.small` |
| `--space-4..6` | 16 / 20 / 24 | `Spacing.medium` / `Spacing.large` / `Spacing.xLarge` |
| `--space-7` | 28 | no token, and the "28px rhythm" claim is wrong anyway — measured gaps are 9–22px; use `small`–`large` |
| `--space-8..10` | 32 / 40 / 48 | `Spacing.twoXLarge` / `Spacing.threeXLarge` / `Spacing.fourXLarge` |
| `--screen-gutter` | 24 | `EdgeInsetsDirectional.symmetric(horizontal: Spacing.xLarge)` on every redesigned body |

### 4.4 Radius bridge

Rule of two tiers: **shared kit widgets** (`lib/core/widgets/jeeb/`, §5) may use design-exact px
internally (the token script only scans `lib/features`); **feature files** use the nearest
`OmdsBorderRadius` token:

| Design px | Feature-level token | Notes |
|---|---|---|
| 999 (pill) | `OmdsBorderRadius.pill` (100) | dominant shape — 218 uses |
| 24 | `.xLarge` | mic hero container |
| 20 | `.large` | hero cards, map clip, code display tiles |
| 18 | `.large` (20) at feature level; exact 18 inside kit widgets | offer cards, capture rows |
| 16 | `.medium` | default card/cell radius |
| 14 | `.medium` (16) at feature level; exact inside kit | countdown strip |
| 12 | `.small` | at-door code cells |
| 8–9 | `.xSmall` (8) | meters, connectors, bars |
| chat bubble `18 18 18 6` / `18 18 6 18` | built once inside `JeebChatBubble` with `BorderRadiusDirectional` | never re-derived per screen |

**Theme change (Wave 0):** `chipTheme.shape` flips from 8px rect to `StadiumBorder()` in
`app_theme.dart` — deliberate global alignment with `OmdsChip`'s own pill default; visually QA
the 33 chip sites in the Wave-5 sweep.

### 4.5 Elevation bridge → `lib/core/theme/jeeb_shadows.dart` (NEW, static consts)

Both the token-file values and the realized screen values (screens win where they conflict):

| Const | Value | Used on |
|---|---|---|
| `JeebShadows.card` | `0 1 3 rgba(11,19,81,.06)` + `0 1 2 rgba(11,19,81,.04)` | rare resting cards |
| `JeebShadows.raised` | `0 4 16 rgba(11,19,81,.10)` | sheets-adjacent raised bits |
| `JeebShadows.sheet` | `0 −4 24 rgba(11,19,81,.08)` | bottom sheets |
| `JeebShadows.fab` | `0 6 20 rgba(11,19,81,.28)` | floating actions |
| `JeebShadows.ctaNavy` | `0 10 24 rgba(11,19,81,.28)` | primary CTA pill, promoted navy cards |
| `JeebShadows.heroNavy` | `0 12 28 rgba(11,19,81,.30)` | stat hero cards (19, 23), code display tiles (13) |
| `JeebShadows.bubbleOut` | `0 6 16 rgba(11,19,81,.20)` | outgoing chat bubble |
| `JeebShadows.floatPill` | `0 6 16 rgba(11,19,81,.18)` | floating ETA pill on map |
| `JeebShadows.accentBanner` | `0 10 24 rgba(215,59,0,.35)` | at-door arrival banner (13) |
| `JeebShadows.stepGlow` | `0 0 0 5 rgba(215,59,0,.18)` | active stepper node halo |
| `JeebShadows.focusRing` | `0 0 0 3 rgba(119,127,192,.35)` | focused inputs |

Mic-glow ring stacks (three size-dependent variants) are parameters of `JeebMicHero`, not tokens.
**Everything else stays flat** — outlined cards carry NO shadow, ever.

---

### 4.6 ✅ WAVE 0 IS ALREADY DONE — use these exact symbols

**Do not create theme tokens. They exist.** Wave 0 shipped on this branch on 2026-08-03; full detail
in `03-WAVE0-FOUNDATION.md`. Every symbol below is live — use it verbatim. Inventing a parallel
constant, or hardcoding a hex where one of these exists, is a review defect.

**`context.jeebText`** → `lib/core/theme/jeeb_text_styles.dart` (16 `TextStyle` fields, Inter,
color-free except `sectionLabel`):
`statHero` 38/w800 · `statDisplay` 42/w800 · `h1` 24/w700 · `h2` 20/w700 · `titleProminent` 17/w700 ·
`cardTitle` 15.5/w700 · `body` 13.5/w500 · `bodySmall` 12/w600 · `caption` 11.5/w600 · `label` 10.5/w700 ·
`badge` 10.5/w800 · `sectionLabel` 11/w700/+1.2 · `price` 21/w800 · `button` 17/w600 ·
`keypadDigit` 23/w700 · `codeInput` 29/w800

```dart
Text(l10n.chooseYourRequest, style: context.jeebText.h2)
```

**`JeebShadows`** → `lib/core/theme/jeeb_shadows.dart`. **Static consts, NOT a ThemeExtension** — no
`context` needed. `card` · `raised` · `sheet` · `fab` · `ctaNavy` · `heroNavy` · `bubbleOut` ·
`floatPill` · `accentBanner` · `stepGlow` · `focusRing`. Outlined cards take **no** shadow.

```dart
BoxDecoration(color: cs.primary, boxShadow: JeebShadows.ctaNavy)
```

**`context.jeebRoles`** → the accent quartet is new: `.accent` `#D73B00` · `.onAccent` `#FFFFFF`
(never fade it — 4.65:1, AA by 0.15) · `.accentContainer` `#FFDBD1` · `.onAccentContainer` `#3A0B01`.
This is the **only** sanctioned orange in the 18 contrast-gated files; `.tertiary*` stays banned there.

**`JeebSemanticColors`** — read via `Theme.of(context).extension<JeebSemanticColors>()!` (no context
extension exists). **Decorative only, never body-text ink**: `.mutedSurface` `#F4F4F6`/`#29292F` ·
`.readTick` `#20F0FF` (outgoing chat bubbles only) · `.accentTint` `rgba(215,59,0,.12)` ·
`.accentRing` `rgba(215,59,0,.30)`.

**Stars:** `context.omdsColorTokens.starRatingColor` is provided app-wide — never a literal.

**Also already applied by Wave 0:** error quartet re-tint, `chipTheme.shape` → `StadiumBorder()`,
and a new `switchTheme`. Theme tests are 84/84 green.

⚠️ **`Inter-ExtraBold.ttf` (w800) is DEFERRED** — no ExtraBold face exists in the repo, so
`pubspec.yaml` was deliberately left untouched. The w800 values remain in the ramp (they are the
design truth) and currently render at the bundled w700, which Flutter substitutes automatically.
**Do not add a pubspec font entry** — it would point at a missing asset and break the build for all
24 lanes. Do not build anything that depends on a true w800 face rendering.

---

## 5. Shared components to build once (Wave 1)

All live **in the app**, NOT in OMDS (CI pulls OMDS from GitHub — an OMDS edit never reaches CI).
Directory: **`lib/core/widgets/jeeb/`**, one file per widget, snake_case = class name. Every
interactive widget takes an optional `identifier` and applies it via an **explicit
`Semantics(identifier: …)` wrapper** (never OMDS's `identifier:` param — stale local clone).
Every widget gets a widget test + an RTL smoke test in `test/core/widgets/jeeb/`.

| # | Widget | File | Visual spec (exact) | Consumers |
|---|---|---|---|---|
| 1 | `JeebTopBar` | `jeeb_top_bar.dart` | In-body row, padding `14/24/0`, gap 12–14. **`leading` is a mode, not a bool:** `back` (40px circle `surfaceContainerHigh` + 20px navy `DirectionalIcons.back` — 08 11 12 23), **`close` ×** (18px glyph, same circle — 17), or `identity` (back circle + Ø42 avatar + name 16/w700 + sub 11.5/w600 — 21). Title `jeebText.h2`; two-line variant + subtitle 12.5/w600 `mutedText`. **Real trailing slot**: Ø40 circle action (12 = chat glyph, 21 = phone glyph). `identifier` for back = `<screen>_back` (reuse existing value). **04 and 16 do NOT use this** — they use #21 | 03 05 06 07 08 09 10 11 12 13 17 18 20 21 22 23 |
| 2 | `JeebCtaButton` (+`JeebCtaFooter`) | `jeeb_cta_button.dart` | Variants: `primary` h56 (08) / h58 (17) navy pill, white `jeebText.button`, `JeebShadows.ctaNavy`; `outline` h50–54, 1.5px `colorScheme.outline`; `text` (`onSurfaceVariant`); `accentText` (orange links via `jeebRoles.accent`). Optional leading glyph (23's `＋ Top up wallet`) and **inline placement** (23's CTA is mid-flow, not docked). **The footer has THREE realized forms, not one padding:** `single` (one pill, pad `0/24/32`); `split` (text button + expanded pill — 01 `Skip`/`Next →`; text button + outline pill — 12 `Report no-show`/`Open dispute`); `textStack` (11: orange 12/w700 line + brown 14.5/w600 link, **no pill at all**) | 13 CTA screens |
| 3 | `JeebOutlinedCard` | `jeeb_outlined_card.dart` | White fill, `1.5px colorScheme.outline`, radius 16 (04 08 16) / 18 (11) / 20 param, NO shadow, default padding 13–16, optional `1px outlineVariant` inner dividers inset 16. **States: `default` · `selected` (delegates to #4 — one state machine, see below) · `dormant`** (11's third offer: `opacity .75` **and** the action row removed — an explicit named state so §7.2-C4 stays a conscious choice) | every screen except 01 |
| 4 | `JeebNavySurfaceCard` | `jeeb_navy_surface_card.dart` | `primary` fill, radius 14–24 param, shadow param **including `none`** (04's r24 hero has NO shadow — it relies on `overflow:hidden` + the accent ring; 21/16 strips use `0 8 20 rgba(11,19,81,.25)`; 08's selected tier uses `0 10 22 rgba(11,19,81,.28)`). Optional decorative off-canvas circle Ø140–200 stroked `1.5px JeebSemanticColors.accentRing` (ClipRRect'd), optional top-band mode (`0 0 36 36`, screen 02). **When used as the `selected` state of #3 it must re-tone every internal chip**: fill `rgba(255,255,255,.14)`, ink `rgba(255,255,255,.7)`, empty meter dots `rgba(255,255,255,.25)`. Selection is a *fill* swap — never a thicker border | 02 04 14 16 19 20 21 23 |
| 5 | `JeebAccentFrameCard` | `jeeb_accent_frame_card.dart` | White, `2px jeebRoles.accent` frame, r16/18, no shadow; `filled` variant = accent fill + `accentBanner` shadow (13's arrival banner) | 13 16 18 20 24 |
| 6 | `JeebSelectChip` / `JeebChipRow` | `jeeb_select_chip.dart` | Pill. Selected: navy fill, white w700. Unselected: white, `1.5px outline`. **Takes a `role`, never a size — there are five realized scales and the unselected ink is NOT constant:** `filter` pad `11/20`, 14.5/w600, ink `onSurfaceVariant` (04 16) · `sort` pad `8/15`, 12.5/w600–700, ink `onSurfaceVariant` (11) · `choice` pad `11/0` + `flex:1`, 13.5/w600, ink **navy** (17's ETA row) · `quickReply` pad `8/13`, 12/w600, ink **navy** (21) · `inlineAction` pad `9/16–18`, 13/w600 (04 `View offers`, 11 `Accept`). Optional count badge: min-w 18, h18, orange fill, 11/w800 white, pad `0/4` | 04 07 09 11 15 16 17 20 21 24 + filters |
| 7 | `JeebTierChip` | `jeeb_tier_chip.dart` | Pill `surfaceContainerHigh`, emoji + 11.5–12.5/w700 (`⚡ Flash`) | 04 10 12 16 19 21 24 |
| 8 | `JeebTierRow` | `jeeb_tier_row.dart` | Two named constructors, NOT merged. `.compact` (07): 20px emoji, name 16/700, sub 12/500, trailing 22px radio (`2px surfaceContainerHighest`); selected = solid navy + orange check (check ink `jeebRoles.accent` on white disc); `Most picked` badge = **the one legitimate `accentTint` use**. `.catalog` (08): card r16 pad `13/16` gap 9, emoji 17px, name `cardTitle`, SLA chip pad `3/9` r999 `surfaceContainerHigh` navy w700, vehicle line 11.5/w600 periwinkle; price meter delegates to **#21**; selected = navy fill + `0 10 22 rgba(11,19,81,.28)` + 15px white check at the row end + `Recommended` badge as a **solid orange pill, white 10/w800, pad `2/8`** (not `accentTint`) | 07 08 |
| 9 | `JeebAvatar` / `JeebAvatarStack` | `jeeb_avatar.dart` | Three realized sizes: **Ø30** (stack, `2px white` ring, −9px overlap, initial 11/w800), **Ø42** (list/thread, 15/w800), **Ø46** (screen header, 17/w800). Fill rotation `[primary, mutedText, jeebRoles.accent]`; **`surfaceContainerHighest` fill + periwinkle initial = unknown/dormant** (11's Rami, 04's own user). **Two dot components sharing one shape, both directional:** `presence` = Ø12 `jeebRoles.success` + 2px white ring at **bottom-END** (21); `unread` = Ø12 `jeebRoles.accent` + 2px white ring at **top-END** (04). Stack overlap via `EdgeInsetsDirectional` | 04 11 12 15 16 19 20 21 |
| 10 | `JeebSectionLabel` | `jeeb_section_label.dart` | w700 / ls 1.2 / uppercase / `mutedText`, `toUpperCase()` applied internally (locale-safe: EN only, AR strings pass through). **Default 12.5px** (19 20 23; 13px on 15/17 is visually the same token) with a `small` flag for the shipped 11px (05 only) — see §4.2. **`hint` slot** for the inline non-uppercase w600 continuation (17: `PICKUP ETA · Flash allows ≤ 60 min`) — never a second `Text` | 05 15 17 19 20 23 |
| 11 | `JeebStepper` | `jeeb_stepper.dart` | Nodes 26px: done = navy + 14px white check; active = accent + 8px white core + `stepGlow`; pending = `2px surfaceContainerHighest` ring. Connectors `height 3, r8`, navy when passed. Labels `jeebText.label` (done navy / active accent w800 / pending `mutedText`). Plain `Row` (auto-RTL) | 12 18 |
| 12 | `JeebCodeCells` | `jeeb_code_cells.dart` | Variants: `input74` (h74 r16 `surfaceContainerHigh`, digit `codeInput`; active `2px accent` + 2×30 accent caret), `input52` (h52 r12, caret 2×22), `display` (74×92 r20 navy tiles, `statDisplay` white, `heroNavy` shadow), `strip` (20/w800 ls5). Digits always in an LTR isolate | 03 12 13 18 |
| 13 | `JeebNumericKeypad` | `jeeb_numeric_keypad.dart` | 3-col grid gap 10, cells h62 r16 `surfaceContainerHigh`, digits `keypadDigit` navy, blank bottom-start, backspace bottom-end, container pad `0/20/30`. Identifiers `<screen>_keypad_<0-9|backspace>` | 03 18 |
| 14 | `JeebWaveform` | `jeeb_waveform.dart` | **Four realized modes, not two.** `cardMark`: 4 bars w3 r9 gap 2, h 8/14/10/15, accent with the last at `.4`, container h16 (04 16). `onNavy`: 5 bars w3 gap 3, h 9/17/11/20/10, white `.4`/`.55` with two accent bars, container h24 (04 hero). `inBubble`: 5 bars w2.5 gap 2, h 8/14/10/15/9, **navy at opacity .4–.7** (white .4–.7 when outgoing), container h16 (21). `live`: ~11 bars, accent with an alpha tail (01 05) | 01 04 05 10 16 21 |
| 15 | `JeebMicHero` | `jeeb_mic_hero.dart` | Accent circle Ø56/118/128. **Ø56 glow is a two-shadow stack:** `0 0 0 6 rgba(215,59,0,.22)` + `0 10 22 rgba(215,59,0,.45)` (04, measured). Larger sizes add the Ø184 radial halo. **NEW — `progress` param: the max-duration arc** drawn around the mic on 05 (an accent arc on a light track showing the time budget); the plan previously specced glow rings only. `onPressStart/onPressEnd` hold-to-talk callbacks; satellite Ø46 `surfaceContainerHigh` buttons (05's cancel/keyboard, with 12/w600 periwinkle captions beneath) are the consumer's job | 01 04 05 |
| 16 | `JeebChatBubble` | `jeeb_chat_bubble.dart` | Incoming: `surfaceContainerHigh`, `BorderRadiusDirectional(topStart 18, topEnd 18, bottomEnd 18, bottomStart 6)`. Outgoing: navy, mirrored radii, `bubbleOut` shadow. Max-width 78%, padding `11/14`, body `jeebText.body`, timestamp 10/w600 `mutedText`. **Read state is TEXT, not a tick** — `9:25 · Read` in the same 10/w600 `mutedText` meta line, right-aligned. `readTick` (`#20F0FF`) has zero occurrences on the board; do not use it (§4.1). **Media slot** (measured, 21): Ø32 navy play disc + 14px white ▶, `inBubble` waveform, label 11/w700 `mutedText`, then a 120×74 r10 `surfaceContainerHighest` photo tile with a 20px periwinkle glyph, `margin-top 8` | 21 |
| 17 | `JeebSystemChip` | `jeeb_system_chip.dart` | Centered pill: filled `surfaceContainerHigh` `4/12` `label` mutedText, or outlined `1.5px outline` `5/13` ink `onSurfaceVariant` | 21 (timeline events) |
| 18 | `JeebChatComposer` | `jeeb_chat_composer.dart` | h52 full pill `surfaceContainerHigh` + `1px surfaceContainerHighest` border, padding `0/8/0/18` directional, gap 10, placeholder `body` mutedText, **19px periwinkle attach glyph** (the board draws it; `ChatComposer.attachButtonKey` already exists), trailing Ø38 navy circle **send** action. **NO MIC — B04 overrides the board.** Note the board has *no send button at all*: its mic occupies the send slot, so this is "replace send with a mic", not "add a mic" (§7.2) | 21 |
| 19 | `JeebSegmentedToggle` | `jeeb_segmented_toggle.dart` | Outer pill `1.5px outline` pad 4; segments flex pill, selected navy fill + white 13.5/w700 | 20 (language); 01 uses a screen-local dark-on-navy variant. **Do NOT merge 17's ETA row into this** — that is a flat row of `flex:1` `choice` chips (#6), with no outer track |
| 20 | `JeebMeter` | `jeeb_meter.dart` | Track h5–6 r9 `surfaceContainerHighest`, accent fill fraction (11: 70×5 r9 at 65%); `scrubber` variant adds 14px accent knob `0 2 6 rgba(215,59,0,.4)` | 05 06 11 22 |
| **21** | **`JeebPriceMeter`** *(NEW)* | `jeeb_price_meter.dart` | **Split out of #8** — the on-navy inversion is where the bugs are, and 07 needs it too. 4 × Ø7 dots, gap 3, accent filled / `surfaceContainerHighest` empty; caption 10.5/w700 `mutedText` beneath, right-aligned, column gap 3. On navy: dots white / `rgba(255,255,255,.25)`, caption `rgba(255,255,255,.7)` | 07 08 |
| **22** | **`JeebInfoNote`** *(NEW)* | `jeeb_info_note.dart` | **The most-repeated pattern the plan was missing — 5 of the 10 spine screens.** Radius 14–16, pad `11–12/16`, gap 10, leading glyph 14–17px. Tones: `muted` (`surfaceContainerHigh` + 12.5/w500 lh18 `mutedText` — 08), `success` (`jeebRoles.successContainer` + Ø30 check + navy w700 title + `mutedText` sub — 23), `accent` (navy 12.5/w600 text + orange w700 trailing link — 17's wallet strip). Optional trailing: meter (11's countdown), value (12's `2 1 4 4` door code), link | 08 11 12 17 23 |
| **23** | **`JeebProfileHeader`** *(NEW)* | `jeeb_profile_header.dart` | **What 04/16/19 have instead of a top bar.** Ø46 avatar (+ optional `unread` dot), eyebrow 13/w600 `mutedText`, name 19/w700 navy, trailing 24px navy glyph (04's bell) **or** a rating pill (`surfaceContainerHigh`, `★ 4.8`, star inherits navy — do NOT tint it yellow, §4.1) | 04 16 19 |
| **24** | **`JeebMoneyBreakdown`** *(NEW)* | `jeeb_money_breakdown.dart` | Outlined r16 pad `15/16`; rows 13.5/w600 `mutedText` label + navy w700 value, row gap 8; `1px outlineVariant` divider with `10/0` margin; total row 15/w800 navy with a 17px value; footnote 11.5/w500 `mutedText` + 14px lock glyph. **The single enforcement point for D41/D44 wording and `kJeebCommissionRate`** | 14 17 19 |
| **25** | **`JeebListRow`** *(NEW)* | `jeeb_list_row.dart` | Rows inside a grouped `JeebOutlinedCard`: navy glyph, title navy w700, subtitle `mutedText`, trailing periwinkle chevron (`DirectionalIcons`); inset `1px outlineVariant` divider between rows | 20 23 |
| **26** | **`JeebQuickReplyRow`** *(NEW)* | `jeeb_quick_reply_row.dart` | Horizontally scrollable outline pills, pad `8/13`, `1.5px outline`, 12/w600 navy, gap 8, `nowrap`, container pad `10/24/0`. Includes AR strings in an EN thread — must not force-LTR. **Does not exist in the app today** | 21 |
| **27** | **`JeebStepperPill`** *(NEW)* | `jeeb_stepper_pill.dart` | The ±1 adjusters: pad `6/12`, r999, `1.5px outline`, 12.5/w700 navy, gap 6. Identifiers `<screen>_price_decrement` / `_increment` | 17 |
| **28** | **`JeebPageDots`** *(NEW)* | `jeeb_page_dots.dart` | Active = **28×8 accent pill**; inactive Ø8 `surfaceContainerHighest`; gap 6. Index is directional-safe | 01 |

### 5.1 Build order (Wave 1 is NOT flat — build in this order)

Ordered by how many lanes each unblocks and by where drift is most expensive. Items in the same
numbered step ship as one PR.

1. **`JeebOutlinedCard` + `JeebNavySurfaceCard`** — every other component sits inside one, and
   selected/unselected is a single state machine; splitting it guarantees the navy variant drifts.
2. **`JeebInfoNote`** — 5 of the 10 spine screens, zero dependencies. Land it late and five lanes
   hand-roll five different grey panels in the same week.
3. **`JeebTopBar` + `JeebProfileHeader`** — unblocks 17 of 24 screens and owns the `<screen>_back`
   identifier contract; must exist before any lane edits a header.
4. **`JeebCtaButton` + `JeebCtaFooter`** (single / split / textStack) — the docked footer is the
   universal structural element: 22 of 24 screens have exactly one `flex:1` spacer above it.
5. **`JeebSelectChip` + `JeebChipRow`** with the five-role size table baked in — chips are above the
   fold on 04, 11, 16, 17 and 21; the table must exist before three lanes each invent a padding.
6. **`JeebAvatar` + `JeebAvatarStack`** (both dot semantics) — needed by 04, 11, 12, 16, 21; cheap,
   and directionally easy to get wrong.
7. **`JeebMeter` + `JeebPriceMeter`** — 11's countdown and 08's tier meter; the on-navy inversion is
   the only hard part and it should be solved once.
8. **`JeebWaveform` (4 modes), then `JeebMicHero` (+ progress arc)** — the signature marks. Waveform
   first: the hero contains none, but 01, 04, 05, 16 and 21 all need the mark.
9. **`JeebStepper`** — only 12 and 18, but the highest-risk widget for RTL and it carries the frozen
   `tracking_step_*` Maestro identifiers.
10. **`JeebChatBubble` + `JeebSystemChip` + `JeebChatComposer` + `JeebQuickReplyRow`** — one screen,
    but 43 identifiers to preserve plus the B04 refusal; a single reviewable diff beats parallelism.
11. **`JeebMoneyBreakdown` + `JeebListRow`** — pure composition over step 1 and the single
    enforcement point for D41/D44 wording, so it lands after that wording is settled.
12. **The remainder** — `JeebCodeCells`, `JeebNumericKeypad`, `JeebTierRow`, `JeebAccentFrameCard`,
    `JeebSegmentedToggle`, `JeebTierChip`, `JeebPageDots`, `JeebStepperPill`. Each serves ≤2 screens
    outside the spine; none blocks another lane.

**Not shared:** the offer card (screen-specific, lives in
`lib/features/client_offers/presentation/widgets/`, composed from kit primitives); the bottom tab
bar — **restyle `_JeebBottomBar` in `shell_screen.dart` in place** (selected tab = 52×30
`surfaceContainerHigh` pill + navy glyph + 12/w700 label; unselected 22px `mutedText` glyph +
12/w600; top border `1px outlineVariant`; pad `12/8/26`), keeping `shell_tab_${tab.id}`
identifiers and the **existing per-role tab sets** (see §9-Q1 — do NOT unify roles around the
board's 5-tab bar). Switch styling = `switchTheme` in `app_theme.dart` (navy on /
`surfaceContainerHighest` off, white knob); the big green online switch on 16 is a screen-local
variant using `jeebRoles.success`.

---

## 6. Migration waves

Dependency rule: W0 → W1 → (W2 ∥ W3 ∥ W4 ∥ W5-screens), integration last. Within a wave, lanes are
parallel per feature directory; **all shared-file edits are serialized through the integrator**
(§7.4).

### Wave 0 — Foundation (ONE agent, owns `lib/core/theme/*`, `lib/app/app.dart`, `pubspec.yaml`)
1. `app_theme.dart`: error quartet (`#B00020`/white/`#FFDAD6`/`#410002`); `chipTheme.shape` →
   `StadiumBorder()`; add `switchTheme`; register `JeebTextStyles`.
2. `jeeb_color_roles.dart`: `accent/onAccent/accentContainer/onAccentContainer` (+ dark values:
   reuse light accent `#D73B00`/white — passes AA — until a dark redesign exists) + add the pairs
   to `color_role_contrast_test.dart`.
3. `jeeb_semantic_colors.dart`: + `mutedSurface`, `readTick`, `accentTint`, `accentRing`
   (light + dark values, `copyWith`/`lerp` extended).
4. NEW `jeeb_text_styles.dart`, NEW `jeeb_shadows.dart`.
5. `app.dart:616`: `OmdsColorTokens(starRatingColor: Color(0xFFFFC107))`.
6. `pubspec.yaml`: `Inter-ExtraBold.ttf` (w800) under the existing Inter family + the asset file.
   **Exit:** `dart analyze` = the same 11 baseline issues; `flutter test test/core/theme/` green;
   full `flutter test` green (the errorContainer re-tint and chip flip may touch goldenless
   widget tests — fix forward, never by weakening gates).

### Wave 1 — Component kit (parallel, one agent per §5 widget, no shared-file edits)
Each: widget + widget test + RTL smoke. No screen edits. Exit: kit compiles, tests green,
analyze clean.

### Wave 2 — Self-contained screens (parallel)
| Screen | Feature dir | Red flags |
|---|---|---|
| 13 OTP handover | `otp_handover` | auto-brighten = existing capability only; SMS-fallback copy must not invent an endpoint |
| 14 Receipt confirm | `delivery_receipt` | NO commission line on customer surface (by design, matches D41 spirit) |
| 15 Mutual rating | `rating` | **D56**: no skip/close/back — design agrees; `rating_root` + PopScope pinned by test; NOT in `backFallbacks` |
| 19 Earnings | `earnings` (shell `earnings_tab`) | **D41/D44** wording: "Platform fee" / "Total cash kept"; NEVER "Commission"; 10% only via `kJeebCommissionRate` |
| 20 Settings | `settings` | mostly OMDS rows today — keep `OmdsSettingsRow` semantics; Become-a-Jeeber = `JeebAccentFrameCard` |
| 22 Become a Jeeber (KYC) | `kyc` | **D52**: no resubmit on final rejection; **D20**: no vehicle-contract keys; baseline error at `kyc_status_view.dart:490` is pre-existing — leave it |
| 23 Wallet | `wallet` | file is in the no-raw-colors gate → orange ONLY via `jeebRoles.accent`; keep `JeeberKycGateBuilder` at `wallet_hub_screen.dart:61` |
| 24 Order history | `order_history` | `order_status_chip.dart` gated; **date-filter sheet has committed goldens** — regenerate; Re-broadcast reuses the existing no-show/rebroadcast flow, "Jeeb it again" = client-side re-compose through the existing create flow |

### Wave 3 — Client request flow (parallel after W1; 06↔05 copy consistency)
| Screen | Feature dir | Red flags |
|---|---|---|
| 04 Client home | `home_client` | shell tab; uses `JeebProfileHeader`, **not** `JeebTopBar`. Hero = navy r24, **no shadow**, Ø140 `accentRing` circle off-canvas top-END, Ø56 orange mic (two-shadow glow). **Reach count ("12 Jeebers reached") has no source — omit with a TODO, do not fake it**; offer floor "from $8" IS derivable from offers already in state (§7.6) |
| 05 Voice recording | `voice_request` | not a route — hosted in `voice_request_screen.dart`. **Two new interactions**: slide-to-cancel (the `‹ Slide` satellite) and the **max-duration progress arc** around the mic (`JeebMicHero.progress`). Bottom-thumb cluster: Ø46 cancel ← mic → Ø46 keyboard, captions 12/w600 `mutedText`. The top 60% of the screen is deliberately empty below the transcript card (R1) |
| 06 Transcription review | `transcription` | per-word confidence needs a field check (§7.6) |
| 07 Request type | `request_type` | selected tier = navy + orange check via kit; `tier_selection` gate rules apply to shared bits |
| 08 Tier catalog | `tier_selection` | **NO route today (deliberately deleted).** NEW route `/tier-catalog` (name `tier-catalog`), opened from 07's "Compare tiers"; `backFallbacks['tier-catalog'] = '/request-type'`; do NOT resurrect `/tier-selection`. File is contrast-gate-listed → orange via `jeebRoles.accent` only. **`Recommended` is a SOLID orange pill + white 10/w800 — not `accentTint`.** Vehicle-class lines are tier metadata → **new** l10n keys only, never the D20-banned names. The board draws the vehicle glyph on Flash alone — a design slip; render it on all five |
| 09 Location picker | `location` | `/capture-location` must keep refusing to fabricate coordinates (JEBV4-176) |
| 10 Request summary | `request_summary` | structural collapse to one ticket — inventory identifiers FIRST; typed variant = audio bar simply absent |
| 11 Offers | `client_offers` | accept sheet stays a QUESTION (tense test); "Accept only one offer." in accent. **Countdown is buildable TODAY** — `ClientOffersState.windowExpiresAt` + `windowRemaining` + injected `now` all exist (§7.6). Three emphasis levels: recommended = `2px navy` + solid-orange `Best value` tab at `top:-9/right:14`; normal = brown outline + outline Accept; **dormant = `.75` opacity with the action row DELETED — do not ship that (§7.2-C4): every offer must stay acceptable.** Footer is `textStack`, no pill |

### Wave 4 — Jeeber & realtime (parallel after W1)
| Screen | Feature dir | Red flags |
|---|---|---|
| 12 Live tracking | `live_tracking` | **The courier card asks for two fields the parser destroys on purpose.** `DeliveryTrackingInfo.fromTrackingJson` nulls `phoneE164`, `rating` AND `avatarUrl`; `test/delivery_tracking_jeeber_parse_test.dart:44–64` asserts all three. **Build the card with the initial disc, name, vehicle and cash — no ★, no call button** (§7.2-C3, owner decision). Door code always visible; keep `?deliveryId=` resolution; Maestro `jm-032` ids frozen (`tracking_stepper`, `tracking_step_*`, `order_summary_pinned`, `tracking_dispute_cta`, `tracking_noshow_*`). Stepper labels must resolve through the existing `TrackingStage` enum + `DeliveryStatusAlias` — no new stage names. Footer is `split` (text + outline pill) |
| 16 Jeeber home | `jeeber_home` | shell tab; uses `JeebProfileHeader`. Keep `JeeberKycGateBuilder` in feed view. **`Extend` is buildable TODAY** — `AvailabilityCubit.extendActivity()` + `AvailabilityInactivityPolicy` (warn 7h30 / offline 8h) exist; **but the state exposes `warningVisible` (bool), not a remaining Duration**, so the literal "goes offline in 1h 40m" is NOT available — ship the warning copy + Extend and TODO the countdown (§7.6). **The magnifier is NOT a resurrection of deleted search** — `jeeber_feed_tab_view.dart:62 searchBarKey` already ships a live search bar; this is a collapse to a Ø46 circle, do not refuse it. `Make offer` on the freshest card is a **solid orange pill with an orange glow**; the older card gets the outline variant |
| 17 Offer composer | `offers` | fee math ONLY from `kJeebCommissionRate` — **already correct** at `offer_submission_screen.dart:196`; the real change is wording: the board's **"Jeeb fee (10%)" is a D41/D44 violation → "Platform fee (10%)"** via l10n. `JeebTopBar.close` (×), not back. Route self-wraps RootAwareBackScope — do NOT add to `backFallbacks` |
| 18 Active delivery | `active_delivery_jeeber` | **committed goldens ×3 (EN / AR-RTL / 200% text)** — regenerate; baseline error at `gps_permission_banner.dart:163` is pre-existing — leave it |
| 21 Order chat | `chat` | **Highest-risk file on the board: 1105 LOC, 18 widgets, 43 identifiers, two locked-decision collisions. Sequence it ALONE, not in parallel with the rest of Wave 4.** (1) **B04: no mic.** The board's Ø38 navy circle *is* the send slot — this is "replace send with a mic", so build it as send and keep the attach glyph (`ChatComposer.attachButtonKey` exists). (2) **The pinned strip violates the pinned vocabulary on THREE counts**, not one: `order_chat_pinned_summary_labels_test.dart` pins heading = order reference, link = "View summary", cash = "Pay cash on delivery", status = canonical `deliveryStage*`, unresolved = "Pending"; the board's `Medicine · In transit · $8 cash` + `Track` uses the item name as the heading, drops the link, and inlines the cash line. **Restyle the strip to navy r14 + `0 8 20 rgba(11,19,81,.25)` + a white `Track` pill, and keep all four pinned strings inside it.** (3) Read state is the text `· Read`, not a cyan tick. Quick-reply row is net-new |

### Wave 5 — Entry + integration
| Item | Notes |
|---|---|
| 01 Onboarding | `onboarding`; marketplace-preview collage is static/decorative — no invented live data; wordmark assets must exist in the bundle before wiring. **The only full-bleed navy screen and the only screen with no `flex:1` spacer** — a white bottom sheet with a large top radius carries AR (orange w700) + EN (navy w800 ~28) paired copy, `JeebPageDots`, and a `split` footer (`Skip` text + expanded `Next →` pill). **`Skip` here is legitimate** — D56's no-skip rule is the mutual-rating screen only |
| 02 Registration | `registration`; phone-first, social demoted (keep `social_sign_in_button.dart` hex exemption); keep the raw-TextField +961 exemption |
| 03 OTP verify | `registration`; not a route; structural (in-screen keypad, auto-verify on 4th digit) — inventory identifiers FIRST |
| Integration sweep | serialized l10n/router/DI batches landed; `dart analyze --fatal-infos .` vs baseline; full `flutter test`; `l10n_parity_check.sh`; `tool/check_design_tokens.sh`; golden regeneration (18 + 24-sheet) on the Mac Studio; chip-flip visual QA across the 33 chip sites; Maestro smoke of the key flows on the S22 (real-flow standard) |

---

## 7. Guardrails

### 7.1 Hard constraints (restated — violating any fails the work)
1. No git operations of any kind. Edit files only.
2. Preserve every existing `Semantics(identifier:)` value (565 literals — frozen public API).
   Add new ones per convention (§7.5). Never rename.
3. No new pubspec **dependencies** (the Inter-ExtraBold font asset in Wave 0 is the single
   sanctioned pubspec edit).
4. No invented backend endpoints/fields/contracts (§7.6 policy).
5. All user-visible strings through l10n, EN + real AR, RTL-aware layouts only
   (directional APIs; `DirectionalIcons` for glyphs; LTR isolates for money/digits).
6. Analyze baseline = 11 issues / 6 errors, all pre-existing (2 stale-OMDS `identifier:` errors +
   4 `DioExceptionType.transformTimeout`). Bar: **no new issues of ANY severity** — CI runs
   `dart analyze --fatal-infos`. Do not "fix" the 6.
7. Comments: short, why-focused. No essays.
8. Code passes `prefer_const_constructors`, `prefer_final_locals`, `sort_constructors_first`,
   `use_build_context_synchronously`, `avoid_print`.

### 7.2 Locked product decisions — where the board loses
These are pinned by `test/decision_violations_test.dart` and friends. If the design contradicts
them, **the design is refused on that point** and the refusal noted in the screen's PR notes:

| Decision | Rule | Board conflict? |
|---|---|---|
| D56 | Mutual rating: no skip, no close, no back (`PopScope.canPop == false`) | board agrees — keep |
| D52 | Final KYC rejection: no resubmit CTA, no "Resubmit" text | no conflict — keep |
| D20 | No vehicle contract: the banned l10n keys must not reappear. Tier "vehicle class" labels (08) are tier metadata — use NEW keys, never the banned names | compatible |
| D41/D44 | Earnings framing: "Platform fee", "Total cash kept"; "Commission" appears NOWHERE | board's "Jeeb fee (10%)" → render via l10n as "Platform fee (10%)" |
| Single 10% literal | `kJeebCommissionRate` is the only numeric copy of the rate; 17's live math and 22's terms line must reference it | compute, never hardcode |
| B04 | NO mic button in the chat composer. Pinned by `test/features/chat/chat_composer_no_mic_b04_test.dart:102` (`Icons.mic_none` findsNothing) + `sendButtonKey`/`attachButtonKey`/`textFieldKey` | **REFUSED (C2).** Sharper than previously written: the board has **no send button at all** — its mic occupies the send slot. Build the Ø38 navy circle as send; keep the attach glyph the board also draws |
| Accept-sheet tense | "Accept X's offer?" question form, EN+AR; past-tense string forbidden on the sheet | keep |
| Pinned chat summary | Pinned by `test/features/chat/order_chat_pinned_summary_labels_test.dart`: heading = human order reference (never the screen title); link = "View summary"; cash = "Pay cash on delivery"; status = canonical `deliveryStage*`; unresolved = "Pending" | **THREE violations, not one (C1).** The board's strip (`Medicine · In transit · $8 cash` + `Track`) uses the item name as the heading, drops the View-summary link, and inlines the cash reminder. **Restyle the strip navy + keep all four strings inside it, with Track as a trailing white pill** |
| Tracking privacy | `DeliveryTrackingInfo.fromTrackingJson` **nulls `phoneE164`, `rating` AND `avatarUrl`**; `test/delivery_tracking_jeeber_parse_test.dart:44–64` asserts all three ("blind-reveal / privacy guard") | **The board's courier card is data-blocked, not merely discouraged (C3).** Its `★ 4.9` and its call button are both unbuildable. Ship name + vehicle + cash on an initial disc. A gated contact path exists elsewhere (`DeliveryStatusCubit.requestContactNumber()` → `contactUnavailable`) — any call affordance must route through it. **OWNER DECISION** |
| Every offer stays acceptable | not test-pinned, but a product invariant: "Accept only one offer." is about exclusivity, not about which offers are actionable | **The board's third offer card is `.75` opacity with its whole action row deleted (C4).** Build all cards with a full action row; dimming may stay as a pure rank signal if the owner confirms. **OWNER DECISION, low cost either way** |
| Deleted features stay deleted | in-app role switch, email/password funnel, client-side search | **No board item resurrects one.** Explicitly: 16's magnifier is NOT the deleted search (`jeeber_feed_tab_view.dart:62` already ships a live search bar), and 01's `Skip` is not a D56 violation. Do not refuse either by mistake |
| Deep-link guard | clients refused jeeber-scoped destinations; guard must not over-refuse | don't touch dispatch logic |
| Blocked account | only exits = support + sign-out | keep |
| No pre-accept cancel endpoint | cancel is locally authoritative only — copy must never imply server confirmation | word cancel surfaces accordingly |

### 7.3 Theme gates
- `test/core/theme/no_raw_semantic_colors_test.dart` bans `.tertiary*`, `Color(0x`, and named
  Material colors in 18 files (incl. screens 08, 23, 24 targets). **Orange in those files comes
  ONLY from `context.jeebRoles.accent`** (added in Wave 0). Do not amend the regexes; do not
  remove files from the list; the test also asserts the files exist at their paths — don't move
  them.
- `color_role_contrast_test.dart`: every pair added to `jeeb_color_roles.dart` must be ≥4.5:1 in
  light AND dark. The periwinkle-fails-on-white guard stays.
- `tool/check_design_tokens.sh`: no hex/`Colors.*`/`fontSize:`/raw `BorderRadius.circular(N)` etc.
  in `lib/features` (existing exemptions only). Design-exact px live inside `lib/core/widgets/jeeb/`.

### 7.4 File ownership (anti-collision)
- A screen lane owns **only its `lib/features/<name>/` tree** (+ its tests/goldens).
- **Integrator-owned, serialized, append-only batches:** `lib/l10n/app_en.arb`,
  `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart` (4-edit recipe: EN key + `@key`
  description → real AR value ≠ key → `_get` getter → call site; the parity gate fails BOTH
  directions, so never land a key without its getter and both locales),
  `lib/core/router/app_router.dart` (routes append inside `_wrapRootAware([...])` in the matching
  wave band; `backFallbacks` per its rules), `lib/core/di/injection_container.dart` (3-line
  `registerLazySingleton` + WHY comment).
- Wave-0 agent owns `lib/core/theme/*`, `app.dart`, `pubspec.yaml` — frozen after Wave 0.
- **Nobody edits `../omds-flutter`** or `.github/workflows/*` or weakens any test gate.
- Router facts: no `pageBuilder`/`parentNavigatorKey`/`onExit` — `_wrapGoRoute` silently drops
  them; no motion is specced between screens, so `_wrapGoRoute` is NOT widened. Routes that
  self-wrap `RootAwareBackScope` (delivery-detail, settings-addresses, jeeber-offer-submission)
  and the PopScope screens (feedback, mutual-rating) stay OUT of `backFallbacks`.
- Preserve every constructor seam (`this.repository`, `this.cubitFactory`…) — the devtool catalog
  (11 batch files), the no-DI route-resolve suites, and 50 GetIt-stubbing tests depend on them.
  Never delete a `Fake/Stub/Empty/Noop` class or a `_resolve*()` fallback branch.

### 7.5 Semantics identifiers
- Before editing a screen, **grep its feature dir for `identifier:` and write the inventory into
  the lane's notes**; after the restyle, every inventoried value must still be emitted (625
  `find.bySemanticsIdentifier` assertions + 83 Maestro flows, and Maestro is NOT in CI — silent
  rot if you miss one).
- Structural screens (03, 10, 18) re-home identifiers onto the new widgets — value-identical.
- New interactive widgets: `<screen>_<element>[_suffix]` snake_case (`_cta`, `_field`, `_toggle`,
  `_back`, `_root`…); each new screen surface keeps exactly one `<screen>_root`.
- Parent `Semantics` that wraps children needs `container: true` + `explicitChildNodes: true` or
  it swallows nested ids (see `active_request_card.dart` for the canonical idiom).
- Always an explicit `Semantics` wrapper — never OMDS widgets' `identifier:` param (stale local
  clone can't compile it).

### 7.6 Data-gap policy (constraint 4 in practice)
Allowed: rendering existing fields; **client-side derivations of existing fields** (e.g.
Best-value = rank by price × rating × distance if all three exist on the offer DTO; live fee math
from `kJeebCommissionRate`; countdown from an existing TTL/expiry field). Forbidden: new
endpoints, invented fields, fabricated placeholders (the JEBV4-176 lesson). When the design wants
data that doesn't exist: render the surface without it and leave
`// TODO(redesign-24): needs gateway <field> — omitted, not faked.`
Screen agents must verify per item.

**VERIFIED BUILDABLE — removed from the suspect list (three of the loudest ones were wrong):**

| Item | Evidence |
|---|---|
| **11 — offer-window countdown** | `ClientOffersState.windowExpiresAt`, `windowRemaining` (clamped, non-negative) and an injected `now` all exist today. The plan previously called this one of the three most likely casualties. Build the strip **and** its meter |
| **16 — `Extend`** | `AvailabilityCubit.extendActivity()` + `AvailabilityInactivityPolicy` (warn 7h30 / auto-offline 8h) + `warningVisible`. **Partial:** the state exposes a *bool*, not a remaining `Duration`, so the literal "goes offline in 1h 40m" is NOT available — ship the warning copy + Extend, TODO the live figure |
| **17 — live fee math** | already computed from `kJeebCommissionRate` at `offer_submission_screen.dart:196`. Only the label is wrong (D41/D44) |

**BLOCKED BY A PRIVACY GUARD, not merely missing:** 12's courier `★` and phone — the parser deletes
them and a test asserts it (§7.2-C3). This is not a data gap to TODO around; it is an owner decision.

**Still genuinely suspect:** broadcast reach count (04 — the one spine number with no source at all),
offer floor + avatar stack (04 — the floor IS derivable from offers already in state), review counts
"(127)" (11), distance / "3 km away" (11, 16), "usually replies in 1 min" (11, 21), GPS accuracy
meters (09), starter-credit flag (23), reserved-amount breakdown (23), avg-kept stat (19), PDF export
(19), proof-photo timestamp (14), capture-quality verdicts (22), per-tier ETA bands / vehicle class /
price level / "Most picked" (07, 08, 17) — tier metadata may be a client-side constant table if the
gateway has none, since tiers are a fixed product lexicon.

---

## 8. Definition of done

### Per screen
- [ ] Matches the `NN-slug.png` layout, structure, and token usage (mock chrome excluded); copy
      matches the HTML (via l10n, EN + real AR).
- [ ] Consumes §5 kit widgets — no per-screen re-derivation of shared patterns; no new hex/px
      literals in `lib/features` (`tool/check_design_tokens.sh` clean).
- [ ] Semantics inventory: every pre-existing identifier still emitted; new elements identified
      per convention; surfacing test updated only by ADDING.
- [ ] RTL: renders correctly under `ar` (directional APIs only, digits/money LTR-isolated);
      text scale 200% does not overflow-crash.
- [ ] Dark mode still renders legibly through theme roles (no light-only hardcoding; no invented
      dark design).
- [ ] Locked decisions honored; refusals (if any) noted in lane notes.
- [ ] `dart analyze --fatal-infos .` → zero NEW issues (baseline stays 11/6).
- [ ] All existing widget tests for the feature pass (updated only where visuals legitimately
      changed — never by renaming identifiers or weakening gates); goldens regenerated where they
      exist (18, 24-sheet).
- [ ] l10n: keys + getters + both locales landed via the integrator batch; parity script green.

### Migration overall
- [ ] `dart analyze --fatal-infos .` reports exactly the pre-existing baseline (11 issues,
      6 errors — the 2 stale-OMDS `identifier` errors and 4 `transformTimeout` errors untouched).
- [ ] Full `flutter test` green — **all 505 test files pass**, including
      `decision_violations_test.dart`, both theme gates, `back_nav_all_routes_test.dart`, the
      w0–w4 route-resolve suites, l10n suites, and the 6 regenerated golden PNGs.
- [ ] `qa/t-mob-fix-002/l10n_parity_check.sh --analyze` + `ar_plurals_check.sh` green.
- [ ] `tool/check_design_tokens.sh` reports no new violations.
- [ ] The 83 Maestro flows are untouched-by-necessity (identifier freeze held); key flows
      smoke-run on the S22 per the real-flow validation standard.
- [ ] No changes outside `jeeb-mobile`; no new deps; no branch/commit/push performed.

---

## 9. Open questions / risks (honest)

1. **Bottom-bar unification (Q-OWNER).** The board renders one 5-tab bar
   (Requests/Delivery/Dashboard/Earnings/Profile) on client home, jeeber home AND order history —
   including Earnings on a client surface. The in-app role switch was deliberately deleted in
   July; unifying the shell would resurrect it. **Plan's decision: restyle `_JeebBottomBar` in
   place, keep per-role tab sets.** Needs owner confirmation; if the owner wants the board's
   literal bar, that is a product change outside this migration.
2. **Inter w800 asset.** Plan says bundle `Inter-ExtraBold.ttf` (OFL). If the owner vetoes the
   pubspec/asset edit, all `w800` specs degrade to `w700` silently — acceptable but flatter.
3. **Arabic display face.** Baloo Bhaijaan 2 is unlicensed per the DS itself. AR headlines ship
   in Inter/system Arabic; a licensed face is a follow-up.
4. **Dark mode.** The redesign is light-only; dark remains the unbranded navy-seed scheme and
   every redesigned surface will be *legible but off-spec* in dark (`ThemeMode.system` ships it).
   A dark pass is a separate engagement; inventing one here would be design fabrication.
5. **Data gaps (§7.6) — downgraded.** Still real, but three of the loudest suspects turned out to
   be already buildable (11's countdown, 16's Extend, 17's fee math). Expect `TODO(redesign-24)`
   omissions on reach count, review counts and PDF export. **No longer the largest source of
   divergence** — see risks 13 and 14, which now outrank it.
6. **`/tier-catalog` route.** 08 has no route today because `/tier-selection` was deliberately
   deleted and the flow standardized on `/request-type`. Adding `/tier-catalog` as a secondary
   "compare tiers" surface is this plan's call — flag to the owner in the Wave-3 notes.
7. **Tier emoji lexicon (⚡🚀🟦🤝🌿).** Load-bearing per the DS, but 🟦 is a cross-platform
   rendering gamble. Default: ship the emoji; if 🟦 renders badly on the S22, substitute a
   rounded-square glyph tinted `JeebTierColors.standard` — decided centrally in `JeebTierChip`,
   never per screen.
8. **Chip-shape flip blast radius.** `chipTheme` → pill changes every raw `Chip` surface at once
   (33 sites). Wave-5 visual QA sweep is the mitigation; a site that genuinely needs 8px opts out
   locally.
9. **ErrorContainer re-tint.** 12+18 call sites change appearance in Wave 0 by design. Any widget
   test pinning the old `#B00020` slab must be updated in Wave 0 itself, not left for lanes.
10. **Golden fragility.** Regenerating the 6 PNGs (18 + 24-sheet) on a different machine/SDK
    produces spurious diffs for everyone. Regenerate on the Mac Studio only, once, in Wave 5
    (18's lane may carry a temporary red golden until then — sequence 18 late in Wave 4 or accept
    the intermediate failure locally only).
11. **Pinned-summary Track affordance (21) — restated correctly.** This was written as "the board
    puts Track where a test pins the cash chip". Measured, it is worse: the board's strip **deletes
    three pinned strings** (heading, View-summary link, cash reminder) and replaces them with one
    line. Plan: restyle the strip to navy and keep all four strings inside it, with Track as the
    trailing white pill. The test is not to be weakened unilaterally; if the resulting strip reads
    as too dense, the copy question goes to the owner.
12. **Local-vs-CI OMDS skew.** Lanes building locally against the stale clone will see the 2
    baseline errors and cannot use OMDS `identifier:` params. The explicit-`Semantics`-wrapper
    rule (§7.5) is the standing mitigation; checking out `main` in `omds-flutter` locally is
    allowed but never part of the diff.
13. **The density change is the top delivery risk (NEW — from the renders, R1/R12/R14).** Every
    redesigned screen ends its content by ~55% of the viewport, spaces cards at 9–12px and carries
    a mostly-white lower half. This is invisible in the designer notes, unreviewable in a diff, and
    the single easiest thing to quietly skip — and skipping it leaves the app looking exactly like
    it does today under new tokens. Mitigation: the Wave-5 sweep compares each screen against its
    PNG at the same scale, not against a checklist.
14. **Screen 21 is the top engineering risk (NEW).** 1105 LOC, 18 widgets, 43 identifiers, two
    locked-decision collisions, and a net-new quick-reply row and media bubble. Sequence it alone.
15. **Chip-scale drift (NEW — R2).** Five realized pill scales with two different unselected inks,
    consumed by six lanes through one widget. Mitigation: the role enum in §5 #6 — lanes pass a
    role, never a padding or a size.
16. **Two owner decisions block a clean build (NEW).** (a) Screen 12's courier star + call button
    are refused by a privacy test (§7.2-C3); (b) screen 11's third offer is drawn without an Accept
    (§7.2-C4). Both are cheap either way, but both are product calls, not engineering calls, and
    both sit on the two-sided spine.
