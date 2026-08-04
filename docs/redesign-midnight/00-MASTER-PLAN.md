# MIDNIGHT — Master plan, loop & resume protocol

**Date:** 2026-08-03 · **Owner directive:** the **Rich UI "Midnight" board is now THE spec** — the
whole app follows it. This supersedes the pass-1 ruling that the base 24-screen board was the spec
and Rich UI was "reference only".

**Mission:** every production screen and **every empty / loading / error state** ships the Midnight
design language. No surface keeps the light theme. One branch. No exceptions beyond the ⛔ list.

---

## 0. Ground rules (override everything else)

1. **ONE branch: `feat/redesign-midnight`**, cut from `integration/redesign-ui` @ `90970d89`.
   All waves commit there. Never a new repo, never a second branch, push to
   `origin` (olivium-dev/jeeb-mobile) regularly.
2. **The spec is the Rich UI board**, read three ways:
   - Tiles (PNG): `/Users/oudaykhaled/Downloads/Jeeb - Marketing-3/export-rich-ui/screens/`
     — **each tile's bottom caption band is the designer's UX note. Read it; it is part of the spec.**
   - Live animations: open `file:///Users/oudaykhaled/Downloads/Jeeb%20-%20Marketing-3/Jeeb%20Rich%20UI.dc.html`
     in Chrome and **watch the tile before implementing its motion**. The PNGs froze one frame;
     the HTML is the truth for what moves, how fast, and what stays still.
   - Exact px/hex: the same HTML file, inspected.
   - The tile frame includes marketing-page backdrop + caption band. **The spec surface is the
     phone interior only.**
3. **Model routing:** the orchestrator session runs on **Fable** and makes all critical calls
   (theme/token cuts, kit API, navigation, ambiguity rulings, accept/reject of screens, deletions).
   Implementation and mid/light work runs on **Opus** subagents (`Agent` tool, `model: "opus"`),
   using the prompt template in §7.3. An Opus agent that hits an ambiguity **stops and returns the
   question** — it never invents design.
4. **⛔ Never build `L1 Log in` / `L2 Sign up`** (tiles 34–35). The email/password funnel was
   REMOVED in JEBV4-199 (Q-044 RATIFIED, `app_router.dart:753-758`). Auth = phone-OTP + social only.
5. **Honest omission policy stands:** a designed fact the wire contract can't carry gets
   `TODO(midnight): omitted, not faked` — never fake data. The 13 missing gateway fields are ONE
   backend contract request (`../redesign-2026-08/13-DESIGN-VS-IMPLEMENTATION.md` §Pattern A), not
   46 mobile hacks.
6. **Frozen test identifiers** (Maestro/semantics ids) are preserved — **re-home them onto
   board-drawn elements or zero-size semantics nodes**; then delete the chrome that existed only to
   host them (standing ruling; kills doc-13 Pattern D everywhere).
7. **`lottie: 3.3.1` stays an EXACT pin** — `^` resolves to 3.5.1 locally and breaks CI at
   Flutter 3.38.9.
8. Validation that counts is the **real-app standard**: real OTP login, real taps, two devices for
   chat, final pass on the physical S22. Endpoint-200 proofs and harness-only captures don't close
   the engagement.
9. Commit discipline: **one commit per completed checklist item**, message
   `feat(midnight): <item> — <what changed>`; tick the §6 checklist row **in the same commit**;
   `git push` every ~3 commits.
10. Before editing any screen: **confirm the file is reachable from `lib/main.dart`**
    (`../redesign-2026-08/screen-repo-map.md` — 3 of 24 package-map entries pointed at dead code;
    class-name grep finds the dead copy first).

---

## 1. Sources of truth

| What | Where |
|---|---|
| Tile PNGs (35) + index | `~/Downloads/Jeeb - Marketing-3/export-rich-ui/{screens,INDEX.md}` |
| Live board (animations, px, hex) | `~/Downloads/Jeeb - Marketing-3/Jeeb Rich UI.dc.html` |
| Design assets to import | `export-rich-ui/assets/delivery-3d.png`, `assets/jeeb-wordmark.svg` |
| Corrected screen→file map | `docs/redesign-2026-08/screen-repo-map.md` (**wins over any other map**) |
| Full 71-screen inventory + the 46 remainder | `docs/redesign-2026-08/01-SCREEN-COUNT.md` §3d |
| Honest audit of pass 1 (carry-ins) | `docs/redesign-2026-08/13-DESIGN-VS-IMPLEMENTATION.md` |
| Pass-1 motion spec | `docs/redesign-2026-08/08-MOTION-SPEC.md` |
| Verification baseline + env traps | `docs/redesign-2026-08/_BASELINE.md` |
| Pass-1 theme/kit (the layer we re-cut) | `lib/core/theme/…`, `lib/core/widgets/jeeb/…` |

---

## 2. The Midnight design contract

### 2.1 Palette (extracted from the board HTML, by frequency of use)

| Token role | Hex | Evidence / usage |
|---|---|---|
| `midnight.page` — deepest field | `#070C33` | `body{background}` — the page base |
| `midnight.surface` — card/nav navy | `#0B1351` | 45× |
| `midnight.surfaceHigh` — raised navy | `#10175E` | 36× |
| `midnight.ink` — primary text | `#FFFFFF` / `#EDEFFC` | headings, key figures |
| `midnight.inkMuted` — the voice of the app | `#8A93D8` | **211×** — dominant secondary ink |
| `midnight.inkSoft` — brighter muted | `#B9C0F0` | 62× — captions on dark, emphasized muted |
| `midnight.orange` — THE accent | `#D73B00` | 23× — **strictly budgeted, see 2.2** |
| `midnight.orangeBright` | `#FF6A2B` | glows, gradient ends |
| `midnight.orangeSoft` / tints | `#FFB27A`, `#FFB499` | waveform bars, soft accents |
| `midnight.amber` — stars/ratings | `#FFC107` | 22× |
| `midnight.success` | `#3BB273` (deep) / `#7BD9A4` (soft) | money-in, positive chips |
| `midnight.danger` | `#FF5252` / `#FF7B7B` | errors on navy |
| legacy periwinkle | `#777FC0` | 7× only — superseded by `#8A93D8`; do not propagate |
| pressed orange shades | `#C23300`, `#B33000` | pressed/darkened CTA states |

Notes: pass-1's brown-for-periwinkle AA stopgap (doc-13 Pattern B) **dies with the light theme** —
on navy the board's periwinkle IS the ink. Re-cut the guarded contrast test for navy pairs
(`#8A93D8` on `#0B1351` ≈ AA for body text; verify per-pair in the M0 token test, largest text may
use lower-contrast tints only where the board does).

