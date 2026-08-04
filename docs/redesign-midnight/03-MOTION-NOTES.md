# MIDNIGHT — 03 Motion notes (per-tile)

**Date:** 2026-08-04 · **Source:** `~/Downloads/Jeeb - Marketing-3/Jeeb Rich UI.dc.html` (251 KB, 2170 lines)
**Consumers:** M2 per-screen implementers, M5 motion pass. Primitives + curves live in §2.6 of
`00-MASTER-PLAN.md` and `lib/core/motion/jeeb_motion.dart`.

## Method — READ THIS FIRST

> **ALL tiles below are `static-analysis only`.** The live board could not be opened in Chrome:
> the extension refuses `file://` URLs, and a loopback static server was unreachable from Chrome
> (5 attempts; only `curl` requests ever hit the server log, and the frame reported
> `ERR_CONNECTION_REFUSED`). Findings come from parsing the board HTML directly.

Why the static read is nonetheless **authoritative and complete**, not a degraded fallback:

- The board's entire `<style>` block (lines 18–29) contains **only** the 8 `@keyframes` plus
  `body{}` and `a{}`. There are **no class-based animation rules**, so nothing can animate that is
  not declared inline on the element.
- Every animation is an inline `animation:` shorthand in a `style="…"` attribute. `grep -o` counts
  **84 occurrences**; the tag-level extractor resolved **84/84** to a specific element and tile.
- There are **zero** `transition:` declarations and **zero** `animation-*` longhands in the file.
- Tiles are delimited by `data-screen-label="…"`; every animated element was assigned by line range.

The only thing static analysis cannot give is subjective feel (perceived speed, overlap). It gives
element, primitive, duration, delay and stagger exactly.

## Headline findings (read before implementing any tile)

1. **20 of the 30 in-scope tiles have ZERO animation.** Motion is deliberately concentrated in the
   voice/recording moment (R2), the onboarding + walkthrough art (R5/W1–W3), and the empty states
   (E1–E4). Product/list/form screens are completely still. Do not add novelty motion to them.
2. **No new primitives.** All 84 declarations use the 8 §2.6 keyframes. **Nothing to flag as NEW.**
3. **R1 Client home does not animate at all** — including its "Broadcasting" live dot and its
   orbit ring. §4 M5 of the master plan says "R1 rings+broadcast dot"; **the board contradicts it.**
4. **R3 Live tracking does not animate its route** — the dashed path is static. W3's route is the
   *same* path construction *with* `jDash`. §4 M5 says "map `jDash`"; **the board contradicts it**
   for R3. `jDash` occurs only on W3 and E1 samples B/C.
5. **`jWave` is applied to the waveform CONTAINER, never per bar.** There is no per-bar stagger
   anywhere on the board, contrary to the §2.6 "per-bar stagger" note. The bars are static children;
   the whole row scales as one via `transform-origin: center bottom` (R2) / `center` (R5/W1/E1).
6. **E1's route-dot ring is static.** §2.7 describes "medallions orbiting on a `jDash` route-dot
   ring"; on the E1 tile the ring (`stroke-dasharray="2 9"`) and both orange arcs
   (`stroke-dasharray="1 9"`) have **no** animation, and the 4 medallions do not orbit.

### §2.6 timing table needs widening (observed values vs the spec column)

