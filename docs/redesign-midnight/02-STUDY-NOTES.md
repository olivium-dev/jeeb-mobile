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

## Map rulings (M0-6, ratified 2026-08-03)

- R3/R11 tiles draw ZERO map labels/POIs. Ruling: **labels stay**, styled periwinkle
  (`#8A93D8` fill on `#070C33` stroke) — the tiles are zoom-frozen marketing frames; a
  label-free production map fails usability. POI + transit stay OFF (tile-faithful).
- Water `#070C33` is spec-derived (no water in either tile) — verify against the sea on a
  real device at M7.
- `delivery_3d.png` is cyan/magenta 3D art (not the navy/orange pair) — flagged for the M5
  navy-hostility audit before any screen uses it.
