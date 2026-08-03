# MIDNIGHT — Ratified token sheet (M0-1)

**Ratified by Fable 2026-08-03.** Every value below is measured from `Jeeb Rich UI.dc.html`
(frequency-weighted) or explicitly marked *derived*. This sheet is the contract for M0-2…M0-8;
implementers do not re-measure and do not invent.

Measurement notes: board px = Flutter dp (1:1, per the pass-1 audit convention). The 32×
`0 24px 60px rgba(0,0,0,.5)` shadow and marketing-container styles are the TILE FRAME, not the
phone interior — excluded throughout.

---

## 1. ColorScheme (dark — the ONLY scheme)

The app becomes Midnight-only. **Ruling: `JeebTextStyles.light()` / `JeebColorRoles.light()` /
`JeebSemanticColors.light()` factories REMAIN (API stability) but are re-pointed to the same
Midnight values as `.dark()`** — a stray light-theme code path must render Midnight, never white.
`AppTheme` builds one theme; `themeMode` pins dark.

| Slot | Value | Source |
|---|---|---|
| `brightness` | `Brightness.dark` | — |
| `primary` | `#D73B00` | board orange, 23× — **budget §2.2 of master plan applies; M0-2 must override every auto-consumer** |
| `onPrimary` | `#FFFFFF` | 4.65:1 AA (pass-1 verified) |
| `primaryContainer` | `#431505` | *derived* deep-burnt step (board never draws this Material slot) |
| `onPrimaryContainer` | `#FFB499` | board orangeSoft tint |
| `secondary` | `#8A93D8` | 211× dominant periwinkle |
| `onSecondary` | `#070C33` | page navy |
| `secondaryContainer` | `#10175E` | surfaceHigh |
| `onSecondaryContainer` | `#B9C0F0` | inkSoft, 62× |
| `tertiary` | `#D73B00` | compat alias of primary (pass-1 files reference `.tertiary`) |
| `surface` | `#0B1351` | 45× card/nav navy |
| `surfaceContainerLowest` | `#070C33` | page |
| `surfaceContainerLow` | `#0A1147` | *derived* midpoint |
| `surfaceContainer` | `#0B1351` | = surface |
| `surfaceContainerHigh` | `#10175E` | 36× raised navy |
| `surfaceContainerHighest` | `#151C69` | *derived* one step above (menus/highest slabs) |
| `onSurface` | `#EDEFFC` | board primary ink |
| `onSurfaceVariant` | `#8A93D8` | muted ink role |
| `surfaceTint` | `Colors.transparent` | **kill M3 elevation tinting** |
| `error` | `#FF5252` | board danger (ink-first usage) |
| `onError` | `#070C33` | white-on-#FF5252 fails AA (~3.1:1); page navy passes (~5.9:1) |
| `errorContainer` | `#4A1220` | *derived* deep red-navy |
| `onErrorContainer` | `#FF7B7B` | board danger-soft |
| `outline` | `Color(0x24FFFFFF)` (white 14%) | glass-border cluster .12/.14/.16 |
| `outlineVariant` | `Color(0x1FFFFFFF)` (white 12%) | — |
| `scaffoldBackgroundColor` | `#070C33` | fallback only — screens mount `JeebMidnightField` |
| `canvasColor` / `cardColor` / `dialogBackgroundColor` | `#0B1351` | — |

## 2. JeebColorRoles (Midnight quartets)

| Role | solid | on | container | onContainer |
|---|---|---|---|---|
| success | `#3BB273` | `#070C33` | `#0E3B2C` *derived* | `#7BD9A4` |
| warning | `#FFC107` | `#3B2600` | `#4A3200` *derived* | `#FFDF9E` *derived* |
| info | `#8A93D8` | `#070C33` | `#10175E` | `#B9C0F0` |
| accent | `#D73B00` | `#FFFFFF` | `#431505` *derived* | `#FFB499` |

`onSuccess`/`onInfo` are page-navy: white ink on `#3BB273`/`#8A93D8` fails AA; navy passes.
Board evidence: success `#3BB273` deep / `#7BD9A4` soft; amber `#FFC107` 22×.

## 3. JeebSemanticColors (re-valued + NEW fields — API addition sanctioned)