| Primitive | §2.6 says | Board actually uses | Action |
|---|---|---|---|
| `jFloat` | 4s / 4.4s, delays ≤1.2s | 2.6s, 2.8s, 3.4s, 3.6s, 4s, 4.4s; delays 1.2/1.3/1.4s | widen; short values are for map pins, long for card art |
| `jTwinkle` | 2.4–3s, stagger .7/1.3s | 2.2–3s; delays .4/.6/.7/.9/1.1/1.3/1.4/1.6/1.7s | widen delay set |
| `jBreathe` | 1.6–3.6s | 1.6, 1.8, 2.4, 2.6, 2.8, 3, 3.2, 3.4, 3.6s; delays .8/1.6s | matches |
| `jWave` | 1.3s, per-bar stagger | 1.2s, 1.3s, 1.4s — **container-level, no stagger** | drop "per-bar stagger" |
| `jDash` | 2s | 2s, 2.4s, 2.6s | widen |
| `jHalo` | 2.6s | 2.2, 2.4, 2.6, 2.8s; delay .5s | widen |
| `jArcPulse` | 2.4s, stagger .4/.8s | 2.2, 2.4, 3, 3.2, 3.4s; delays .4/.45/.5/.6/.8/1s | widen |
| `jBlink` | 1.1s step-end | 1.1s step-end | exact |

All durations are `infinite`; easing is `ease-in-out` except `jHalo` (`ease-out`), `jDash`
(`linear`) and `jBlink` (`step-end`).

---

## R1 · Client home

Method: static-analysis only · lines 51–138 · **animated elements: 0**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| — | — | — | nothing on this tile animates |

**Does not move:** top-right orbit ring (340px, `1px rgba(255,255,255,.08)`, L52); the 6px
periwinkle field dot (L55); the **"Broadcasting" label and its 7px orange dot** (L91); both
waveform bar clusters (L81 = 5 white 3px bars, L86 = 3 orange 3px bars); the mic capsule and
"Hold to talk" (L78); the floating pill nav; all cards and glass surfaces.

> **Ruling needed (Q-M5-a):** master plan §4 M5 promises "R1 rings+broadcast dot" motion the tile
> does not draw. Default per §2.6 rule *"no novelty motion the tile doesn't show"* → **ship R1 still.**

---

## R2 · Voice recording

Method: static-analysis only · lines 139–192 · **animated elements: 4**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| live-transcript caret (`<span>` 2px×20px, orange, L153) | `jBlink` | 1.1s step-end | sits after the Arabic transcript run, `display:inline-block`, `vertical-align:middle`, `margin-right:4px` |
| waveform row **container** (`<div>` flex, h44, L156) | `jWave` | 1.2s ease-in-out | `transform-origin:center bottom`. Holds **10 static bars**, 4px wide, r9, heights 12/24/34/18/40/26/36/16/28/12, orange at varying alpha. **The bars do not animate individually.** |
| "Recording — release to send" caption (L162) | `jBreathe` | 1.8s ease-in-out | orange text under the 00:07 / 1:00 timer |
| mic halo ring (138px, `2px solid #FFB27A`, L170) | `jHalo` | 2.4s ease-out | ring is a *separate* element behind the 130px mic disc; it is the only thing that scales |

**Does not move:** the 130px orange mic disc itself; the 164px SVG timer arc
(`stroke-dasharray="54.5 410.4"`, L169) — it is a static progress arc, **not** a `jDash` target;
the 420px orange field ring (L138); the `00:07` timer text; the cancel/lock rail; all glass chrome.

---

## R3 · Live tracking

Method: static-analysis only · lines 193–257 · **animated elements: 0**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| — | — | — | nothing on this tile animates |

**Does not move:** **the dashed route path** (L203, `stroke-dasharray="1 12"`, `rgba(215,59,0,.9)`,
5px round cap) — byte-for-byte the same construction as W3's animated route (L1596) **minus** the
`style="animation:jDash …"`, so the stillness is a deliberate designer choice, not an omission; the
"Arriving in 20 min" glass chip; the courier marker; the rating star; the courier card; the map.

> **Ruling needed (Q-M5-b):** master plan §4 M5 promises "map `jDash`" on R3. The board draws it
> still. Default → **ship R3's route static**; if the owner wants the dash to crawl, W3's
> `jDash 2.6s linear infinite` is the exact value to copy.

---

## R4 · Wallet

Method: static-analysis only · lines 258–322 · **animated elements: 0**

