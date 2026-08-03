# 09 — Motion Validation (Lottie asset set)

Validation of `assets/animations/` — 10 compositions authored across four parallel lanes.
Date: 2026-08-03. Branch: `feat/redesign-24-migration` (no branch/commit/push performed).

**Headline: all 10 files pass every check. Zero defects found, zero fixes required.**
No file in `assets/animations/` was modified by this validation pass.

---

## 1. What was actually run (and what was not)

| # | Validation | Ran? | Method |
|---|---|---|---|
| 1 | Directory reconciliation | YES | `ls -la`, diffed against the reported manifest |
| 2 | Structural / schema audit | YES | `/tmp/lottie_audit.py` — walks every property |
| 3 | Colour audit | YES | every `c.k` extracted, `round(v*255)` back to hex, matched to palette |
| 4 | Brand audit (bounce / loop) | YES | `/tmp/lottie_bounce.py`, `/tmp/lottie_bounce2.py` — frame-by-frame bezier evaluation |
| 5 | **Real runtime parse** | **YES** | `lottie` **3.3.1**, `LottieComposition.fromBytes`, real Flutter runtime |
| 6 | **Real pixel render** | **YES** | `LottieDrawable.draw` → `Picture.toImage` → RGBA, on white **and** navy |
| 7 | Visual inspection | YES | rendered PNG contact sheets, viewed directly |
| 8 | Loop-seam measurement | YES | every consecutive frame delta, seam ranked against interior |

### Note on how the runtime parse was achieved
The task specified `dart run`. **That is not possible for this package** and I want to be explicit
rather than quietly substitute. `lottie` depends on the Flutter SDK, so a plain `dart run` fails in
the kernel compiler before reaching any of my code:

```
Crash when compiling:
type 'InvalidType' is not a subtype of type 'FunctionType' in type cast
#0 _FfiUseSiteTransformer._verifyAndReplaceNativeCallable (package:vm/.../ffi/use_sites.dart:1317)
```

I did **not** fall back to structural validation. I ran the real parser under a real Flutter
runtime instead, via `flutter test` in a throwaway project at `/tmp/lottie-verify/`
(its own `pubspec.yaml`, `lottie: 3.3.1` resolved from the pub cache). **The project's
`pubspec.yaml` was not touched.** This is genuine runtime validation — the same
`LottieComposition` / `LottieDrawable` code paths the app will execute.

This also unlocked the check that structural validation fundamentally cannot do: **rendering actual
pixels** to prove nothing draws an empty frame.

---

## 2. Directory reconciliation

`ls -la assets/animations/` — **10 files, exactly the 10 reported. No missing files, no extras.**
Every reported byte size matched to the byte. Total 132 KB; largest single file 21,384 B
(onboarding-say-it), well under the 100 KB per-file budget.

---

## 3. Per-file results

Loop column = *intended* behaviour. Lottie JSON has **no loop flag** — looping is the player's
`repeat:` argument. Verified no file carries `markers` or a `loop` key that could force it.

| File | Bytes | Canvas | `op` | Layers | Loop | Colours (verified in-palette) | Parse | Render |
|---|---|---|---|---|---|---|---|---|
| `broadcasting.json` | 16,364 | 280×280 | 240 | 6 | LOOP | navy, periwinkle, orange | PASS | PASS |
| `courier-in-transit.json` | 7,904 | 320×96 | 180 | 3 | LOOP | navy, orange | PASS | PASS |
| `empty-say-it.json` | 7,519 | 240×240 | 90 | 2 | ONE-SHOT | navy, orange, white | PASS | PASS |
| `kyc-review.json` | 5,525 | 220×220 | 120 | 2 | LOOP | navy, periwinkle, orange, white | PASS | PASS |
| `loading-dots.json` | 5,269 | 120×48 | 90 | 3 | LOOP | periwinkle | PASS | PASS |
| `mic-listening.json` | 9,774 | 240×240 | 120 | 4 | LOOP | orange, white | PASS | PASS |
| `nearby-scan.json` | 18,105 | 280×200 | 240 | 9 | LOOP | navy, periwinkle, surface-high | PASS | PASS |
| `onboarding-say-it.json` | 21,384 | 360×420 | 150 | 5 | ONE-SHOT | periwinkle, orange, surface-high, white | PASS | PASS |
| `success-check.json` | 6,646 | 200×200 | 66 | 3 | ONE-SHOT | success, white | PASS | PASS |
| `voice-waveform.json` | 20,329 | 320×96 | 90 | 11 | LOOP | orange | PASS | PASS |

