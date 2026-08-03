# w4 — `biometric` onto the Jeeb design system

**Lane:** `w4-biometric` · **Branch:** `feat/redesign-24-migration` (no branch/commit/push)
**Owned file (only file changed):**
`lib/features/biometric_auth/presentation/biometric_lock_screen.dart`

No render exists for this screen. Reference used: **01 Onboarding** (`screens/01-onboarding.png`
/ `.html`) — the nearest neighbour in the journey and the only other full-bleed navy field on the
board — plus the shipped `lib/features/onboarding/presentation/onboarding_screen.dart` for house
conventions.

---

## What the screen was

A vertically centred `Column` inside `SafeArea` on the default white `Scaffold`:
`Icons.fingerprint` in `colorScheme.primary` at `Sizes.fiveXLarge`, `textTheme.headlineSmall`
title, `textTheme.bodyMedium` body, a raw red `bodySmall` failure line, then two stacked
`OmdsPrimaryButton`s (`primary` + `text`). No navy anywhere, no field, no sheet, no kit widget —
it read as a Material sample screen sitting next to a designed product.

## What it is now

The board's navy-field structure, taken from 01:

| Band | Treatment |
|---|---|
| **Field** (`Expanded`) | Full-bleed navy (`colorScheme.secondaryContainer`, 01's own field role). Two faint decorative accent rings (Ø380 @ .10 / Ø270 @ .18 of `jeebRoles.accent`, 1.5px) painted by a `CustomPaint` under a `ClipRect`, centred on a Ø118 glass disc (white @ .10 fill, white @ .18 hairline) carrying the 56px white fingerprint mark. |
| **Sheet** (docked) | White `colorScheme.surface`, top corners `Spacing.twoXLarge` (32, matching the shipped onboarding sheet), `SafeArea(top: false)`, capped at 62% viewport height with `ClampingScrollPhysics` for large text scales. 24px gutters, 32px top/bottom. |
| **Sheet content** | `jeebText.h1` + `letterSpacing: -0.6` navy headline · `jeebText.body` in `onSurfaceVariant` body · failure hint as `JeebInfoNote.error` · `JeebCtaFooter.single` with `JeebCtaButton.primary` and `below:` `JeebCtaButton.text`. |

**Kit widgets adopted:** `JeebCtaButton` (`.primary`, `.text`), `JeebCtaFooter.single`,
`JeebInfoNote.error`. **Tokens adopted:** `context.jeebText.h1/.body`, `context.jeebRoles.accent`,
`colorScheme.secondaryContainer/.surface/.onPrimary/.primary/.onSurfaceVariant`, `Spacing.*`,
`Sizes.fiveXLarge`, `UIConstants.strokeWidthThin`. Zero raw hex, zero raw `TextStyle`, zero
`fontSize:`.

## Deliberate non-changes (restraint)

- **Flow untouched.** Same two affordances, same order, same handlers, same routing
  (`authenticate()` / release-gate-then-`goNamed('register')`), same enable rule
  (`!state.isPrompting`), same failure condition (`state.hasFailed`). No new step, no new tap
  target, nothing removed.
- **Copy untouched.** All five strings are the existing keys (`biometricUnlockTitle`,
  `biometricLockBody`, `biometricLockFailure`, `biometricLockRetry`,
  `biometricUnlockAuthenticateCta`, `biometricUnlockUsePasswordLink`). **No ARB edit, no parser
  edit, no wiring request** — the repo has no gen-l10n and this lane needed no new string.
- **`biometricLockPrompting` stays unused.** Feeding it into `JeebCtaButton.isLoading` would have
  been a nice spinner, but it changes what the CTA says during the platform prompt — a copy change,
  not a re-skin. Left alone.
- **The fingerprint mark is not tappable and not orange.** 01 spends its orange fill on the mic,
  which *is* the action; here the action is the CTA below, and nothing on this surface decays. The
  accent is rationed to the two decorative rings. Making the mark a second way to raise the prompt
  would have been a new affordance.
- All existing navigation/guardrail comments preserved verbatim.

## Semantics

Byte-identical, all three:

- `biometric_unlock_prompt` — same `container: true, explicitChildNodes: true` root wrapper.
- `biometric_unlock_authenticate_cta` — same `button: true, enabled: !state.isPrompting` wrapper.
- `biometric_unlock_use_password_link` — same `button: true` wrapper.

`JeebCtaButton` adds no `Semantics` node unless given an `identifier`, so none is passed — the
existing wrappers stay the only nodes. No new interactive widget was introduced, so no new
identifier was minted.

## Constraint check

| Constraint | Status |
|---|---|
| 1 Semantics preserved | ✅ byte-identical ×3 |
| 2 No pubspec edit | ✅ |
| 3 No invented endpoint/field/contract | ✅ renders only `state.hasFailed` / `state.isPrompting` |
| 4 l10n | ✅ no new strings, no ARB/parser edit, no `gen-l10n` |
| 5 RTL | ✅ `EdgeInsetsDirectional` throughout; the sheet radius is top-symmetric; no left/right |
| 6 D56 / D52 / D20 / fee wording | n/a — this screen touches none of them |
| 7 analyze / tests | ✅ see below |
| 8 Lints | ✅ const constructors, `sort_constructors_first`, no `print`, no async-context gap |
| 9 Own directory only | ✅ one file; **no wiring request needed** |
| 10 Tagged orphans | ✅ untouched |

## Verification

```
dart analyze lib/features/biometric_auth/            → No issues found!
flutter test test/features/biometric_auth/ \
             test/core/router/w0_routes_resolve_test.dart   → +18 All tests passed!
flutter test test/core/router/back_nav_all_routes_test.dart → +54 All tests passed!
```

`w0_routes_resolve_test` is the one test that mounts `BiometricLockScreen` directly (bare
`MaterialApp`, no `AppTheme`) and asserts `biometric_unlock_prompt`. Both `context.jeebText` and
`context.jeebRoles` fall back to their `.light()` defaults when the extension is absent, so the
screen renders in that harness. Design-token gate patterns re-run against this file alone: clean
(only `Colors.transparent`, which the gate excludes by name). The full suite and repo-wide analyze
were **not** run — ~20 sibling lanes are editing concurrently.

## Known divergences from the neighbour (honest list)

1. **Hero anchoring.** 01 anchors its mic to the *bottom* of the navy stage (`bottom: 24`) because
   a collage occupies the upper field. This screen has nothing else in the field, so the mark is
   centred and the rings are centred on it (01's painter offsets to `0.375` of stage height).
   Deliberate, but it is a divergence.
2. **No eyebrow.** 01's sheet opens with the orange Arabic tagline above the headline. Adding one
   here would mean inventing copy (constraint 4), so the sheet starts at the headline.
3. **Ring painter duplicated.** `_AccentRingsPainter` is a near-copy of onboarding's private
   painter. The kit has no ring/décor primitive and I may not add one; a shared
   `JeebAccentRings` would be the right Wave-5 cleanup for whoever owns the kit.
4. **Sheet gutters 24, not 32.** 01's sheet measures 32px gutters; the plan's law is 24px side
   gutters. I followed the law and kept 32 only for the sheet's top/bottom and its corner radius.
5. **The failure note is start-aligned inside a centred sheet.** `JeebInfoNote` is a
   glyph + text row; its copy does not centre with the headline above it. It is the kit's shape and
   I did not override it, but the mixed alignment is visible when the note is present.
6. **No `JeebTopBar`.** Correct — a lock gate has no back affordance and none was added — but it
   does mean the screen has no chrome band at all, unlike 17 of 24 board screens.
7. **Not visually verified on a device.** No render existed to diff against and this lane ran
   headless; the layout is reasoned from 01's HTML measurements and the shipped onboarding widget
   tree, not from a screenshot of this screen.