**Does not move:** anything. Includes the field orbit ring, the radial glow behind the balance, the
balance figure, all transaction rows and chips.

---

## R5 · Onboarding

Method: static-analysis only · lines 323–372 · **animated elements: 4**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| left glass voice bubble (L334, `left:24px;top:56px`, radius `16 16 16 4`) | `jFloat` | 4s ease-in-out | `backdrop-filter:blur(12px)`, max-width 200px |
| mini waveform inside that bubble (`<span>` flex h14, L336) | `jWave` | 1.3s ease-in-out | `transform-origin:center`; **3 static orange bars** 3px wide, heights 7/13/9 |
| right glass offer bubble (L341, `right:22px;top:170px`, radius `16 16 4 16`) | `jFloat` | 4.4s / **delay 1.2s** | the 1.2s delay is what de-syncs the two bubbles — keep it |
| mic halo ring (132px, `2px solid #FFB27A`, L345) | `jHalo` | 2.6s ease-out | behind the 124px orange mic disc |

**Does not move:** the 124px mic disc; the wordmark; the `عربي` language pill; the bubble contents
(`"40 mins — $8"`, `Karim · ★ 4.9 · 3km`, the `0:04` stamp, the Arabic transcript); the CTA; the
page dots.

---

## R6 · Registration

Method: static-analysis only · lines 373–417 · **animated elements: 0**

**Does not move:** anything — including the field orbit ring, the social pills, the phone field.

---

## R7 · OTP verify

Method: static-analysis only · lines 418–465 · **animated elements: 0**

**Does not move:** anything. Note the 13 `backdrop-filter` surfaces (the OTP digit boxes) are
glass but **static** — no focus pulse, no caret blink. `jBlink` is R2's transcript caret only.

---

## R8 · Transcription review

Method: static-analysis only · lines 466–519 · **animated elements: 0**

**Does not move:** anything — including the scrubber row. (Reinforces the doc-13 carry-in: the
injected waveform must be *removed*, and it certainly must not animate.)

---

## R9 · Request type

Method: static-analysis only · lines 520–594 · **animated elements: 0**

**Does not move:** anything — tier rows, badges, the pre-selected radio, all 7 glass surfaces.

---

## R10 · Offers

Method: static-analysis only · lines 595–680 · **animated elements: 0**

**Does not move:** anything — offer rows, the 3 rating stars, avatars, the accept CTA. Offer
arrival is **not** animated on this tile (contrast E2, the waiting state, which is where the motion
lives).

---

## R11 · Location picker

Method: static-analysis only · lines 681–736 · **animated elements: 2**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| drop-off map pin (`<svg>` 42px, `#FF5252`, L699) | `jFloat` | 2.6s ease-in-out | `filter:drop-shadow(0 0 16px rgba(255,82,82,.5))`; **2.6s — much faster than the 4s card-art float** |
| pin ground shadow (`<span>` 12×5px, `rgba(0,0,0,.35)`, L700) | `jBreathe` | 2.6s ease-in-out | **same 2.6s period, no delay** — shadow fades in sync as the pin lifts. Ship them as one composed widget. |

**Does not move:** the "Drop-off here" glass label; the map; the recenter FAB; the confirm CTA;
the address sheet.

---

## R12 · Request summary

Method: static-analysis only · lines 737–799 · **animated elements: 0**

**Does not move:** anything — including the **6 static waveform bars** in the voice-note row. This
is a playback summary, not a live recording: **do not** wire `jWave` here.

---

## R13 · OTP handover

Method: static-analysis only · lines 800–844 · **animated elements: 0**

**Does not move:** anything — the 4 code digits, the arrival banner, all 6 glass surfaces.

---

## R14 · Receipt confirm

Method: static-analysis only · lines 845–881 · **animated elements: 0**

**Does not move:** anything — money figures, line items, the confirm CTA.

---

## R15 · Mutual rating

Method: static-analysis only · lines 882–923 · **animated elements: 0**

