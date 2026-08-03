# 02 · Plan enhanced — design critique from the renders

Companion to `00-MIGRATION-PLAN.md` (which has been edited in place with these corrections).
This document is the evidence: what the ten spine screens actually show, measured from the PNGs
and the HTML, checked against the code that ships today.

Method: read all ten renders as images; read all ten `.note.md`; read `04`, `08`, `11`, `17`, `21`
HTML in full plus targeted greps across all 24; opened the current Flutter screens and the tests
that pin the locked decisions. Every number below is measured, not inferred from the token files.

**Scope note:** the plan's Wave 0 has already landed on this branch (`jeeb_text_styles.dart`,
`jeeb_shadows.dart` exist; `app_theme.dart`, `jeeb_color_roles.dart`, `jeeb_semantic_colors.dart`,
`app.dart` are modified). Corrections below are written so Wave 1 can absorb them without
re-opening Wave 0, except where explicitly noted.

---

## 1. The ten screens — what actually changes

| # | Screen | The single most consequential change | Distance from today |
|---|---|---|---|
| 04 | Client home | The buried "+" becomes a navy r24 hero card with a Ø56 orange mic and a hold-to-talk affordance; request rows become outlined cards that lead with a waveform mark and end with a live-state row (`● Broadcasting` / avatar stack + `View offers`). | **Rebuild of the top third + new interaction.** 514 LOC, 6 widgets, 13 identifiers today. The mic hero is a new press-and-hold gesture surface, not a button restyle. |
| 05 | Voice recording | The recording controls move into the bottom thumb zone as a three-part cluster (cancel ← Ø~150 mic → keyboard) with a **max-duration progress arc** around the mic, while a live transcript card sits alone at the top under 60% empty space. | **Rebuild + two new interactions** (slide-to-cancel, arc-as-time-budget). 692 LOC today. The arc is not in the plan's `JeebMicHero` spec. |
| 08 | Tier catalog | Dollar figures are replaced by a **relative price meter** (4 dots + "Highest/Balanced/Lowest price"), every tier gains an SLA chip and a vehicle line, and selection is a navy fill — not a radio. | **Restyle + new derived data.** The file is dead code (devtool-only, route deleted); the live picker is inside `request_type_screen.dart`. Price levels and SLA bands do not exist as fields — they are a fixed product lexicon, so a client-side constant table is the honest answer. |
| 11 | Offers | A three-level emphasis hierarchy: recommended (2px navy + solid-orange "Best value" tab), normal (brown outline + outline Accept), and **dormant (opacity .75 with the entire action row deleted)**; plus a countdown strip with a progress meter. | **Restyle + one real product question.** 512 LOC. The countdown is buildable today (`ClientOffersState.windowExpiresAt`/`windowRemaining` exist). The dormant card is a functional regression as drawn — see §4. |
| 12 | Live tracking | The screen becomes a stack of four fixed blocks — 4-node stepper, r20 map with a floating ETA pill and an orange glowing courier marker, a courier identity card, and an always-visible door-code strip — with a split text/outline footer. | **Restyle, but the courier card is data-blocked.** 677 LOC, 27 identifiers, Maestro `jm-032` frozen. The card's ★ 4.9 and its call button are both deliberately unavailable (§4, C3). |
| 21 | Order chat | The thread becomes WhatsApp-shaped: navy pinned strip with a white `Track` pill, media bubbles (play disc + waveform + photo thumb), outlined/filled system chips as a quiet timeline, and a scrollable quick-reply row above the composer. | **Rebuild of the chrome, restyle of the thread.** 1105 LOC, 18 widgets, **43 identifiers** — the highest-risk file on the board. Quick replies do not exist today. Two locked decisions collide here (§4, C1/C2). |
| 16 | Jeeber home | Three stacked status surfaces before the feed: navy availability strip with a green switch and an inline `Extend`, a 2px-orange-framed active-delivery card, then feed cards whose freshest item carries a **solid-orange `Make offer` CTA with an orange glow**. | **Restyle + one honest-copy fix.** 603 LOC, 9 widgets, 18 identifiers. `AvailabilityCubit.extendActivity()` already exists; the live "1h 40m" figure does not (§5). |
| 17 | Offer composer | The money math becomes the hero: a 2px-navy-bordered price field with ±1 pills, tier-bounded ETA choice pills, a fee breakdown card, an inline wallet strip, and a CTA that restates the kept amount. | **Restyle of an already-correct screen.** 841 LOC. Fee math already computes from `kJeebCommissionRate` at line 196 — the only real change is wording (D41/D44) and shape. |
| 23 | Wallet | A navy balance hero with an on-navy outlined starter-credit pill, then an honest affordability note ("You're set to bid") instead of a capacity number, a reserve explainer, an inline CTA, and a grouped list card. | **Restyle.** 543 LOC, 34 identifiers, contrast-gate-listed → orange only via `jeebRoles.accent`. Introduces the grouped-list-row and info-note patterns the plan is missing. |
| 01 | Onboarding | Abstract slide art becomes a full-bleed navy stage with floating "live marketplace" cards around an orange mic, and a white bottom sheet carrying AR+EN paired copy, a pill page indicator and a `Skip` / `Next →` row. | **Rebuild of the visual, keep the carousel.** 547 LOC, 5 identifiers, 3 pages already exist. The only full-bleed navy screen in the app — and the only screen with no `flex:1` spacer. |

