# MIDNIGHT — Fable study notes & kit rulings (accumulating)

One section per studied tile. These are ORCHESTRATOR observations + rulings; implementers still
do their own STEP-0 tile read.

## R1 · Client home (studied 2026-08-03)

- Header: avatar disc (surfaceHigh navy, white initial) · "Good evening" inkMuted small over
  "Hello, Lina" white w700 ~17 · bell icon white top-end.
- Hero: "What do you need tonight?" white h1 (2 lines) + Arabic tagline "جيب لي أي شي" in
  ORANGE, brand Arabic face — a tile-drawn orange moment (budget-sanctioned).
- Voice capsule: full-width glass pill (capsule radius), orange mic disc w/ glow at start,
  "Hold to talk" white w700 / "or tap to type" inkMuted, small orangeSoft waveform glyph at end.
- Active-request card: glass lg; waveform icon + title white w700; row 2: "⚡ Flash" navy chip,
  "● Broadcasting" orange w/ dot (jBreathe), "12 Jeebers reached" inkMuted end-aligned.
- Awake card: glass lg; 3-disc avatar stack (navy/periwinkle/orange), "7 Jeebers awake near
  you" white w700, "Offers in minutes · cash at the door" inkMuted, live orange dot end.
- Floating pill nav: detached capsule, navy surface + glass border, floatNav shadow. 5 tabs:
  Requests · Delivery · Dashboard · Earnings · Profile. Active = orange rounded-square pill
  behind icon + white label; inactive = periwinkle icon + label (~10.5). Orange ONLY active pill.
- Field: hero variant — orange glow top-end, periwinkle wash start, orbit arcs top-end.

## E1 · Empty — no requests (studied 2026-08-03)

- Header persists. Segmented control below: **active chip = WHITE fill + navy ink** (ruling:
  this is the Midnight segmented-active treatment), inactive = glass chip + periwinkle ink.
- Illustration (the JeebEmptyState canon): center orange mic disc (gradient + glow, jBreathe/
  jHalo) flanked by orangeSoft waveform bars; FOUR icon medallions (medicine, groceries,
  document/envelope, gift) in navy glass discs with flat two-tone icons (white/periwinkle
  bodies, orange accents) orbiting on the dotted route-ring (dasharray 1 9, jDash); jTwinkle
  stars; a periwinkle route dot on the ring; medallions drift (jFloat).
- Headline "What do you need?" white w700 centered; body inkMuted 14.5 centered 2 lines.
- Voice capsule pinned bottom: "Hold to talk — Jeeb it" / "or tap to type your first request".
- Nav not drawn in tile but coexists in-app (R1 shows it).

## Kit rulings extracted (bind M1)

1. `JeebEmptyState` API: field + composed illustration (configurable center + medallion icon
   set, defaults = E1) + white headline + inkMuted body + optional CTA. Loading state = same
   skeleton with jBreathe; error = danger-tinted center. E1 samples A/B/C are alt center
   compositions.
2. Floating pill nav (`M1-4`): 5 fixed slots, always-visible labels, active-pill orange
   rounded-square on icon only. Tab label/route mapping is decided at M2-01 (product
   semantics), not in the kit.
3. `JeebSegmentedToggle` restyle: active = white fill/navy ink, inactive = glass.
4. Chips on navy ("⚡ Flash"): solid deep-navy pill (surfaceHigh) + white label, NOT glass.

## Motion rulings (M0-4, ratified 2026-08-03)

- Defaults accepted: jBreathe 2.6s (range midpoint), jTwinkle 2.4s (+3s slow variant),
  jWave bar stagger 120ms, jBreathe stagger caller-supplied, dash default 5/5.
- Dash patterns are per-surface: map route = `5 6` (measured) → call sites MUST override
  travel to a multiple of 11 (e.g. −44) for a seamless wrap; orbit rings = `1 9` (period 10
  divides −40, fine as-is).
- Midnight primitives loop ∞ (board-faithful), unlike the bounded `JeebLottieMark` rule.
  Consequence: screen tests advance with `tester.pump(duration)`; `pumpAndSettle` only under
  reduce motion. **Catalog captures run with `disableAnimations: true`** so every capture is
  the deterministic rest frame (M0-9 harness must set this).

## Wave-A review rulings (2026-08-04)