**Does not move:** anything — the star row does **not** twinkle, fill, or pop. The amber field
glow is static.

---

## R16 · Jeeber home

Method: static-analysis only · lines 924–1015 · **animated elements: 0**

**Does not move:** anything — including **"Online · goes offline in 1h 40m"** (L940) and
**"Active: Medicine → Rue Monot"** (L948). There is no live/online pulse dot on this tile. The
availability strip, rating pill and feed cards are all still.

---

## R17 · Offer composer

Method: static-analysis only · lines 1016–1074 · **animated elements: 0**

**Does not move:** anything — the 3 ETA pills, the price field, the submit CTA.

---

## R18 · Active delivery — Jeeber

Method: static-analysis only · lines 1075–1135 · **animated elements: 0**

**Does not move:** anything — the segmented stepper does not animate its active segment; the
action pills are still.

---

## R19 · Earnings

Method: static-analysis only · lines 1136–1194 · **animated elements: 0**

**Does not move:** anything — hero stats, the radial glow behind them, the bar chart (no grow-in),
the rating star.

---

## R20 · Order chat

Method: static-analysis only · lines 1195–1251 · **animated elements: 0**

**Does not move:** anything. Explicitly: **there is no typing indicator** on this tile (no "typing"
string, no 3-dot cluster), and the orange send button / avatar dots are static. Do not invent a
typing animation.

---

## R21 · Order history

Method: static-analysis only · lines 1252–1344 · **animated elements: 0**

**Does not move:** anything — rows, status chips, the 2 rating stars, the expired-row dimming.

---

## R22 · Settings

Method: static-analysis only · lines 1345–1418 · **animated elements: 0**

**Does not move:** anything — rows, switches, the MORE band.

---

## R23 · Become a Jeeber

Method: static-analysis only · lines 1419–1481 · **animated elements: 0**

**Does not move:** anything — the wizard stepper does not animate; the ID band and upload tiles
are still.

---

## W1 · Walkthrough — Say it

Method: static-analysis only · lines 1482–1531 · **animated elements: 4**

Structurally identical to R5 (same art, shifted positions). Ship one widget, two placements.

| element | primitive | duration/delay | notes |
|---|---|---|---|
| left glass voice bubble (L1493, `left:26px;top:60px`) | `jFloat` | 4s ease-in-out | radius `16 16 16 4`, blur 12px |
| mini waveform in that bubble (L1495) | `jWave` | 1.3s ease-in-out | `transform-origin:center`; 3 static orange bars 7/13/9 |
| right glass offer bubble (L1500, `right:24px;top:150px`) | `jFloat` | 4.4s / **delay 1.2s** | contents `Groceries — Spinneys` + `⚡ Flash` chip |
| mic halo ring (128px, `2px solid #FFB27A`, L1504) | `jHalo` | 2.6s ease-out | behind the 120px orange mic disc |

**Does not move:** the 120px mic disc; the wordmark; the `عربي` pill; bubble contents; the headline,
CTA and page dots.

---

## W2 · Walkthrough — Trusted Jeebers

Method: static-analysis only · lines 1532–1585 · **animated elements: 6**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| outer orbit ring 370px (`1px rgba(255,255,255,.07)`, L1533) | `jArcPulse` | 3.2s / **delay .6s** | centered `left:50%;top:290px` |
| inner orbit ring 250px (`1px rgba(255,255,255,.12)`, L1534) | `jArcPulse` | 3.2s, no delay | the .6s offset between the two rings is the whole effect |
| verified check badge (22px orange disc, `3px solid #10175E`, L1546) | `jTwinkle` | 2.6s ease-in-out | corner badge on the "K" avatar — **`jTwinkle` used on a UI badge, not a star** |
| trust chip "🛡 ID-verified" (L1559, `left:22px;top:96px`) | `jFloat` | 4s ease-in-out | glass pill, blur 10px |
| trust chip "Rated after every delivery" (L1560, `right:20px;top:128px`) | `jFloat` | 4.4s / **delay 1.3s** | same treatment, de-synced |
| orange chip "Your 4-digit code proves the handoff" (L1561, `top:392px`) | `jBreathe` | 2.8s ease-in-out | `rgba(215,59,0,.2)` fill + `.45` border — the accent chip breathes rather than floats |