All ten: `v` 5.7.4, `fr` 60, `ip` 0, `assets: []`, `ddd: 0`, **layer types `{4: n}` only** — shape
layers exclusively, no precomps/solids/images/text, no `refId`, no masks, no track mattes, no
effects, no expressions, no gradients.

### Runtime parse output (lottie 3.3.1, verbatim)
```
PASS | broadcasting.json       | 280x280 | ip=0 op=239 fr=60 | layers=6  | dur=4000ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | courier-in-transit.json | 320x96  | ip=0 op=179 fr=60 | layers=3  | dur=3000ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | empty-say-it.json       | 240x240 | ip=0 op=89  fr=60 | layers=2  | dur=1500ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | kyc-review.json         | 220x220 | ip=0 op=119 fr=60 | layers=2  | dur=2000ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | loading-dots.json       | 120x48  | ip=0 op=89  fr=60 | layers=3  | dur=1500ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | mic-listening.json      | 240x240 | ip=0 op=119 fr=60 | layers=4  | dur=2000ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | nearby-scan.json        | 280x200 | ip=0 op=239 fr=60 | layers=9  | dur=4000ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | onboarding-say-it.json  | 360x420 | ip=0 op=149 fr=60 | layers=5  | dur=2500ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | success-check.json      | 200x200 | ip=0 op=65  fr=60 | layers=3  | dur=1100ms | imgs=0 fonts=0 chars=0 | warn=0
PASS | voice-waveform.json     | 320x96  | ip=0 op=89  fr=60 | layers=11 | dur=1500ms | imgs=0 fonts=0 chars=0 | warn=0
--- total=10 failed=0
```
Zero parser warnings, zero image/font/character dependencies — every file is fully
offline-renderable, as claimed.

---

## 4. Structural audit — 0 errors, 0 warnings

Checked across all 10 files: 1,247 static properties (`a:0`) and 62 animated properties
(`a:1`, 194 keyframes total).

