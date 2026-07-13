# FINDINGS — R5CT71TVVAJ (Samsung SM-S908B / Galaxy S22 Ultra)

Device-scoped Maestro suite for the **Jeeb customer app**, tuned to one physical
handset. This directory is device-isolated — nothing here touches other devices'
suites, and it deliberately does NOT reuse the semantic-id emulator flows in
`.maestro/` (those need a Flutter semantics tree this device does not expose).

---

## 1. Device profile

| Property | Value |
|---|---|
| Serial | `R5CT71TVVAJ` |
| Model | Samsung SM-S908B (Galaxy S22 Ultra) |
| Platform | Android (physical device) |
| App under test | `app.jeeb.mobile` (**PROD flavor** — real backend, real OTP; NOT `.dev`) |
| Backend | MSI dev/staging (real `/v1/auth/*` + `/v1/requests`) |
| Maestro | 2.0.5 (`~/.maestro/bin/maestro`) |
| **drive_mode** | **`coordinate`** — see §2 |

## 2. Semantics / drive mode — WHY coordinates

`maestro hierarchy` on this handset returns nodes with **empty `text` / `resource-id`**
for all in-app (Flutter) content: the Flutter **semantics tree is not exported** here.
Consequence:

- **No `assertVisible: id:` and no `assertVisible: text:` for app content.** Structural
  assertion is impossible. Correctness is proven by **screenshots** (the
  `maestro-visual-capture` empty-semantics fallback) — every page/journey drops
  `takeScreenshot` at each meaningful state; a vision pass grades them.
- Every in-app tap is a **coordinate `point:` percentage** (device-calibrated
  fractions, converted to Maestro `X%,Y%`). These are THIS device's "selectors".
- **EXCEPTION — Android system dialogs** (notification + location permission) are
  native OS UI, not Flutter, so their **text IS matchable**. Those two pages use
  `tapOn: text: "Allow"` / `"While using the app"` with `optional: true` (robust to
  the dialog being absent), with a coordinate fallback commented inline.

> If a future build lands `Semantics(identifier: …)` and it surfaces on this device
> (`maestro hierarchy` shows resource-ids), migrate the coordinate taps to `id:`
> and add real `assertVisible` gates — coordinates are the fallback, not the goal.

## 3. Input reliability

- Maestro `inputText` (driver-level, per-char) is reliable here; we still `eraseText`
  before typing the phone to clear residual/autofill. The digit drop/duplicate
  corruption in the recipe is a **raw `adb shell input text`** problem, not Maestro's.
- OTP 4-box **auto-submits on the 4th digit** — no Verify tap on success.

---

## 4. Screen index (page objects)

All under `flows/pages/` — appId-less subflows, composed via `runFlow`. `[JEEBER-SKIP]`
= delivery-side, out of scope for the customer suite (captured, never actioned).

| Page object | Screen | Primary action / notes |
|---|---|---|
| `onboarding.yaml` | Voice-first 3-page carousel | Skip -> register (Next x3 alt commented) |
| `notif-permission.yaml` | System notif dialog | Allow (text, optional) |
| `register.yaml` | Enter phone / Welcome | type `PHONE` -> Send code (otp/request 200) |
| `otp-entry.yaml` | Enter the code (4-box) | type `OTP` -> auto-submit (otp/verify 200) |
| `name-capture.yaml` | What should we call you? | Skip for now -> shell |
| `home-requests-empty.yaml` | Home / No orders yet | New Order -> request-type |
| `home-requests-populated.yaml` | Requests tab + list | Record a request (voice) |
| `request-type.yaml` | Flash/Express/Standard | select `TIER_POINT` -> Continue |
| `client-location-compose.yaml` | Location / What do you need? | type `DESC` -> Confirm (requests 201) |
| `location-permission.yaml` | System location dialog | While using the app (text, optional) |
| `waiting-no-coverage.yaml` | **Finding a Jeeber (DEEPEST)** | screenshot; retarget/cancel commented |
| `cancel-delivery-sheet.yaml` | Cancel Delivery sheet | Cancel (confirm) |
| `voice-request.yaml` | Record your request | long-press mic (see §7 caveat) |
| `wallet.yaml` | Wallet | screenshot |
| `notifications.yaml` | Notifications | screenshot |
| `profile.yaml` | Profile tab | screenshot; RegisterJeeber `[JEEBER-SKIP]` |
| `language-settings.yaml` | Language EN/AR | screenshot; **do not switch to AR mid-run (RTL flips coords)** |
| `delivery-tab.yaml` | Delivery tab | screenshot |
| `dashboard-tab.yaml` | Dashboard (Become a Jeeber) | screenshot; StartNow `[JEEBER-SKIP]` |
| `earnings-tab.yaml` | Earnings (Become a Jeeber) | screenshot; StartNow `[JEEBER-SKIP]` |
| `settings-addresses.yaml` | Saved addresses | Add new location -> address-detail |
| `address-detail.yaml` | Address form + map | fill `LABEL/BUILDING/FLOOR` -> Save |