Kit fixup round 2 (all board-measured, Fable-sanctioned): `JeebCtaButton.accent` (accent fill /
onAccent / ctaOrange shadow / orangePressed) replacing R9+R12 Theme-swap workarounds ·
`JeebWaveform` live ink → `#D73B00` (R2 measured 431px exact) + new `playbackBand` profile
(R12: 6-bar/h26 full-orange) · R12 ticket chips = GLASS (measured white .10; M1 ruling 4
narrows to "solid only where a tile draws opaque", R1) · `JeebEmptyState` medallions become
custom two-tone art (E1 caption: "no stock art") + compact/inline variant (R11) ·
`JeebSegmentedToggle` trackless option (E1 free pills) · `JeebNavySurfaceCard.selectedShadow`
default → NONE (glow only where a tile draws it; accentSelected carries its own) · capture
harness sets `debugShowCheckedModeBanner: false` · R9 badge keeps tinted treatment on lit rows.

Accepted as shipped: R9 pre-selects Standard (carry-in beats the tile's drawn Flash frame) ·
R11 `onCameraIdle` gate (map-unavailable explicit state queued to M4) · R2 rest-frame captures
are the capture truth (M5 does live side-by-side) · R2 cubit `initialState` harness param ·
shell badge kept (product feature, renders error-red, no orange spend) · closest-Material
glyphs where no exact match exists (earnings note → §8) · Maestro jm-027 AC2
behaviour-preserving reading (QA note → §8). Deferred deaths: `ClientHomeEmptyMark` (M5 audit),
tier catalog helpers + `JeebTierRow.catalog` (M3), R12 voice-band fixture gap (M4).

## M1 kit-review rulings (2026-08-04, post-workflow)

Confirmed as shipped: glass-capsule default radius = pill · pill nav strict 5 slots, navy
surface (sheet §4 corrected), active label `onSurface` · composer/bubbles pre-baked
translucency (screens own real blur) · glass border 1px everywhere · badge pair
`accentContainer`/`onAccentContainer` · segmented gap 5 · mic `large` glow → `ctaOrange` ·
avatar `dormant` unchanged. Fixup lane added: accent selected card state (R9, orange 20%/2px/
glow), `glassBorderVivid` 22%, R20 outgoing bubble orange-tint (fill 24%/border 45%, white
body, tail-corner 6). R20 outgoing waveform bars = white on the tinted fill (now non-inert).

## Motion-study rulings (2026-08-04 — 03-MOTION-NOTES.md is authoritative per element)

1. Board-still tiles ship STILL (R1 incl. broadcast dot + rings, R3's map route, E1's ring
   and medallions, 20 of 30 tiles total). Field consumers on still tiles disable decor
   animation — `JeebMidnightField` gains an `animateDecor: false` knob at M2-02 (sanctioned).
2. jWave is CONTAINER-level (one scaling row); never add per-bar stagger the board lacks.
3. Motion-module defaults unchanged; per-element durations come from 03-MOTION-NOTES at
   wiring time (board ranges are wider than §2.6's column).
4. Do NOT add: R20 typing indicator, R15 star twinkle — tempting, board-absent.

## Wave-B review rulings (2026-08-04) — BINDING

**Sanctioned kit/theme changes** (batched into the wave-B fixup lane; kit re-freezes after):
1. `JeebEmptyStateVariant.radar` — E2's concentric-ring waiting state. Sanctioned because
   03-MOTION-NOTES lists "Concentric ring pulse | E2, W2, sample C" as a *recurring* composite,
   not a one-screen widget. Rings `jArcPulse` 3s on a **1 / .5 / 0** outward-to-inward delay
   ladder, centre glow `jBreathe` 3s, three avatars `jBreathe` 2.6s at 0 / .8 / 1.6s.
2. `JeebEmptyStateVariant.street` — E3's night-street scene. E3 is one of §2.7's four canonical
   instances, so it gets a real variant rather than `balcony` (which draws a request bubble and a
   `jDash` route E3 does not). Lamp bulb + cone `jBreathe` 3.6s as ONE element; two listening arcs
   `jArcPulse` 2.2s at 0 / .45s. This tile's sparkles are STATIC, unlike E1/E4.
3. `JeebAvatarFill.glass` — board Ø74 disc is white ~22% with a WHITE initial. Existing rungs are
   both opaque navy and `dormant` also forces periwinkle ink. Unblocks R15 and E2's initial discs.
4. `JeebCodeCells` display border `glassBorderStrong` (.16) → `glassBorderVivid` (.22) — R13
   measures .22, which is exactly the cluster `glassBorderVivid` was added for.
5. `JeebStepper` bar `doneInk` (fill-through colour) — R3 fills passed segments ORANGE, R18 fills
   them periwinkle. Two tiles genuinely disagree, so this is a parameter, not a per-screen repaint.
   Removes the feature-side duplication M2-08 shipped. Must land before M2-14 (R18).
6. `JeebFieldWashPlacement.topStart` (≈0.10, 0.03) — R14 measures its decorative lift top-start.
7. **`_glowRadiusFactor` 1.35 → 1.18** — see 01-TOKEN-SHEET §8 CORRECTION. Affects every screen.

**Rejected / clamped:**
- R14's zoom chip measures a white **31%** border. The ladder tops out at `glassBorderVivid` 22%
  and stays there — one outlier chip on one screen does not earn a fourth rung. Clamp, note it.

**Standing rulings (no kit change):**
- Bottom sheets are NOT automatically the `sheet` (26) rung. R3 measures ≈21dp → `xl` (22) wins.
  Measurement beats the semantic name; the ladder's "snap to nearest, ±2" rule governs.
- `onSurface` (`#EDEFFC`) is the heading ink app-wide. Tiles that read pure `#FFFFFF` do not
  override §1 — do not shift the hex per screen.
- Offer meta line keeps the **vehicle** run until `distanceKm` exists on the wire. Real data beats
  a blank slot, and three tests (incl. an Arabic assertion) pin it. doc-13's "defect" framing
  assumed distance was obtainable; it is not.
- R10's third offer card ships **un-dimmed and actionable**. The tile's "recede" is a marketing
  metaphor; §7.2-C4 (every offer stays acceptable) is a product rule and wins.
- E2's "Add details to attract offers" CTA stays **unmounted** — no add-details route or seam
  exists anywhere, and a CTA with no destination is worse than an absent one. Key stays queued.
- R16's extra bands (3 tab chips + search toggle + tier band vs the tile's 2) **stay**. Their
  identifiers are frozen and Maestro-pinned; ground rule 6 outranks tile-count fidelity.
- R15 tag chips ship **board-faithful** (33dp targets). Wrapping them in `MinTapTarget` inflates
  the measured 8dp run gap to ~22dp and breaks the 3+2 rhythm. Routed to the M6 a11y sweep, which
  should decide it once for all inline chip rows rather than per screen.
- Catalog mounting live-tracking with `useLiveMap: false` is **accepted** — it cures 2 of the 4
  known harness render failures and the capture harness was never the place to exercise a live
  GoogleMap platform view.
- `JeebMoneyBreakdown` is NOT consumed on R14: the widget forbids a fee line on customer surfaces
  and R14 draws one inline sentence. Consume its *treatment*. §3's carry-in line was corrected.

**Regression attribution (measured, not assumed):** `test/core/router/` is **38 red**, and it is
red identically at `fc93ace9` (pre-wave-B) — verified by running the suite in a worktree at that
commit. Wave B introduced none of it. Cause: the shell's home tab mounts `JeebEmptyState`, whose
E1 illustration loops ∞ *by design* (7 animated elements), so `pumpAndSettle` can never settle.
This is a **test-harness gap, not a spec violation** — R1's field decor is correctly static
(`animateDecor: false` at `client_home_screen.dart:208`). Fix is the sanctioned one from §Motion:
`disableAnimations: true` in the harness. Wave A missed it because the full suite only runs at
wave gates and wave A was not a gate. **Lesson: run the router/shell suites at every wave close,
not only at gates.**

**Live defect — CORRECTED 2026-08-04, my first diagnosis was WRONG.** I originally recorded this
as "`CaptureLocationScreen._onPin` pops with no value, so `pickOnMap()` resolves null, and it
predates Midnight." The fixup lane refuted it and I verified the refutation directly:
**neither live call site ever reaches that branch** — `google_map_picker_launcher.dart:47` and
`app_router.dart:182` both pass `onPinned` and both pop `cameraLive ? controller.center : null`.
The real cause of the null is **M2-05's JEBV4-176 camera-liveness gate** (`onCameraSettled` /
`cameraLive` did not exist before M2-05), which is *ratified wave-A behaviour*, not a defect —
and the two launcher tests were GREEN before M2-05, so this is a **wave-A regression**, not a
pre-existing one. Disposition: the stale launcher tests were realigned to the ratified contract
(their non-contradictory coverage kept), and `_onPin`'s valueless branch was still fixed to pop
`controller?.center` as defensive correctness with a new regression guard.
**The genuine risk survives and is NOT closed** (§8 Q-021): on a real device a Confirm tap landing
before the first `onCameraIdle` silently returns null, so "Edit pin" discards the user's choice.
Note the verify set as I briefed it was internally contradictory — `pin_location_coordinate_
survives_b35_test.dart` asserts the confirm pops WITHOUT a coordinate, which is the same condition.
**Lesson: a diagnosis handed to an implementer is a hypothesis, not a finding — say so, and let the
lane refute it.**