**Does not move:** the "K" avatar and the `ID ✓ / Verified` card; the rating star; the wordmark;
headline, CTA, page dots.

---

## W3 · Walkthrough — Live tracking

Method: static-analysis only · lines 1586–1636 · **animated elements: 5**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| route path (`<path>` L1596, `stroke-dasharray="1 12"`, `rgba(215,59,0,.9)`, 5px round) | `jDash` | 2.6s linear | **the only route dash on any R/W tile.** R3 draws the same path without it |
| courier halo ring (54px, `2px solid #FFB27A`, L1598) | `jHalo` | 2.2s ease-out | **2.2s — the fastest halo on the board**; behind the 38px orange courier disc |
| destination map pin (`<svg>` 28px, `#FF5252`, L1602) | `jFloat` | 2.8s ease-in-out | `drop-shadow(0 0 14px rgba(255,82,82,.6))`; same short-period float as R11's pin |
| chip "Arriving in 20 min" (L1603, `left:24px;top:400px`) | `jFloat` | 4s ease-in-out | white glass pill |
| chip "Pay cash at the door" (L1604, `right:24px;top:452px`) | `jFloat` | 4.4s / **delay 1.4s** | orange-tinted pill `rgba(215,59,0,.2)` |

**Does not move:** the 38px orange courier disc; the map blocks; the wordmark; headline, CTA,
page dots.

---

## E1 · Empty — no requests

Method: static-analysis only · lines 1637–1745 · **animated elements: 7**
The canonical `JeebEmptyState` illustration. All art is inline SVG in a 300×280 viewBox.

| element | primitive | duration/delay | notes |
|---|---|---|---|
| center glow `<circle r=74 fill=url(#e1glow)>` (L1669) | `jBreathe` | 3.2s ease-in-out | the halo-at-rest behind the mic |
| waveform "ears" `<g>` (L1712, `#FFB27A`, 3.5px round) | `jWave` | 1.4s ease-in-out | `transform-box:fill-box;transform-origin:center`. Group holds 2 static paths (3 strokes each) — **6 bars, one shared scaleY** |
| sparkle `<path>` 4-point, `#FFB27A` (L1717) | `jTwinkle` | 2.4s, no delay | top of the ring |
| sparkle `<path>`, `rgba(255,255,255,.55)` (L1718) | `jTwinkle` | 2.8s / delay .7s | right |
| sparkle `<path>`, `rgba(255,255,255,.4)` (L1719) | `jTwinkle` | 3s / delay 1.3s | left |
| star dot `<circle r=3>`, `#D73B00` (L1720) | `jTwinkle` | 2.2s / delay 1.7s | upper-left |
| star dot `<circle r=3>`, `rgba(255,255,255,.5)` (L1721) | `jTwinkle` | 2.6s / delay .4s | lower-right |

All 5 twinkles carry `transform-box:fill-box;transform-origin:center` — required for SVG scaling.

**Does not move:** **the route-dot ring** (`r=97`, `stroke-dasharray="2 9"`, L1668) and both orange
arcs (`stroke-dasharray="1 9"`, L1702/L1703) — **no `jDash`**; the outer field ring (`r=132`); the
**4 orbiting item medallions** (medicine / groceries / documents / gift) — they are placed, not
orbiting; the mic body, its rim and its highlight arc; the headline "What do you need?"; the body
copy and CTA.

> **Contradicts §2.7**, which describes medallions "orbiting on a `jDash` route-dot ring". On the
> tile the ring is still and the medallions are fixed. Default → build it as drawn.

---