---

## 2. Visual-language rules the images reveal and the notes do not state

These are the things you can only get by looking. They are the difference between "we applied the
tokens" and "it looks like the board".

**R1 — One spacer, one dock.** 22 of the 24 screens are literally `column → content → flex:1 →
footer`. The spacer is *real emptiness*: on 04, 08, 11, 12, 16, 17 and 23 the bottom 35–45% of the
screen is plain white. Never fill it, never vertically centre content, never let a list expand to
consume it. The redesign is a **low-density** design and today's app is high-density — this is the
largest perceptual change on the board and it appears in none of the notes.

**R2 — There are five pill scales, not one chip.** Measured:

| Role | Padding | Type | Unselected ink | Example |
|---|---|---|---|---|
| Filter chip (04, 16) | `11/20` | 14.5/w600 | `onSurfaceVariant` | `Pending 1` |
| Sort chip (11) | `8/15` | 12.5/w600–700 | `onSurfaceVariant` | `Lowest price` |
| Choice pill, flex (17) | `11/0`, `flex:1` | 13.5/w600 | **navy** | `40 min` |
| Meta chip (04 tier, 08 SLA) | `4/10`, `3/9` | 12/w700, 11.5/w700 | navy on `surfaceContainerHigh` | `⚡ Flash`, `≤ 1 hr` |
| Quick reply (21) | `8/13` | 12/w600 | **navy** | `I'm home` |
| Micro badge (08, 11) | `2/8`, `3/10` | 10/w800, 10.5/w800 | white on solid orange | `Recommended`, `Best value` |
| Inline action pill (04, 11) | `9/16`, `9/18` | 13/w600 | navy or white-on-navy | `View offers`, `Accept` |

Note the unselected ink is **not constant**: filters and sorts use brown `onSurfaceVariant`, while
choices and quick replies use navy. One `JeebSelectChip` with a single padding will be visibly
wrong on four of the ten screens.

**R3 — Weight carries the hierarchy; size barely moves.** Almost everything lives between 10px and
15.5px. The ranking is done by weight (500 → 600 → 700 → 800) and by ink, not by size. Only four
things exceed 20px anywhere on the spine: screen title (20), offer price (21), the wallet/earnings
balance (~42) and the code display. **Do not "make it bigger" — make it heavier and darker.**

**R4 — Three inks, strictly ranked, often in one row.** Navy `#0B1351` = the fact. Periwinkle
`#777FC0` = the qualifier of that fact. Brown `#5C4038` = a secondary interactive word. 11's action
row shows all three at once: periwinkle "Pay $8 cash on delivery", navy-filled "Accept", brown
"Cancel request" below. Periwinkle never carries the primary fact; navy never carries a qualifier.