## Wave-B FIXUP outcomes (2026-08-04) — all 7 sanctioned changes landed

Kit re-frozen again at **757/757** (kit+theme) and **613** in `test/core/widgets/jeeb` alone.
- Added: `JeebEmptyStateVariant.radar` / `.street`, `JeebEmptyMedallion.letter()`,
  `JeebEmptyState.radarMedallions` / `medallionsFor()`, `JeebAvatarFill.glass`,
  `JeebStepperDoneInk{periwinkle,accent}` + `JeebStepper.bars(doneInk:)` (default = today's
  behaviour, so no existing caller moved). `JeebCodeCells` display border → `glassBorderVivid`.
- **`_glowRadiusFactor` 1.35 → 1.18.** Finding worth keeping: **no test held the old value** —
  all 28 field tests were relational or pinned points already outside the fade stop, so the wrong
  factor was invisible to the suite. A discriminating test was added and *proved* discriminating
  (reverting the const fails it at 115.36 vs 103.09 expected).
- `test/core/router/` **95/38 → 133/133**. Two edits were needed, not one: the reduce-motion
  wrapper, and then draining a 150ms fake-latency timer in `InMemoryClientHomeRepository` that the
  timeout had been *masking*. **Anyone applying the wrapper elsewhere must pair the two.**
