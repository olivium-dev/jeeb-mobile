# Jeeb CUSTOMER Maestro suite — how to run and test Jeeb (canonical)

The one reusable, indexed customer test suite for the Jeeb mobile app
(`app.jeeb.mobile`, prod v6). Consolidates three per-device exploration runs
(SM-S921B, SM-A33, SM-S908B) into device-agnostic **coordinate-mode** flows.

- **App under test**: `app.jeeb.mobile` (prod flavor v6, installed versionName 1.0.0), launcher `.MainActivity`
- **Gateway (LIVE, not a mock)**: `http://192.168.2.39:10090` (the MSI dev env)
- **Role**: customer/user only (jeeber onboarding deliberately not entered)
- **Default drive mode**: COORDINATE FRACTIONS (Maestro `"x%,y%"` points) — see the Semantics Reconciliation note

```
.maestro/jeeb/
├── config.yaml                 # appId, shared env defaults (PHONE/OTP/DESC)
├── INDEX.md                    # THIS doc
├── BUGS.md                     # UX defects found during exploration
├── flows/
│   ├── pages/*.yaml            # one page-object subflow per customer screen (coordinate-mode)
│   └── journeys/
│       ├── fastest-path.yaml       # fresh install -> live request (13 taps / ~55s)
│       └── full-customer-tour.yaml # exhaustive customer traversal
├── helpers/
│   ├── otp.sh                  # read the real OTP from jeeb-otpdb (dev 1234 never works)
│   └── prep.sh                 # (re)install APK + pre-grant notif + location perms
└── devices/                    # RAW per-device reference suites (do not edit; provenance)
    ├── RFCX306JSRT/            # SM-S921B — FULL 33-screen coordinate map (PR #131)
    ├── RZCT505K7WF/            # SM-A33   — pre-auth only, device was offline (PR #130)
    └── R5CT71TVVAJ/            # SM-S908B — coordinate map, run stopped mid-way (PR #132)
```

---

## 1. Fastest customer test path

Deepest state a **solo** customer run can reach = `waiting-no-coverage`
("Finding Jeebers", a LIVE request via `POST /v1/requests` 201, 5-min offer timer).
`flows/journeys/fastest-path.yaml` composes it from the page objects.

| # | Action | Selector (coord) | Result |
|---|--------|------------------|--------|
| 0 | `prep.sh <serial>` — pre-grant notif + location (0 taps) | — | drops 2 OS dialogs |
| 1 | `launchApp clearState:true`, **Skip** onboarding | `50%,88%` | route `register` |
| 2 | tap phone field, type `71963130` | `50%,59%` + type | number entered |
| 3 | hide keyboard, **Send code** | `50%,67%` | `POST /v1/auth/otp/request` 200 → OTP screen |
| 4 | read OTP from jeeb-otpdb, type it (auto-fills 4 boxes) | `otp.sh` + type | code entered |
| 5 | **Verify** | `50%,38%` | `POST /v1/auth/otp/verify` 200 → `profile-name` |
| 6 | **Skip for now** | `50%,45%` | route `shell` (home); `GET /v1/users/me` 200 |
| 7 | **New Order** | `50%,81%` | route `request-type` (Flash pre-selected) |
| 8 | **Continue** | `50%,87%` | route `client-location` |
| 9 | type description, hide kb, **Confirm location** | `50%,26%` + `50%,87%` | `POST /v1/requests` 201 → `waiting-no-coverage` |

- **~13 discrete taps** (+3 text inputs: phone, OTP, description) with perms pre-granted; ~15 taps if the 2 OS dialogs are tapped through in-UI.
- **~55s wall** scripted end-to-end, dominated by the OTP DB round-trip (~10–15s) and the two ~1.6s slow gateway GETs. Pure in-app transitions total <10s (all APIs 30–530ms).
- **Why minimal**: onboarding **Skip = 1 tap** (vs Next×2 + Get Started = 3); **Skip for now** avoids name entry; **Flash is pre-selected** so request-type is a single Continue; the description is the only required field to enable Confirm. No wasted navigation.

