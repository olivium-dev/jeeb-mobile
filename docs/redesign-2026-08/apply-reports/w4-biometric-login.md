# w4 — `biometric-login` onto the Jeeb design system

**Lane:** `w4-biometric-login` · **Branch:** `feat/redesign-24-migration` (no branch/commit/push)
**Owned file (only file changed):**
`lib/features/biometric_login/presentation/biometric_prompt_screen.dart`

No render exists for this screen. Reference used: **02 Registration**
(`screens/02-registration.png` / `.html`) as instructed — the nearest neighbour in the journey —
plus the shipped `lib/features/registration/presentation/registration_screen.dart` (the board's own
implementation of that render) and `lib/features/order_history/presentation/order_history_screen.dart`
for house conventions.

---

## ⚠️ Read this before reviewing: the screen is an ORPHAN

The file carries a tag it has carried since 2026-07-12:

```
// ORPHAN (JEBV4-227, verified 2026-07-12): superseded by biometric_auth/biometric_lock_cubit
```

Verified again here: `BiometricPromptScreen` is referenced **only** by
`lib/devtool/catalog/entries/batch_01_entries.dart` (4 seeded catalog states). It is not in
`app_router.dart`, not reachable from `lib/main.dart`, and has no widget or Maestro test. Its live
successor is `BiometricLockScreen` (`lib/features/biometric_auth/`), which the sibling lane
`w4-biometric` redesigned in parallel.

It is not on the plan's §10 do-not-touch list and it was explicitly assigned to this lane, so it was
re-skinned — but **the user-visible impact of this diff is zero**. If the intent was to spend a lane
on a live surface, this was not one. Flagging rather than silently claiming a win.

## What the screen was

A vertically centred `Column` inside `SafeArea` on a default `Scaffold`: `Icons.fingerprint` at
`Sizes.eightXLarge` in `colorScheme.primary`, a `textTheme.headlineMedium` title, a **hardcoded
English** `bodyLarge` subtitle, then a state switch that returned an `OmdsPrimaryButton` with a
hardcoded `'Authenticate'` label, an `OmdsLoadingState`, or a bare unstyled `Text`. No navy, no
kit widget, no gutters, no docked footer — a Material sample screen sitting next to a designed
product.

## What it is now

Screen 02's band structure, one-for-one:

