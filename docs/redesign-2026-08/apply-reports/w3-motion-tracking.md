# w3 — motion lane `motion-tracking`

**Assigned files:** `broadcasting.json`, `courier-in-transit.json`, `nearby-scan.json`
**Assigned screens:** 11 offers waiting state · 12 live tracking · no-offer-timeout
**Dirs:** `lib/features/{client_offers,no_offer_timeout,live_tracking}`

**Result: 2 of 3 files wired, at 3 placements. 1 deferred with reasons.
`dart analyze` clean on all four directories; the lane's tests are green
(158 + 5 new).**

---

## 1. What was wired

| # | Surface | File | Size (dp) | Loop | Mirror | Why here |
|---|---|---|---|---|---|---|
| 1 | `no_offer_timeout` → `_BroadcastHeader` | `broadcasting.json` | 140×140 | bounded | no | The header IS the broadcast state — the matching service really is fanning the request out while it is mounted. Motion spec §2.3 names "10's post-submit moment" as a home; this screen is that moment's own surface. |
| 2 | `no_offer_timeout` → `_NoOffersYetHeader` | `nearby-scan.json` | 140×100 | bounded | no | Ongoing "still looking near you" state. Spec §2.7's zero-orange grounded radar. See the divergence note in §3. |
| 3 | `client_offers` → offer-list empty state | `broadcasting.json` | 140×140 | bounded | no | Spec §2.3 names this exactly: "11 while the offers window is open with zero offers in… also the board's *waiting for offers* empty state." |

All three replaced a **static Material icon**, so nothing gained a widget where
the board had whitespace: `Icons.podcasts` → sonar, `Icons.location_off_outlined`
→ scan, `Icons.hourglass_top_outlined` → sonar. Net widget count is unchanged.

Placement #3 is **gated on the window actually being live**
(`state.requestIsOpen && !state.requestIsExpired` — the same server authority
`acceptDisabled` reads, never the locally elapsed display countdown). On a
closed or expired request nothing is being broadcast, so a sonar loop there
would be a picture of an event that is not happening; the static hourglass
stays. `OmdsEmptyState` already had an `illustration` slot, so this is a slot
swap, not a layout change.

Both files are authored **WHITE-SURFACE ONLY** (09-MOTION-VALIDATION §7:
`broadcasting` measures 0.00–0.59% ink on navy, `nearby-scan` 2.5–2.6%). All
three placements sit on the scaffold's white surface. Neither file is
directional, so neither is mirrored — `mirrorInRtl` stays false, which is a
correctness requirement, not a default.

---

## 2. `courier-in-transit.json` — deferred, not forgotten

It is not wired, and screen 12 gets **no** Lottie. Three independent reasons,
all from the spec itself:

1. **The spec assigns nothing to screen 12.** The §2 table's Screens column
   reads `04, 18, 24` for this file. Screen 12 appears nowhere in the whole
   ten-file table.
2. **§3 explicitly refuses the only moving thing on 12.** "Live-tracking courier
   marker — **Refused**. The real marker follows the SSE position stream and is
   already glided in Dart. A looping Lottie on the map would be *a lie about
   where the courier is* — exactly what a trust product must not do." §11
   repeats it. The stepper's advance (§3) and the at-door pulse (§3) are refused
   too, and `JeebStepper`'s glow is frozen kit motion I was told not to fight.
3. **Its sanctioned homes are other lanes' directories.** "for cards and list
   rows only — 04 active-order card, 18 header strip, 24 in-transit row." None
   of those is in `lib/features/{live_tracking,no_offer_timeout,client_offers}`.

Placements I considered inside my dirs and rejected:

* **`TrackingCourierCard`** ("Karim is on the way") — a card, which is the
  sanctioned shape, and the board leaves its trailing slot empty (the Ø40 phone
  circle is deliberately not shipped, privacy contract). But the card sits
  ~8 dp below the live map, whose marker is the truthful position. An abstract
  canned dot travelling a fake dashed route, inches under the real one, is the
  same misrepresentation §3 refuses — twice as confusing for being adjacent to
  the truth.
* **`_MapPlaceholderMark`** (the non-live map tile) — a dashed route with a
  moving dot standing *in the map's place* reads as a live route even harder.
  It is also effectively test-only: production defaults to `useLiveMap: true`
  with the Maps key provisioned, so no customer would see it.
* **`OrderSummaryPinnedHeader`** — the customer analogue of 18's strip, but it
  is a `JeebTopBar` whose subtitle is already a `Wrap` fighting 200% text scale
  and Arabic overflow (see its own doc comment). No room.

**Recommendation:** hand `courier-in-transit.json` to whichever lane owns
`04-client-home` (active-order card) and `24-order-history` (in-transit row).
Display it at ~160×48 (half of the 320×96 canvas) and wrap it with
`JeebLottieMark(mirrorInRtl: true)` — the file is directional and must flip in
Arabic.

---

## 3. Divergence flagged for the owner — `nearby-scan` on a client surface

The spec's Screens column assigns `nearby-scan.json` to **16** (jeeber home,
empty feed) only. I used it on the client's waiting screen.

Reasoning, so the owner can overrule cheaply (it is a two-line revert):

* The waiting screen is **not one of the 24 board screens**, so no render is
  contradicted.
* The icon it replaced actively fought the copy that ships beside it.
  `waitingNoCoverageBody` reads *"Jeebers near you are **still reviewing** your
  request. Keep waiting, re-target, or cancel — it's free"*, and the state is
  gated `!isTerminal`. A struck-through location pin in the warning role reads
  as a coverage failure; the state is not one.
