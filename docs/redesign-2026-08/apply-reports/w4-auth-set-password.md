# W4 · auth-set-password — apply report

**Lane:** `w4-auth-set-password` · **Branch:** `feat/redesign-24-migration` · **Date:** 2026-08-03
**File:** `lib/features/auth/presentation/set_password_screen.dart` (the lane's only production file)
**Reference:** no render exists for this screen. Language taken from the neighbour
`screens/02-registration.png` / `.html`, from the kit reference `03-WAVE1-KIT.md`, and from the two
already-redesigned screens it sits between: its caller
`lib/features/password_security/presentation/password_security_screen.dart` and its settings-family
sibling `lib/features/settings/presentation/screens/profile_edit_screen.dart`.

**Status: done.**

---

## 1. What the neighbour does, and what this screen did instead

| Screen 02 (redesigned) | `set-password` (before) |
|---|---|
| Header is a body band — no Material toolbar anywhere on the board | Material `OMDSAppBar`, 56px toolbar, centred title, non-directional `Icons.arrow_back`, **no `Semantics(identifier:)` on back** |
| 24px side gutters on every band (`tpl 77/87/91/98`) | 16px (`Spacing.medium`) start/end |
| `column → content → flex:1 real emptiness → docked strip at 0/24/32` | Everything, including the CTA, inside one scrolling `ListView`; no empty band, no docked footer |
| CTA is a navy pill, `jeebText.button`, `JeebShadows.ctaNavy` (`tpl 86`) | `OmdsPrimaryButton` — correct family, but not the kit's pill and off the footer contract |
| Every state message is a soft, rounded, tinted note | Validation error was a bare `Text` on `textTheme.bodyMedium` + `colorScheme.error` — the M3 body ramp, not `jeebText`, and red ink on white rather than the Wave-0 soft `errorContainer` |
| Orange appears where something decays or is "do-it-now" | Nothing orange (correct — see §4) |

## 2. What changed

Bands, top to bottom, now match `profile_edit_screen.dart` band-for-band:

1. `JeebTopBar.back(title: l10n.setpwTitle, identifier: 'setpw_back')` — in-body, Ø40
   `surfaceContainerHigh` circle + `jeebText.h2` navy title, pad `14/24/0`, directional glyph.
2. `Expanded(ListView)` — `EdgeInsetsDirectional.fromSTEB(24, 16, 24, 20)`: the two password
   fields at `Spacing.medium` rhythm, then the conditional validation note at `Spacing.small`.
3. The `Expanded` **is** the empty band (§3 "real emptiness"), then
4. `SafeArea(top: false) → JeebCtaFooter.single` docking the Save pill at `0/24/32`.

`SafeArea(bottom: false)` on the outer column so the docked footer owns the bottom inset — the same
split profile-edit and settings use.

Kit widgets adopted: **`JeebTopBar.back` · `JeebCtaFooter.single` · `JeebCtaButton.primary` ·
`JeebInfoNote.error`.**

Token/style swaps: the validation node's raw
`textTheme.bodyMedium.copyWith(color: colorScheme.error)` → `JeebInfoNote.error(icon: Icons.error,
text: …)`, which paints Wave-0's `errorContainer`/`onErrorContainer` — literally the same note the
caller screen renders for its own `password_strength_error` / `password_mismatch_error` guards, so
the two surfaces finally agree. No other raw `TextStyle`, no `Color(0x…)`, no `fontSize:` in the
file (verified by grep; `tool/check_design_tokens.sh`'s rules hold).

## 3. Preserved byte-identically

`setpw_root` (`container` + `explicitChildNodes`) · `setpw_new_field` · `setpw_confirm_field` ·
`setpw_new_visibility_toggle` · `setpw_confirm_visibility_toggle` · `setpw_validation_error`
(`liveRegion: true`) · `setpw_submit_cta` — all seven `Semantics(identifier:)` wrappers are
unchanged in id *and* in their flags, and each still wraps the widget it wrapped before (the kit
widgets add a node of their own only when handed an `identifier`, so there is no duplicate node).

One identifier **added**: `setpw_back` on the new top bar's leading circle — `<screen>_<element>`,
per the kit's `<screen>_back` contract. The old `OMDSAppBar` back button had none.

## 4. Deliberately NOT changed

- **`OmdsTextField` stays.** The kit has no input primitive and OMDS's field already reads the
  Wave-0 theme; profile-edit records the same call ("swapping it would be churn, not migration").
  The eye-toggle `IconButton`s, their icons and their `cubit.toggle*Obscured` wiring are untouched.
- **Back behaviour.** `JeebTopBar`'s default `onLeadingPressed` is the guarded
  `Navigator.maybePop()` the OMDSAppBar back button already called, so
  `AppRouter.backFallbacks['set-password']` and the system BACK wrapper are unaffected. No
  `goNamed` was introduced (unlike the caller, which had an explicit JM-061 AC for it).
- **Submit semantics.** Still `isEnabled: !submitting`, **not** `JeebCtaButton.isLoading` —
  `isLoading` swaps the whole label row for a spinner, which would remove `find.text('Save
  password')` from the tree during a submit. Same call profile-edit made.
- **No orange.** 18 of 24 board screens carry an orange fill, this one carries none: nothing on
  set-password decays, expires or is a "do-it-now" moment, and §4.1 rations orange to exactly
  those. Adding it here would be the regression, not the fix.
- **No new copy.** No lead-in paragraph, no policy hint, no bottom trust note — each would need a
  new hand-parsed ARB key and would be a product change, not a re-skin. The policy-hint proposal is
  filed paste-ready in `wiring/w4-auth-set-password.md` §1 as explicitly non-blocking.
- **The removed funnel stays removed.** No login/sign-up surface, no email field, no recovery
  affordance was reintroduced (JEBV4-199 / Q-044 RATIFIED). `SetPasswordMode` still resolves every
  `?mode=` to `inAppSocial`.

## 5. Tests

New: **`test/features/auth/set_password_screen_test.dart`** (4 tests) — the screen had **zero**
widget coverage, so the id contract Maestro keys on was unprotected while its layout moved. Covers
the full id contract incl. `setpw_back`, the structural facts (`JeebTopBar` present,
`JeebCtaFooter` present, `AppBar` absent), the empty-submit → `setpw_validation_error` →
`JeebInfoNote` path (client-side only, no network), and the eye toggle.

```
dart analyze lib/features/auth test/features/auth   →  No issues found!
flutter test test/features/auth/ \
             test/core/router/w0_routes_resolve_test.dart \
             test/features/password_security/          →  +27 All tests passed
```
(4 new + 23 pre-existing; no full-suite or repo-wide analyze run — ~20 sibling lanes are editing
concurrently.)

## 6. Honest remaining gaps vs the neighbour

1. **Field chrome diverges.** 02's input is an h60 r16 `surface-high` filled capsule with a **2px
   navy focus border**, a **bold navy 14/w700 label sitting above it**, and a periwinkle helper
   line below. `OmdsTextField` gives a white fill, a floating M3 label and OMDS's own border ramp.
   This is a house decision, not an oversight — but it is the single largest visual difference
   left, and it will persist on every OMDS-field screen until the kit gains an input primitive.
2. **No helper line under the new-password field** — the policy is only stated after it is
   violated. Blocked on new copy; see `wiring/w4-auth-set-password.md` §1.
3. **No docked trust note.** 02 pins a `surface-high` info strip at `0/24/32`; here that band is
   plain white. `JeebInfoNote.muted` is ready for it the moment copy exists.
4. **CTA is 56px (`primaryHeight`), the board's registration pill is 58 (`primaryHeightTall`).**
   56 is the settings-family default profile-edit uses; chosen for sibling consistency over
   render fidelity to a first-run funnel screen.
5. **No navy hero band, wordmark or bilingual AR/EN line.** Correct by the plan — 02 is a
   first-run funnel screen with a band; interior screens use `JeebTopBar` (§5 #1). Recorded so it
   is not mistaken for an omission.
