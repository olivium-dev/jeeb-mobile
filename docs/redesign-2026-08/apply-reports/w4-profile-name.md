# w4 · profile-name — apply report

**Screen:** post-OTP display-name onboarding step (`DisplayNameSetupScreen`).
**File owned & changed:** `lib/features/profile_name/presentation/display_name_setup_screen.dart`
(+54 / −31, one file).
**Reference:** no render exists for this screen. Applied the language from
`screens/02-registration.png` — the neighbour one step earlier in the same funnel — plus the
already-migrated `otp_verification_screen.dart` (the step immediately before this one).

---

## What the neighbour does, and what this screen did instead

| 02 registration (render) | this screen, before |
|---|---|
| 24px side gutters, content in one top-aligned block | 16px gutters on all four sides (`EdgeInsetsDirectional.all(Spacing.medium)`) |
| Headline 24/w700 **navy** | `textTheme.headlineSmall.copyWith(fontWeight: w700)` — an ad-hoc weight override, stock M3 ramp |
| Subtitle 13.5/w500 muted | `textTheme.bodyMedium` (14/w400) |
| Primary CTA = full navy pill, r999, h56, `ctaNavy` lift, disabled drops the lift | `OmdsLoadingButton` — stadium, but not the board's pill scale/lift and no token type |
| Secondary exit = bare text, quieter ink, no pill | `OmdsPrimaryButton(variant: text)` |
| Field → 16 → CTA; everything below stays plain white | field → 24 → CTA → 12 → skip, top gutter 16 |
| Field: filled slab, r16, 2px navy border, standalone navy label above, helper beneath | `OmdsTextField` — white fill, 1px cool border, M3 floating label |

## What I changed

1. **Layout rhythm** — the body is now one `EdgeInsetsDirectional.fromSTEB(24, 32, 24, 24)` block:
   the board's 24px gutters (§4.3), with the 32px top inset standing in for the top bar this step
   deliberately does not have. Residual space below the skip exit stays plain white (R1) — no
   `Center`, nothing stretched into it.
2. **Type on tokens** — headline → `context.jeebText.h1` inked `colorScheme.primary`; subtitle →
   `context.jeebText.body` inked `colorScheme.onSurfaceVariant`. Zero raw `TextStyle`, zero
   `fontSize:`, zero hex left in the file. The subtitle is deliberately AA-safe brown, **not** the
   board's periwinkle: §4.1 bans periwinkle as body ink on a light surface and a contrast test
   asserts it.
3. **Kit adoption** — `OmdsLoadingButton` → `JeebCtaButton.primary` (h56 navy pill, `ctaNavy`
   shadow, in-pill spinner on `isLoading`, disabled fill `.45` with the lift dropped);
   `OmdsPrimaryButton(text)` → `JeebCtaButton.text`. Both keep their existing `Key`s and their
   existing `Semantics` wrappers; neither is passed a kit `identifier`, so no nested duplicate id
   can shadow the frozen one.

## What I deliberately did NOT change

- **The flow.** Same steps, same two affordances, same copy, same navigation, same fail-soft
  behaviour (a failed PUT keeps the user here with skip live). No back affordance was added — this
  is a one-way step and adding one would be a product change, not a re-skin.
- **No navy hero band.** 02 has one because it opens the funnel; 03 (OTP) has none, and this step
  sits after 03. A band here would break the funnel's own progression.
- **Docked `JeebCtaFooter` — considered, then rejected.** I built it first (spacer + docked
  footer, the 22-of-24 shape) and it broke the fail-soft exit: the save-error snackbar sits exactly
  on top of a docked skip button, which the lane's own regression test caught
  (`failed PUT keeps the step on screen with skip still available`). 02 is the one funnel screen
  whose primary CTA is **inline under its field** rather than docked, and this screen is 02's
  sibling, so the inline form is both the correct reference and the safe one. Recorded in a code
  comment so the next lane does not re-litigate it.
- **The text field.** `OmdsTextField` stays. `tool/check_design_tokens.sh` bans raw `TextField(`
  in `lib/features` (02 has a named exemption), the kit ships no input widget, and overriding
  `fillColor` screen-locally would reintroduce the OMDS "P0-X03" white-outlined-field decision in
  reverse. Filed as a request in `wiring/w4-profile-name.md` (kit `JeebTextField`, or extend the
  gate exemption) — nothing in this lane's code depends on it being granted.
- **No `JeebInfoNote` / trust footer.** 02 has one; this screen's subtitle already carries the
  "you can skip and add it later" reassurance, and a note would need new l10n copy this lane has
  no mandate to invent.

## Verification

- `dart analyze lib/features/profile_name test/features/profile_name` → **No issues found!**
- `flutter test test/features/profile_name/` → **16/16 pass** (all 5 widget tests, including the
  Arabic RTL one and the fail-soft-skip regression).
- `bash tool/check_design_tokens.sh` reports **no** violation in `profile_name`.
- Semantics ids unchanged, byte for byte: `profile_name_root` · `profile_name_input` ·
  `profile_name_submit_cta` · `profile_name_skip_cta`. Widget keys unchanged:
  `profile-name.title` · `.field` · `.submit` · `.skip`. No new interactive widget was added, so
  no new identifier was minted.
- Constraints touched by nothing here: no pubspec edit, no shared-file edit, no l10n key added, no
  endpoint/field invented, no D20/D41/D44/D52/D56 surface involved.

## Remaining inconsistencies (honest list)

1. The input still reads as stock Material (floating label, white fill, 1px cool border, no helper
   line) where the board draws a filled r16 slab with a standalone navy label. Blocked on the
   shared gate/kit — see the wiring request.
2. No `JeebTopBar`: correct for a one-way step, but it does mean this is one of the few screens in
   the funnel with no chrome at all at the top.
3. The board's periwinkle subtitle ink is rendered as `onSurfaceVariant` brown here. Intentional
   (AA gate), but it is a visible divergence from the render on any light-surface screen.
4. This screen has no orange anywhere. That is correct rationing — nothing here is live, expiring
   or decaying — but it does read cooler than 02, which spends its orange on the wordmark wheel
   and the live-valid tick.