## E2 · Empty — waiting for offers

Method: static-analysis only · lines 1746–1794 · **animated elements: 7**

A concentric-ring "radar" built from DOM divs (not SVG). Ring pulses run on a shared 3s period with
delays walking **outward-to-inward**, so the pulse reads as travelling *toward* the centre.

| element | primitive | duration/delay | notes |
|---|---|---|---|
| ring 300px (`1px rgba(215,59,0,.12)`, L1761) | `jArcPulse` | 3s / **delay 1s** | outermost, faintest |
| ring 216px (`1px rgba(215,59,0,.2)`, L1762) | `jArcPulse` | 3s / **delay .5s** | middle |
| ring 132px (`1px rgba(215,59,0,.32)`, L1763) | `jArcPulse` | 3s, no delay | innermost, brightest |
| center glow 150px `radial-gradient(circle, rgba(215,59,0,.35)→0)` (L1764) | `jBreathe` | 3s ease-in-out | same 3s period as the rings |
| jeeber avatar "K" (36px, L1770, `left:38px;top:74px`) | `jBreathe` | 2.6s, no delay | brightest — fill `.12`, border `.25`, blur 8px |
| jeeber avatar "N" (36px, L1771, `right:44px;top:120px`) | `jBreathe` | 2.6s / **delay .8s** | mid — fill `.09`, ink `.7` |
| jeeber avatar "R" (36px, L1772, `left:74px;bottom:52px`) | `jBreathe` | 2.6s / **delay 1.6s** | faintest — fill `.06`, ink `.45` |

The three avatars share one 2.6s period on a **0 / .8 / 1.6s** ladder — they read as jeebers fading
in and out of range. Opacity, fill alpha and ink alpha all step down together; keep all three.

**Does not move:** the 58px orange center disc (the "your request" broadcast icon) and its
`0 0 0 8px rgba(215,59,0,.22)` bloom ring; the small 6px orange satellite dot (L1773) — it does
**not** twinkle; the headline, body copy and CTA.

---

## E3 · Empty — no requests nearby

Method: static-analysis only · lines 1795–1888 · **animated elements: 4**
A night-street scene in SVG: a streetlamp over an empty road, with a "listening" delivery box.

| element | primitive | duration/delay | notes |
|---|---|---|---|
| streetlamp bulb `<circle r=7 fill=#FFC107>` (L1828) | `jBreathe` | 3.6s ease-in-out | amber, not orange |
| lamp light cone `<path>` `#FFC107` `opacity=".12"` (L1829) | `jBreathe` | 3.6s ease-in-out | **same 3.6s, no delay** — bulb and cone breathe as one; ship as a single composed element |
| listening arc, inner (`<path>` `#D73B00` 3.5px, L1864) | `jArcPulse` | 2.2s, no delay | radiates from the box |
| listening arc, outer (`<path>` `#D73B00` 3.5px, L1865) | `jArcPulse` | 2.2s / **delay .45s** | the .45s offset makes the pair read as an outward ripple |

**Does not move:** the delivery box and its straps; the ground line and road dashes; the 3.5px
orange emitter dot at the arcs' origin; the sparkles (this tile's sparkles are **static** — unlike
E1/E4); the green field glow; headline, copy, CTA.

---

## E4 · Empty — no orders yet

Method: static-analysis only · lines 1889–1932 · **animated elements: 4**

| element | primitive | duration/delay | notes |
|---|---|---|---|
| center glow 170px `radial-gradient(circle, rgba(215,59,0,.22)→0)` (L1904) | `jBreathe` | 3.2s ease-in-out | behind the box |
| sparkle 5px orange (L1913, `left:44px;top:44px`) | `jTwinkle` | 2.4s, no delay | `box-shadow:0 0 10px rgba(215,59,0,.9)` |
| sparkle 6px `rgba(255,255,255,.4)` (L1914, `right:40px;top:70px`) | `jTwinkle` | 2.8s / delay .7s | |
| sparkle 5px `rgba(255,255,255,.3)` (L1915, `right:64px;bottom:40px`) | `jTwinkle` | 3s / delay 1.3s | |