---

## 2. Per-device run matrix

| Serial | Model | Screen | Semantics finding | Drive mode | LAN → gateway? | Status | Source |
|--------|-------|--------|-------------------|-----------|----------------|--------|--------|
| **RFCX306JSRT** | SM-S921B (Galaxy S24) | 1080×2340 | **Empty a11y tree** (semantics OFF) | coordinate | Yes | **FULL** — 33 screens, fastest-path proven to `waiting-no-coverage` (`POST /v1/requests` 201) | PR #131 / devices/RFCX306JSRT |
| **RZCT505K7WF** | SM-A33 | 1080×2400 | **Semantics PRESENT** (`onboarding_headline`) | coordinate (semantics alt viable pre-auth) | **No — device OFFLINE** | **OFFLINE-PARTIAL** — 8 pre-auth screens only; needs LAN wifi to 192.168.2.39 | PR #130 / devices/RZCT505K7WF |
| **R5CT71TVVAJ** | SM-S908B (S22 Ultra) | 720×1544 | **Empty a11y tree** (semantics OFF) | coordinate | Yes | **PARTIAL** — coordinate map captured; workflow stopped mid-run (validate/ screenshots incl. `waiting_finding_a_jeeber`) | PR #132 / devices/R5CT71TVVAJ |

The canonical `flows/` are authored from the **RFCX306JSRT** full map (the most
complete) and are resolution-independent, so they drive all three devices.

---

## 3. Semantics reconciliation note (IMPORTANT)

The **same prod APK** reported **contradictory** accessibility state across devices:

- **S921B & S908B**: `maestro hierarchy` → all-empty tree, 0 clickable nodes, blank text/ids. Text/id selectors DO NOT resolve.
- **A33**: reported Flutter semantics **present** (a real id, `onboarding_headline`).

This is build/device/first-frame-timing dependent (likely semantics not yet
flushed, or a device/GPU a11y-service difference), **not** a reliable per-app
setting. Therefore:

- **Coordinate mode is the safe default** for the canonical suite. Every page
  object uses `tapOn: { point: "x%,y%" }` and carries a **commented `text:`/`id:`
  alternative** where the A33 evidence proved one works (onboarding Skip/Get Started,
  Send code, phone field, language labels).