**R5 — Orange marks what is happening or expiring right now — and exactly once it is a button.**
18 of 24 screens carry an orange fill; 04 carries seven. The permitted set, measured: the mic
(01, 04, 05), a live-state dot (04, 11, 16, 21), a count badge (04), a micro badge (08, 11), the
courier marker and the active stepper node (12), the active-delivery disc and the 2px frame (16),
the 30% decorative ring (04, 05, 19, 23) and the 1.5px on-navy pill border (23). Orange **text**:
`Broadcasting`, `Recording — release to send`, `Accept only one offer.`, `Top up`, `How fees work`.
And one CTA: **16's `Make offer` on the freshest feed card is a solid orange pill with an orange
glow** — the second, older card gets the outline treatment. So the plan's "never large fills except
the at-door banner" is too strict; the correct rule is *orange fills the one action that decays*.

**R6 — The navy hero has three behaviours and never two on one screen.** (a) full-bleed screen
background — 01 only; (b) an inset card, radius 20–24, with an off-canvas Ø140 `1.5px accentRing`
circle at the top-END and **no shadow** (04, 23, 19); (c) a one-line status strip, radius 14–16,
**with** shadow `0 8 20 rgba(11,19,81,.25)` (21 pinned, 16 availability). 16 pairs the navy strip
with an orange-framed card precisely because they are different weights of the same "status" idea.

**R7 — The outline is the default; a shadow is a promotion.** Every list card is `1.5px #916F66` on
white at radius 16 (04, 08, 16) or 18 (11), flat. Shadows appear *only* under navy or orange
surfaces. **A white card with a shadow does not exist anywhere on this board.**

**R8 — Selection is a fill swap, never a border swap.** Selected = navy fill + white ink + shadow,
and every chip inside it re-tones to `rgba(255,255,255,.14)` fill, `.7` ink, `.25` empty dots. 11's
`2px navy` border is *recommendation*, not selection — do not conflate them.

**R9 — De-emphasis is opacity, and it removes affordances.** 11's third offer card is
`opacity: .75` **and** its entire second row (cash line + Accept) is deleted. The board therefore
has a "dormant list item" state that is functionally reduced, not merely faded. See §4 C4 —
as drawn this is a product regression.

**R10 — Icons: filled, single-colour, five sizes.** 14 / 17 / 18–20 / 22 / 24 px, navy or
periwinkle, no outline or two-tone variants anywhere. Circle icon buttons are Ø40 in a top bar and
Ø46 in content, filled `surfaceContainerHigh`, glyph 17–20px navy. Tier marks are **emoji at 17px**,
never icons.

**R11 — Avatars carry three signals at three sizes.** Ø30 in a stack (2px white ring, −9px overlap,
initial 11/w800), Ø42 in a list or thread (15/w800), Ø46 in a screen header (17/w800). The fill
rotates navy → periwinkle → orange; a **`surfaceContainerHighest` fill with a periwinkle initial
means unknown/dormant** (11's Rami, 04's own user). The dot is two different components sharing a
shape: **orange at the top-END = unread** (04), **green at the bottom-END = presence** (21).

**R12 — Lists breathe at 9–12px; sections at 14–20px.** Card gaps: 9 (08), 11 (11), 12 (04).
Section gaps: 14–20. In-card, the identity row and the action row are separated by exactly
`margin-top: 12`. The screen gutter is always 24. **Nothing on this board is spaced at 28 or 32** —
the plan already caught this, and the measurements confirm it.

**R13 — Money is always a two-part unit.** A navy w800 amount with a periwinkle w600 qualifier
directly beneath it, right-aligned: `$8` / `in 40 mins`; `$6.40` / `USD`; `$7.20` under
`You keep (cash)`. A money figure never appears as a single line.