- R3's stepper duplicate deleted; the two stepper-bearing captures came back **byte-identical**,
  which is the strongest available proof the kit widget reproduces the deleted painter exactly.

**Ruling — the periwinkle wash is per-tile, not a constant.** The fixup lane asked whether
`bottomEnd`'s `radiusFactor: 1.0` is the same class of error as the glow's 1.35. It is not
resolvable the same way: the board draws the wash at rx **460 / 480 / 500 / 520 / 600 / 700 / 900**
across tiles (factors 1.05–2.05), with no cluster, whereas the orange glow sits tightly at 500–560.
So there is no single ratifiable wash factor. `startMid` is pixel-measured on R1 and stands;
`bottomEnd` keeps 1.0; **any screen adopting a wash placement measures its own tile and passes an
override.** Also confirmed: the trailing `1.35` in the `startMid(...)` tuple is the *aspect*, not a
radius — correctly left alone.

**Accepted from the adoption lanes:** E2 pins one existing test to the board canvas (440×956)
rather than loosening a 1px centring tolerance — right call. E2's error form keeps a local
"no signal" centre so a failed load does not bloom a live broadcast glyph. E3's lamp reads at 45%
in stills because `JMotionLoop` pins reduce-motion at the breathe rest opacity — kit-wide
convention, not an E3 miss.
**Deferred to M4 (states sweep):** `JeebEmptyState._skeleton()` still paints E1's 4-disc 300×280
shape for *every* variant, so E2 loads a 4-disc skeleton that morphs into a 3-disc radar. It is a
kit change and M4 owns loading states.
**Deferred to M6:** the kit's own E3 colour deviations (background glow on `#8A93D8` vs the board's
legacy `#777FC0`; ground shadow as page-navy @ .45 vs black @ .35).

## Wave-C review rulings (2026-08-04) — BINDING

**MY ERROR, now corrected:** wave-B ruling 6 (`JeebFieldWashPlacement.topStart`) was sanctioned in
these notes but **never briefed to either kit lane** — I listed 7 changes and wrote only 6 into the
fixup prompts. R14 shipped on `startMid` and R17 hit the same wall. The M2-13 lane also established
the board is **directional per tile**: R4/R9/R17 draw the decorative bloom **top-start**;
R1/R6/R8/R12/R19/R22/R23 draw it **top-end**. So `topStart` is not a one-screen convenience — it is
the anchor for a whole class. Landing in the wave-C fixup, with R14/R17 adopting and R4/R9 re-checked.
*Lesson: a ruling that is recorded but not transcribed into a lane prompt does not exist.*

**Newly sanctioned kit changes** (wave-C fixup lane; kit re-freezes after):
8. `JeebFieldWashPlacement.topStart` (≈0.10, 0.03) — above.
9. `JeebEmptyStateVariant.parcel` — E4's open glass parcel box with the mic glowing inside. E4 is
   one of §2.7's four canonical instances, which is exactly the argument that carried `radar` and
   `street`. `pocket` has no orbit ring and adds a `jFloat` E4 does not draw; `e1` (what M2-17
   shipped) keeps E4's exact glow/sparkle timings but over-draws the waveform ears and 2 star dots.
10. `JeebAccentFrameCard` frame fill — R21's in-motion row measures an **orange 10–12%
    (`accentTint`) fill inside the accent frame**; the kit keeps `JeebOutlinedCard`'s white-7% glass.
    `accentSelectedFill` (20%) is too hot. **R16/R18/R20 are the other frame consumers and must be
    re-measured with it** — do not assume this is an R21-only change.