### 2.2 The orange budget

R1's designer caption, verbatim: *"orange reserved for the mic and the active tab."* Generalized
rule: **orange appears only where the tile draws it** — the mic disc/capsule, the active nav tab,
live/"Broadcasting" accents, primary CTA **when the tile shows it orange**. Everything else defaults
to frosted glass, periwinkle ink, or navy surfaces. **When in doubt: not orange.**
Consequence for Material: `colorScheme.primary` may be orange, but every Material widget that
auto-consumes primary (FAB, filled buttons, progress, selection, focus rings, switches, sliders,
text cursors, chips) must be checked — either themed to the correct Midnight treatment or
explicitly styled. Do not let Material spend the orange budget for you.

### 2.3 Background — a WIDGET SYSTEM, not a color (owner flagged this)

A flat `#070C33` scaffold is **wrong**. The board's field is layered — R1 caption: *"layered navy
field (orange glow top-right, periwinkle wash left), orbit rings, frosted-glass voice capsule,
cards and floating nav."* Build once in M0:

- `JeebMidnightField` — paints: base vertical wash `#070C33 → #0B1351`-family, a soft **orange
  radial glow** (placement variant), a **periwinkle wash**, optional **orbit rings** (thin
  periwinkle arcs, the `jArcPulse` targets), optional twinkle dots. Variants (pick per tile):
  `hero` (home/onboarding — full treatment), `content` (forms/lists — quieter, no rings),
  `map` (tracking — dimmed edges over the map), `sheet` (bottom sheets — navy surface + top glow).
- **Every screen renders on this field.** `scaffoldBackgroundColor` is the base color only as a
  fallback; screens mount the field widget (via the kit scaffold) so glows/rings are consistent.
- **Frosted glass** surfaces (voice capsule, cards, nav): translucent white fill (≈6–10%) +
  1px white ≈12% border + radius; **real `BackdropFilter` blur budget ≤1–2 per screen** (hero
  surfaces only) — everywhere else use pre-baked translucency. Perf on low-end Android matters.
- **No white flash**: check route transitions, first frame, dialogs, keyboards — anything that
  betrays a light Material default underneath.

### 2.4 Material overrides (the owner's explicit caution — do these deliberately in M0)

Re-cut `ThemeData` to `Brightness.dark` with, at minimum, ALL of:

- `ColorScheme`: dark; `surface`/`surfaceContainer*` = navy family; **`surfaceTint: Colors.transparent`**
  (kill M3 elevation tinting — it turns navy purple); `onSurface`/`onSurfaceVariant` = ink roles;
  `primary`/`secondary`/`error` per §2.1; check `outline`/`outlineVariant` (periwinkle @ low alpha).
- `scaffoldBackgroundColor: #070C33`; `canvasColor`, `cardColor`, `dialogBackgroundColor` = navy.
- Sub-themes: `appBarTheme` (transparent over the field, white ink, no elevation),
  `bottomNavigationBarTheme`/`navigationBarTheme` (the **floating pill nav** is a kit widget, but
  theme the fallback), `cardTheme`, `chipTheme` (StadiumBorder stays), `dialogTheme`,
  `bottomSheetTheme` (navy + top radius), `snackBarTheme`, `dividerTheme` (periwinkle @ ~12%),
  `inputDecorationTheme` (frosted field, no box-in-a-box), `switchTheme`, `sliderTheme`,
  `progressIndicatorTheme`, `popupMenuTheme`, `menuTheme`, `datePickerTheme`, `timePickerTheme`,
  `textSelectionTheme` (cursor + handles periwinkle/orange per board), `tooltipTheme`,
  `listTileTheme`, `checkboxTheme`, `radioTheme`.
- `splashFactory` / hover / focus: subtle white-alpha ripple, never Material purple.
- **System chrome:** `SystemUiOverlayStyle.light` everywhere (white status glyphs on navy),
  transparent status + nav bars, Android nav bar navy; **iOS keyboard `Brightness.dark`**.
- Scroll glow/stretch: dark-appropriate (`ColorScheme` handles glow color — verify on Android).
- **Google Maps needs a dark style JSON asset** (R3/R11 tiles show navy maps) — a light default
  map would blind the theme. Add `assets/map_styles/midnight.json`, apply on every `GoogleMap`.
- Images/illustrations: import `delivery-3d.png` + `jeeb-wordmark.svg`; audit existing light-theme
  assets and Lotties for navy-hostile art (see M5).

### 2.5 Typography

- Sans = **Inter** (already bundled 400/500/600/700). **Add Inter ExtraBold (w800)** — money
  emphasis was literally invisible without it (doc-13 Pattern C).
- **Arabic brand face**: the board sets `--font-arabic` (pass-1 identified **Baloo Bhaijaan 2**;
  M0 must confirm the exact face from the board package `support.js`/HTML before bundling).
  Bundle it + add `fontFamilyFallback: [<arabic face>, <platform emoji>]` on the ramp — closes
  the "Arabic never renders in brand face" defect and the emoji-tofu question at once.
- Re-cut the ramp (`jeeb_text_styles.dart`) against the **Rich UI HTML's actual sizes**: pass-1
  ran one step small (h1 24 vs board 25–27; body 13.5 vs 14.5–15) and dropped the board's negative
  tracking (−0.5/−0.6). One ruling in M0, then every screen inherits.
- Ink colors move to §2.1 roles; sentence case per DS; copy comes from the tile literals.

### 2.6 Motion — the 8 Midnight primitives (extracted from the board CSS, exact)

Implement once in M0 as `lib/core/motion/jeeb_motion.dart` (curves/durations as constants +
reusable widgets), then screens consume. **Watch each tile live in Chrome before wiring** — the
PNGs cannot tell you what moves.

| Primitive | Keyframes (exact) | Board timing | Used for |
|---|---|---|---|
| `jFloat` | translateY 0 → −7px → 0 | 4s / 4.4s ease-in-out ∞ (delays up to 1.2s) | floating illustrations, walkthrough art |
| `jTwinkle` | opacity .2→1→.2, scale .7→1.15→.7 | 2.4–3s ease-in-out ∞, staggered .7s/1.3s | star dots around illustrations |
| `jBreathe` | opacity .45→1→.45 | 1.6–3.6s ease-in-out ∞, staggered | glows, live dots ("Broadcasting"), halos at rest |
| `jWave` | scaleY .5→1.15→.5 | 1.3s ease-in-out ∞ (per-bar stagger) | **voice waveform bars** |
| `jDash` | stroke-dashoffset → −40 | 2s linear ∞ | dashed route/orbit lines (map path, rings) |
| `jHalo` | scale .75→1.6, opacity .8→0 | 2.6s ease-out ∞ | **mic halo pulse** |
| `jArcPulse` | opacity .15→1(@35%)→.15 | 2.4s ease-in-out ∞, staggered .4s/.8s | orbit-ring arcs behind heroes |
| `jBlink` | opacity 1↔0 hard cut | 1.1s step-end ∞ | live-transcript caret |