**R14 — Section labels are one of two sizes, and one of them is what shipped.** Realized:
**11px on 05** (a dense overlay context) and **12.5–13px on 15, 17, 19, 20, 23** — all w700 /
ls 1.2 / uppercase / periwinkle. Wave 0 shipped `sectionLabel` at **11px**, which is the minority
case; eight of the nine occurrences are 12.5–13. See §3 for the fix.

---

## 3. Shared-component list — corrections

### 3.1 Components the images do not support

- **`JeebSemanticColors.readTick` (`#20F0FF`) has zero occurrences across all 24 screens.**
  `--jeeb-cyan-check` is a token-file leftover. Screen 21's read state is the literal text
  `9:25 · Read` at 10/w600 **periwinkle**, inside the outgoing bubble's meta line. The token has
  already shipped in Wave 0 — do not churn the theme to remove it, but **no lane may consume it**,
  and `JeebChatBubble` must render the text form.
- **`accentTint` is not a badge family — it has exactly one consumer board-wide** (07's
  "Most picked", `rgba(215,59,0,0.12)`). The dominant badge treatment is the opposite: **solid
  `--jeeb-orange` fill with white w800 ink** (08 `Recommended` 10/w800, 11 `Best value` 10.5/w800).
  The plan's rule "badge ink on it = accent at w800" describes the exception, not the rule.
- **`JeebTierRow.compact` / `.catalog` as one file** is fine, but the price meter inside `.catalog`
  should be its own widget — its on-navy inversion (white dots / `.25` empties / `.7` caption) is
  where the bugs will be, and 07 needs it too.

### 3.2 Components the plan is missing (all repeat across the spine)

| New widget | Where it repeats | Spec (measured) |
|---|---|---|
| **`JeebInfoNote`** | **08, 11, 12, 17, 23** — five of the ten | Radius 14–16, pad `11–12/16`, gap 10, leading glyph 14–17px. Tones: `muted` (`surfaceContainerHigh` + periwinkle 12.5/w500 lh18), `success` (`successContainer` + navy w700 title + periwinkle sub), `accent` (navy text + orange w700 trailing link). Optional trailing: meter (11), value (12's `2 1 4 4`), link (17's `Top up`). |
| **`JeebProfileHeader`** | 04, 16 (+19) | Ø46 avatar with optional dot, eyebrow 13/w600 periwinkle, name 19/w700 navy, trailing 24px glyph **or** a rating pill (`surfaceContainerHigh`, `★ 4.8`). This is what 04/16 have instead of a `JeebTopBar`. |
| **`JeebMoneyBreakdown`** | 17 (+14, 19) | Outlined r16 pad `15/16`; rows 13.5/w600 periwinkle label + navy w700 value; 1px `outlineVariant` divider with `10/0` margin; total row 15/w800 with a 17px value; footnote 11.5/w500 periwinkle + 14px lock glyph. **The single place D41/D44 wording is enforced.** |
| **`JeebListRow`** (in a grouped `JeebOutlinedCard`) | 23 (+20) | Navy glyph, title navy w700, subtitle periwinkle, trailing periwinkle chevron; inset 1px divider between rows. |
| **`JeebQuickReplyRow`** | 21 | Horizontally scrollable outline pills, pad `8/13`, 1.5px outline, 12/w600 navy, gap 8, `nowrap`. Does not exist in the app today. |
| **`JeebStepperPill`** (±1) | 17 | Pad `6/12`, r999, 1.5px outline, 12.5/w700 navy, gap 6. |
| **`JeebPriceMeter`** | 08 (+07) | 4 × Ø7 dots, gap 3, orange filled / `surfaceContainerHighest` empty, caption 10.5/w700 periwinkle, right-aligned column gap 3; on-navy inversion as above. |
| **`JeebPageDots`** | 01 | Active = 28×8 orange pill; inactive Ø8 `surfaceContainerHighest`; gap 6. |

### 3.3 Corrections to components the plan already has