11. `JeebStepperDoneInk.washed` — R18's PASSED bars measure white ~33% (`#626794`), not the ratified
    periwinkle `#8A93D8`. **Ruling: a third enum value, NOT a new glass-fill rung.** The glass ladder
    is 7/10/14 and a 33% fill would blow it open (and repeat the R14 clamp argument I already
    refused); the stepper enum exists precisely because tiles disagree about this one ink, so the
    semantic belongs there. R3 keeps `accent`, R18 moves to `washed`.

**Non-kit fixups sanctioned in the same wave:**
- **`InMemoryClientHomeRepository`'s default `latency: 150ms`** becomes `Duration.zero`, with
  callers opting *in*. It is a frameless `Future.delayed` that every widget test mounting the shell
  must know to drain — it is the entire root cause of the "Edit B" class that cost two lanes real
  time. This is the product-code shape fixing itself instead of 15 harnesses compensating.
- A **guard test** asserting that any harness mounting `ShellScreen` sets `disableAnimations`. The
  reduce-motion `builder:` is now load-bearing in **15 harnesses**, trivially omitted on a new one,
  and fails in a way that reads as a product bug. Makes the wave-close lesson mechanical.
- `order_history_date_filter_sheet.dart` restyle — a **light-theme Material/OMDS sheet still
  shipping** on a screen we just marked done. Its goldens were 99.87% stale at baseline.
- Order-history **Completed/Cancelled catalog states** (needs a tab-preselection seam), then delete
  the one-off `test/tools/m2_17_capture_test.dart`.

**Standing rulings:**
- R21 expired-row dimming: the tile is **not a uniform fade** (fill d≈0.41, title d≈0.62, meta and
  `Re-broadcast` d≈0.80). A 0.65 blanket puts the meta run under 4.5:1. Recommendation attached to
  owner Q6: dim the **fill** near 0.41 and hold **ink** at 0.80, which matches the tile's own ink
  alphas and stays near AA. Shipped at 0.65 pending sign-off.
- R21's green completed-check stays navy-knockout on green. The board draws white-on-green, but
  §2 ratifies `onSuccess = #070C33` because white on `#3BB273` fails AA. **The token wins over the
  tile when the tile loses an AA pair** — same principle as the retired brown-on-white guard.
- `chat_header_contrast_test` is a **pass-1 instrument measuring a pre-Midnight palette** — verified
  5-red at `493f588b`, i.e. not wave-C fallout. Two of its rows measure a genuine sub-AA pair
  (`onPrimary` on an orange-blended chip at 3.87:1) that needs either a large-text determination or
  a token fix. Routed to **M6**, which owns the AA re-test; filed as Q-022 so it is not mistaken
  for new breakage at the G-M2 gate.

## Wave-C FIXUP outcomes + round-4 rulings (2026-08-04) — BINDING

**THE GOLDEN GATE IS BLIND TO TOKEN CHANGES — standing finding, act on it.**
`test/flutter_test_config.dart`'s `_TolerantGoldenComparator` accepts up to **5%** pixel diff.
R18's stepper-ink swap moved **0.097%** of the frame (320px of 329,160), so all three R18 goldens
**passed unchanged while carrying the wrong ink** — caught only by diffing bytes. Consequence:
**any token re-point on a small element is invisible to goldens.** Ruling: goldens are *evidence*,
not gates. Every adoption must land a per-element assertion (colour/geometry read off the widget),
and lanes may not cite a green golden as proof that an adoption took. This is already how the good
lanes worked; it is now the rule. Revisit the 5% tolerance itself at M6.

**Two of my own ruled figures were wrong; the board corrected both.**
- `topStart` fy: I wrote (0.10, **+0.03**). Measured is (0.12, **−0.06**) — the *sign* was wrong.
  **No top-start bloom anywhere on the board sits inside the canvas** (periwinkle four at −6%,
  orange three at −8%). 0.12 is also the exact start-side mirror of the ratified `topEnd` 0.88.
- `washed` ink: I ruled ~33% from `#626794`, which appears **nowhere in the board HTML** — it was a
  screenshot pixel. The CSS declares `rgba(255,255,255,.35)` on all three R18 passed segments.
  **A declaration beats a sampled pixel.** Shipped .35.