Bottom-nav x-fractions @ y=90.5%: **Delivery 30.6% - Dashboard 51.7% - Earnings 73.2%
- Profile 91.4%**. (Requests/home tab x is unmapped — return home via hardware Back.)

---

## 5. Fastest path (deepest state) + timing

**Deepest customer state:** `waiting-no-coverage` ("Finding a Jeeber", request
broadcasting after `POST /v1/requests 201`).

Sequence (~11 taps, ~90s wall): cold launch -> notif Allow -> skip onboarding ->
phone `76543201` -> Send code -> **[read OTP]** -> OTP auto-submit -> Skip name ->
New Order -> Flash + Continue -> grant location -> describe + Confirm -> **waiting**.

Journeys (`flows/journeys/`):
- `fastest-path.yaml` — the whole path in one file; requires `-e OTP` (see §6).
- `auth-request-otp.yaml` — Phase 1 (cold launch -> Send code), parks on OTP screen.
- `after-otp.yaml` — Phase 2 continuation (no relaunch) -> deepest state; needs `-e OTP`.
- `full-customer-tour.yaml` — Phase-2 continuation; screenshot sweep of every screen.

---

## 6. Auth recipe (two-phase, REAL OTP)

Phone OTP, fresh +961 8-digit (e.g. `76543201`, stored as `+96176543201`). **`1234`
never works.** OTP is inherently two-phase — you cannot know the code before
send-code fires — so:

```bash
export JAVA_HOME="$(/usr/libexec/java_home)"
DIR=.maestro/devices/R5CT71TVVAJ
M=~/.maestro/bin/maestro

# Phase 1 — sends the code, parks on the OTP screen (keeps the session).
"$M" --device R5CT71TVVAJ test -e APP_ID=app.jeeb.mobile -e PHONE=76543201 \
  "$DIR/flows/journeys/auth-request-otp.yaml"

# Read the REAL code from jeeb-otpdb (native psql; never docker).
OTP="$("$DIR/helpers/otp.sh" 76543201)"

# Phase 2 — continue the SAME session to the deepest state.
"$M" --device R5CT71TVVAJ test -e APP_ID=app.jeeb.mobile -e OTP="$OTP" \
  -e DESC="Two coffees from the corner shop" \
  "$DIR/flows/journeys/after-otp.yaml"
```

`helpers/otp.sh` runs (defaults target MSI):
`PGHOST=192.168.2.20 PGPORT=5432 PGUSER=oudaykhaled PGDATABASE=jeeb-otpdb`
-> `SELECT "OTP" FROM "Phones" WHERE "PhoneNumber" LIKE '%76543201%' ORDER BY "OTPSentDate" DESC LIMIT 1`.

The all-in-one `fastest-path.yaml` is for when you **already hold** a valid latest
code (`-e OTP=<code>`); on a cold real device use the two-phase split above.

---

## 7. UX bugs / device caveats observed

- **Maps never render:** both the client-location compose map and the address-detail
  map show only a grey "Map preview" placeholder — no tiles. Location still resolves
  via **GPS** (Current Location), so the happy path works, but "Edit pin" is
  unreliable; flows rely on the GPS-resolved default pin, not manual map pinning.
- **No semantics tree** (root cause of coordinate mode) — see §2.
- **Arabic/RTL** flips every horizontal coordinate; `language-settings.yaml` captures
  the screen but the suite never switches locale inside an LTR happy-path run.
- **`voice-request.yaml`** uses `longPressOn: point:` to emulate press-and-hold.
  Maestro has no explicit hold-duration primitive; if the record gesture doesn't
  register on-device, replace with a duration `swipe` in place or an `adb` motion —
  verify during the Validate phase (this page is off the fastest path).

---

## 8. How to run on THIS device

```bash
export JAVA_HOME="$(/usr/libexec/java_home)"
adb devices | grep R5CT71TVVAJ          # confirm attached
adb -s R5CT71TVVAJ shell pm list packages | grep app.jeeb.mobile   # confirm installed
# (optional, steadier screenshots) disable animations:
adb -s R5CT71TVVAJ shell settings put global window_animation_scale 0
adb -s R5CT71TVVAJ shell settings put global transition_animation_scale 0
adb -s R5CT71TVVAJ shell settings put global animator_duration_scale 0
```

- **Deepest-state proof:** two-phase recipe in §6 (`auth-request-otp` -> `otp.sh` ->
  `after-otp`).
- **Full screenshot tour:** Phase 1 + `otp.sh`, then
  `... -e OTP="$OTP" flows/journeys/full-customer-tour.yaml`.
- **Single page objects** are subflows (no `appId`) — run them via a journey's
  `runFlow`, not standalone.
- Screenshots land in Maestro's run dir; for a known path use
  `adb -s R5CT71TVVAJ exec-out screencap -p > <out>.png` between steps.

> Authored with the flows NOT executed here (no device attached to this session).
> YAML well-formedness verified for all 27 files via a parser; Maestro has no
> offline lint in 2.0.5, so on-device runtime validation is the Validate phase's job.
