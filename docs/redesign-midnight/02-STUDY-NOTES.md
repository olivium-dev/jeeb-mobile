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

**Live defect found, pre-existing:** `CaptureLocationScreen._onPin` calls `Navigator.maybePop()`
with **no value**, so `GoogleMapPickerLauncher.pickOnMap()` always resolves null. Live consumer is
`address_detail_form_screen.dart:219` ("Edit pin"), which therefore silently discards the pinned
coordinate. Byte-identical before M2-05 (`git show ca57dda2^`), so it predates Midnight. Fixed in
the wave-B fixup lane rather than parked — we had just shipped R11 as done.

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
