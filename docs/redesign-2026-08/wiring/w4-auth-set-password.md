# Wiring requests — `w4-auth-set-password`

**Lane:** `lib/features/auth/presentation/set_password_screen.dart`
**Date:** 2026-08-03

## Shared files edited by this lane

**None.** The migration is contained inside `lib/features/auth/` plus one new test file
(`test/features/auth/set_password_screen_test.dart`). No `app_router.dart`,
`injection_container.dart`, `lib/l10n/*`, `lib/core/theme/*`, kit or `pubspec.yaml` edit was
needed, so nothing here is blocking.

---

## OPTIONAL — not blocking, integrator's call

### 1. A password-policy helper line under the new-password field

The design language pairs every input with a periwinkle constraint hint (screen 02:
*"8-digit Lebanese number — we text you a code."*, `tpl 85`, 12.5/w500 periwinkle, `margin-top 8`).
`set-password` states its policy **nowhere** until the user fails it — `SetPasswordPolicy`
(≥8 chars, ≥1 letter, ≥1 digit) is only surfaced through the after-the-fact
`setpw_validation_error` note.

This needs new copy, so it was **deliberately NOT added**: the repo has no gen-l10n and
`lib/l10n/app_localizations.dart` is a hand-authored runtime ARB parser (constraint 4), and adding
copy is a product change, not a re-skin (constraint 4 of the lane brief). Coding "as if granted"
against a missing key would fail the build for every lane, so it is filed instead.

Paste-ready, if the integrator wants it:

`lib/l10n/app_en.arb`
```json
  "setpwPolicyHint": "At least 8 characters, with a letter and a number.",
  "@setpwPolicyHint": { "description": "JM-022 password-policy helper line under setpw_new_field." },
```

`lib/l10n/app_ar.arb`
```json
  "setpwPolicyHint": "٨ أحرف على الأقل، تتضمّن حرفًا ورقمًا.",
```

`lib/l10n/app_localizations.dart` — add the getter next to the other `setpw*` entries, following
whatever accessor shape the surrounding keys use.

Call site (would go directly after the `setpw_new_field` `Semantics` block, before the
`SizedBox(height: Spacing.medium)`):

```dart
const SizedBox(height: Spacing.xSmall),
Text(
  l10n.setpwPolicyHint,
  // Periwinkle is banned as body ink on white (§4.1), so the hint takes the
  // brown subtitle role — the same substitution password-security made.
  style: context.jeebText.bodySmall.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
),
```

### 2. Dedicated `setpw` back-edge, if `password-security` ever stops being the only caller

`JeebTopBar.back` here keeps the kit default (`Navigator.maybePop()`) — byte-equivalent to the
`OMDSAppBar` back button it replaced, and `AppRouter.backFallbacks['set-password'] = '/'` still
governs the system BACK gesture. No change requested; recorded so the next reader does not
"fix" it into a `goNamed`.
