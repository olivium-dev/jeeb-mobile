# Jeeb CUSTOMER exploration — UX bugs & observations

Concrete defects surfaced while mapping the customer flow for the Maestro suite.
Primary source = the **SM-S921B (RFCX306JSRT)** full customer run (2026-07-13);
cross-device confirmations from SM-A33 (RZCT505K7WF) and SM-S908B (R5CT71TVVAJ)
are noted. File these against JEBV4 (dedupe against existing tickets first).

## From the S921B full-customer run (RFCX306JSRT)

1. **Flutter semantics DISABLED in the prod build** (highest impact)
   `maestro hierarchy` returns an all-empty accessibility tree: 0 `clickable=true`,
   blank `text`/`resource-id`/`accessibilityText` on every Flutter widget. This
   blocks ALL text/id-based Maestro automation AND screen readers (a real
   accessibility regression, not just a test-tooling problem). Forces the whole
   suite into coordinate mode. Fix: ship with semantics enabled and add
   `Semantics(identifier:)` ids on the key CTAs (onboarding Next/Skip/GetStarted,
   phone field, Send code, Verify, New Order, Continue, Confirm location).
   NOTE: on SM-A33 the same APK reported semantics PRESENT (`onboarding_headline`) —
   so this is build/device/first-frame-timing dependent, not a flat "off". See the
   Semantics Reconciliation note in INDEX.md.

2. **Two consistently slow endpoints (~1.6s each)**
   `GET /api/users/me/saved-locations` and `GET /v1/notifications/preferences` both
   return in ~1.6s vs 30–130ms for every other call — visible lag entering the
   location picker and the notification-settings screen.

3. **Customer role-bleed: jeeber tabs in the customer bottom nav**
   A phone-only customer sees **Dashboard** and **Earnings** tabs (2 of 5) in the
   bottom nav; both are dead-ends rendering only "Become a Jeeber / Start now".
   Clutters customer navigation with two upsell gates.

4. **Notification-preferences wrong subtitle copy (2 strings)**
   - "Wallet" category subtitle reads "Manage what you get notified about" (the
     screen header text, duplicated).
   - "Rating reminders" subtitle reads "Discounts and seasonal promotions" (copied
     from the Offers category).

5. **Phone-field editing fragility**
   Tapping into the number field mid-string inserts stray digits; there is no
   select-all affordance and no input mask beyond 8 digits, so a malformed number
   is easy to submit. (Also bites automation — the suite `eraseText`s before typing.)

6. **Onboarding language toggle ambiguity**
   "English" renders as plain text next to an "العربية" pill; unclear which is the
   active selector (both look tappable).

## Cross-device confirmations / additional finds

7. **Onboarding overflow debug stripe in a PROD build** (SM-A33)
   Onboarding pages 1 & 2 in **English** render the Flutter "BOTTOM OVERFLOWED BY
   4.0 PIXELS" yellow/black debug stripe over the subtitle. Page 3 and the Arabic
   variant do not. A debug-overflow indicator shipping in prod is itself a red flag;
   the subtitle box is ~4px too short for 2-line EN copy at that text scale.

8. **Phone validator rejects a VALID Lebanese number** (SM-A33)
   `71893001` (well-formed 8-digit Alfa-71 number, accepted by the gateway) is
   rejected client-side with "Enter a valid Lebanese phone number"; the `71888xxx`
   range passes. The client regex is too strict.

9. **Network failure mis-surfaced as a validation error** (SM-A33)
   With a client-valid number, tapping Send code while offline shows the same red
   "Enter a valid Lebanese phone number" instead of a connectivity error —
   upstream/network faults are rendered as phone-format errors.

10. **Maps never render — grey "Map preview" placeholder** (SM-S908B)
    Both the compose `client-location` map and the `address-detail` map show only a
    grey placeholder (no tiles). Consistent with the known Maps-API-key gap
    (JEBV4-176). Customer can still proceed via GPS "current location".
