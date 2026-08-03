# Jeeb — Motion Spec (Lottie set)

Derived 2026-08-03 from `_ds/readme.md` (Motion, hover & press · Visual Foundations), the 24 screen
renders, and `00-MIGRATION-PLAN.md` §5 rows 11/14/15/20. This is the authoring contract for every
Lottie file in `assets/animations/`. Ten files. Nothing else ships without amending this spec.

---

## 0. Binding rules (from the design system — not negotiable)

1. **Functional and gentle.** Fades, short slides, slow ring expansions. Nothing moves unless it
   states something: *listening*, *broadcasting*, *in transit*, *under review*, *done*.
2. **No bounce. No overshoot.** No keyframe value may pass its target and come back. Bezier `y`
   handles stay inside `[0, 1]`. No elastic, no spring, no squash.
3. **No decorative loops.** A file loops **only** if it depicts an ongoing state (listening,
   scanning, moving, reviewing, loading). One-shots (success, empty-state entrance, onboarding
   hero) play once and hold their final frame.
4. **Orange is rationed.** Orange appears as thin strokes, small dots, single pulses — never a
   large animated fill. Where nothing is actionable (jeeber idle scan), there is **no orange at
   all**.
5. **The mic is the hero.** The mic + waveform marks get the most motion investment; the scooter
   is secondary and abstracted to a travelling dot.
6. **Bright and literal surfaces.** No gradients, no grain, no blur layers, no glow other than the
   opacities specified here.

## 1. Lottie technical contract

- Top level: `{"v":"5.7.4","fr":60,"ip":0,"op":<frames>,"w":<px>,"h":<px>,"nm":"<name>","ddd":0,"assets":[],"layers":[…]}`
- **Shape layers only** (`"ty":4`). No images, no fonts, no expressions, no external assets, no
  mattes. Fully offline-renderable. One composition per file. Valid JSON.
- 60 fps. Every file **< 100 KB** (these specs land well under 20 KB each).
- Loop policy is enforced by the *player* (`Lottie.asset(repeat: …)`), but loops must be
  **seamless**: frame `op` state ≡ frame `0` state for every animated property.
- **Easing vocabulary** (the only curves allowed):
  - `standard` (default, in-out): `o:{"x":[0.33],"y":[0]}` → `i:{"x":[0.33],"y":[1]}`
  - `enter` (decelerating entrances, ring expansion): `o:{"x":[0.2],"y":[0.4]}` → `i:{"x":[0.4],"y":[1]}`
  - `exit` (accelerating fade-outs): `o:{"x":[0.4],"y":[0]}` → `i:{"x":[0.8],"y":[1]}`
  Never `y` < 0 or > 1 on either handle.
- Static property: `{"a":0,"k":<v>}`. Animated: `{"a":1,"k":[{keyframes}]}` per the schema above.
- Rings that "expand" do it by animating group **scale** around a centered anchor, or by animating
  ellipse size — either is fine; keep opacity fade on the same keyframe timings.

### 1.1 Palette — normalized RGBA (computed `round(hex/255, 3)`; use these exact arrays)

| Token | Hex | Lottie `k` |
|---|---|---|
| navy | `#0B1351` | `[0.043, 0.075, 0.318, 1]` |
| ink | `#0B0E53` | `[0.043, 0.055, 0.325, 1]` |
| orange | `#D73B00` | `[0.843, 0.231, 0, 1]` |
| white | `#FFFFFF` | `[1, 1, 1, 1]` |
| periwinkle | `#777FC0` | `[0.467, 0.498, 0.753, 1]` |
| brown-outline | `#916F66` | `[0.569, 0.435, 0.4, 1]` |
| surface-muted | `#F4F4F6` | `[0.957, 0.957, 0.965, 1]` |
| surface-high | `#EAE7EB` | `[0.918, 0.906, 0.922, 1]` |
| success | `#43A047` | `[0.263, 0.627, 0.278, 1]` |
| star | `#FFC107` | `[1, 0.757, 0.027, 1]` |

Tier colors (Flash `#E53935` → `[0.898,0.224,0.208,1]` etc.) are **not used** in this set — tier
identity stays in static chips, not motion.

