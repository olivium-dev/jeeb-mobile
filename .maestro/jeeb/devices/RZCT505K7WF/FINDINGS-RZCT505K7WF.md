# FINDINGS — Maestro flows for device RZCT505K7WF (Jeeb customer app)

## Device profile

| | |
|---|---|
| Serial | `RZCT505K7WF` |
| Model | Samsung SM-A336B (Galaxy A33 5G) |
| Screen | 1080 x 2400 |
| App | `app.jeeb.mobile` (prod, versionName 1.0.0, sha 68fd38f) |
| Launcher | `app.jeeb.mobile/app.jeeb.mobile.MainActivity` |
| Configured gateway | `http://192.168.2.39:10090` (healthy from the Mac; **unreachable from this phone**) |
| Role | customer / user only |
| Map source | `evidence/fastpath/RZCT505K7WF/APP-MAP-RZCT505K7WF.md` + `explore/01..12_*.png` |
| Maestro | v2.0.5 (`~/.maestro/bin/maestro`) |

## Drive mode: COORDINATE FRACTIONS (not semantics ids, not text)

The task nominally requested `drive_mode=semantics`, but this build does **not**
publish a usable semantics tree. `maestro --device RZCT505K7WF hierarchy` on the
Flutter surface returns **no `text` and no `resource-id`** — the empty-semantics-tree
case. Therefore:

- **Flutter screens** (onboarding, register) are driven by `tapOn: point:` using
  **percentages of the 1080x2400 screen** (resolution-independent). `tapOn: id:`
  and `tapOn: text:` do **not** resolve on these screens.
- **Native system dialogs** (Android notification permission, Google Play sign-in)
  DO expose text, so those are tapped by `tapOn: text:` with a `point:` fallback.
- Correctness is verified by **vision on screenshots**, not by the (empty) hierarchy.
  Every page object captures a `takeScreenshot` at its state.

> To make these flows i18n-safe/structural in future, the app must ship
> `Semantics(identifier: ...)` on: onboarding Next/Skip/Get Started, the language
> toggle, the phone field, and Send code. Until then, coordinates are the only
> reliable driver on this device.

### Selector table (percentages of 1080x2400)

| screen | element | text (native only) | point (x%,y%) |
|--------|---------|---------------------|---------------|
| S00 | Allow notifications | `Allow` | 50%,82.0% |
| S00 | Don't allow | `Don't allow` | 50%,88.2% |
| S01/2/3 | Language to Arabic | `العربية` | 87%,7.8% |
| S04 | Language to English | `English` | 31%,7.8% |
| S01/2 | Next | (Flutter, no text) | 50%,81.5% |
| S03 | Get Started | (Flutter, no text) | 50%,81.5% |
| S01/2/3 | Skip | (Flutter, no text) | 50%,88.9% |
| S05 | Continue with Google | (Flutter, no text) | 49%,38.2% |
| S05 | Phone field (+961) | (Flutter, no text) | 46%,54.0% |
| S05 | Send code | (Flutter, no text) | 50%,62.1% |

## Screen index (8 offline-reachable pre-auth screens)

| id | title | route | page object |
|----|-------|-------|-------------|
| S00 | Android notification permission dialog | (system over `onboarding`) | `flows/pages/_notif-permission.yaml` |
| S01 | Voice-first deliveries (1/3, EN) | `onboarding` | `flows/pages/_onboarding-page.yaml` |
| S02 | Trusted Jeebers (2/3, EN) | `onboarding` | `flows/pages/_onboarding-page.yaml` |
| S03 | Live tracking (3/3, EN) | `onboarding` | `flows/pages/_onboarding-page.yaml` |
| S04 | Onboarding Arabic / RTL variant | `onboarding` | `flows/pages/_language-toggle.yaml` |
| S05 | Welcome to Jeeb / register (phone-OTP entry) | `register` | `flows/pages/_register.yaml` |
| S06 | Register with validation error | `register` | `flows/journeys/register-validation-bugs.yaml` |
| S07 | Google Play sign-in (network dead-end) | (system) | `flows/pages/_google-signin.yaml` |

## CRITICAL BLOCKER — device is fully offline (scope limit)

This phone has **no usable network** (`ip -o addr` shows only `lo`+`dummy0`;
empty `ip route`; WiFi enabled but DISCONNECTED, saved SSID not in range; SIM
OUT_OF_SERVICE). It **cannot reach** the LAN gateway `192.168.2.39:10090`. Every
in-app request logs `status:null`; both auth paths dead-end (phone-OTP submit
never creates a DB row; Continue with Google -> "You don't have a network
connection"). The gateway itself is healthy from the Mac and the OTP contract is
proven there.

Consequently **only the 8 pre-auth screens are mapped and covered.** All
authenticated customer screens — home, compose-request (voice + manual), address/
location picker, Requests/Delivery/Wallet/Profile tabs, wallet, notifications,
profile+language, order history — were **NOT reachable** and are **intentionally
not fabricated** here. **RESUME and extend the tour once the device can reach
192.168.2.39** (join the bridging WiFi, or USB reverse-tether e.g. gnirehtet —
the APK install was permission-denied this run and needs an owner allow-rule).

## Fastest path (fresh install -> deepest reachable state)

Deepest offline-reachable state = `register`. **2 taps, ~9s** — Skip collapses all
3 onboarding pages at once.

| # | action | selector | ~wall |
|---|--------|----------|-------|
| 1 | `launchApp clearState:true` | — | 6.0s |
| 2 | dismiss notif dialog | `Don't allow` @ 50%,88.2% | 1.0s |
| 3 | Skip onboarding -> register | Skip @ 50%,88.9% | 2.0s |