- **To re-probe semantics on a device before trusting id selectors**:
  ```bash
  ~/.maestro/bin/maestro --device <serial> hierarchy | \
    grep -c 'clickable=true'        # 0  => semantics off, stay on coordinates
                                     # >0 => semantics on, id/text selectors viable
  ```
  Also request real `Semantics(identifier:)` ids from the app team (BUGS.md #1) so
  the whole suite can migrate off coordinates.

---

## 4. Screen index

Coordinates are fractions of the screen (Maestro `%`), resolution-independent.
All page objects live in `flows/pages/`.

| id / route | Screen | Flow file | Key selectors (coord %) |
|------------|--------|-----------|--------------------------|
| (system) | OS permission dialogs | `os-permissions.yaml` | Allow / While using the app (text: selectors work) |
| `onboarding` | Voice-first deliveries (3-page pager) | `onboarding.yaml` | Next/GetStarted 50,80 · Skip 50,88 · EN 66,9 · AR 86,9 |
| `register` | Enter your phone (auth entry) | `register-auth-phone.yaml` | Google 50,42 · phone 50,59 · Send code 50,67 |
| `register` (OTP) | Enter the code | `auth-otp.yaml` | boxes 50,28 · Verify 50,38 · Resend 50,45 · Change phone 50,51 |
| `profile-name` | What should we call you? | `profile-name.yaml` | name 50,29 · Continue 50,38 · Skip for now 50,45 |
| `shell` | Everything, One Place (home / Requests tab) | `shell-home.yaml` | New Order 50,81 · FAB 88,74 · wallet 78,8 · bell 91,8 · nav 10/31/52/73/91,92 |
| `request-type` | Choose your request (tiers) | `request-type.yaml` | Flash 50,26 · Express 50,38 · Standard 50,51 · Continue 50,87 |
| `client-location` | What do you need? (compose + picker) | `client-location.yaml` | desc 50,26 · mic 88,25 · Current 50,51 · Confirm 50,87 |
| `waiting-no-coverage` | Finding Jeebers (deepest solo state) | `waiting.yaml` | Re-target 50,67 · Cancel 50,75 |
| (sheet) | Cancel Delivery | `cancel-delivery-sheet.yaml` | Cancel(red) 50,81 · Keep delivery 50,88 |
| `shell`/Delivery | Delivery / order history | `tab-delivery.yaml` | Filter 50,8 · Active 17,14 · Completed 50,14 · Cancelled 83,14 |
| `shell`/Dashboard·Earnings | Become a Jeeber (upsell — role-bleed) | `tab-become-jeeber.yaml` | Start now 50,60 (JEEBER-SKIP, capture only) |
| `shell`/Profile | Profile | `tab-profile.yaml` | Password 39,51 · Notification 29,58 · Language 27,65 · Saved addr 34,72 |
| `wallet` | Wallet (0.00 USD) | `wallet.yaml` | Top up 50,52 · How fees 50,60 · Earnings&fees 50,70 · Activity 50,77 |
| `notifications` | Notifications inbox (empty) | `notifications.yaml` | Back 8,8 |
| `language-settings` | Language | `language-settings.yaml` | English 12,23 · العربية 10,30 |
| `settings-notifications` | Notification preferences | `settings-notifications.yaml` | 4 toggles ~87,y (2 wrong subtitles — BUGS.md #4) |
| `password-security` | Password & security | `password-security.yaml` | pw 50,25 · new 50,34 · confirm 50,42 · Save 50,51 |
| `settings-addresses` | Saved addresses (empty) | `settings-addresses.yaml` | Add new location 70,88 |

---

## 5. Exact run commands

Maestro CLI: `~/.maestro/bin/maestro` (installed 2.0.5; flow syntax is 1.x-compatible).
Env vars are injected with `-e KEY=VALUE`.

**Single device — fastest path (live, OTP fetched from the DB):**
```bash
cd .maestro/jeeb
helpers/prep.sh RFCX306JSRT                         # pre-grant perms (drops 2 dialogs)
# Send code first so a fresh OTP exists, then read it:
OTP=$(helpers/otp.sh 71963130)
~/.maestro/bin/maestro --device RFCX306JSRT test flows/journeys/fastest-path.yaml \
  -e PHONE=71963130 -e OTP=$OTP -e DESC="Maestro automated test delivery"
```
> The OTP expires in 5 min; because the code is generated when Send code is tapped
> inside the run, the cleanest live pattern splits auth: run `register-auth-phone.yaml`
> to send the code, `otp.sh` to read it, then continue. The per-device suites under
> `devices/RFCX306JSRT/helpers/run-fastest-path.sh` show that split orchestration.

**Single device — full customer tour:**
```bash
~/.maestro/bin/maestro --device R5CT71TVVAJ test .maestro/jeeb/flows/journeys/full-customer-tour.yaml \
  -e PHONE=71963130 -e OTP=$(.maestro/jeeb/helpers/otp.sh 71963130)
```

**All journeys on one device (config.yaml globs `flows/journeys/*.yaml`):**
```bash
~/.maestro/bin/maestro --device RFCX306JSRT test .maestro/jeeb/config.yaml \
  -e PHONE=71963130 -e OTP=$(.maestro/jeeb/helpers/otp.sh 71963130)
```

**Run on several devices in parallel (comma-separated serials):**
```bash
~/.maestro/bin/maestro --device "RFCX306JSRT,R5CT71TVVAJ" test .maestro/jeeb/flows/journeys/fastest-path.yaml -e OTP=...
```

**CI sharding (split journeys across N runners):**
```bash
# shard 0 of 2, etc. Feed the shard's slice of flows/journeys/*.yaml to maestro test.
~/.maestro/bin/maestro test $(ls .maestro/jeeb/flows/journeys/*.yaml | awk "NR % 2 == $SHARD_INDEX")
```
(See the `maestro-ci-sharding` skill for the full matrix pattern; Maestro Cloud
also sharding-splits a folder automatically.)

---

## 6. Caveats (read before running)

- **Prod build semantics are unreliable → coordinate mode.** Do not assume text/id
  selectors work; re-probe with the `hierarchy | grep clickable=true` check (§3).
- **OTP: the dev code `1234` NEVER works.** Read the real 4-digit code from
  `jeeb-otpdb."Phones"` via `helpers/otp.sh` after Send code; it expires in 5 min.
- **Alt fast login — DevTool "Super Login Plus".** The Jeeber Dev Tool build exposes
  a fast-login path (see memory `devtool-login-for-tests` / gateway `[DevOnly]`
  TestControlPlane) that bypasses the OTP DB round-trip. Not wired into these flows
  (they target the real prod build), but it is the fastest auth for a DevTool run.
- **A33 (RZCT505K7WF) needs LAN wifi.** It cannot reach `192.168.2.39` (offline, no
  route). Join the wifi that bridges the 192.168.2.0/24 LAN or USB reverse-tether
  before expecting any authenticated screen.
- **THE FULL CASH-LOOP E2E NEEDS A SECOND DEVICE ACTING AS A JEEBER.** A solo
  customer run stops at `waiting-no-coverage` ("Finding Jeebers") — with no jeeber
  in the area the live gateway returns the no-coverage variant and the request
  eventually expires. **This is NOT a broken E2E.** To drive accept → deliver →
  COD settlement you must run a *second* device (or account) as the jeeber to accept
  the offer. `fastest-path.yaml` intentionally ends at the customer's deepest solo
  state. (Full loop twice-proven manually — see memory `jebv4-9-e2e-proven` /
  `mvp-clean-close`.)
- **`waiting.yaml` / `cancel-delivery-sheet.yaml` create and can cancel a LIVE
  request** on the real gateway. The cancel sheet defaults to **Keep delivery**
  (non-destructive); pass `CONFIRM=true` only when you mean it.
- **Coordinate drift**: if the app layout changes, the fractions can go stale.
  Re-capture from a fresh screenshot; the fractions are documented per page object.

---

## 7. How to extend (add a page object)

1. Capture the screen (`~/.maestro/bin/maestro --device <serial> hierarchy` and a
   screenshot) and record each CTA as a fraction of the screen: `fx = x/width`,
   `fy = y/height` → `"{fx*100}%,{fy*100}%"`.
2. Create `flows/pages/<screen>.yaml` following the existing template:
   - header: `appId: ${APP_ID}` + `env:` defaults (APP_ID, any params, `SHOT`) + `---`
   - commands: `waitForAnimationToEnd`, `takeScreenshot: "${SHOT}"`, then
     `tapOn: { point: "x%,y%" }` per CTA. Add a commented `text:`/`id:` alternative
     if semantics are available on any device.
   - Parameterize variable behavior with `env:` + `runFlow: { when: { true: "${VAR == 'x'}" }, commands: [...] }`.
3. Add the screen to the §4 screen index in this file.
4. Wire it into `flows/journeys/full-customer-tour.yaml` (and `fastest-path.yaml` if
   it is on the critical path) via a `runFlow: { file: ../pages/<screen>.yaml, env: {...} }`.
5. Validate: run the flow on a device, or at minimum confirm YAML parses and every
   `runFlow` include resolves.
