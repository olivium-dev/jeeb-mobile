# w3 · lane `motion-confirm` — wiring `success-check.json` + `kyc-review.json`

**Screens:** 14 receipt-confirm · 22 become-a-jeeber (KYC status) · 23 wallet
**Animations:** `success-check.json` (one-shot, both surfaces, no mirror) · `kyc-review.json`
(loop, white surface, no mirror)
**Branch:** `feat/redesign-24-migration` (no branch/commit/push performed)

---

## 1. What actually shipped

| # | Screen | Moment | Composition | Loop | Where |
|---|---|---|---|---|---|
| 14 | receipt confirm | "Yes, I got it" succeeded → the 900ms beat before the rating hand-off | `success-check.json` | ONE-SHOT | full-bleed overlay over `receipt_prompt` |
| 22 | KYC pending | documents under review | `kyc-review.json` | LOOP (state is ongoing) | head slot of `_StatusScaffold`, replaces `Icons.hourglass_top_rounded` |
| 22 | KYC approved | the decision landed | `success-check.json` | ONE-SHOT | head slot, replaces `Icons.verified_rounded` |
| 23 | wallet | a reload came back with MORE available balance = a top-up landed | `success-check.json` | ONE-SHOT | centred `IgnorePointer` overlay over the hub body |

Files:

```
lib/features/delivery_receipt/presentation/delivery_receipt_screen.dart      (modified)
lib/features/delivery_receipt/presentation/widgets/receipt_confirmed_overlay.dart (new)
lib/features/kyc/presentation/kyc_status_view.dart                           (modified)
lib/features/kyc/presentation/widgets/kyc_status_marks.dart                  (new)
lib/features/wallet/presentation/wallet_hub_screen.dart                      (modified)
lib/features/wallet/presentation/widgets/wallet_topup_confirmed_mark.dart    (new)
test/features/delivery_receipt/receipt_confirm_motion_test.dart              (new, 4 cases)
test/features/kyc/kyc_status_marks_test.dart                                 (new, 4 cases)
test/features/wallet/wallet_topup_confirmed_motion_test.dart                 (new, 5 cases)
docs/redesign-2026-08/wiring/w3-motion-confirm.md                            (new)
```

No kit file, no pubspec, no l10n, no theme, no router, no DI touched. Zero new user-visible strings.

---

## 2. The three judgement calls

### 2.1 Screen 23 has no top-up transaction — so what fires the mark?

D92/D93 are explicit: the Jeeber charges the wallet **at a store**, in cash, and "the balance
auto-updates". `wallet_charge_info_screen.dart` makes no network call at all. There is therefore no
in-app "top-up succeeded" event to hang `success-check` off, and inventing one was not an option.

The one honest signal the app already owns is **a reload that returns more available balance than
the reload before it**. That is what fires the mark (`_WalletHubViewState._isTopUp`), computed
purely from two `WalletHubState` snapshots — no new endpoint, no new field, no new cubit state.

The cold `initial → loaded` transition is explicitly excluded (there is no "before" to compare
against), so opening the wallet never fires it. Pinned by three of the five wallet tests.

### 2.2 Screen 14 navigates away the instant the confirm returns

A mark that renders for two frames before `goNamed('mutual-rating')` is not motion, it is a
flicker. So the hand-off now waits **900ms** — long enough for the check to draw (it completes at
f44 = 733ms) and nothing more.

Guardrails on that delay, because it is the one behavioural change in the lane:

- The destination, the path parameters and the stack-REPLACING semantics are byte-identical (D56 —
  the mandatory rating still cannot be backed out of).
- The navigation is owned by a `Timer` on the screen's own state, **never** by the animation's
  completion. A composition that loads slowly, fails to parse, or is missing entirely cannot strand
  the customer on the receipt prompt — worst case is a blank 900ms.
- `MediaQuery.disableAnimations` skips the beat **and** the overlay: reduce-motion users get
  today's exact behaviour, instantly.
- Maestro `jm-033` AC2 waits on `rating_submit_cta` with `timeout: 20000`, so 900ms is nowhere near
  the budget.

### 2.3 The kit's own motion was left alone

Nothing here replaces a Dart animation. `JeebMicHero`'s glow, `JeebWaveform`'s bars and
`JeebStepper` are untouched — none of them lives on 14, 22 or 23. The two icons that were replaced
(`hourglass_top_rounded`, `verified_rounded`) were **static glyphs**, not animations, and both stay
in `_StatusScaffold` as the fallback for the two terminals with no authored composition (rejected,
resubmit-requested).

---

## 3. Spec compliance