| Field | Midnight value | Note |
|---|---|---|
| `mutedText` | `#8A93D8` | supersedes `#777FC0` AND pass-1 dark `#9DA3E0` — do not propagate either |
| `mutedSurface` | `#10175E` | raised navy |
| `readTick` | `#20F0FF` | keep; flag at R20 review |
| `accentTint` | orange 12% | keeps compositing over navy |
| `accentRing` | orange 30% | stroke only |
| **NEW** `inkSoft` | `#B9C0F0` | brighter muted, 62× |
| **NEW** `amber` | `#FFC107` | stars/ratings |
| **NEW** `orangeBright` | `#FF6A2B` | gradient ends, glow cores |
| **NEW** `orangeSoft` | `#FFB27A` | waveform bars, soft accents (`#FFB499` = its deep pair via accent.onContainer) |
| **NEW** `orangePressed` | `#C23300` | pressed CTA (darker step `#B33000` for keyboard-pressed if needed) |
| **NEW** `glassFill` | white 7% | rest glass card fill |
| **NEW** `glassFillEmphasis` | white 10% | capsule / raised glass |
| **NEW** `glassFillPressed` | white 14% | pressed/active glass |
| **NEW** `glassBorder` | white 12% | 1px, every glass surface |
| **NEW** `glassBorderStrong` | white 16% | hero capsules |

## 4. Glass recipe (ratified)

- **Rest glass card:** fill `glassFill` (7%), border 1px `glassBorder`, radius `lg` — **NO blur**
  (pre-baked translucency).
- **Hero glass (voice capsule, floating nav):** fill `glassFillEmphasis`, border `glassBorderStrong`,
  radius `capsule`/`pill`, real `BackdropFilter` blur **10** (ladder: soft 8 / standard 10 / hero 12;
  board 8×38, 10×44, 12×23; 14–18 exist but are rare marketing-frame cases).
- **Budget: ≤2 real BackdropFilters per screen**, hero surfaces only.

## 5. Radii ladder (snap to nearest; ±2 board tolerance)

`sm 9` (51×) · `md 14` (42×) · `lg 18` (32×; board 16s snap here) · `xl 22` · `sheet 26` ·
`hero 34` · `capsule 40` (32×, voice capsule) · `pill 999` (269×).

Spacing: keep the 4px scale; default screen gutter stays 24 — a tile that measurably draws
tighter gutters wins per-screen (STUDY step notes it).

## 6. Type ramp re-cut (all styles: `fontFamily: Inter`, `fontFamilyFallback: ['Baloo Bhaijaan 2', 'Apple Color Emoji', 'Noto Color Emoji']`)

| Field | Midnight | was | Evidence |
|---|---|---|---|
| `statHero` | **40 / w800 / −1.2** | 38/w800/−1.0 | 40px 2×, cluster 36–44 |
| `statDisplay` | **44 / w800** | 42/w800 | 44px 4× (OTP tiles) |
| `h1` | **26 / w700 / −0.6** | 24/w700 | board 25–27 (27×7); tracking −.6 ×6 |
| `h2` | **20 / w700 / −0.5** | 20/w700 | 20px 24×; tracking −.5 ×7 |
| `titleProminent` | **17 / w700 / −0.2** | 17/w700 | 17px 22× |
| `cardTitle` | **15.5 / w700** | same | 15.5px 13× |
| `body` | **14.5 / w500, 21px line** | 13.5/19px | audit: board body 14.5–15 (14.5×18, 15×64) |
| `bodySmall` | **12.5 / w600** | 12/w600 | 12.5px 58× (12px 129× is caption-band pollution) |
| `caption` | **11.5 / w600** | same | 11.5px 24× |
| `label` | **10.5 / w700** | same | 10.5px 10× |
| `badge` | **10.5 / w800 / +1.0** | +0 | uppercase badges share the 1px-tracking cluster (35×) |
| `sectionLabel` | **11 / w700 / +1.2, ink `#8A93D8`** | ink #777FC0/#9DA3E0 | tracking 1.2px 13×; single ink both factories |
| `price` | **22 / w800 / −0.5** | 21/w800 | 22px 7×; money emphasis is doc-13 Pattern C carry |
| `button` | **17 / w600** | same | — |
| `keypadDigit` | **23 / w700** | same | 23px 10× |
| `codeInput` | **29 / w800** | same | 29px 2× |

Fonts to bundle (M0-5): **Inter ExtraBold w800** (w800 currently degrades to w700 — that
degradation is no longer acceptable: money emphasis depends on it) and **Baloo Bhaijaan 2
w500/600/700** — face CONFIRMED from `_ds/tokens/typography.css`:
`--font-arabic: "Baloo Bhaijaan 2", "Inter", "SF Arabic", sans-serif`.

## 7. JeebShadows re-cut (old navy-tinted set DIES — invisible on navy)