The 2.4 / 2.8 / 3s + 0 / .7 / 1.3s ladder is **identical to E1's** — same three-sparkle recipe.
Reuse one widget.

**Does not move:** the 250px orbit ring (`1px rgba(255,255,255,.07)`, L1903) — **no `jArcPulse`**;
the box body, lid and mic glyph; the headline "No orders yet"; body copy and CTA.

---

## E1 sample A · The empty pocket

Method: static-analysis only · lines 1933–1971 · **animated elements: 6** · §2.7 illustration variant

| element | primitive | duration/delay | notes |
|---|---|---|---|
| ground shadow `<ellipse>` (L1948) | `jBreathe` | 3.2s ease-in-out | pairs with the float below |
| pocket/bag `<g>` (L1952) | `jFloat` | 3.4s ease-in-out | `transform-box:fill-box;transform-origin:center` |
| sparkle `<path>` (L1958) | `jTwinkle` | 2.4s, no delay | |
| sparkle `<path>` (L1959) | `jTwinkle` | 2.8s / delay .6s | |
| star dot `<circle>` (L1960) | `jTwinkle` | 2.2s / delay 1.1s | |
| star dot `<circle>` (L1961) | `jTwinkle` | 3s / delay 1.6s | |

**Does not move:** both dashed paths (static, no `jDash`); the mic glyphs; headline and copy.
Note the float period (3.4s) and its shadow's breathe period (3.2s) are **deliberately unequal** —
the pairing slowly drifts out of phase, unlike R11's locked 2.6s/2.6s pin.

---

## E1 sample B · Ask from the balcony

Method: static-analysis only · lines 1972–2025 · **animated elements: 7** · §2.7 illustration variant

| element | primitive | duration/delay | notes |
|---|---|---|---|
| window/light `<rect>` (L1994) | `jBreathe` | 3.4s ease-in-out | |
| window/light `<rect>` (L1995) | `jBreathe` | 3.4s ease-in-out | same period, no delay — lit together |
| figure/parcel `<g>` (L2002) | `jFloat` | 3.6s ease-in-out | `transform-box:fill-box` |
| waveform `<g>` (L2004) | `jWave` | 1.3s ease-in-out | `transform-origin:center`; container-level as everywhere |
| route `<path>` (L2010) | `jDash` | **2.4s linear** | one of only 3 `jDash` instances on the board |
| beacon `<circle>` (L2016) | `jBreathe` | 1.8s ease-in-out | fast breathe = "live" |
| beacon `<path>` (L2017) | `jBreathe` | 1.8s ease-in-out | locked to the circle |

**Does not move:** the balcony/building geometry; headline and copy.

---

## E1 sample C · The beacon

Method: static-analysis only · lines 2026–2079 · **animated elements: 16** — the busiest tile on the
board · §2.7 illustration variant

| element | primitive | duration/delay | notes |
|---|---|---|---|
| star dot `<circle>` (L2039) | `jTwinkle` | 2.6s, no delay | |
| star dot `<circle>` (L2040) | `jTwinkle` | 3s / delay .9s | |
| sparkle `<path>` (L2041) | `jTwinkle` | 2.4s / delay 1.4s | |
| halo `<circle>` (L2048) | `jHalo` | 2.6s ease-out | `transform-box:fill-box;transform-origin:center` — the SVG halo recipe |
| 6 arc `<path>`s (L2056–L2061) | `jArcPulse` | 2.4s · delays **0 / .4 / .8 / 0 / .4 / .8** | two mirrored fans of 3; the delay ladder repeats per fan |
| 2 route `<path>`s (L2064, L2065) | `jDash` | 2s linear | the §2.6 canonical `jDash` value |
| beacon `<circle>` + `<path>` (L2066, L2067) | `jBreathe` | 1.6s, no delay | pair 1 |
| beacon `<circle>` + `<path>` (L2068, L2069) | `jBreathe` | 1.6s / **delay .8s** | pair 2 — half-period offset against pair 1 |