Total ~9s. Flow: `flows/journeys/fastest-path.yaml`.
(Alternate: Next->Next->Get Started = 4 taps, ~13s, same destination.)

## Auth recipe (proven at gateway; in-app blocked by network on this device)

1. Request OTP: `POST http://192.168.2.39:10090/v1/auth/otp/request` with
   `{"phone":"+961XXXXXXXX"}` — field is **`phone`**, E.164 with `+961`. Returns
   `{"ttlSeconds":300}`.
2. Read the real 4-digit OTP (1234 never works) from Postgres
   `192.168.2.20:5432` db `jeeb-otpdb`:
   `SELECT "OTP" FROM "Phones" WHERE "PhoneNumber"='+961...' ORDER BY "ID" DESC LIMIT 1;`
   -> both steps wrapped in **`helpers/otp.sh`** (run from a LAN host, not the phone).
3. In-app: type a number the CLIENT validator accepts (71888xxx passes; 71893001
   is wrongly rejected — bug #2), Send code, then enter the DB OTP on the OTP
   screen (only reachable on a networked device).

## UX bugs observed (evidence in `evidence/fastpath/RZCT505K7WF/explore/`)

1. **Onboarding overflow stripes** — EN pages 1 & 2 render the Flutter
   "BOTTOM OVERFLOWED BY 4.0 PIXELS" debug stripe over the subtitle (shots 02,03).
   Page 3 and the Arabic variant do not. A debug-overflow indicator in a **prod**
   build is itself a red flag.
2. **Phone validator rejects a valid Lebanese number** — `71893001` (well-formed
   Alfa-71 8-digit, accepted by the gateway) is rejected client-side with
   "Enter a valid Lebanese phone number" (shot 08). The 71888xxx range passes.
   Client regex too strict. Reproduced by `register-validation-bugs.yaml`.
3. **Network failure mis-surfaced as a validation error** — with a client-valid
   number (71888123), Send code while offline shows the SAME red
   "Enter a valid Lebanese phone number" (shot 10) instead of a connectivity
   error. Reproduced by `register-validation-bugs.yaml`.

## How to run on THIS device

```bash
cd maestro/jeeb/devices/RZCT505K7WF
MAESTRO=~/.maestro/bin/maestro

# 1) fastest path -> deepest offline state (register), 2 taps
$MAESTRO test --device RZCT505K7WF flows/journeys/fastest-path.yaml

# 2) full pre-auth tour (all 8 screens, screenshots per state)
$MAESTRO test --device RZCT505K7WF -e PHONE=71888123 \
  flows/journeys/full-customer-tour.yaml

# 3) reproduce the register validation bugs (#2, #3)
$MAESTRO test --device RZCT505K7WF flows/journeys/register-validation-bugs.yaml

# On a NETWORKED device, fetch a real OTP from a LAN host first:
export PGUSER=... PGPASSWORD=...
OTP=$(helpers/otp.sh +96171888123)
$MAESTRO test --device <serial> -e PHONE=71888123 -e OTP=$OTP \
  flows/journeys/full-customer-tour.yaml
```

Screenshots land in Maestro's run dir (`~/.maestro/tests/<ts>/`); move them next
to the evidence set for parity comparison.

## Notes / method

- Device-isolated: everything lives under `maestro/jeeb/devices/RZCT505K7WF/`.
  Other devices' dirs were not touched. Only serial `RZCT505K7WF` was driven.
- Maestro 2.0.5 has **no** `--dry-run` / syntax subcommand; flows were validated
  for YAML well-formedness with a parser. Full end-to-end execution is the
  Validate phase's job, on-device.
- Point values are percentages so they survive minor DPI/scaling as long as the
  layout is unchanged; re-map if the onboarding/register layout is redesigned.