**MY ERROR #3 — I conflated the wash and the glow.** The "top-start class" ruling assumed one
layer. Three lanes independently established there are two: **R7/R14/R21/E4 draw a periwinkle
*wash* top-start; R4/R9/R17 draw an orange *glow* top-start and declare zero periwinkle.**
`JeebFieldWashPlacement` paints `periwinkleWash` unconditionally, so adopting it on R4/R9/R17 would
paint periwinkle on tiles that have none. Evidence: least-squares hue fit per tile — R14 periwinkle
α .167 / rms **0.36** vs orange rms 15.80; R17 orange α .145 / rms **0.31** vs periwinkle rms 17.10.
**Sanctioned: `JeebFieldGlowPlacement.topStart` at (0.12, −0.08)**, then R4/R9/R17 adopt.
**R9 is the worst live case — it currently draws `glowPlacement: bottom` (0.50, 0.94), i.e. the
opposite end of the screen from where its tile draws the only radial it has.**

**Also sanctioned:** R16's accent banner takes `fill: JeebAccentFrameFill.accentTint` at **both**
call sites — `jeeber_active_deliveries/.../active_deliveries_banner.dart:221` (the one a registered
jeeber actually sees, injected by `shell/tabs/dashboard_tab.dart:147`) and the `jeeber_home` `??`
fallback. Tinting only one splits a pair whose own doc says they must stay identical. That identity
is currently guarded by **a source comment and nothing else** — add a test.

**Accepted:** `topStart` wash alpha clamps to **.22** (§8's ratified band is .18–.22; R14/R7 declare
.24, R21/E4 declare .22 — a 2pp divergence, recorded not chased). `JeebStepper.washedInk` stays
public, matching `barGlow`/`barHeight`. R20's pinned strip stays glass — the board draws white-9%
glass there, so "no change, measured" was the correct outcome, not a miss.

**Still open, not ours to close:** R18 renders **5** stepper segments where the board draws **4**,
because `active_delivery_stage_done` is a frozen identifier (owner Q7 territory).

## Glow-anchor wave outcomes (2026-08-04)

`JeebFieldGlowPlacement.topStart` (0.12, -0.08) landed and R4/R9/R17 adopted it. All three were
wrong before: R9 at `bottom` (opposite end of the screen), R4/R17 mirrored at the `topEnd` default.
Two independent measurements agreed without consulting each other — CSS declarations, and a
pixel-space 5-parameter least-squares fit that un-composites the orange ink per channel (fx within
0.0016 on all three). **fy is an extrapolation, not a measurement** (the anchor is 76px off-canvas;
profile likelihood is flat across -0.094..-0.073) — it rides on the board's literal `-8%`.

**Three real defects found and NOT yet closed:**
1. **R4's periwinkle wash is 335px too low.** Shipped `JeebFieldWashPlacement.bottomEnd` is
   (0.90, 1.0); the board declares — and pixels confirm at fy 0.6503, exact — an end-side wash at
   mid-height. Ratified anchor for the kit: **`endMid(1.17, 0.65, 0.21, 1.78, 0.714)`**. Pinned with
   a test meanwhile so the orange adoption cannot silently drag it. **Fix in the next kit lane.**
2. **The glow-alpha split may be wrong.** Kit gives `content` 0.22 / `hero` 0.28; the board measures
   **0.246 / 0.249 / 0.259** on R4/R9/R17 — all three cluster *between* the two kit constants, so
   both content tiles ship ~0.027 low and the hero tile ~0.021 high. Do not patch per screen: this
   wants a survey across all 30 tiles at **M6**, then one ruling.
3. **Fade stop is 58% on the board vs the shipped `_glowFade` 0.60** — global, shared with the
   `topEnd` tiles. Also M6.

**Catalog coverage gaps found (neither element has ANY capture):**
- The active-delivery card's whole treatment is uncapturable: the only banner catalog state seeds
  **2** deliveries, which trips `_disclosureThreshold = 2` and collapses to a disclosure row with
  zero cards. Needs a 1-delivery state in `batch_04_entries.dart`.
- No `jeeber_home` catalog state mounts an active-delivery banner at all.

**Accepted:** the R16 banner pair is *not* pixel-identical by design (the shell twin's end pill is a
periwinkle CTA + status line; the fallback's is a white select chip). The new pair test therefore
pins the **frame treatment** — fill rung, painted surface, stroke, radius — not the whole card.
Pinning the pill would have failed on day one. The "visually identical" doc claim should be read as
"identical framing", and if the owner means it more strictly that is a separate product call.

## Wave-D review rulings (2026-08-04) — M2 COMPLETE at 24/24

**The glow-alpha survey is now unavoidable — five independent data points, all disagreeing with
the two-value split.** Board-declared glow alphas: R4 .26 · R9 .24 · R17 .24 · **R22 .20** · plus
the pixel fits 0.246/0.249/0.259. The kit ships `content` .22 / `hero` .28. R22 also declares a
**480×380** ellipse (rx factor 1.091), which sits **below** the 500–560 cluster the ratified 1.18
was derived from, and a **58%** fade against the shipped .60 — the third tile to measure 58%.
Ruling stands: **do not patch per screen.** M6 surveys all 30 tiles, then one ruling covers radius,
alpha and fade together. Recorded here so the evidence is not re-gathered.

**R6/R7 are a mirrored pair, and that is now measured, not inferred.** R6's field bloom is ORANGE
at the top END (ΔB negative — blue falls, the orange signature); R7's is PERIWINKLE at the top
START (channel-equal deltas), and a least-squares fit finds **no orange radial in R7's field at
all**. Independent confirmation of the wave-C wash-vs-glow ruling from a lane that had no stake in it.

**Accepted as shipped:**
- R22's notification toggles left OMDS. `OmdsSettingsSwitchRow` only forwards `activeColor` (the
  *thumb*), so the board's orange **track** and its bloom were unreachable through it — the rows had
  been rendering a periwinkle track. Replaced with the board's own geometry; the OMDS-derived toggle
  id was identifier-only chrome with zero references and was deleted, not re-homed.