- Required top-level keys `v fr ip op w h layers` present everywhere; `layers` non-empty.
- Every layer carries `ty`, `ks`, `ip`, `op`; every `op > ip`.
- Every `a:1` property has an **array** `k` of keyframe objects, each carrying `t`.
- Every `a:0` property has a scalar/array `k` — **no `a:0` holding keyframe-shaped data**
  (the classic silently-doesn't-render bug). Zero instances.
- Keyframe times strictly ascending, no duplicate timestamps.
- Every `gr` group's last `it` item is exactly one `tr`.
- No animated colours; no `gf`/`gs` gradients; no `tt`/`refId`/expressions.

Two files carry keyframes beyond `op` (`mic-listening` t→180 vs op 120; `nearby-scan` t→300 vs
op 240). **This is correct, not a defect** — it is the `ip`/`op`-windowed layer technique both
authors documented, where a layer is clipped to a window and its keyframes start negative or run
past the end so it enters mid-flight. Both render correctly (verified in pixels, §7).

---

## 5. Colour audit — all in palette

Every `"c":{"k":[...]}` on every `fl` and `st` was extracted and converted back with
`round(v*255)`. **No off-palette colour in any file.**

| Normalized RGB in files | Hex | Palette name |
|---|---|---|
| `[0.043, 0.075, 0.318, 1]` | `#0B1351` | navy |
| `[0.843, 0.231, 0.0, 1]` | `#D73B00` | orange |
| `[0.467, 0.498, 0.753, 1]` | `#777FC0` | periwinkle |
| `[0.918, 0.906, 0.922, 1]` | `#EAE7EB` | surface-high |
| `[0.263, 0.627, 0.278, 1]` | `#43A047` | success |
| `[1, 1, 1, 1]` | `#FFFFFF` | white |

Six distinct colours across the set. The divisor is correct in every case — spot-checked by hand:
`0xD7 = 215`, `215/255 = 0.84314 → 0.843`; `0x3B = 59`, `59/255 = 0.23137 → 0.231`.
No ink `#0B0E53`, no brown-outline, no star, no tier colours are used — none of these ten
compositions calls for them.

**Orange rationing holds.** Orange never appears as a large fill. Its total use across the set:
the `mic-listening` disc + rings, the `voice-waveform` bars, one 2.5 px `broadcasting` ping ring,
one D16 `courier` dot + halo, one `kyc-review` scan beam, one `empty-say-it` ring, and the
`onboarding` mic disc + two w3 rings. `nearby-scan` uses **zero** orange, as its spec requires.

---

## 6. Brand audit — bounce and loop correctness

### 6.1 No bounce. Confirmed by frame-by-frame evaluation, not by inspection.

Every animated property was evaluated at **every frame** through its cubic-bezier easing and
compared against the range of its own bracketing keyframes.

> **Result: zero properties overshoot. No value anywhere in the set ever exceeds the range of the
> keyframes it sits between.**

All 388 bezier handle components are inside `[0,1]`, so springy overshoot is not even
representable. Only `enter` (`o 0.2/0.4 → i 0.4/1`), `standard` (`o 0.33/0 → i 0.33/1`) and
`exit` curves appear.

### 6.2 Direction changes are NOT bounce — the distinction that matters

A naive non-monotonic scan flags 30 properties. **None of them is bounce.** Bounce is a value
overshooting its *target* and returning (§6.1: zero). A fade `0→80→0`, a waveform oscillating, or
a dot riding a curved path are all legitimate. Each of the 30 was resolved individually:

| Flagged | Verdict |
|---|---|
| Opacity reversals (`broadcasting` ×6, `empty-say-it`, `onboarding`, `success-check`) | Fade in/out cycles. Legitimate by definition. |
| `voice-waveform` 21 bar scale-Y turns | Oscillation **is** the semantic content of a waveform. No bar exceeds its own max height (all values 25–100). Legitimate. |
| `courier-in-transit` `.p[1]` turns at f61, f121 | The drawn route is an S-curve; the courier rides it. Verified visually — the dot tracks a wavy dashed line. Path geometry, not bounce. |
| `kyc-review` scan-line `.p[1]` turn at f111 | Reset to top at **effective opacity 0.00%**. Invisible. |
| `broadcasting` orange-ping `el.s` turn at f121 | **Resolved empirically** — see below. |

The `broadcasting` ping was the only case where static analysis was ambiguous, because the
`h:1` hold keyframe at t=70 makes the 44→26 reset a hold-boundary artefact. I settled it by
measuring orange pixels in the **rendered** output:

```
f0   orangePixels=278 ringDiameter=30      f119 orangePixels=0   ringDiameter=0
f5   orangePixels=304 ringDiameter=32      f120 orangePixels=0   ringDiameter=0
f30  orangePixels=348 ringDiameter=42      f121 orangePixels=266 ringDiameter=30
f60  orangePixels=0   ringDiameter=0       f125 orangePixels=305 ringDiameter=32
f70..f120 orangePixels=0                   f150 orangePixels=348 ringDiameter=42
```

The ring only ever grows (30→42 px) while fading; it is **completely absent (0 orange pixels)
from f60 through f120**, so the size reset happens entirely out of sight. Not bounce. Correct.

### 6.3 Loops and one-shots — correct as declared

No file contains a loop key or markers, so nothing forces a loop; the three one-shots cannot
self-loop. All three **settle to a genuinely held final frame** (measured: final frame vs
last-keyframe frame, pixel delta `0.0000` for all three):

| One-shot | Last keyframe | `op` | Held tail |
|---|---|---|---|
| `success-check` | f48 | 66 | 18 frames |
| `empty-say-it` | f70 | 90 | 20 frames |
| `onboarding-say-it` | f136 | 150 | 14 frames |

All seven looping files depict genuinely ongoing states (listening, uploading, searching, in
transit) — none is a decorative loop.

### 6.4 Loop seams — measured in real pixels

For each looping file I rendered **every** frame, computed all consecutive deltas, and ranked the
wrap `f(last)→f0` against them.

| File | Seam delta | Interior max | Seam rank | Verdict |
|---|---|---|---|---|
| `broadcasting` | 0.501 | 0.983 | 92nd of 240 | Seamless — unremarkable |
| `courier-in-transit` | 0.023 | 0.633 | low | Seamless (masked by opacity 0 at both ends) |
| `kyc-review` | 0.000 | 1.731 | last | Perfect |
| `loading-dots` | 0.000 | 0.228 | last | Perfect |
| `voice-waveform` | 0.005 | 0.268 | low | Seamless |
| `mic-listening` | 1.596 | 1.623 (f60→f61) | 2nd of 120 | Seamless — see below |
| `nearby-scan` | 0.244 | 0.227 (f60/f120/f180) | 1st of 240 | Seamless — see below |

`mic-listening` and `nearby-scan` rank at the top, which looks alarming until you see *what* the
largest interior delta is. In both cases it is a **ring/ripple birth**, and those births are
periodic:

- `mic-listening`: seam 1.596 vs the f60→f61 ring-b birth at 1.623 — within 1.7%. Births every
  60 frames, one of which lands on the wrap.
- `nearby-scan`: seam 0.244 vs ripple births at f60/f120/f180, all exactly 0.227 — within 7%.

So the wrap is not a jump; it is the same heartbeat that fires four times per cycle. Both authors'
claims verified. I initially measured this wrong (used `f(last-1)→f0`, which spans two frames of
travel and manufactured a false "JUMP" on `mic-listening`); corrected to `f(last)→f0`, since
lottie's `endFrame` is already the last real frame.

---

## 7. Render verification — nothing draws an empty frame

Each file rendered at 9 points across its timeline on **both** `#FFFFFF` and `#0B1351`, measuring
the share of pixels differing from the background, then assembled into contact sheets and
**viewed directly**. All ten read as intended: `mic-listening` is an unmistakable microphone disc
with sonar rings; `success-check` draws its check on progressively (confirming the trim-path item
order is right); `courier-in-transit` rides its dashed route; `onboarding-say-it` assembles mic →
transcript card → offer bubble.

The only blank frames are intentional pre-entrance frames (`success-check` f0, `empty-say-it` f0,
`courier-in-transit` f0 at opacity 0). No file is blank across its timeline.

### Surface verdicts — measured, not assumed

| File | Ink on white | Ink on navy | Verdict |
|---|---|---|---|
| `mic-listening` | 12.4–15.1% | 13.8–16.7% | **BOTH** |
| `voice-waveform` | 5.4–7.6% | 5.4–7.6% | **BOTH** (outer bars at 28/40% alpha are dim on navy — raise the alphas, don't change the colour) |
| `success-check` | 26.5–32.4% | 28.7–32.5% | **BOTH** — verified visually on navy |
| `loading-dots` | 6.25–6.46% | 6.25–6.39% | **BOTH**, but periwinkle at 35% is weak on navy — place on a white/surface-muted chip |
| `kyc-review` | 7.1–8.4% | 30.0–30.1% | **WHITE** is the design target; degrades gracefully on navy (the doc's white fill carries it, the navy outline is lost) |
| `onboarding-say-it` | 4.9–6.5% | 5.7–22.0% | **NAVY** — designed for the navy field; canvas is transparent |
| `broadcasting` | 2.7–4.8% | 0.00–0.59% | **WHITE ONLY** — effectively invisible on navy |
| `nearby-scan` | 4.9–5.5% | 2.5–2.6% | **WHITE ONLY** — confirmed visually: pin and ripples vanish on navy, only the pale ground ellipse floats |
| `courier-in-transit` | 1.1–2.5% | 0.00–1.5% | **WHITE ONLY** — the navy dashed route and destination dot disappear |
| `empty-say-it` | 9.0–11.6% | 2.1–4.6% | **WHITE ONLY** — the navy disc vanishes |

---

## 8. RTL

| File | RTL treatment |
|---|---|
| `courier-in-transit` | **MIRROR REQUIRED** — verified visually: the courier travels left→right. Wrap in `Transform.flip(flipX: isRTL)`. |
| `loading-dots` | **MIRROR REQUIRED** — the phase sequence travels left→right (peaks f30/f45/f60). |
| `onboarding-say-it` | **MIRROR REQUIRED** — asymmetric layout (transcript upper-left, offer mid-right) and the offer slides leftward. |
| all other 7 | **No mirror.** Radially symmetric or vertical-only motion. Do not wrap. |

`nearby-scan` has one nuance: its two static blips fade in sequence left-then-right *in time*
(f30–110, then f140–220). Nothing moves, so it does not read as direction — no mirror needed, but
flagged as the one non-symmetric element.

---

## 9. Fixes applied

**None. No file required a fix.** Every candidate defect surfaced by the audits resolved on
investigation to correct, intentional authoring — documented in §6.2 rather than "fixed" by
flattening something that was right. I changed nothing in `assets/animations/`.

The two corrections made during this pass were to **my own harness**, not to the assets:
1. `LottieDrawable.draw` takes no `progress:` argument in 3.3.1 — must call `setProgress()` first.
2. Loop seams must be measured `f(last)→f0`, not `f(last-1)→f0`.

Both are recorded because the second one produced a false positive that would have led to
"fixing" a correct file.

---

## 10. Open items (cosmetic, not defects — owner's call)

Both were self-declared by their authors; I verified both and confirmed neither is a bug.

1. **`kyc-review` beam overhang.** The scan beam is 116 px against a 108 px doc (4 px proud each
   side) and its travel endpoints (y=52, y=168) sit inside the doc's 12 px corner radius.
   Confirmed in the render: at the extremes it reads as a cap across the doc edge; mid-travel it
   reads perfectly. The spec fixes these numbers. If the owner dislikes it, changing travel to
   y=60→y=160 fixes it with no other edit.
2. **`onboarding-say-it` ring clip.** Rings reach D200 centred at `[180,330]` on a 420-tall
   canvas → 10 px bottom overflow. Confirmed arithmetically and in the render. Inconsequential:
   clipping only begins once the stroke is below 9.3% opacity and still fading. A clean fix is a
   spec amendment (mic anchor y=320, or ring max D180), not a unilateral change.

---

## 11. For the implementer

- **`pubspec.yaml` asset registration is still outstanding.** No lane has done it; it belongs to
  the wiring lane per motion spec §4. `assets/animations/` is not yet registered, so
  `Lottie.asset(...)` will fail until it is. This is the one thing standing between these files
  and working in the app.
- One-shots must be played with `repeat: false` and left on their final frame (do not rewind):
  `success-check`, `empty-say-it`, `onboarding-say-it`.
- Canvases are ~2× typical display size — render `success-check` at ~100 dp, `empty-say-it` at
  ~120 dp.
- Some players treat `op` as exclusive (last drawn frame 65 / 89 / 149). All three one-shots are
  fully settled well before that, so it makes no visual difference.
- **`courier-in-transit` is for cards and list rows only** (04 active-order card, 18 header strip,
  24 in-transit row). Do **not** use it as the live map marker on screen 12 — that marker is
  data-driven from the SSE position stream, and a canned loop there would misrepresent where the
  courier actually is.
- Trim-path item order is load-bearing: `tm` must come **after** the `sh` it trims
  (`lottie-3.5.1/lib/src/animation/content/shape_content.dart:41-58`). All files here are correct
  — `success-check`'s draw-on was confirmed rendering.

---

## Appendix — reproducing this

| Artefact | Path |
|---|---|
| Structural + colour audit | `/tmp/lottie_audit.py` |
| Bounce / reversal analysis | `/tmp/lottie_bounce.py`, `/tmp/lottie_bounce2.py` |
| Runtime parse + render harness | `/tmp/lottie-verify/` (`flutter test test/<name>_test.dart`) |
| Rendered frames + contact sheets | `/tmp/lottie-verify/out/`, `/tmp/lottie-verify/out/sheets/` |

Harness tests: `parse_test.dart` (runtime parse), `render_test.dart` (pixel coverage on both
surfaces), `ping_test.dart` (orange ring measurement), `seam_test.dart` / `seam2_test.dart`
(loop seams). All temporary; nothing under `/tmp` is part of the repo.
