# Wiring requests — w4 · `biometric-login` (`BiometricPromptScreen`)

One request, and — deliberately — the screen is **NOT** written as if it were granted.

`lib/features/biometric_login/presentation/biometric_prompt_screen.dart` is imported by
`lib/devtool/catalog/entries/batch_01_entries.dart`, which is inside `lib/`. An undefined
`AppLocalizations` getter there is a **compile error in the app target**, not just in a test — it
would break `flutter build`/`flutter test` for all ~20 lanes running in parallel on this branch.
So the literal stays in place behind a `TODO(redesign-24)` until this request lands.

### l10n
file: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `lib/l10n/app_localizations.dart`
need: one new key for the biometric-enrolment prompt's subtitle, which has been a hardcoded English
literal since the screen was written (it renders English in the Arabic locale today).
exact change:

`app_en.arb` — add next to `biometricNotAvailable` (append-only):

```json
"biometricPromptSubtitle": "Sign in quickly with your fingerprint or face",
"@biometricPromptSubtitle": {
  "description": "Subtitle under the heading on the biometric enrolment prompt screen; explains what enabling biometrics buys you."
}
```

`app_ar.arb` — add:

```json
"biometricPromptSubtitle": "سجّل دخولك بسرعة ببصمتك أو بوجهك"
```

`app_localizations.dart` — add directly after the `biometricNotAvailable` getter (line ~352):

```dart
  String get biometricPromptSubtitle => _get('biometricPromptSubtitle');
```

then, in `biometric_prompt_screen.dart`, replace the literal + its four-line `TODO(redesign-24)`
comment with:

```dart
            l10n.biometricPromptSubtitle,
```

**Copy is byte-identical to what ships today** — this is a localization fix, not a copy change.

### Not requested
- No theme, router, DI, kit or pubspec changes. The screen composes existing kit widgets only.
- No new key for the CTA: the existing, already-translated `biometricUnlockAuthenticateCta`
  ("Authenticate" / "مصادقة") is byte-identical to the literal it replaced, so that hole is closed
  without wiring.