- R6's hero box **deleted** — the caption is explicit ("welcome typography sits straight on the
  glowing field (no hero box)"), so this is a removal the board asks for, not a simplification.
- R8's injected scrubber waveform **removed**, not stilled. 03-MOTION-NOTES calls this out
  specifically: the tile draws none there, so stilling it would have been the wrong close-out.
- R5/W1 ship as ONE widget with two placements (the motion notes' own cheat-sheet says to).
- KYC's encryption/consent clause preserved verbatim under legal hold, even where the board's
  layout would displace it.

**Standing reminders re-confirmed this wave** (both were repeat offenders and both held): `jWave`
goes on the waveform CONTAINER with static bars beneath it, never per-bar; `jHalo` goes on a ring
SIBLING, never on the disc, which does not move.

**Deferred, with the reasoning:** W2's wash shipped through `glowColor` (right anchor, right layer,
**wrong hue**) because there is no feature-safe wash-ink lever — Q-034, kit. R6 ships ringless
because `showRings` would draw R1's hero pair *including an orange 15% inner arc R6 does not draw*
— Q-038; that restraint is correct, an unbudgeted orange would have been the worse error.

## M3 Tier-1 rulings (2026-08-04) — the tile-less method works

**The derivation discipline held.** Every lane named a nearest tile, justified it, and traced its
decisions to a token-sheet value or a standing ruling. Two lanes reached a decision they could not
trace and returned the question instead of inventing — which is exactly the behaviour the M3 brief
asked for and the reason M3 rows are safe to run without tiles.

**A live orange-budget defect found on an M3 row.** `delivery_detail_screen`'s rating-summary star
was inked `colorScheme.primary` under a code comment reading *"Navy, not warm"* — true in pass 1,
false under Midnight, where `primary` **IS** `#D73B00`. A read-only summary was spending the orange
budget. This is the same class already fixed on R16's headline, R3's courier card and the jeeber
feed's search glyph: **any pass-1 comment asserting `primary` is a cool colour is now a lie, and
`colorScheme.primary` on a non-CTA is a defect signature worth grepping for at M6.**

**Counterpart-name carry-in CLOSED, with a role gate the brief did not anticipate.**
`OrderChatSummary.jeeberName` is real wire data, but it names the *counterpart* only for a CLIENT
viewer — for a jeeber viewer it names the viewer themselves. The lane gated on viewer role, passed
null on the jeeber leg (no customer-name field exists on that wire) and filtered synthetic
`jeeb-<hash>` handles through `displayNameOrNull` rather than rendering them. Nothing fabricated.
`app_router.dart` needed no edit — the helper's signature was already right.

**Standing rulings re-confirmed:** M3 screens ship with no motion beyond what kit widgets bring;
`animateDecor: false` unless a reason is named. Glow (orange) and wash (periwinkle) stay distinct
layers — R21's derived screen correctly took wash `topStart` + glow `topEnd`, not one anchor for both.

**Deliberate non-fixes, all correctly reasoned rather than papered over:** the cancellation picked
row does not ignite (no danger `accentSelected` rung exists — Q-041); glow alpha runs ~.02 low on
derived screens (wave-D ruling: **do not patch per screen**, M6 surveys all 30 tiles); a screen with
one content group leaves the lower half empty because no wire data exists for a second band.

## ORPHAN rulings (M3 rows, ratified 2026-08-04 from the evidence sweep — owner confirm batched as §8 Q9)