| Name | Value | Use |
|---|---|---|
| `ctaOrange` | `0 14px 32px rgba(215,59,0,.45)` | mic disc, orange CTA (16×) |
| `ctaOrangeSmall` | `0 8px 20px rgba(215,59,0,.40)` | small orange pills (5×) |
| `glowRest` | `0 0 30px rgba(215,59,0,.18)` | halos at rest (5×) |
| `glowDot` | `0 0 10px rgba(215,59,0,.85)` | live/broadcast dots (.8/.9 cluster) |
| `glowDotSuccess` | `0 0 14px rgba(59,178,115,.9)` | online/success dots |
| `micActive` | `0 0 0 10px rgba(215,59,0,.2)` + `0 20px 46px rgba(215,59,0,.55)` | recording mic ring |
| `floatNav` | `0 20px 46px rgba(0,0,0,.4)` | floating pill nav, sheets |
| `overlay` | `0 2px 8px rgba(0,0,0,.4)` | small floating chips |

## 8. JeebMidnightField spec (M0-3 contract)

- **Base wash (canonical, 35×):** `linear-gradient(175deg, #10175E 0%, #0B1351 45%, #070C33 100%)`
  — lighter at top, deepest at bottom.
- **Orange glow:** radial ellipse ≈520×420 board-px (≈1.35× screen width), `#D73B00` → transparent
  at 58–70% stop. Alpha by variant: hero .26–.30 · content .22 · sheet .26.
  Placements (fractions of the field): `topEnd (0.88, −0.06)` · `centerUpper (0.50, 0.34–0.42)` ·
  `bottom (0.50, 0.92–0.96)`.
- **Periwinkle wash:** `rgba(119,127,192,.18–.22)` — the ONE sanctioned use of legacy
  periwinkle (decorative glow only). CORRECTED 2026-08-04: hero anchor = `(0.0, 0.39)`
  (start-edge mid-height, pixel-measured on R1; the caption's "periwinkle wash left");
  `(0.90, 1.00)` is the alternate anchor from other tiles, selectable via `washPlacement`.
- **Hero orbit arcs (corrected from R1 pixels):** two concentric arcs at `(0.90, 0.055)`,
  radii `0.40 W` / `0.26 W`; OUTER = white ≈7%, INNER = ORANGE ≈15% (tile-drawn, budget-
  sanctioned), both × jArcPulse opacity.
- **Success wash variant:** `rgba(59,178,115,.16)` at `(0.88, −0.06)` — earnings/money screens.
- Variants: `hero` (wash + orange glow + periwinkle wash + orbit rings + twinkles) ·
  `content` (wash + one quiet glow, no rings) · `map` (dimmed edges over map) ·
  `sheet` (navy surface + top glow).
- Orbit-ring strokes (measured from board SVG): quiet background rings `white @ 7%`,
  ~1.5px, **dotted** `stroke-dasharray 1 9` (the route-dot ring; variants `2 9`, `1 12`);
  emphasized/pulsing arcs (`jArcPulse` targets): SVG stroke `white @ 22%`, but the RENDERED
  resting composite on R1 measures ≈7% — the ratified resting value is the hero-arc block
  below; occasional periwinkle ring `#777FC0` (decorative, sanctioned like the wash). Dashed drop-zone borders:
  `1.5px dashed white @ .30–.35`. Map route line: `#D73B00`, dash pattern `5 6`, animated
  by `jDash`.

## 9. AA pairs the re-cut contrast test must gate (M0-8)

- `#EDEFFC` on `#070C33` / `#0B1351` / `#10175E` (all ≫7:1)
- `#8A93D8` on `#0B1351` and `#070C33` (body-text bar 4.5:1 — the master plan expects ≈AA;
  test asserts, and if a pair lands <4.5 the FIX is: that pair is large-text-only, mirror what
  the board does — do not shift the hex)
- `#B9C0F0` on all three navies · `#FFFFFF` on `#D73B00` (4.65:1) · `#070C33` on `#FF5252`,
  `#3BB273`, `#FFC107`, `#8A93D8` · `#FF7B7B` / `#7BD9A4` / `#FFDF9E` / `#FFB499` on their
  containers · retire the brown-on-white guard entirely.

## 10. Explicitly retired

- Light palette (`#EAE7EB`/`#E5E1E5`/`#F4F4F6` surfaces, brown outlines `#916F66`/`#5C4038`,
  ink `#0B0E53`) — dies everywhere.
- Legacy periwinkle `#777FC0` as ink (glow-wash use only, §8) and pass-1 dark muted `#9DA3E0`.
- Navy-tinted shadow set (§7 replaces).
- Tier spectrum (`jeeb_tier_colors.dart`) is UNCHANGED this wave — tier hues are product
  semantics, not theme chrome; they render on navy already. Revisit only if R9's tile disagrees.