| Rule | How it is met |
|---|---|
| Explicit sizing, never unbounded | Every mark is a named-const `SizedBox`: 100 for `success-check` (09-MOTION-VALIDATION §11), 88 for `kyc-review`. |
| Surface verdict respected | `kyc-review` is WHITE-only and sits on the white `Scaffold` body. `success-check` is BOTH; all three of its homes are white anyway. Nothing was placed on navy. |
| RTL | Neither file is RTL-flagged (§8: only `courier-in-transit`, `loading-dots`, `onboarding-say-it` mirror). Nothing is wrapped in a flip — mirroring a check mark reads as wrong worldwide. |
| One-shots must not loop | All three `success-check` sites are driven by an `AnimationController` with a single `forward()` and hold the settled frame. `repeat:` is never set true anywhere in this lane. |
| Reduce motion | `kyc-review` renders frame 0 (the document, beam at opacity 0) via `animate: false`. The one-shots jump to `value = 1` — the settled check — so the confirmation is never withheld from a11y users, it just does not move. Covered by three tests. |
| Never block a user action | 14's navigation is timer-owned. 23's mark is inside `IgnorePointer` and dismissed on a **host-owned** 1.8s timer, not on the animation finishing. 22's marks gate nothing — the approved body's role activation and all three CTAs are live from frame 0. |
| Semantics preserved | Every existing `Semantics(identifier:)` is byte-identical. The marks are decorative, so each is `ExcludeSemantics` — no new identifiers, no new nodes inside `receipt_prompt` / `kyc_status_root` / `wallet_hub_root`. |

---

## 4. Sizing note (a real correction, not a preference)

`kyc-review.json` at the spec's 2x-canvas size (110) **overflowed `_StatusScaffold` by 2px** on an
800x600 surface — the pending body is a fixed `Column` with a `Spacer` and no scroll, and it had
only ~44px of slack over the 64px glyph. Caught by `kyc_status_view_test.dart`, not by inspection.
It renders at **88**, which keeps ~20px of headroom while still reading 37% larger than the icon it
replaced. `success-check` stays at the recommended 100 (the approved body carries no `extra` block
and has room).

---

## 5. Verification

```
dart analyze lib/features/{wallet,kyc,delivery_receipt} test/features/{wallet,kyc,delivery_receipt}
  → No issues found!

flutter test test/features/kyc test/features/wallet test/features/delivery_receipt \
             test/kyc_status_view_test.dart test/kyc_wizard_screen_test.dart
  → +166 All tests passed

bash tool/check_design_tokens.sh
  → 3 violations, all pre-existing and in other lanes' files
    (location/client_location_screen.dart, wallet_activity_list_screen.dart,
     reviews_list_screen.dart) — this lane added none.
```

Also re-run green after the change: `test/core/router/**`, `test/devtool/**`,
`test/decision_violations_test.dart`, `test/jeeber_role_activator_test.dart`,
`test/kyc_submitting_view_test.dart`, `test/back_arrow_dead_at_root_test.dart`.

### Two findings worth recording for the other motion lanes

1. **A looping `Lottie` never settles — `pumpAndSettle()` on any screen hosting one will time out.**
   Measured, not assumed: `repeat: false` settles, `animate: false` settles, the default
   `repeat: true` does not. Screen 22's pending body now loops, and it survived only because
   `kyc_status_view_test.dart` drives bounded `pump()`s. Any lane putting a loop on a screen whose
   tests call `pumpAndSettle` will break those tests.
2. **`Lottie.asset` loads fine under `flutter test`** (assets are in the test bundle, no exception),
   but it resolves on the REAL event loop, which a pumped fake clock does not advance. Tests that
   depend on the composition being loaded are flaky-by-construction; tests should depend on
   host-owned timers instead. Both of this lane's dismissals were restructured for exactly that
   reason, and are now deterministic.

---

## 6. Not done, deliberately

- **No shared `JeebLottieMark`.** Three near-identical one-shot widgets exist, one per feature. The
  kit is frozen and the lane rule forbids new shared core files; proposed in
  `wiring/w3-motion-confirm.md` §1 for the kit owner.
- **No spoken confirmation.** The marks are silent to screen readers by design (surrounding copy
  covers it). An explicit live-region string is filed in `wiring/w3-motion-confirm.md` §2 because
  it needs three consistent l10n edits this lane may not make.
- **No mark on the KYC *rejected* / *resubmit-requested* terminals.** `success-check` would be a
  lie there and the spec authored nothing else for them; they keep their glyphs.
- **No `success-check` on screen 15 (mutual rating).** Spec §2.5 lists it, but 15 is another lane's
  file.