| Screen | Ruling | Key evidence |
|---|---|---|
| M3-15/16 settlement pair | **DELETE** (routes+screens+tests+catalog; keep cubit/repo only if referenced elsewhere) | zero inbound, no deep link, no Maestro; T-MOB-032 designed-never-linked — restorable from git |
| M3-23 profile_edit | **KEEP+restyle** | live row in SettingsScreen (R22/M2-19 chain); 9 widget tests incl. regression guard |
| M3-31 reviews_list | **KEEP+restyle, BOTH routes** | query-param route is LIVE (client_offers→profile→reviews); path-param twin pinned by Maestro jm-068 |
| M3-36 jeeber_pending_offers | **KEEP+restyle** | notification_deep_link.dart:57 fallback + dispatcher tests + Maestro jm-047 |
| M3-37 live_settings | **KEEP+restyle** (loading/error chrome only; delegates to SettingsScreen) | sole live mount of SettingsScreen; destination of 5 back-fallbacks |
| M3-38 diagnostics | **KEEP+restyle** | Diag.enabled-gated, 19 tests, dev-support value |
| M3-42 rating_prompt | **DELETE screen+previews+fixtures; KEEP route+redirect** (inline minimal builder; update Type-A gate list if it names the file) | builder unreachable behind unconditional redirect; redirect is the live rating-push path |
| M3-43 location placeholder | **DELETE with M2-05** incl. the devtool-only 626-LOC twin + its catalog entries | ratified P0-1/P0-2; twin's only importer is batch_06 catalog |

Also: docs claim all 9 carry `// ORPHAN` tags — only 5 do (live_settings, diagnostics,
rating_prompt, location placeholder untagged). Evidence tables live in the sweep agent
report; deletion agents must update `no_raw_semantic_colors_test.dart` pinned paths and
back-fallback maps when removing routes.

## Theme rulings (M0-2/M0-8, ratified 2026-08-03)

1. **Shadow migration map RATIFIED** — legacy navy-tinted `JeebShadows` entries survive M0
   (29 consumers) and DIE at M1-5 kit re-freeze via: `card/raised/sheet/heroNavy/bubbleOut`
   → none; `fab/ctaNavy/accentBanner` → `ctaOrange`; `floatPill` → `floatNav`/`overlay`;
   `stepGlow` → `glowRest`/`micActive`; `focusRing` → `glassBorderStrong` border.
2. **Radii ladder gets a public home**: `lib/core/theme/jeeb_radii.dart` (`JeebRadii.sm 9 /
   md 14 / lg 18 / xl 22 / sheet 26 / hero 34 / capsule 40 / pill 999`) — created by M0-3,
   consumed by M1's 32 widgets; app_theme's private consts re-point to it.
3. **Bare Material FilledButton/FAB = periwinkle** stands ("when in doubt: not orange").
   Orange CTAs come only from the kit accent button where a tile draws them.
4. **Cursor/selection periwinkle** stands app-wide; R2's transcript caret color decided at
   M2-03 from the live board (may be orange — tile-sanctioned if so).
5. Unaudited scheme-derived sub-themes (drawer, rail, search, dropdown, segmentedButton,
   expansionTile, scrollbar, badge, banner) → M6 sweep list.
6. `test/app_shell_test.dart` brightness test rewritten: both factories assert Midnight.

## Harness rulings (M0-9, ratified 2026-08-03)

- Emoji in captures come from the macOS system `Apple Color Emoji.ttc` (device-parity with
  iOS); the CBDT `NotoColorEmoji.ttf` painted nothing under `flutter test` → deleted, with
  the `zz_probe_test.dart` diagnostic. Linux capture runs render no emoji — accepted.
- OMDS token set extracted to `lib/core/theme/jeeb_omds_tokens.dart` (single source for
  app.dart + harness; kills silent drift).
- Harness themes with `AppTheme.midnight()`; every capture mounts under a stand-in GoRouter
  (`canPop()==true` — matches the ~44 pushed screens; sole build-time reader is R12's ticket).
- 4 remaining render failures are pre-existing, not harness-shaped: live-tracking ×2
  (GoogleMap platform view — unmockable), customer-profile (network avatar fixture),
  rating-prompt compact overflow (screen defect → its M3 row).
- Midnight capture re-baseline = `flutter test test/tools/catalog_capture_test.dart
  --update-goldens` — run per-screen during M2, not at G-M0.

## Map rulings (M0-6, ratified 2026-08-03)

- R3/R11 tiles draw ZERO map labels/POIs. Ruling: **labels stay**, styled periwinkle
  (`#8A93D8` fill on `#070C33` stroke) — the tiles are zoom-frozen marketing frames; a
  label-free production map fails usability. POI + transit stay OFF (tile-faithful).
- Water `#070C33` is spec-derived (no water in either tile) — verify against the sea on a
  real device at M7.
- `delivery_3d.png` is cyan/magenta 3D art (not the navy/orange pair) — flagged for the M5
  navy-hostility audit before any screen uses it.