- **`JeebTopBar`** needs a `leading` mode — `back` (08, 11, 12, 23), **`close` ×** (17), or an
  identity block (21: back circle + Ø42 avatar + name + sub). And a real `trailing` slot: 12 carries
  a chat glyph, 21 a phone glyph, both Ø40 `surfaceContainerHigh`. Note 04 and 16 use
  `JeebProfileHeader` instead — they are not top bars.
- **`JeebCtaFooter` has three realized forms**, not one padding: **single pill** (08 h56, 17 h58,
  pad `0/24/32`); **split row** (01 `Skip` text + expanded `Next →` pill; 12 `Report no-show` text +
  `Open dispute` outline pill); **text stack** (11 orange w700 line + brown w600 link, no pill at
  all). Footer bottom padding is 30 **or** 32 depending on screen — pick 32 and note the divergence.
- **`JeebOutlinedCard` and `JeebNavySurfaceCard` are one state machine**, not two components:
  unselected = white + 1.5px outline + flat; selected = navy + shadow + re-toned internals (R8).
  Building them as strangers guarantees the selected variant drifts. Add the **dormant** state
  (opacity, actions removed) as an explicit named state so §4 C4 is a conscious choice, not a
  side effect.
- **`JeebNavySurfaceCard` must allow `shadow: none`** — 04's r24 hero has no shadow (it relies on
  `overflow: hidden` + the accent ring). The plan's spec implies a shadow is always present.
- **`JeebMicHero` needs a progress ring.** 05 draws a max-duration arc around the Ø~150 mic. Also
  the exact Ø56 glow is a **two-shadow stack**: `0 0 0 6 rgba(215,59,0,.22)` +
  `0 10 22 rgba(215,59,0,.45)`.
- **`JeebWaveform` has four realized modes**, not two: *card mark* (4 bars w3, h8–15, orange, last
  at .4 — 04, 16); *on-navy* (5 bars w3, h9–20, white .4/.55 with two orange — 04 hero); *in-bubble*
  (5 bars w2.5, h8–15, navy at .4–.7 — 21); *live recording* (~11 bars, orange with an alpha tail —
  05, 01).
- **`JeebChatComposer`**: the board's left glyph is an **attach/photo** action, and `ChatComposer`
  already ships `attachButtonKey`, `sendButtonKey`, `textFieldKey`. Spec the composer as
  `[field] [attach 19px periwinkle] [Ø38 navy circle = SEND]`. The board puts a mic in that circle;
  B04 refuses it (§4 C2).
- **`JeebAvatar`**: add the **orange unread dot at top-END** (04) alongside the green presence dot at
  bottom-END (21) — same shape, different meaning, and both must be directional.
- **`JeebSectionLabel` / `jeebText.sectionLabel`**: the shipped 11px is the minority reading. Add a
  standard 12.5px variant and keep 11px as `sectionLabelSmall` (05 only). Also: 17 renders a
  **non-uppercase, unspaced w600 trailing hint** inside the same label
  (`PICKUP ETA · Flash allows ≤ 60 min`) — the widget needs a `hint` slot, not a second Text.

---

## 4. Conflicts with locked decisions and backend contracts

Stated plainly. Each is verified against the test or the parser, not assumed.

**C1 — Screen 21's pinned strip violates the pinned vocabulary on three counts, not one.**
`test/features/chat/order_chat_pinned_summary_labels_test.dart` pins: heading = the human order
reference (`ORD-…` / `#XXXXXX`), link = `"View summary"`, cash reminder = `"Pay cash on delivery"`,
status chip = the canonical `deliveryStage*` vocabulary, unresolved values = localized `"Pending"`.
The board's navy strip reads `Medicine · In transit · $8 cash` + a white `Track` pill: the heading
is the item name, there is **no** View-summary link, and the cash reminder has been inlined.
**Resolution: restyle the strip to navy r14 + shadow + white Track pill, and keep all four pinned
strings inside it.** That satisfies the test and the design's intent. The plan's risk #11 framed
this as "add Track alongside" — the real problem is that the board *deletes* the pinned strings.