Rules: respect `MediaQuery.disableAnimations` (render the rest frame); no novelty motion the tile
doesn't show; existing pass-1 Lotties are AUDITED in M5 (recolor/replace navy-hostile art; the 2
deliberately-unwired ones stay unwired and unregistered).

### 2.7 Empty states — "Empty ≠ dead" (owner emphasized)

E1's caption, verbatim: *"a drawn vector illustration of the brand promise — bring me anything:
medicine, groceries, documents and a gift orbit the glowing mic on the route-dot ring, waveform
radiating. Flat two-tone objects in the app's palette (white/periwinkle bodies, orange accents),
no stock art."*

- Build the pattern once in M1: `JeebEmptyState` = Midnight field + **composed illustration**
  (icon medallions orbiting on a `jDash` route-dot ring, `jHalo`/`jBreathe` center, `jTwinkle`
  stars, `jFloat` drift) + white headline + periwinkle body + optional CTA. Prefer composed
  widgets over baked PNGs; PNG only if fidelity demands.
- E1–E4 tiles are the four canonical instances; **E1 samples A/B/C** (empty pocket / balcony /
  beacon) are the approved illustration alternatives for surfaces that need variety.
- **Every screen's empty, loading, AND error state** uses this pattern family (loading = the
  illustration skeleton breathing; error = danger-tinted variant). M4 sweeps the app so none is
  missed — including states the catalog harness can't reach.

---

## 3. Tile → screen → file map (M2 scope)

Files relative to `lib/features/` unless noted. **Carry-ins** = surviving defects from
`13-DESIGN-VS-IMPLEMENTATION.md` to close while the screen is open (its P0/P1 entries + patterns).