Opacity is expressed via shape `fl.o` / `st.o` (0–100) or layer `ks.o` — the spec below says
"opacity 40" meaning the 0–100 scale.

### 1.2 Surface + RTL flags

- Every file is marked **white**, **navy**, or **both**. "Both" means every stroke/fill reads on
  `#FFFFFF` *and* on `#0B1351` without edits (orange, white-on-orange, success-green pass; bare
  navy or bare white marks do not).
- **RTL**: any file whose motion has a horizontal direction is flagged `RTL: mirror`. The
  implementer wraps it in `Transform.flip(flipX: isRTL)` (or `Directionality`-aware transform).
  Radially symmetric and vertical-motion files are `RTL: none`.

---

## 2. The set — 10 files

| # | File | Canvas | Frames (60fps) | Loops | Surface | RTL | Screens |
|---|---|---|---|---|---|---|---|
| 1 | `mic-listening.json` | 240×240 | 120 | yes | both | none | 04, 05 |
| 2 | `voice-waveform.json` | 320×96 | 90 | yes | both | none | 05, 06, 21 |
| 3 | `broadcasting.json` | 280×280 | 240 | yes | white | none | 04, 10, 11 |
| 4 | `courier-in-transit.json` | 320×96 | 180 | yes | white | **mirror** | 04, 18, 24 |
| 5 | `success-check.json` | 200×200 | 66 | **no** | both | none | 14, 15, 22, 23 |
| 6 | `empty-say-it.json` | 240×240 | 90 | **no** | white | none | 04, 24 |
| 7 | `nearby-scan.json` | 280×200 | 240 | yes | white | none | 16 |
| 8 | `kyc-review.json` | 220×220 | 120 | yes | white | none | 22 |
| 9 | `loading-dots.json` | 120×48 | 90 | yes | both | **mirror** | 03, 10, 17 |
| 10 | `onboarding-say-it.json` | 360×420 | 150 | **no** | navy | **mirror** | 01 |

---

### 2.1 `mic-listening.json` — hold-to-talk, the hero *(loop · both · 240×240 · 120f)*

**Purpose.** Plays while the user is holding to talk (04 hero card, 05 recording screen). It is the
live counterpart of `JeebMicHero`'s static glow stack — the Dart widget owns press scale and the
max-duration progress arc; this file owns only the *organic listening pulse* around it.

**Composition** (canvas center `[120,120]`):
- **L4 (bottom) `mic-button`** — static. Ellipse Ø88, fill orange. On top (same group): the mic
  glyph in white — (a) rounded rect 20×34, r10, centered at `[120,109]` (capsule body);
  (b) an open "U" arc: path stroke white, w6, round caps — semicircular arc of radius 17 centered
  `[120,116]`, from left horizontal to right horizontal, opening upward; (c) vertical stem
  line from `[120,133]` to `[120,142]`, stroke w6; (d) base bar from `[109,142]` to `[131,142]`,
  stroke w6, round caps.
- **L2/L1 `ring-a` / `ring-b`** — identical layers, `ring-b` time-shifted +60f. Each: ellipse
  stroked orange w3, no fill, centered. Animates Ø96 → Ø200 over 120f (`enter` easing) while
  stroke opacity runs 55 → 0 (linear-ish `standard`). `ring-b` achieves the offset by starting its
  keyframes at t=−60 (i.e. keyframes at −60→60 and a wrapped copy) **or** simply by two keyframe
  spans phased so frame 0 ≡ frame 120 across both layers. Seamlessness: at any t, one ring is at
  phase t/120, the other at (t+60)/120.
- **No motion on the mic button itself.** The rings carry everything. No scale pulse on the
  orange disc — press-scale (~0.97) is Dart's job per the DS.

**Feel check:** two soft sonar breaths per 2 s, opacity-led, dissolving before they near the canvas
edge. Reads on navy (orange + white) and on white.

### 2.2 `voice-waveform.json` — organic recording bars *(loop · both · 320×96 · 90f)*