**C2 — Screen 21's composer is refused (B04), and the board has no send button at all.**
`test/features/chat/chat_composer_no_mic_b04_test.dart:102` asserts `find.byIcon(Icons.mic_none)`
finds nothing and pins `sendButtonKey` / `attachButtonKey` / `textFieldKey`. The board's Ø38 navy
circle is a **mic** — it occupies the send slot, so this is not "add a mic", it is "replace send
with a mic". Build the circle as **send**; keep the attach glyph (which the board also draws).

**C3 — Screen 12's courier card asks for two fields the app deliberately destroys.**
`DeliveryTrackingInfo.fromTrackingJson` nulls `phoneE164`, `rating` **and** `avatarUrl` on the
in-flight slice, and `test/delivery_tracking_jeeber_parse_test.dart:44–64` asserts all three
("blind-reveal / privacy guard"). The board draws `★ 4.9` and a Ø46 call button on that exact card.
**Build the card with the initial-disc avatar, name, vehicle and cash — no star, no call button.**
A gated contact path does exist elsewhere (`DeliveryStatusCubit.requestContactNumber()`, with a
`contactUnavailable` state), so if the owner wants a call affordance on tracking it must route
through that gate; the star cannot return without amending a privacy test. **Owner decision.**

**C4 — Screen 11's third offer cannot be accepted, and that is a product regression.** The HTML
applies `opacity: .75` to the whole card *and* deletes its action row (cash line + Accept). Every
offer must remain acceptable — "Accept only one offer." is a statement about exclusivity, not about
which offers are actionable. **Build all cards with a full action row.** If the owner wants the
dimming as a ranking signal, it must be visual only. **Owner decision, low cost either way.**

**C5 — "Jeeb fee (10%)" is a D41/D44 violation, and the board writes `10%` four times.** 17's
breakdown row and 23's affordability + fee-explainer copy all spell the rate literally. Render as
**"Platform fee (10%)"** via l10n, with the number computed from `kJeebCommissionRate`
(`lib/core/jeeb_commission.dart:71`). 17's math already does this at
`offer_submission_screen.dart:196` — only the label is wrong.

**C6 — Screen 04's "12 Jeebers reached" is the one number on the spine with no source.** The offer
floor ("from $8") is derivable from the offers already in state; the reach count is not. Omit it
with a `TODO(redesign-24)` rather than faking it (the JEBV4-176 lesson).

**C7 — Screen 08's vehicle line is tier metadata, not a vehicle contract.** "Bike / scooter",
"Any vehicle" must ship as **new** l10n keys; the D20-banned keys must not reappear. Separately,
the board draws the vehicle glyph on Flash only and omits it on the other four — a design slip.
Render the glyph on all five.

**C8 — Screen 16's magnifier is NOT a resurrection of the deleted search.** The jeeber feed already
ships a live search bar (`jeeber_feed_tab_view.dart:62`, `searchBarKey`). Collapsing it into a Ø46
circle is a restyle, and a lane should not refuse it by mistake. (The deleted search was elsewhere.)

**C9 — Screen 01's `Skip` is legitimate.** D56's no-skip rule is about the mutual-rating screen
only. Written down because a lane grepping for "skip" will otherwise hesitate.

**C10 — Screen 12's four stepper labels must map onto the existing stage vocabulary.**
Ordered / Picked / In transit / Delivered has to resolve through the existing `TrackingStage` enum
and the `DeliveryStatusAlias` dual-read table — do not introduce a fifth name or reorder.

---

## 5. Data-gap corrections (three of the plan's "likely casualties" are not gaps)

Verified in code:

- **11's offer-window countdown is buildable today.** `ClientOffersState.windowExpiresAt`,
  `windowRemaining` (clamped) and an injected `now` all exist. The plan named this one of the three
  most likely casualties; it is not. Build the strip with its meter.
- **16's `Extend` is buildable today.** `AvailabilityCubit.extendActivity()` exists, with
  `AvailabilityInactivityPolicy` (warn at 7h30, auto-offline at 8h) and a `warningVisible` flag.
  **But the state exposes a boolean, not a remaining `Duration`** — so the literal
  "goes offline in 1h 40m" is *not* available. Ship the honest form: the warning copy + `Extend`,
  and `TODO(redesign-24)` the live countdown.