| Tile | Design | Screen file(s) | Notes / carry-ins |
|---|---|---|---|
| R1 (01) + E1 (27) | Client home + its empty | `home_client/presentation/client_home_screen.dart` (+ `client_home_empty_view.dart`, `pending_requests_tab.dart`, `replies_card.dart`) | doc-13 P0-6/P0-7 (hold-to-talk promise, single "View offers" pill); waveform/reach are Pattern-A TODOs |
| R2 (02) | Voice recording | `voice_request/presentation/voice_recording_screen.dart` | **P0-5: LIVE TRANSCRIPT band** — ship the designed awaiting-state card + `jBlink` caret; `jWave` bars, `jHalo` mic |
| R3 (03) | Live tracking | `live_tracking/presentation/live_tracking_screen.dart` | dark map style; `jDash` route; header meta P1; courier card Pattern-A TODOs |
| R4 (04) | Wallet | `wallet/presentation/wallet_hub_screen.dart` | P2 tints → new tokens |
| R5 (05) + W1–W3 (24–26) | Onboarding + 3 walkthrough slides | `onboarding/presentation/onboarding_screen.dart` | slide art gets `jFloat`+`jTwinkle`; copy from tiles; AR retranslation flag |
| R6 (06) | Registration | `registration/presentation/registration_screen.dart` | fix social-pill labels + box-in-a-box field (P1) |
| R7 (07) | OTP verify | `registration/presentation/otp_verification_screen.dart` (mounted by R6's file) | delete/re-home Verify pill (P0-carry, Pattern D) |
| R8 (08) | Transcription review | `transcription/presentation/transcription_screen.dart` | low-confidence underline is Pattern-A; remove injected waveform from scrubber row |
| R9 (09) | Request type (+ tier catalog section) | `request_type/presentation/request_type_screen.dart` | **P0-3/P0-4: compact radio rows (`JeebTierRow.compact`), badge on Standard, pre-select** |
| R10 (10) + E2 (28) | Offers + waiting-for-offers empty | `client_offers/presentation/client_offers_screen.dart` (+ waiting state; verify exact surface in STUDY) | P1 row-layout fixes; distance is Pattern-A |
| R11 (11) | Location picker | `location/presentation/client_location_screen.dart` + `capture_location_screen.dart` | **P0-1/P0-2: wire map builder; DELETE legacy `/location` route + orphan** (`app_router.dart:966-971`); highest-risk item |
| R12 (12) | Request summary | `request_summary/presentation/request_summary_screen.dart` | **P0-8: fix harness (`standInRouter`) + `canPop` hardening + ICU plural** — screen is UNVERIFIED today |
| R13 (13) | OTP handover | `otp_handover/presentation/otp_handover_screen.dart` | demote added rating CTA (Pattern D); arrival banner fixture |
| R14 (14) | Receipt confirm | `delivery_receipt/presentation/delivery_receipt_screen.dart` | money emphasis: w800 + size step |
| R15 (15) | Mutual rating | `rating/presentation/mutual_rating_screen.dart` | counterpart-name plumbing (3 route builders, P1); star fill P2 |
| R16 (16) + E3 (29) | Jeeber home + no-requests-nearby empty | `jeeber_home/presentation/jeeber_home_screen.dart` (+ `jeeber_feed_tab_view.dart`, `availability_card.dart`, `jeeber_feed_card.dart`) | P1 cluster: availability strip, rating pill, "Make of…" squeeze |
| R17 (17) | Offer composer | `offers/presentation/offer_submission_screen.dart` | 3 ETA pills + default; l10n validation strings |
| R18 (18) | Active delivery — Jeeber | `active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart` | wire `onEnterGoodsCost` or get 2-pill ratified; 4-segment stepper ruling |
| R19 (19) | Earnings | `earnings/presentation/earnings_dashboard_screen.dart` | hero stat #3; rows Pattern-A |
| R20 (20) | Order chat | `deep_link_targets/chat_detail_screen.dart` (**the `/chat/:id` container, 1795 LOC**) + `chat/presentation/chat_screen.dart` | **pass-1's zero-diff trap was HERE — assert non-zero diff on the container**; green banner → quiet timeline chip; B-04 no-mic stands |
| R21 (21) + E4 (30) | Order history + no-orders empty | `order_history/presentation/order_history_screen.dart` | row facts are Pattern-A; expired-row AA ruling pending |
| R22 (22) | Settings | `settings/presentation/screens/settings_screen.dart` (NOT `live_settings_screen.dart`) | MORE-band restructure (P1); CF rulings stand |
| R23 (23) | Become a Jeeber | `kyc/presentation/kyc_wizard_screen.dart` | ID-band relocation (P1); encryption clause legal hold |
| — | **Shell / floating pill nav** (drawn inside R1) | `shell/shell_screen.dart` | **frames all 5 tabs — do early**; orange = active tab only |
| E1 samples A/B/C (31–33) | approved illustration variants | consumed by §2.7 / M4 | not separate screens |
| ⛔ L1/L2 (34–35) | Log in / Sign up | **DO NOT BUILD** | JEBV4-199 Q-044 |

---

## 4. Wave plan

| Wave | What | Who | Gate |
|---|---|---|---|
| **M0 Foundation** | Token re-cut to §2.1–2.5 (`app_theme.dart`, `jeeb_color_roles`, `jeeb_semantic_colors`, `jeeb_text_styles`, `jeeb_shadows`); Material override sweep §2.4; `JeebMidnightField`; motion module §2.6; dark map style; fonts (w800 + Arabic face + fallbacks); system chrome; AA test re-cut for navy; import board assets; fix capture-harness holes (doc-13 Pattern G: `standInRouter` for R12, star token provider, harness emoji font) | **Fable designs the token sheet; Opus implements** | app boots on navy everywhere kit is used; analyze 0 errors; token tests green |
| **M1 Kit re-skin** | All 32 kit widgets (`lib/core/widgets/jeeb/`) restyled on the new tokens; add `JeebGlassCard`/glass capsule + **`JeebEmptyState`** (§2.7) + floating pill nav; kit metric fixes (doc-13 Pattern E: chip size classes, `JeebListRow` padding, 48dp hit-test-not-layout); kit tests updated; **kit re-frozen after** | Opus fleet, Fable reviews API changes | 476+ kit tests green; 0 raw hex outside theme |
| **M2 The 24 mapped surfaces** (§3) | Per-screen loop §7, journey order: shell + R1/E1 first, then client loop R2→R9→R11→R12→R10/E2→R3→R13→R14→R15, jeeber loop R16/E3→R17→R18→R19, then R20, R21/E4, R4, R22, R23, R5+W, R6, R7, R8 | Opus per screen, Fable review each | every screen: §7.5 definition of done |
| **M3 The 46 remaining screens** | System-derived restyle (no tile: field + tokens + kit + nearest tile pattern; **all states**). Order = `01-SCREEN-COUNT.md` §3d tiers: **Tier 1 (11)** delivery_detail, escalate, no_offer_timeout, cancellation, order_summary, jeeber_request_detail, customer_profile, notifications_list, rating_screen, delivery_man_profile (+shell already done) → **Tier 2 (6)** wallet/earnings subtree → **Tier 3 (6)** KYC funnel → **Tier 4 (7)** settings subtree → **Tier 5 (16)** edge/support. **The 9 `ORPHAN (JEBV4-227)` screens: Fable rules delete-vs-restyle per screen** (default: delete dead routes, like pass-1 did `/location`) | Opus per screen, Fable review + deletion rulings | same as M2 |
| **M4 Empty/edge-state sweep** | Enumerate EVERY empty/loading/error surface app-wide (grep `OmdsEmptyStatePage`, `EmptyView`, `ErrorView`, error/`loading` builders, `when(`-state branches); each gets the §2.7 pattern (E1-sample variants for variety); kill any remaining light-theme state | Opus sweep, Fable spot-checks | zero light-theme states left; sweep report committed |
| **M5 Motion pass** | Wire per `03-MOTION-NOTES.md` (AUTHORITATIVE per-element, board-measured — supersedes the examples formerly here: R1/R3/E1-ring are STATIC on the board; jWave is container-level, no per-bar stagger; timing ranges wider than §2.6's column). Audit pass-1 Lotties on navy; reduced-motion verified | Opus, Fable arbitrates taste | motion matches the live board side-by-side |
| **M6 Global audits** | Raw-hex grep (0 outside theme/motion files); `Colors.` grep; Material-leak checklist §2.4 walked surface-by-surface (dialogs, pickers, snackbars, menus, scroll glow, keyboard, status bar, route transitions — **no white flash anywhere**); RTL sweep; AA re-test; full `flutter analyze` + full test suite vs baseline; catalog re-capture ALL entries incl. states | Opus executes, Fable signs | §5 gates all green |
| **M7 Device validation** | Build on device; **real-flow standard**: real OTP login (+9613000077 / OTP 1234 jeeber), two-sided journey client↔jeeber incl. chat on 2 devices, door OTP, rating; screenshot key screens next to tiles; final pass on the physical S22 | Fable orchestrates, owner sees results | owner sign-off |

---

## 5. Verification baseline & environment (do not re-derive — measured)

From `docs/redesign-2026-08/_BASELINE.md`:

- `flutter analyze --no-pub`: **5 issues, 0 errors** (5 = `containsSemantics` deprecation infos,
  local-SDK-only). Bar: **0 errors, no new warnings**.
- `flutter test`: exactly **4 pre-existing failures** are not ours:
  `client_offers_screen_test` (inside R10!), `mutual_rating_tag_chips_l10n_test` (inside R15!),
  `jeeber_feed_card_test`, `gesture_log_test` (local-SDK skew, green in CI). A 5th failure is a
  regression. If your change alters one of the first two's failure *mode*, say so explicitly.
- **`jeeb-mobile` main is RED in CI** on 3 of those — don't panic-chase CI red that predates us.
- Env preconditions (this machine, `oudays-mbp-2`, already corrected): sibling
  `../omds-flutter` on `origin/main` ≥ `6f9c166` (NOT `iter5-flutter-blankscreen`);
  `pubspec.lock` dio ≥ **5.11.0**. **On any other machine, re-apply `_BASELINE.md` env fixes
  first or the gate reports ~155 phantom failures.** Local Flutter 3.44.2 vs CI 3.38.9 (hence the
  lottie exact pin).
- Per-screen verification = targeted test suites + catalog capture; full suite at wave gates only.
- **Per-directory diff assertion:** the screen's primary file(s) MUST show a non-zero diff —
  pass-1's screen-21 "passed" with a zero-line diff on its most important file.

---

## 6. THE CHECKLIST (living state — tick rows in the same commit as the work)

Legend: `[ ]` todo · `[~]` in progress · `[x]` done (add `@commit-sha date`) · `[D]` deleted
(ORPHAN ruling) · `[!]` blocked → §8 queue.

### Wave gates
- [x] **G-BOOT** branch `feat/redesign-midnight` created; plan + doc-13 + `actual/` + harness
  fixes (`test/support/fonts`, `test/tools`) committed; baseline re-measured @8b49108b 2026-08-03.
  Re-measured analyze on this branch: **0 errors / 0 warnings / 31 infos** (the `_BASELINE.md`
  "5 infos" figure predates the integration merge; the extra infos are pre-existing test-file
  deprecations on `integration/redesign-ui`, none ours). Bar stays: 0 errors, no new warnings.
- [x] **G-M0** foundation gate @2026-08-04 — analyze 0 err/31 infos; token tests green (165 theme + 27 field + 54 motion); full suite minus captures 6234 pass / 61 skip / 48 fail, ALL classified: 18 kit (M1 handoff), ~26 feature/preview assertion+golden churn (their M2 rows), **3 REAL overflow regressions from the bigger ramp** (earnings AR body → M2-15, chat header 320×480@2.0 → M2-16, offer composer 200% → M2-13 — live defects, do not lose), 1 baseline (gesture_log; the other 3 baseline reds now PASS post-re-cut). Captures excluded (light-theme goldens stale by design; re-baselined per-screen in M2). Boot-on-navy evidenced via harness full-app mounts; device boot at M7.
- [x] **G-M1** kit gate @2026-08-04 — 570/570 kit tests green (was 552/18 red pre-wave); analyze kit+theme 0 issues; greps: 0 raw hex outside palette, 0 `Colors.*` beyond 3 sanctioned field canvas paints + transparent, 0 orange-budget leaks. Workflow: 11 agents / 0 errors / ~21 min.
- [ ] **G-M2** mapped-surfaces gate ·
  [ ] **G-M3** remainder gate · [ ] **G-M4** states gate · [ ] **G-M5** motion gate ·
  [ ] **G-M6** audit gate · [ ] **G-M7** S22 sign-off

### M0 Foundation
- [x] M0-1 Token sheet ratified (Fable) — `01-TOKEN-SHEET.md`: palette→ColorScheme/roles mapping, ramp re-cut (h1 26/−0.6, body 14.5/21, price 22), radii ladder 9/14/18/22/26/34/40/999, glass recipe, field gradients (175deg wash + measured glows), shadow/glow set, Baloo Bhaijaan 2 confirmed from `_ds` tokens @2026-08-03
- [x] M0-2 Theme re-cut + §2.4 Material sweep (29 sub-themes, orange budget enforced per auto-consumer, OMDS 22-token override, bootstrap/splash/first-frame chrome de-flashed; light()==dark()==midnight; shadow migration map + open items ruled in 02-STUDY-NOTES §Theme) @2026-08-03
- [x] M0-3 `JeebMidnightField` (hero/content/map/sheet, glow+wash placements RTL-directional, static/animated painter split, pixel-verified vs R1 within ~1%) + public `JeebRadii`; 27 tests @2026-08-04
- [x] M0-4 Motion module `lib/core/motion/` (8 primitives §2.6, TweenSequence-per-leg keyframes, reduce-motion pins rest frame, 54 tests; defaults ratified in 02-STUDY-NOTES §Motion) @2026-08-03
- [x] M0-5 Fonts: Inter-ExtraBold w800 + Baloo Bhaijaan 2 (500/600/700) bundled as verified static TTFs (no fvar, correct usWeightClass, Inter metrics match rsms instances; family string exactly "Baloo Bhaijaan 2"); `fontFamilyFallback` wired by M0-2 @2026-08-03
- [x] M0-6 Dark map style JSON (`assets/map_styles/midnight.json`, measured from R3/R11: land=wash, roads land+0x0F, labels periwinkle ON by ruling, POI/transit off) + `JeebMapStyle` helper + both live `GoogleMap` sites styled via `style:` param @2026-08-03
- [x] M0-7 Board assets imported → `assets/brand/jeeb_wordmark.svg`, `assets/illustrations/delivery_3d.png` (repo snake_case convention; delivery art flagged navy-hostile for M5) @2026-08-03
- [x] M0-8 AA tests re-cut for navy — all sheet-§9 pairs PASS (worst body ink 5.17:1), failure-by-design pairs asserted, brown-on-white guard retired; 165 theme tests green @2026-08-03
- [x] M0-9 Capture-harness fixes — generic GoRouter stand-in (R12 + 8 more crashed captures fixed), shared OMDS tokens (`jeeb_omds_tokens.dart`), Midnight theme + reduce-motion enforced, brand/emoji/Arabic fonts loaded; render failures 18→4 (all pre-existing; rulings in 02-STUDY-NOTES §Harness) @2026-08-03

### M1 Kit
- [x] M1-1 Kit restyle sweep — 31 widgets via 7-lane parallel workflow + fixup (orange-budget leaks killed, AA fixes, accent selected state, R20 bubble tint, glassBorderVivid; rulings in 02-STUDY-NOTES §M1) @2026-08-04
- [x] M1-2 `JeebGlassCard` + `JeebGlassCapsule` (pill default, pre-baked translucency) @2026-08-04
- [x] M1-3 `JeebEmptyState` — E1 canon + 3 sample variants, board-static ring/medallions, loading=jBreathe skeleton, error=danger tint @2026-08-04
- [x] M1-4 `JeebPillNav` — navy capsule, 5 slots, orange active pill only, 48dp hit targets, RTL @2026-08-04
- [x] M1-5 Pattern E metric fixes (rode in M1-1: list-row 11/14, size-class overrides deleted, 48dp hit-test nav) + tests → **kit RE-FROZEN** @2026-08-04. API additions this wave (all Fable-sanctioned): JeebCardState.accentSelected, JeebSurfaceToneData.accentSelected, JeebShadows.accentSelected, semantic fields glassBorderVivid/bubbleOutFill/bubbleOutBorder/accentSelectedFill, 3 new widgets. From here kit API changes need a fresh ruling.

### M2 Mapped surfaces (order = exposure)
- [x] M2-01 Shell / floating nav — JeebPillNav wired, frozen ids re-homed, badge overlay, VIS-P1-2 inset preserved @2026-08-04
- [x] M2-02 R1+E1 Client home + empty — hero field static (animateDecor knob), capsule promise P0-6, single View-offers P0-7, E1 kit empty @2026-08-04
- [x] M2-03 R2 Voice recording — live transcript band + jBlink caret (P0-5), container jWave, micActive halo; fixed inherited AR@200% overflow @2026-08-04
- [x] M2-04 R9 Request type — compact tier rows, accentSelected, Standard pre-selected + badge (P0-3/4) @2026-08-04
- [x] M2-05 R11 Location picker — real map wired (onCameraIdle gate), /location route + placeholder + devtool twin DELETED per ORPHAN ruling @2026-08-04
- [x] M2-06 R12 Request summary — ICU plural, canPop hardened, all 4 catalog states render (was 3 RenderErrorBoxes) @2026-08-04
- [x] M2-07 R10+E2 Offers + waiting empty — lit card = rim+glow (not a fill), glass sibling CTAs, money column un-flexed (P1), E2 waiting/loading/error from one JeebEmptyState block @2026-08-04
- [ ] M2-08 R3 Live tracking
- [ ] M2-09 R13 OTP handover
- [ ] M2-10 R14 Receipt confirm
- [ ] M2-11 R15 Mutual rating
- [ ] M2-12 R16+E3 Jeeber home + feed empty
- [ ] M2-13 R17 Offer composer
- [ ] M2-14 R18 Active delivery — Jeeber
- [ ] M2-15 R19 Earnings
- [ ] M2-16 R20 Order chat (container + thread; non-zero-diff assertion)
- [ ] M2-17 R21+E4 Order history + empty
- [ ] M2-18 R4 Wallet
- [ ] M2-19 R22 Settings
- [ ] M2-20 R23 Become a Jeeber (KYC wizard)
- [ ] M2-21 R5+W1-3 Onboarding + walkthrough slides
- [ ] M2-22 R6 Registration
- [ ] M2-23 R7 OTP verify
- [ ] M2-24 R8 Transcription review

### M3 Remainder (46) — Tier 1
- [ ] M3-01 `deep_link_targets/delivery_detail_screen.dart` (697, `/orders/:id`)
- [ ] M3-02 `escalate/presentation/escalate_screen.dart` (739)
- [ ] M3-03 `no_offer_timeout/presentation/no_offer_timeout_screen.dart` (567)
- [ ] M3-04 `cancellation/presentation/cancellation_screen.dart` (317)
- [ ] M3-05 `order_summary/presentation/order_summary_screen.dart` (152)
- [ ] M3-06 `jeeber_request_detail/…/jeeber_request_detail_screen.dart` (258)
- [ ] M3-07 `customer_profile/presentation/customer_profile_screen.dart` (193)
- [ ] M3-08 `notifications/presentation/notifications_list_screen.dart` (326)
- [ ] M3-09 `rating/presentation/rating_screen.dart` (308)
- [ ] M3-10 `delivery_man_profile/presentation/delivery_man_profile_screen.dart` (150)

### M3 — Tier 2 (money surfaces)
- [ ] M3-11 `wallet_activity_list_screen.dart` (392) · [ ] M3-12 `transaction_detail_screen.dart` (388)
- [ ] M3-13 `wallet_charge_info_screen.dart` (194) · [ ] M3-14 `customer_wallet_stub_screen.dart` (123)
- [ ] M3-15 `settlement_screen.dart` (291) **ORPHAN — ruling** · [ ] M3-16 `settlement_detail_screen.dart` (165) **ORPHAN — ruling**

### M3 — Tier 3 (KYC funnel)
- [ ] M3-17 `dm_onboarding_screen.dart` (258) · [ ] M3-18 `onboarding_funding_screen.dart` (202)
- [ ] M3-19 `offer_kyc_gate_screen.dart` (260) · [ ] M3-20 `delivery_register_prompt_screen.dart` (96)
- [ ] M3-21 `kyc_rejected_screen.dart` (222) · [ ] M3-22 `account_status_screen.dart` (205)

### M3 — Tier 4 (settings subtree)
- [ ] M3-23 `profile_edit_screen.dart` (293) **ORPHAN — ruling** · [ ] M3-24 `notification_prefs_screen.dart` (324)
- [ ] M3-25 `notification_preferences_screen.dart` (31) · [ ] M3-26 `password_security_screen.dart` (317)
- [ ] M3-27 `language_settings_screen.dart` (130) · [ ] M3-28 `saved_locations_screen.dart` (593) **+ triage its crash with exception visible (doc-13 P0-9)**
- [ ] M3-29 `address_detail_form_screen.dart` (493)

### M3 — Tier 5 (edge/support)
- [ ] M3-30 `support_ticket_screen.dart` (616) · [ ] M3-31 `reviews_list_screen.dart` (563) **ORPHAN — ruling**
- [ ] M3-32 `dispute_status_screen.dart` (423) · [ ] M3-33 `display_name_setup_screen.dart` (276)
- [ ] M3-34 `set_password_screen.dart` (244) · [ ] M3-35 `biometric_lock_screen.dart` (141)
- [ ] M3-36 `jeeber_pending_offers_screen.dart` (175) **ORPHAN — ruling** · [ ] M3-37 `live_settings_screen.dart` (228) **ORPHAN — ruling**
- [ ] M3-38 `diagnostics_screen.dart` (353) **ORPHAN — ruling** · [ ] M3-39 `jeeber_request_unavailable_screen.dart` (62)
- [ ] M3-40 `request_summary_unavailable_screen.dart` (29) · [ ] M3-41 `profile_unavailable_screen.dart` (30)
- [ ] M3-42 `rating_prompt_screen.dart` (46) **ORPHAN — ruling** · [ ] M3-43 `location_picker_screen.dart` placeholder (36) **ORPHAN — deleted with M2-05**
- [ ] M3-44 `dev_chat_preview_screen.dart` (148, debug-gated — style if kept) · [ ] M3-45 `voice_request_screen.dart` (28, shim — verify delegate covers it)

### M4/M5 sweeps
- [ ] M4-1 State inventory built (grep methodology §4) → appended here as sub-items
- [ ] M4-2 All states restyled; zero light-theme states
- [ ] M5-1 Motion wiring per §2.6 · [ ] M5-2 Lottie audit on navy · [ ] M5-3 Reduced-motion pass

---

## 7. THE LOOP (per checklist item)

### 7.1 Session bootstrap (run at the start of EVERY session)

```bash
cd /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile
git status -sb   # expect feat/redesign-midnight, clean-ish
# First session only:
#   git switch integration/redesign-ui && git pull
#   git switch -c feat/redesign-midnight
#   git add docs/redesign-midnight docs/redesign-2026-08/13-DESIGN-VS-IMPLEMENTATION.md \
#           docs/redesign-2026-08/actual test/support/fonts test/tools
#   git commit -m "docs(midnight): master plan + pass-1 audit + capture-harness fixes"
#   git push -u origin feat/redesign-midnight
git -C ../omds-flutter log --oneline -1        # must be origin/main ≥ 6f9c166
grep -A1 '  dio' pubspec.lock | head -3        # must be ≥ 5.11.0
flutter analyze --no-pub                        # 0 errors (5 infos OK)
```
Then open §6, find the first non-`[x]` row, and enter the loop. Never leave the branch.

### 7.2 The loop

```
PICK    next open checklist item (§6 order).
STUDY   (Fable, or Opus with Fable spot-check)
        1. Read the tile PNG(s) — INCLUDING the caption band (designer's note).
        2. Open the live board in Chrome; watch this tile's motion; note which §2.6
           primitives appear, on which elements, with what stagger.
        3. Read the current screen source + its doc-13 carry-ins (§3 row).
        4. M3 items (no tile): pick the nearest tile pattern; list which field
           variant, surfaces, and states apply.
MAP     Confirm file reachability from lib/main.dart (screen-repo-map rules).
        Ambiguity → Fable rules now, or → §8 queue if it needs the owner.
IMPL    Spawn Opus implementer with the §7.3 template. It must not touch
        lib/core/theme, the frozen kit API, or navigation without a Fable ruling.
VERIFY  (same Opus agent) analyze delta vs §5 · targeted tests · non-zero diff on
        primary file(s) · catalog capture of ALL states of this screen.
REVIEW  (Fable) captures side-by-side vs tile; walk §7.5. Accept, or bounce with a
        concrete fix list. Max 2 bounces → park as [!] in §6 + entry in §8; move on.
COMMIT  One commit: work + checklist tick (+ capture PNGs under
        docs/redesign-midnight/captures/<item>/). Push every ~3 commits.
GATE    At wave boundaries: full analyze + full test vs §5, catalog sweep,
        push, tick the G-row, update §9 log.
```

### 7.3 Implementer prompt template (Opus, `model: "opus"`)

```
You are implementing one screen of the Jeeb MIDNIGHT redesign (dark navy design language).
Work ONLY on branch feat/redesign-midnight in /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile.

STEP 0 — MANDATORY. Read these image files with the Read tool NOW, before any code:
  {TILE_PNG_PATHS}   (the bottom caption band is the designer's spec note — read it)
Then write down 8+ concrete observations (whatISaw): background layers (glow placement,
rings), where orange appears (it is BUDGETED — mic/active-tab/live accents only), ink
hierarchy, glass surfaces, radii, spacing, motion cues (what the static frame implies moves),
Arabic runs, the empty/loading/error treatment, copy literals.
MOTION SPEC for this screen: {MOTION_NOTES}  (primitives + timings are in
docs/redesign-midnight/00-MASTER-PLAN.md §2.6 — consume lib/core/motion/jeeb_motion.dart).

CONSTRAINTS
- Tokens/kit only: colors via theme roles, text via context.jeebText, surfaces via the kit
  (JeebMidnightField variant: {FIELD_VARIANT}). ZERO raw hex, zero Colors.*, zero light-theme
  remnants. Do NOT modify lib/core/theme or kit public APIs — return a question instead.
- Restyle ALL states: default, loading, empty, error → JeebEmptyState family (§2.7).
- Preserve frozen test identifiers by re-homing them (board-drawn element or zero-size
  semantics node); then remove chrome that existed only to host them.
- Copy comes from the tile literals (sentence case). Missing wire data → render the designed
  slot with `TODO(midnight): omitted, not faked` — never invent data.
- RTL-safe (EdgeInsetsDirectional / start-end). Respect MediaQuery.disableAnimations.
- Files for this item: {SCREEN_FILES}. Carry-ins to close: {DOC13_CARRYINS}.

AFTER IMPLEMENTING — selfCritique: re-Read the tile, list 4+ deltas between your result and
the tile (px/hex specific), fix what you can, report the rest honestly.

VERIFY: flutter analyze --no-pub (0 errors; 5 known infos OK) · run {TARGETED_TESTS} ·
git diff --stat (primary file MUST be non-zero) · re-capture this screen's catalog states.

RETURN (raw data, no prose padding): whatISaw list · files+diffstat · what changed per file ·
selfCritique deltas · test results · TODOs added · open questions.
```

### 7.4 Model routing

| Decision class | Who |
|---|---|
| Token sheet, theme/Material overrides, kit API, navigation/route changes, deletions, ambiguity rulings, screen accept/reject, wave gates, owner communication | **The orchestrator session** (originally Fable; role is model-agnostic per §10 — same discipline on any model) |
| Screen implementation, state restyles, sweeps, captures, greps, targeted test runs, draft copy passes | **Opus subagents** |
| Anything an Opus agent is unsure about | It STOPS and returns the question |

### 7.5 Definition of done (per screen — the REVIEW rubric)

1. Midnight field present (correct variant); no white/light flash on entry, exit, keyboard, or dialog.
2. Zero raw hex / `Colors.*` in screen code; tokens + kit only; no Material default leaking (check: ripple color, surface tint, divider, scroll glow, selection handles).
3. Orange budget respected — orange only where the tile draws it.
4. Type ramp roles only; copy matches tile literals; Arabic runs render in the brand face.
5. Empty + loading + error states exist and use the §2.7 pattern.
6. Motion: tile-observed primitives present with §2.6 timings; nothing animates that the board doesn't animate; reduced-motion safe.
7. Frozen identifiers preserved (re-homed is fine); RTL verified.
8. Non-zero diff on primary file(s); analyze 0 errors; targeted tests green (the 4 named pre-existing reds excepted); capture matches tile in side-by-side.
9. Checklist row ticked in the same commit.

---

## 8. Owner-questions queue (batch to the owner; don't block the loop)

Seeded from doc-13 §4 — these survive into Midnight:

1. Money formatting: board mixes "$8" / "$6.50" / "$8.00" vs app's always-2-decimals `MoneyFormat`. One ruling, applied in M2.
2. R11/09 flow shape: board draws two-leg pickup→drop-off; product writes one coordinate to both legs (D-09a). Redraw or product change?
3. R7/03 auto-verify vs the mandated manual fallback — may the fallback be semantics-only?
4. Tier lexicon: app tiers (light/bulk) vs the board's five-name emoji lexicon — product owns the mapping table.
5. R13 post-handover forward path (board draws none; demoted text action proposed).
6. R21/24 expired-row dimming vs AA (0.65 opacity) — designer sign-off.
7. R18 "Costs" third pill: wire it or ratify the 2-pill board (escalation was never resolved).
8. Pattern-A gateway contract request (the 13 fields) — raise as ONE backend ticket with doc-13's table attached.
9. ORPHAN deletions — RULED 2026-08-04 (evidence-based, see 02-STUDY-NOTES §ORPHAN): DELETE
   settlement×2 + rating_prompt screen (route redirect kept) + location placeholder/twin;
   KEEP+restyle profile_edit, reviews_list (both routes), jeeber_pending_offers,
   live_settings, diagnostics. Owner: confirm the 4 deletions, esp. settlement (designed
   T-MOB-032, never linked — restorable from git if product wires it later).
10. `actual/` capture set (9.7 MB) committed for evidence — object if repo weight matters.

11. [Q-011] (M2-01) Earnings tab glyph: no Material filled single-banknote-with-dot exists; shipped `Icons.payments`. Designer: want a custom glyph asset?
12. [Q-012] (M2-02) Maestro jm-027 AC2: `replies_accept_cta` now opens the accept sheet from the card (behaviour-preserving). QA: confirm, or re-point AC2 to `offer_review_list_root`.
13. [Q-013] (M2-06) R12 voice replay band has zero pixel evidence (no fixture carries a real audio path). Approve adding a voice-draft catalog state with an on-disk clip (M4).

*(Append new questions here as `[Q-###]` with the checklist item that raised them.)*

---

## 9. Progress log (append one line per session)

- 2026-08-03 · Plan authored (Fable). Branch not yet cut — G-BOOT is the first action of the
  next session.
- 2026-08-04 · M0 COMPLETE (9/9) + G-M0 closed. Foundation: token sheet, theme re-cut (29
  sub-themes, orange budget), field widget (pixel-verified), motion module (54 tests), fonts,
  dark map, harness fixes. Extra: board-measured motion notes (20/30 tiles STATIC — plan M5
  amended), ORPHAN rulings (4 delete/5 keep), 3 ramp-overflow regressions flagged to M2 rows.
  Orchestration: parallel Opus agents per user directive; M1 kit workflow launching.
- 2026-08-04 · M1 COMPLETE (5/5 + G-M1: 570/570) via 11-agent workflow + fixup. M2 wave A
  COMPLETE (rows 01–06) via 6-lane workflow: shell/pill-nav, R1+E1, R2 transcript band,
  R9, R11 (+ratified deletions), R12 (first-ever verified). Kit fixup round 2 applied
  (accent CTA, waveform inks, drawn medallions, trackless toggle, glass chip, glow opt-in;
  kit suite now 588). **PAUSED by owner for model handoff — wave B NOT launched.** Resume:
  §10 (model-agnostic) → workflows/m2-waveB-workflow.js. Known non-green at pause: 30
  analyze infos (pre-existing) · 3 ramp-overflow regressions parked to M2-13/15/16 (G-M0
  row) · language_settings_screen_test ×2 pins pre-M1 segment ink → M3-27 ·
  gesture_log_test baseline red. Owner questions live in §8 (Q1–Q10, Q-011..013).

---

## 10. Resume prompt (MODEL-AGNOSTIC — paste into a NEW session on ANY capable model)

```
Continue the Jeeb MIDNIGHT redesign — pass 2. The Rich UI board is the ratified spec for
EVERY screen and EVERY empty/loading/error state. You are the ORCHESTRATOR: you make the
critical calls (tokens, kit API, navigation, deletions, accept/reject, ambiguity rulings)
and you delegate ALL implementation to parallel subagents. This role was previously run on
Fable; whatever model you are, the same discipline applies verbatim.

Read IN ORDER, before anything else (all under
/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile/docs/redesign-midnight/):
1. 00-MASTER-PLAN.md — contract, checklist §6 (live state: M0+M1 done, M2-01..06 done),
   loop §7, gates, §8 owner questions, §9 log.
2. 01-TOKEN-SHEET.md — every measured value; do NOT re-measure or invent.
3. 02-STUDY-NOTES.md — ALL standing rulings (theme, motion, ORPHAN delete/keep, M1 review,
   wave-A review). Rulings there BIND implementers; do not re-litigate.
4. 03-MOTION-NOTES.md — board-measured motion per element; supersedes §2.6's example
   column. 20 of 30 tiles are STATIC: never add motion the notes don't list.

RESUME POINT: M2 wave B. The ready-to-run workflow script is
docs/redesign-midnight/workflows/m2-waveB-workflow.js (6 screens + the l10n-merge lane for
docs/redesign-midnight/l10n-queue/*). Before launching it, verify the wave-A kit-fixup
landed (git log should show a "kit fixup round 2" / wave-A rulings commit touching
JeebCtaButton.accent, JeebWaveform live ink, JeebEmptyState medallions): if absent, re-run
that fixup first from 02-STUDY-NOTES §"Wave-A review rulings". Run §7.1 bootstrap, launch
the wave via the Workflow tool ({scriptPath}), then on completion: review every lane's
report, rule on escalations, commit ONE commit per checklist row (tick in the same commit),
push, and author wave C the same way (next rows: M2-13..18; copy m2-waveB-workflow.js as
the template — keep the ownership rules below).

OPERATING RULES (learned + mandated this engagement — non-negotiable):
- ONE branch feat/redesign-midnight; never a new repo/branch; push every ~3 commits.
- USER MANDATE: use Workflow fan-outs and parallelize maximally. Per wave: lanes own
  DISJOINT feature dirs; exactly ONE lane may touch lib/core/router/app_router.dart and
  exactly ONE may touch lib/l10n/*.arb — everyone else queues keys to
  docs/redesign-midnight/l10n-queue/<item>.md with TODO(midnight): l10n-queued call sites.
- USER MANDATE: code comments max 2 lines, only when strictly necessary — in every
  implementer prompt.
- Implementers: model "opus", §7.3 template (tile-PNG read + 8 observations BEFORE code,
  selfCritique after, scoped analyze/tests, captures to docs/redesign-midnight/captures/).
  An implementer that hits ambiguity STOPS and returns the question; you rule or queue §8.
- Kit is RE-FROZEN (570+ tests green). Kit/theme API changes happen ONLY by your explicit
  sanction, batched into a dedicated fixup lane, recorded in 02-STUDY-NOTES.
- Verification bar: flutter analyze 0 errors (~30 known infos) · kit suite all-green ·
  targeted suites per screen · non-zero diff on primary files · the 3 parked ramp-overflow
  regressions (G-M0 row) must be FIXED by M2-13/15/16 when those rows run, not re-parked.
- NEVER build L1/L2 (ratified deletion) · lottie EXACTLY 3.3.1 · frozen test identifiers
  re-homed, never dropped · RTL-safe · reduce-motion respected (tests pump(duration), never
  pumpAndSettle on looping surfaces; captures are rest-frame by design).
- On a machine other than oudays-mbp-2: re-apply docs/redesign-2026-08/_BASELINE.md env
  fixes FIRST (stale omds/dio = ~155 phantom failures).
- Final validation standard is unchanged: real OTP login, real taps, 2 devices for chat,
  physical S22 (M7) — harness captures alone never close the engagement.

Work autonomously wave by wave. At wave gates run full analyze + full suite vs the G-M0
classification, tick the G-row, append one line to §9. When you stop: §9 line + report
rows completed / parked / §8 questions added.
```