| Band | Treatment |
|---|---|
| **Navy band** | `JeebNavySurfaceCard.topBand` — bottom-only r36, full-bleed under the status bar, `JeebNavyRing.bandOuter` + `.bandInner` (the render's Ø200 white-.08 / Ø120 orange-.25 circles). Content: Ø56 glass disc (`onPrimary` @ .10 fill, @ .18 hairline, `UIConstants.strokeWidthThin`) carrying the fingerprint mark → `jeebText.h1` white headline → `jeebText.body` periwinkle subtitle. Same mark → headline → subtitle grammar 02 uses for wordmark → headline → tagline. |
| **White body** | Top-aligned, 24px gutters, one `Spacing.xLarge` block below the band. `unavailable` → `JeebInfoNote.muted` (was a bare `Text`); `checking` → `OmdsLoadingState`; every other state contributes nothing. |
| **Emptiness** | A real `Spacer` (plan R1) — the screen's one affordance does not justify filling it. |
| **Docked footer** | `JeebCtaFooter.single` + `JeebCtaButton.primary` (navy pill, `jeebText.button`, `JeebShadows.ctaNavy`) with `leadingIcon: Icons.fingerprint`, inside `SafeArea(top: false)`. |

Structure is 02's exact `LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight) →
IntrinsicHeight → Column(… Spacer …)` trio, which is what makes the `Spacer` legal inside a scroll
view: the column fills the viewport when it fits and degrades to a real scroll at large text scales.
`AnnotatedRegion(SystemUiOverlayStyle.light)` was added for the same reason 02 has it — the band
paints under the status bar and the dark system glyphs `main()` sets would be invisible on navy.

**Kit widgets adopted:** `JeebNavySurfaceCard.topBand` (+ `JeebNavyRing`), `JeebCtaButton.primary`,
`JeebCtaFooter.single`, `JeebInfoNote.muted`.
**Tokens adopted:** `context.jeebText.h1/.body`, `colorScheme.onPrimary/.onSecondaryContainer`,
`Spacing.*`, `Sizes.fiveXLarge/.twoXLarge`, `UIConstants.strokeWidthThin`.
Zero raw hex, zero raw `TextStyle`, zero `fontSize:`, zero hand-rolled kit copies.

## Two l10n holes, one closed and one filed

| Literal | Disposition |
|---|---|
| `'Authenticate'` | **Closed with no wiring.** Now `l10n.biometricUnlockAuthenticateCta` — an existing, already-translated key whose EN value is byte-identical (`"Authenticate"` / `"مصادقة"`). Zero copy change. |
| `'Sign in quickly with your fingerprint or face'` | **Filed, deliberately NOT coded as granted** — see `docs/redesign-2026-08/wiring/w4-biometric-login.md`. |

On the second: constraint 9 says to code as if granted, and that is right for a feature file whose
only consumer is a test. It is **wrong here.** This screen is imported by
`lib/devtool/catalog/entries/batch_01_entries.dart`, which lives in `lib/` — an undefined
`AppLocalizations` getter there is a compile error in the app target and would break
`flutter build` / `flutter test` for every one of the ~20 lanes on this branch. The literal stays
behind a `TODO(redesign-24)` pointing at the wiring file. The request carries the exact ARB + parser
diff and byte-identical EN copy.

Also added: `semanticLabel: l10n.biometricPromptSemanticLabel` on the fingerprint mark — another
already-translated key that had no consumer.

## Deliberate non-changes (restraint)

- **Flow untouched.** Same states, same single affordance, same `authenticate()` handler, same
  catalog seam (`cubit` injection), same `SizedBox.shrink()` for `initial`/`authenticated`/`failed`.
- **No `JeebTopBar`.** The screen has never had a back affordance; adding one would be a flow change.
- **No orange fill.** The DS rations orange to what is happening or expiring now; this screen has no
  decaying moment, so the only orange is the band's decorative `bandInner` ring. Conscious choice,
  not an omission.
- **No copy rewrites.** `"Use Biometrics"` is Title Case where the DS asks for sentence case — left
  alone, because copy is out of a re-skin's mandate.
- **`biometric_cubit.dart` left byte-identical.** `dart format` had reflowed its enum; reverted, to
  keep the diff to the one file that needed changing.
- **No new tests kept.** Verification harnesses (12 state × locale smoke assertions, a 4-point
  text-scale overflow check, and 3 golden captures) were written, run green, and deleted — `test/`
  is not this lane's directory.

## Semantics — both preserved byte-identically

| Identifier | Before | After |
|---|---|---|
| `biometric_prompt_root` | `Semantics(identifier:, container: true)` wrapping the `Scaffold` | unchanged, same two properties, still wrapping the `Scaffold` |
| `biometric_prompt_authenticate_cta` | `Semantics(identifier:, button: true, container: true)` around the CTA | unchanged, same three properties, around the CTA |

No identifier added, removed or renamed. (`explicitChildNodes` was **not** added to the root even
though the kit convention prefers it — the instruction to preserve the existing nodes byte-identically
outranks the convention.)

## Verification

| Check | Result |
|---|---|
| `dart analyze lib/features/biometric_login/` | **No issues found** |
| `dart format` | clean (0 changed on re-run) |
| `bash tool/check_design_tokens.sh` | 3 violations repo-wide, **none in this lane** (`location/client_location_screen.dart`, `wallet/wallet_activity_list_screen.dart`, `reviews/reviews_list_screen.dart` — all pre-existing, other lanes') |
| temp smoke: 6 states × EN/AR | 12/12 pass, no exceptions, no RTL overflow |
| temp overflow: 1.0/1.5/2.0/3.0× text scale | 4/4 pass (**3.0× failed before the scroll trio was added** — the old centred `Column` had the same defect) |
| `test/devtool/catalog_network_guard_test.dart` (the only test touching the catalog) | 2/2 pass |
| `test/decision_violations_test.dart` | 5/5 pass — this screen touches none of D56/D52/D20/fee-framing |
| Repo-wide analyze / full suite | **not run**, per the instruction not to (≈20 concurrent lanes) |

## Remaining inconsistencies vs the neighbour render

1. **The two biometric surfaces now use two different navy structures.** `BiometricLockScreen`
   (lane `w4-biometric`) took 01's full-bleed navy field + docked white sheet; this one took 02's
   navy top band, because 02 is the neighbour this lane was pinned to. Both are legitimate board
   treatments and the screens differ in kind (a gate vs an enrolment prompt), but if one is to be
   picked, someone should pick it — the orphan should follow the live screen, not the other way round.
2. **Type is one token-step smaller than the render.** 02's band headline is 26/w700 and its
   subtitle 15/w500; `jeebText.h1` is 24/w700 and `jeebText.body` 13.5/w500. Token-correct —
   features may not write `fontSize:` — but the band reads slightly quieter than the PNG. Same
   deviation 02's own implementation carries.
3. **No wordmark.** 02 leads its band with the Jeeb SVG; this screen leads with the fingerprint mark
   instead. Deliberate (the mark is the subject, and this is not a first-run brand moment), but it
   is a visible divergence from the reference.
4. **`checking` shows a bare `OmdsLoadingState` under the band.** There is no kit loading primitive,
   so it stays OMDS and is the one un-tokenized element left on the screen.
5. **The subtitle is still an English literal in Arabic** until the wiring request lands. Pre-existing,
   now documented instead of invisible.
6. **The empty region is large** — with one affordance, roughly 65% of the screen is white. That is
   what R1 asks for and what 02 does below its social row, but on a screen with this little content
   it is the most likely thing a reviewer will push back on.