- **17's fee math is already correct** — computed from `kJeebCommissionRate`. Only the label changes.

Still genuinely gapped on the spine: 04's reach count; 11's review counts `(127)` and "3 km away";
12's courier star (blocked by C3, not merely missing); 16's per-card distance + neighbourhood;
21's "usually replies in 1 min"; 23's starter-credit flag and reserved-amount breakdown.

---

## 6. Build order for the shared kit

Ordered by how many lanes each unblocks and by where drift is most expensive.

1. **`JeebOutlinedCard` + `JeebNavySurfaceCard` (one PR, one state machine).** Every other component
   sits inside one of them, and selected/unselected is a single state machine — splitting it
   guarantees the navy variant drifts from the white one.
2. **`JeebInfoNote`.** Five of the ten spine screens, zero dependencies. If it lands late, five lanes
   hand-roll five different grey panels in the same week.
3. **`JeebTopBar` + `JeebProfileHeader`.** Unblocks 17 of 24 screens and owns the `<screen>_back`
   identifier contract; must exist before any lane edits a header.
4. **`JeebCtaButton` + `JeebCtaFooter` (single / split / text-stack).** The docked footer is the
   universal structural element — 22 of 24 screens have exactly one `flex:1` spacer above it.
5. **`JeebSelectChip` + `JeebChipRow`, with the R2 size table baked in.** Chips are above the fold on
   04, 11, 16, 17 and 21; the size table must exist before three lanes each invent a padding.
6. **`JeebAvatar` + `JeebAvatarStack`** (with both dot semantics). Needed by 04, 11, 12, 16, 21;
   cheap to build and easy to get directionally wrong.
7. **`JeebMeter` + `JeebPriceMeter`.** 11's countdown and 08's tier meter; the on-navy inversion is
   the only hard part and it should be solved once.
8. **`JeebWaveform` (4 modes), then `JeebMicHero` (+ progress ring).** The signature marks. Waveform
   first: the hero does not contain one, but 01, 04, 05, 16 and 21 all need the mark.
9. **`JeebStepper`.** Only 12 and 18, but it is the highest-risk widget for RTL and it carries the
   frozen `tracking_step_*` Maestro identifiers.
10. **`JeebChatBubble` + `JeebSystemChip` + `JeebChatComposer` + `JeebQuickReplyRow` (one PR).**
    One screen, but 43 identifiers to preserve and the B04 refusal — keeping them in a single
    reviewable diff is worth more than parallelism here.
11. **`JeebMoneyBreakdown` + `JeebListRow`.** Pure composition over (1), and the single enforcement
    point for D41/D44 wording — so it lands after the wording decision is settled.
12. **The remainder — `JeebCodeCells`, `JeebNumericKeypad`, `JeebTierRow`, `JeebSegmentedToggle`,
    `JeebPageDots`, `JeebStepperPill`, `JeebAccentFrameCard`.** Each serves ≤2 screens outside the
    spine; none blocks another lane.

---

## 7. What this changes about the plan's risk profile

The plan's biggest stated risk was data gaps. After measuring, the biggest risks are, in order:

1. **Screen 21** — 43 identifiers, two locked-decision collisions, and a from-scratch quick-reply
   row and media bubble. It should be sequenced alone, not in parallel with the rest of Wave 4.
2. **The density change (R1/R12/R14).** Every screen gets emptier and lighter. This is invisible in
   the notes, unreviewable in a diff, and the thing most likely to be quietly ignored — which would
   leave the app looking exactly like it does today under new tokens.
3. **Screen 12's courier card (C3)** — the only place on the spine where the design asks for data
   the app destroys on purpose. Needs an owner decision, not an engineering workaround.
4. **Chip-scale drift (R2).** Five scales, six lanes, one shared widget. Bake the table in.
5. Data gaps — real, but three of the loudest ones turned out to be already buildable.