* Its meaning transfers: *this patch of ground is being watched*. It is the
  set's only **zero-orange** composition, which is the correct register here —
  the spec rations orange to act-now moments and nothing on this screen is one.
* It keeps the screen's two states visually distinct: broadcast (shouting
  outward) → scan (watching). Re-using `broadcasting` for both would erase the
  difference between "the window is running" and "the window elapsed".

---

## 4. The bounded-loop decision (and the measurement behind it)

`Lottie.asset(..., repeat: true)` schedules frames forever, so every
`pumpAndSettle` on a screen mounting one times out. Measured on this branch
before writing a line of wiring:

```
loops: does pumpAndSettle hang?   -> "pumpAndSettle timed out"
animate:false                     -> settles
disableAnimations in widget tests -> false   (reduce-motion does not save us)
bounded 3 cycles                  -> settles, 294 ms
bounded 15 cycles                 -> settles, 207 ms
```

Tests that would have broken: `waiting_resume_backstop_test.dart`,
`client_offers_resume_backstop_test.dart`, `offer_accept_*`,
`offer_card_overflow_test.dart`.

So `JeebLottieMark` plays `cycles` times (default 6 ≈ 24 s on the 4 s canvases)
and rests. Every looping file in the set is authored **seamless** (frame `op` ≡
frame 0, verified in 09-MOTION-VALIDATION §6.4), so the resting pose is the
loop's own opening state, not a freeze mid-gesture. This is the frozen kit's own
pattern — `JeebStepper`'s active glow is a bounded 3-breath pulse "so
`pumpAndSettle` stays safe either way".

**Open question for the owner** (also in `wiring/w3-motion-tracking.md`): a
customer can wait minutes; after ~24 s the sonar rests. Raising the bound is one
line and stays test-safe well past 60 cycles, at the cost of advancing more
simulated time inside every `pumpAndSettle`.

---

## 5. Accessibility

Reduce-motion (`MediaQuery.disableAnimationsOf`) pins the controller at 0 and
**schedules no frames at all** — pinned by
`test/core/widgets/motion/jeeb_lottie_mark_test.dart` (`frames < 5`,
`hasScheduledFrame` false).

The static frame is a real mark for both files, which is why frame 0 is a safe
resting pose here specifically: 09-MOTION-VALIDATION §7 lists the only blank
first frames in the set as `success-check`, `empty-say-it` and
`courier-in-transit` — neither of mine. `broadcasting` f0 renders the field
circles, the navy request dot and the orange ping at Ø26 (278 orange pixels
measured in §6.2); `nearby-scan` f0 renders the pin and the ground.

The marks carry **no semantics node** (`ExcludeSemantics`), so the existing copy
remains the only thing announced, and no `Semantics(identifier:)` byte changed
anywhere in this lane. Nothing is blocked on an animation: every CTA on all
three surfaces is untouched and reachable while the mark plays or rests.

---

## 6. Visual check (rendered, then viewed)

Rendered both marks to PNG at the shipped display sizes on `#FFFFFF` and looked
at them, rather than assuming:

* `broadcasting` @140 at t=0.4 s — navy request dot, the orange ping ring around
  it, one navy sonar ring mid-flight, the two faint field circles, one
  periwinkle jeeber dot. Reads as a calm sonar; the orange is a hairline ring,
  never a fill.
* `broadcasting` @140 at t=1.5 s — ping gone (it runs f0–70), one sonar ring
  mid-flight, no jeeber dot in that window. Very quiet. Compared side by side
  against @180, which has more presence; **kept 140** because it is the spec's
  own ~2×-canvas rule and neither surface has a board render to justify
  deviating from it. Worth re-judging on the S22.
* `nearby-scan` @140×100 at t=0.6 s — the navy pin reads immediately, ground
  ellipse under it, first ripple opening. Better presence than `broadcasting` at
  the same size because the pin is a solid mark.

---

## 7. Files changed

```
lib/core/widgets/motion/jeeb_lottie_mark.dart              (new)
test/core/widgets/motion/jeeb_lottie_mark_test.dart        (new, 5 cases)
lib/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart
lib/features/client_offers/presentation/client_offers_screen.dart
docs/redesign-2026-08/wiring/w3-motion-tracking.md         (new)
```

`lib/features/live_tracking/` — **unchanged** (see §2).
No pubspec edit, no l10n edit, no kit edit, no `Semantics(identifier:)` change.

## 8. Verification

```
dart analyze lib/core/widgets/motion lib/features/client_offers \
             lib/features/no_offer_timeout lib/features/live_tracking \
             test/core/widgets/motion            -> No issues found!

flutter test test/features/client_offers test/features/no_offer_timeout \
             test/client_offers_screen_test.dart test/client_offers_cubit_test.dart \
             test/offer_window_timer_test.dart test/offer_card_test.dart
                                                 -> 158 passed
flutter test test/core/widgets/motion/jeeb_lottie_mark_test.dart  -> 5 passed
flutter test test/core/theme/no_raw_semantic_colors_test.dart \
             test/decision_violations_test.dart \
             test/core/router/w1_routes_resolve_test.dart         -> 29 passed
bash tool/check_design_tokens.sh -> only pre-existing violations, all in other
     lanes' dirs (location, wallet, reviews); none in this lane's files.
```