**Purpose.** The moving version of `JeebWaveform` mode `live` (§5 #14: "~11 bars, accent with an
alpha tail"). Dart's bars are static; this is the organic motion while audio is actually being
captured (05), previewing a voice clip (06), or recording in chat (21).

**Composition** (baseline: vertical center `y=48`; bars grow symmetrically up+down):
- **11 bars**, rounded rects w6, r3, horizontal center-spacing 26 px, centered on `x=160`
  (bar centers at x = 30, 56, 82, …, 290).
- Fill: orange for all bars; **alpha tail** — bar opacities by index from center out:
  center bar 100; ±1: 90; ±2: 75; ±3: 55; ±4: 40; ±5: 28.
- **Max heights** (px, per bar, center-out): 64 · 56 · 60 · 44 · 34 · 24 (symmetric).
- **Motion:** each bar is a group with anchor at its own center, animating **scale Y only**
  between 4 keyframes over 90f, first value ≡ last value (seamless). Scale values sit between
  25 and 100 (% of max height), e.g. center bar `100 → 45 → 80 → 100` at f0/f30/f60/f90. Each
  bar's keyframe *values* differ and its timing is phase-shifted ~7–9 f from its neighbour so the
  field ripples organically — but every bar still closes its own loop at f90. `standard` easing
  everywhere; scale X stays 100.
- No positional motion, no color motion, nothing overshoots.

**RTL:** symmetric about center — no mirror.

### 2.3 `broadcasting.json` — request is out, waiting for offers *(loop · white · 280×280 · 240f)*

**Purpose.** The wait state after a request goes out: 04's "Broadcasting · 12 Jeebers reached"
pending card (expanded/detail state), 10's post-submit moment, and 11 while the offers window is
open with zero offers in. This is also the board's **"waiting for offers"** empty state. Calm
sonar, navy-led, orange only at the epicentre.

**Composition** (center `[140,140]`):
- **L6 `field`** — static: two stroked navy circles, Ø120 opacity 12 and Ø220 opacity 8, w1.5.
  The quiet map-like backdrop.
- **L5 `request-dot`** — static navy ellipse Ø14, fill, center.
- **L4 `orange-ping`** — stroked orange ring w2.5: Ø26 → Ø44, opacity 70 → 0, over f0–70
  (`enter`), then nothing until it repeats at f120–190. (Two pulse spans inside the 240f loop.)
  This is the *only* orange — the "your request is live" heartbeat.
- **L3/L2 `sonar-a`/`sonar-b`** — stroked navy rings w2: Ø40 → Ø260, opacity 30 → 0, each over
  120f, `sonar-b` phase-shifted +120f → one ring is always mid-flight; frame 0 ≡ frame 240.
- **L1 `jeebers`** — three periwinkle dots Ø10, static positions at polar (r≈85, 70°),
  (r≈105, 200°), (r≈70, 320°) from center. Each fades 0 → 80 → 0 over a 70f window (`standard`),
  staggered: a at f10–80, b at f90–160, c at f170–240. Opacity only — dots never move (Jeebers
  are *there*, waking up; nothing flies around).

**RTL:** radial — none.

### 2.4 `courier-in-transit.json` — dot travelling the route *(loop · white · 320×96 · 180f · RTL mirror)*

**Purpose.** Ambient "order is moving" mark for **cards and rows**: 04's active-order card, 24's
in-transit row, 18's jeeber active-delivery strip. It is **not** the live map marker — the real
tracking marker on 12 is data-driven (SSE position stream, already glided in Dart); a canned
animation must never pretend to be live GPS.

**Composition:**
- **L3 `route`** — static path: gentle S-curve from `[16,64]` through `[110,40]` and `[210,58]`
  to `[288,30]`. Stroke navy w3, **dashed** `d=[1,14]`, round caps, opacity 35 — matches 12's
  dotted navy polyline language.
- **L2 `destination`** — static navy dot Ø8 at `[288,30]`, opacity 60.
- **L1 `courier`** — group: orange filled dot Ø16 + concentric orange stroked ring Ø26 w2
  opacity 25 (the courier's small halo — no glow blur, just the ring). Position animates **along
  the route curve** using 4 spatial keyframes (`[16,64]` f0 · `[110,40]` f60 · `[210,58]` f120 ·
  `[288,30]` f168) with smooth spatial tangents following the S-curve; `standard` temporal easing,
  near-constant speed. Layer opacity: 0→100 over f0–18 (`enter`), 100→0 over f160–180 (`exit`).
  The fade at both ends makes the restart read as "still moving", not "teleported back".

**RTL: mirror horizontally** — motion is left→right (toward the destination); Arabic must read
right→left.

### 2.5 `success-check.json` — one-shot confirmation *(no loop · both · 200×200 · 66f)*

**Purpose.** THE terminal mark, shared everywhere something completes: 14 "Yes, I got it"
confirmation, 15 rating submitted, 23 wallet top-up confirmed, 22 KYC approved. One file — a
delivered order, a top-up and an approval must all *feel identical*: quiet, certain, done.

**Composition** (center `[100,100]`):
- **L3 `disc`** — ellipse Ø120, fill success green. Layer opacity 0→100 over f0–14 (`enter`);
  group scale 92→100 over f0–18 (`enter`). Settle only — never past 100.
- **L2 `flourish`** — stroked success ring w3: Ø124 → Ø160, opacity 40 → 0, f10–48 (`enter`).
  One breath outward, gone.
- **L1 `check`** — path stroke white w10, round caps + round joins, points
  `[72,104] → [93,124] → [132,78]`. **Trim path** (`tm`): `e` 0→100 over f14–44 (`standard`),
  `s` fixed 0. Draw-on, left to right.
- Holds the final state f44–66 so the player's last frame is the settled mark. **Must not loop.**

Green disc + white check reads on white and on navy. The check draw direction is a glyph, not
layout — **no RTL mirror** (a mirrored check reads as wrong worldwide).

### 2.6 `empty-say-it.json` — "nothing here yet — say it" *(no loop · white · 240×240 · 90f)*

**Purpose.** The client-side empty states the board defines — **"no requests yet"** (04 with zero
cards) and **"no orders yet"** (24) — share one CTA: make your first request. So the empty-state
mark *is the mic*, per the DS ("build empty-state visuals around the mic + waveform"). One-shot:
an empty list is a still state, and the brand forbids decorative loops — the mark enters, gives a
single inviting pulse, and rests.

**Composition** (center `[120,120]`):
- **L2 `mic`** — the navy inversion of 2.1's button: ellipse Ø88 fill **navy**, white mic glyph
  (same geometry as 2.1 L4, recentered). Enters f0–20: layer opacity 0→100 + position slides up
  8px (`[120,128]`→`[120,120]`, `enter`). A fade and a short slide — the house move.
- **L1 `invite-ring`** — stroked orange ring w3: Ø96 → Ø150, opacity 45 → 0, f24–70 (`enter`).
  **One** pulse. The single rationed-orange "go on — say it" moment, then stillness.
- Holds f70–90. Player shows final frame as the resting empty-state mark (navy mic, no ring).

### 2.7 `nearby-scan.json` — jeeber listening for requests *(loop · white · 280×200 · 240f)*

**Purpose.** 16 jeeber-home when the feed is empty — the board's **"no requests nearby"**. The
loop is legitimate: the app *is* actively scanning for requests. Deliberately different from 2.3
(that's a client shouting outward; this is a courier's patch of ground being watched) and
deliberately **zero orange** — nothing is actionable yet, and orange means act-now.

**Composition:**
- **L5 `ground`** — static ellipse 120×14 at `[140,166]`, fill surface-high, opacity 100.
- **L4 `pin`** — static map-pin at `[140,~96]`: head = ellipse Ø34 stroked navy w3 (no fill,
  white knockout not needed on white surface) centered `[140,88]`, plus tail = path stroke navy
  w3 round caps from `[127,100]` and `[153,100]` converging to `[140,158]` (two straight
  segments forming the taper; or one path `[127,100] → [140,158] → [153,100]`). Inner dot:
  navy fill Ø8 at `[140,88]`.
- **L3/L2 `ripple-a`/`ripple-b`** — flat ground ripples from the pin base `[140,160]`:
  stroked navy **ellipses** (wide, shallow) 40×6 → 220×26, w2, opacity 30 → 0, each over 120f,
  `ripple-b` phased +120f. Grounded radar — horizontal scanning, not airborne sonar.
- **L1 `blips`** — two periwinkle dots Ø8 at `[52,150]` and `[226,140]`: opacity 0 → 70 → 0
  over 80f windows, staggered (a at f30–110, b at f140–220). Far-off maybe-requests. Static
  positions.

**RTL:** symmetric composition, non-directional — none.

### 2.8 `kyc-review.json` — documents under review *(loop · white · 220×220 · 120f)*

**Purpose.** 22 after "Submit for review" — the under-24-hours review wait. Ongoing state ⇒ loop
is functional. The motion literally depicts what's happening: your document being checked.

**Composition** (doc centered `[110,110]`):
- **L3 `doc`** — static: rounded rect 108×140 r12, fill white, stroke navy w3. Inside, three
  "text lines": rounded rects r4, w8 h8… specifically 64×8 at `[110,84]`, 76×8 at `[110,106]`,
  52×8 at `[110,128]`, fill periwinkle opacity 35. (Left-align them at x-start 72 rather than
  centered: positions `[104,84]`, `[110,106]`, `[98,128]` — ragged right edge like real text.)
- **L2 `scan-line`** — rounded rect 116×5 r2.5, fill orange, opacity 0. Sequence: opacity 0→80
  f0–15 (`enter`) at y=52; position y 52 → 168 over f15–95 (`standard`, one smooth pass down the
  doc); opacity 80→0 f95–110 (`exit`); idle f110–120. Frame 0 ≡ frame 120 (invisible at top).
  The thin orange line is the file's only orange.
- **L1 `clock-tick`** *(optional, cut if budget is tight)* — small periwinkle dot Ø6 orbiting is
  **forbidden flavor** (decorative). Omit. The scan line alone is the story.

**RTL:** vertical motion — none.

### 2.9 `loading-dots.json` — inline wait *(loop · both · 120×48 · 90f · RTL mirror)*

**Purpose.** The generic short-wait mark for moments that today have nothing: 03 verifying the
OTP, 10 submitting the request, 17 sending an offer. Small enough to sit inline next to a label.
NOT a skeleton system — skeletons must size to real content and stay in Dart.

**Composition** (dots on the horizontal midline `y=24`, centers at x = 24, 60, 96):
- Three ellipses Ø12, fill **periwinkle** (the muted voice; legible on white and, at these
  opacities, acceptable on navy — flag: on navy prefer placing it on a white/`surface-muted`
  chip, as 04's cards do).
- Each dot: opacity 35 → 100 → 35 over 60f (`standard`), dots phased +15f left→right
  (dot1 peaks f30, dot2 f45, dot3 f60); loop closes at f90 with all values ≡ f0.
  Opacity only — **no vertical hop** (a hop is a bounce).

**RTL: mirror** — the phase sequence travels left→right; mirror so it reads right→left in Arabic.

### 2.10 `onboarding-say-it.json` — page-1 hero narrative *(no loop · navy · 360×420 · 150f)*

**Purpose.** 01 onboarding, panel 1 ("Say what you need"). The one place that earns illustrative,
multi-element motion Dart can't do gracefully: the product story — *you speak → it's understood →
an offer comes back* — told in 2.5 s over the navy field, then still. One-shot; replay only when
the user returns to panel 1.

**Composition** (mic anchor `[180,330]`; canvas is transparent — the screen supplies the navy):
- **L6 `mic-button`** — static from f0: orange ellipse Ø96 + white mic glyph (2.1 geometry scaled
  ×1.09) at `[180,330]`. The anchor of the whole story.
- **L5 `ring-1`** — stroked orange ring w3 from the mic: Ø104 → Ø200, opacity 50 → 0, f0–40
  (`enter`). "You spoke."
- **L4 `transcript-card`** — group at `[130,110]`: rounded rect 200×64 r20 fill white; inside,
  4 mini waveform bars (rects w4 r2, heights 10/16/12/17, fill orange, opacity 100/85/70/55)
  at its left padding, plus two "text" lines (rounded rects 90×7 and 64×7 r3.5, fill surface-high)
  right of the bars. Enters f18–48: opacity 0→100 + slide up 16px (`enter`). "It's understood."
- **L3 `offer-bubble`** — group at `[235,205]`: rounded rect 210×56 r16, fill white **opacity
  12** (the translucent on-navy card from the render); inside, two lines: 120×7 r3.5 white
  opacity 60, and 76×7 r3.5 white opacity 40; plus a periwinkle dot Ø18 at its left (the
  jeeber avatar). Enters f52–82: opacity 0→100 + slide left 16px (from `[251,205]`, `enter`).
  "An offer came back."
- **L2 `ring-2`** — second orange ring, same geometry as L5, f96–136. The story breathes once
  more and settles.
- Hold f136–150. Final frame = complete tableau, static.

**RTL: mirror** — the cards sit asymmetrically (transcript upper-left, offer mid-right) and the
offer slides leftward; Arabic mirrors the layout.

---

## 3. Refused — and why (restraint is part of the brand)

| Candidate | Verdict | Reason |
|---|---|---|
| **Order-progress advance** (Ordered→Picked→In Transit) | **Refused** | `JeebStepper` (§5 #11) owns this: it's state-driven, label-bearing, auto-RTL. The advance is a fill/color crossfade + connector fill — trivial, correct, and data-bound in Dart. A Lottie would hard-code step count/labels, fight real order state, and break RTL. The DS line "the linear progress bar advances" describes the *widget's* behavior, not a film of it. |
| **Offers arriving / cards settling in** | **Refused** | "Fades and short slides" is literally Flutter's native motion language; a staggered list entrance must size to the *real* offer cards. A canned Lottie of fake cards above real cards is noise. Implement as 40ms-staggered fade+8px-slide in Dart. |
| **Live-tracking courier marker** (12) | **Refused** (replaced by 2.4 for cards only) | The real marker follows the SSE position stream and is already glided in Dart. A looping Lottie on the map would be a *lie about where the courier is* — exactly what a trust product must not do. |
| **Skeleton shimmer** | **Refused** | Skeletons must match real layout geometry per screen; a fixed-canvas Lottie can't. Shimmer is a shader/Dart concern. `loading-dots` covers indeterminate inline waits. |
| **Wallet top-up as its own animation** (coin drop) | **Refused** (reuses 2.5) | A coin-drop reads dead without bounce, and bounce is forbidden. Money moments deserve the same quiet certainty as delivery — same mark, same feeling. |
| **Handoff "at your door" pulse** (13's banner dot) | **Refused** | One dot, one opacity pulse — a two-line `AnimatedOpacity`. Lottie adds an asset + a player for nothing. |
| **Mic press feedback** (~0.97 shrink) | **Refused** | Spec'd press behavior in the DS; belongs to `JeebMicHero`'s press states in Dart. |
| **Star-rating fill** (15) | **Refused** | A tap-driven color fill; instant/near-instant in Dart. Animating stars invites playfulness the rating moment shouldn't have. |
| **Confetti / celebration on Delivered** | **Refused** | Decorative by definition. The brand celebrates with certainty (2.5), not particles. |

## 4. Implementation notes for the consuming lanes

- Player: `Lottie.asset('assets/animations/<file>.json', repeat: <loops per table>)`. One-shots:
  `repeat: false` and keep the final frame (`animate` once; do not rewind).
- RTL-flagged files must be wrapped in a horizontal flip when `Directionality.of(context) ==
  TextDirection.rtl`.
- `loading-dots` on navy: place on a light chip/card, or expect reduced contrast.
- Sizing: render at the canvas aspect ratio; canvases are 2× the typical display size (e.g.
  `mic-listening` displays at ~120dp) so strokes stay crisp.
- These files do **not** replace `JeebWaveform`'s static modes (`cardMark`/`onNavy`/`inBubble`)
  — those stay Dart. Only the *live/recording* moment uses `voice-waveform.json`.
- pubspec asset registration (`assets/animations/`) belongs to the wiring lane, not this spec.