**Does not move:** the mic glyphs (4 static paths); the beacon mast; headline and copy.
This tile is the reference for **SVG-space** motion: every transformed SVG node carries
`transform-box:fill-box;transform-origin:center`. Flutter equivalent: transform about the child's
own centre, not the canvas origin.

---

## ⛔ Out of scope

`L1 Log in` (lines 2080–2120, 6 animated) and `L2 Sign up` (lines 2121–2171, 2 animated) were
**not studied** — deleted screens per JEBV4-199 / Q-044. Recorded only so the 84-declaration
audit reconciles: 76 in-scope + 8 in L1/L2.

---

## Implementation cheat-sheet

**Reusable composites worth building once (each appears ≥2×):**

| composite | appears on | recipe |
|---|---|---|
| Mic disc + halo ring | R2, R5, W1, (E1 sample C) | static orange disc + separate ring element running `jHalo` 2.2–2.6s. The ring is a sibling, never the disc itself |
| Glass bubble pair | R5, W1 | two `jFloat` bubbles, 4s and 4.4s with a **1.2s delay** on the second |
| Float chip pair | W2, W3 | 4s and 4.4s with **1.3s / 1.4s** delay on the second |
| Waveform row | R2, R5, W1, E1, sample B | **one** `jWave` on the container, static bars inside; 1.2–1.4s |
| Three-sparkle ladder | E1, E4, sample A | 2.4 / 2.8 / 3s at 0 / .7 / 1.3s delay |
| Pin + shadow | R11, W3 | `jFloat` 2.6–2.8s on the pin; R11 adds a `jBreathe` shadow on the **same** period |
| Concentric ring pulse | E2, W2, sample C | shared period, delay ladder; E2 walks outward-in (1 / .5 / 0s) |

**Rules confirmed by this study:**

1. `jWave` goes on the **container**; bars are static children. Never stagger bars.
2. `jHalo` goes on a **ring sibling**, never on the disc it surrounds.
3. In SVG, every animated node sets `transform-box:fill-box;transform-origin:center`.
4. Delay ladders are the design; copy the exact delays, they are not arbitrary.
5. All 20 zero-motion tiles ship **completely still**. Per §7.5 item 6, adding motion the board does
   not draw is a review-bounce.
6. Everything is `infinite` — no enter/exit or one-shot animations anywhere on the board.

## Open questions for §8

- **Q-M5-a** — §4 M5 promises R1 "rings+broadcast dot" motion; R1 has **zero** animated elements.
  Ship R1 still, or add motion the tile does not draw?
- **Q-M5-b** — §4 M5 promises `jDash` on the R3 map route; R3's route is static while W3's identical
  path animates. Ship R3 still?
- **Q-M5-c** — §2.7 describes E1's medallions "orbiting on a `jDash` route-dot ring"; the E1 tile's
  ring and medallions are both static. Does `JeebEmptyState` animate the ring for non-E1 surfaces,
  or match the tile exactly?
- **Q-M5-d** — §2.6's timing column is narrower than the board (see the widening table above).
  Ratify the widened ranges into `jeeb_motion.dart` defaults, or keep §2.6 values and treat
  per-tile figures as overrides?
- **Q-M5-e** — R2's "Recording — release to send" caption uses `jBreathe`, and W2's accent chip
  likewise. Confirm `jBreathe` is approved for **text**, not only glows/dots.
- **Q-M5-f (verification debt)** — every observation here is static; the live board was never
  rendered. Before the G-M5 gate, someone with a working Chrome path should eyeball R2, E2 and
  sample C to confirm perceived speed. The element→primitive→timing mapping itself is exact and
  does not need re-deriving.
