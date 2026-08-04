# Wiring requests — 02 · Registration

Companion to `per-screen-revised/02-registration.md` (the authoritative spec). The lane code in
`lib/features/registration/presentation/registration_screen.dart` is written **as if every request
below is already granted**, so the file carries exactly 5 `dart analyze` errors until the
integrator applies them:

| file:line | error |
|---|---|
| `registration_screen.dart:384` | `SocialSignInSection(axis: …)` — undefined named parameter |
| `registration_screen.dart:498` | `l10n.registrationTagline` — undefined getter |
| `registration_screen.dart:683` | `l10n.registrationPhoneExample` — undefined getter |
| `registration_screen.dart:726` | `l10n.registrationPhoneHelper` — undefined getter |
| `registration_screen.dart:762` | `l10n.registrationTrustNote` — undefined getter |

`test/registration_screen_test.dart` (this lane's own, updated) is likewise red until then — it
asserts on the four new strings.

---

### l10n
file: lib/l10n/app_en.arb, lib/l10n/app_ar.arb, lib/l10n/app_localizations.dart
need: one value change + four new keys for the rebuilt registration screen, plus their getters.
exact change:
app_en.arb — change:
```json
"registrationWelcome": "Welcome, neighbour",
```
app_en.arb — add:
```json
"registrationTagline": "Your errand, made easier · جيب، مشوارك أسهل",
"@registrationTagline": {"description": "Bilingual brand tagline in the registration hero band; each locale leads with its own script."},
"registrationPhoneHelper": "8-digit Lebanese number — we text you a code.",
"@registrationPhoneHelper": {"description": "Resting helper line under the phone field on registration."},
"registrationPhoneExample": "3 123 456",
"@registrationPhoneExample": {"description": "In-field example hint for the phone number; digit grouping is display-only."},
"registrationTrustNote": "No card needed. Your number is only shared with the Jeeber you accept.",
"@registrationTrustNote": {"description": "Docked trust footer on registration; cash-on-delivery, no in-app payment."}
```
app_ar.arb — change:
```json
"registrationWelcome": "أهلاً بك يا جار",
```
app_ar.arb — add (integrator owns final AR register; these follow the board's warm tone):
```json
"registrationTagline": "جيب، مشوارك أسهل · Your errand, made easier",
"registrationPhoneHelper": "رقم لبناني من ٨ أرقام — منبعتلك رمز برسالة نصية.",
"registrationPhoneExample": "3 123 456",
"registrationTrustNote": "ما في حاجة لبطاقة. رقمك بينشارك بس مع الجيبر يلي بتقبل عرضه."
```
app_localizations.dart — add next to `registrationWelcome` (`:572`):
```dart
String get registrationTagline => _get('registrationTagline');
String get registrationPhoneHelper => _get('registrationPhoneHelper');
String get registrationPhoneExample => _get('registrationPhoneExample');
String get registrationTrustNote => _get('registrationTrustNote');
```
why: the hero tagline, field hint, helper line and trust footer are all new board copy; the
welcome headline changes to the board's "Welcome, neighbour". `registrationPhoneTitle` and
`registrationPhoneSubtitle` become orphan getters — leave them (orphans are warn-only in
`qa/t-mob-fix-002/l10n_parity_check.sh:29`).

**Test coupling:** `test/registration_screen_test.dart` now asserts the literal EN strings
`"8-digit Lebanese number — we text you a code."`,
`"No card needed. Your number is only shared with the Jeeber you accept."`, and the AR strings
`"أهلاً بك يا جار"` and `"جيب، مشوارك أسهل · Your errand, made easier"`. If the integrator adjusts
any of those values, update the matching `find.text()` in that file.

### cross-feature
file: lib/features/auth/social/social_sign_in_section.dart
need: an opt-in horizontal layout so screen 02 can demote social to a compact two-up row.
exact change: add `this.axis = Axis.vertical` to the constructor (`final Axis axis;`). In
`build`, when `axis == Axis.horizontal`, render `Row(children: [Expanded(google), SizedBox(width:
Spacing.small), Expanded(apple-if-available)])` with Google at the start (board order); when
`SocialSignInButton.isAppleAvailable()` is false, the Row degrades to one full-width Google
button. Keys (`registration.googleSignIn`/`appleSignIn`) and identifiers
(`login_social_google`/`login_social_apple`) unchanged. Default stays vertical so
`test/social_collision_sheet_test.dart` is untouched.
why: screen 02 passes `axis: Axis.horizontal` (already written as-if-granted); without this the
screen does not compile.

**Fidelity note for whoever lands this (not a request, an observation):** the board's two-up pills
read `Google` / `Apple`, while `SocialSignInButton` renders the brand-mandated
`Continue with Google` / `Continue with Apple`. At 360dp those labels will ellipsize or shrink
inside a half-width pill. The brand strings win (documented hex/brand exemption at the top of
`social_sign_in_button.dart`), so the honest options are (a) let OMDS ellipsize, or (b) add a
`compact` label key to the social feature — that is the social owner's call, not this lane's.

### cross-feature
file: lib/features/auth/social/social_sign_in_button.dart
need: fix the inverted Apple-glyph ternary — a live visibility defect on every light-mode iOS build.
exact change: at `:137-138`, `_AppleGlyph(color: isDark ? _appleBrandBlack : _appleBrandWhite)`
→ `_AppleGlyph(color: isDark ? _appleBrandWhite : _appleBrandBlack)` (OMDS's neutral skin renders
an always-white pill — `omds_social_button.dart:177` — so light mode currently paints a white
glyph on a white button). Re-check the `isDark:` passthrough at `:142` for the same inversion.
why: the glyph is invisible on screen 02 (and login) in light mode on iOS; found while verifying
this screen, independent of the redesign.
