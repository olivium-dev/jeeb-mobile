# Maestro Device Profile — RFCX306JSRT (Samsung Galaxy S24)

Device-scoped, coordinate-only Maestro 1.x/2.x flows for the **Jeeb customer app**
tuned to a single physical device. This directory is isolated — do **not** point
these flows at any other device; the whole selector strategy is calibrated to this
one screen.

---

## 1. Device profile

| Field | Value |
|---|---|
| ADB serial | `RFCX306JSRT` |
| Model | Samsung **SM-S921B** (Galaxy S24) |
| Screen | 1080 x 2340 px |
| App under test | `app.jeeb.mobile` (prod flavor, installed vName **1.0.0**) |
| Gateway | `http://192.168.2.39:10090` (**live**, not a mock) |
| Role | **customer only** — jeeber onboarding deliberately not entered |
| Drive mode | **coordinate** (see section 2) |
| Maestro | `~/.maestro/bin/maestro` v2.0.5 |

Auth identity used: **+961 71963130**, real OTP read from `jeeb-otpdb."Phones"."OTP"`.

---

## 2. Semantics / coordinate mode (the single most important fact)

This prod build ships with **Flutter accessibility semantics DISABLED**. `maestro
hierarchy` returns an all-empty tree — 1 non-empty text node, **0** nodes with
`clickable=true`. Consequences:

- `id:` selectors **do not resolve** (no resource-ids emitted).
- `text:` selectors **do not resolve** on any in-app screen.
- **Every in-app selector is a coordinate fraction** of 1080 x 2340, expressed as a
  Maestro percentage `point` (e.g. `point: "50%,88%"`). Percentages are
  resolution-independent, so the same fractions hold if the surface re-scales.
- The **only** place `text:` works is **Android system dialogs** (permission
  controller) — those are not Flutter, so `_os-permissions.yaml` uses `text:` there.

Correctness assertion is therefore done by **screenshot + vision** (each page object
calls `takeScreenshot`), never by `assertVisible: id:`. This is the documented
empty-semantics-tree fallback from the `maestro-visual-capture` skill.

> Highest-impact product finding: the disabled semantics tree also breaks screen
> readers (TalkBack) for real users, not just automation. Devs should call
> `SemanticsBinding.instance.ensureSemantics()` and add `Semantics(identifier:)` to
> CTAs so future runs can assert structurally and the app becomes accessible.

---

## 3. Screen index (customer surface)

| # | Screen id | Route | Reached by | Page object |
|---|---|---|---|---|
| 1 | onboarding | `onboarding` | fresh launch | `flows/pages/_onboarding.yaml` |
| 2 | register | `register` | Skip from onboarding | `flows/pages/_register-send-code.yaml` |
| 3 | otp-verify | pushed (prev=register) | Send code => `POST /v1/auth/otp/request 200` | `flows/pages/_otp-verify.yaml` |
| 4 | profile-name | pushed (prev=otp) | Verify => `POST /v1/auth/otp/verify 200` | `flows/pages/_profile-name.yaml` |
| 5 | shell-home (Requests) | `shell` | Skip/Continue from profile-name | `flows/pages/_shell-home.yaml` |
| 6 | request-type | `request-type` | ~~New Order~~ retarget/reorder/dev-seam only since S3 => `GET /tiers 200` | `flows/pages/_request-type.yaml` |
| 7 | client-location | `client-location` | New Order (S3, tier pre-seeded) or request-type Continue => `GET /api/users/me/saved-locations 200` (~1.6s) | `flows/pages/_client-location.yaml` |
| 8 | **waiting-no-coverage** | `waiting-no-coverage` | Confirm => `POST /v1/requests 201` => `GET /v1/offers 200` | `flows/pages/_waiting-no-coverage.yaml` |
| 9 | cancel-delivery-sheet | modal (prev=waiting) | Cancel request | `flows/pages/_cancel-delivery-sheet.yaml` |
| 10 | delivery-order-history | shell (Delivery tab) | Delivery nav tab | `flows/pages/_delivery-history.yaml` |
| 11 | dashboard-become-jeeber | shell (Dashboard tab) | Dashboard nav tab | `flows/pages/_become-jeeber-tab.yaml` |
| 12 | earnings-become-jeeber | shell (Earnings tab) | Earnings nav tab | `flows/pages/_become-jeeber-tab.yaml` |
| 13 | profile | shell (Profile tab) | Profile nav tab | `flows/pages/_profile.yaml` |
| - | OS permission dialogs | system UI | overlays launch / location entry | `flows/pages/_os-permissions.yaml` |

**Deepest solo-reachable customer state = `waiting-no-coverage`** ("Finding Jeebers").
The request is genuinely live (`POST /v1/requests 201`, 5-min offer timer). With
drivers in-area this same screen renders the offers list instead of "Finding Jeebers".

### Selector table (coordinate fractions -> Maestro points)

```
onboarding      Skip 50%,88% | Next/GetStarted 50%,80% | English 66%,9% | Arabic pill 86%,9%
register        Google 50%,42% | phone field 50%,59% | Send code 50%,67%
otp-verify      boxes 50%,28% | Verify 50%,38% | Resend 50%,45% | Change phone 50%,51%
profile-name    name 50%,29% | Continue 50%,38% | Skip for now 50%,45%
shell-home      New Order 50%,83.6% (pinned band, re-measure) | FAB 88%,74% | wallet 78%,8% | bell 91%,8% | help 7%,8%
  bottom nav    Requests 10%,92% | Delivery 31%,92% | Dashboard 52%,92% | Earnings 73%,92% | Profile 91%,92%
request-type    Flash(row) 50%,26% | Express 50%,38% | Standard 50%,51% | ChangeLoc 72%,71% | Continue 50%,87%
client-location desc field 50%,26% | mic 88%,25% | Current Loc 50%,51% | Saved 31%,64% | New 88%,73% | Confirm 50%,87%
waiting         Re-target 50%,67% | Cancel 50%,75%
cancel sheet    Cancel(red) 50%,81% | Keep delivery 50%,88%
delivery hist   Filter 50%,8% | Active 17%,14% | Completed 50%,14% | Cancelled 83%,14%
dashboard/earn  Start now 50%,60% (NOT tapped — role=customer)
profile(top)    Register 81%,43% | Password 39%,51% | Notification 29%,58% | Language 27%,65% | Saved 34%,72%
profile(scroll) Contact us 28%,60% | Rate app 30%,67% | Sign out 25%,75%
```

---

## 4. Fastest path (13 taps, ~55s wall)

Fresh install -> deepest customer state. Auth = phone-OTP with a real code.

1. `pm grant POST_NOTIFICATIONS + ACCESS_FINE_LOCATION` — 0 taps, skips 2 OS dialogs
2. launch -> Skip onboarding `50%,88%` -> register
3. tap phone field `50%,59%` + input `71963130`
4. hide kb -> Send code `50%,67%` => `POST /v1/auth/otp/request 200`
5. read OTP from `jeeb-otpdb` (newest row) -> input the 4-digit code (auto-fills 4 boxes)
6. hide kb -> Verify `50%,38%` => `POST /v1/auth/otp/verify 200` -> profile-name
7. Skip for now `50%,45%` => route shell (home)
8. New Order `50%,83.6%` => client-location directly (S3: recommended tier seeded,
   disclosed by the compose tier row above the fold; grant location
   While-using-app if not pre-granted). The capsule is PINNED to the mic band
   now: its centre is `1-(bottomInset+52)/H`, so re-measure on a device whose
   bottom inset is not ~88dp.
9. input description (required to enable button) -> hide kb -> Confirm location `50%,87%`
   => `POST /v1/requests 201` => route **waiting-no-coverage**

### The OTP timing problem and how these flows solve it

The OTP does **not** exist until Send code is tapped, and it **expires in 5 minutes**
(dev code `1234` never works). A single flow file cannot bake it into `env:`. So the
live path runs in **two Maestro passes that share on-device app state**:

```
helpers/run-fastest-path.sh
  |- pass 1: flows/journeys/auth-send-code.yaml        (launchApp clearState -> Send code)
  |- helpers/otp.sh 71963130                           (reads the just-written code from DB)
  |- pass 2: flows/journeys/fastest-path-continue.yaml (NO launchApp -> resumes on OTP screen)
```

`fastest-path-continue.yaml` deliberately has **no `launchApp`**, so Maestro attaches
to whatever is on screen (the OTP screen pass 1 left), keeping the requested code valid.

`flows/journeys/fastest-path.yaml` is the **readable single-file** end-to-end version;
it requires a currently-valid `OTP` passed in `-e OTP=...` (use it when you already have
an unexpired code, or just for parse review).

---

## 5. Timing notes

- Slow gateway calls surface as visible lag:
  - `GET /api/users/me/saved-locations` ~1.6s (entering client-location + Saved addresses)
  - `GET /v1/notifications/preferences` ~1.6s (Profile -> Notification)
  - vs 30-130 ms for other endpoints.
- Page objects use generous `waitForAnimationToEnd` timeouts (2-6s) to absorb this on a
  real device over Wi-Fi.

---

## 6. UX bugs observed (carry into Jira)

1. **Flutter accessibility semantics disabled in prod** — empty a11y tree blocks all
   text/id Maestro selectors **and** screen readers. Highest-impact finding; forces
   coordinate-only automation. (section 2)
2. **Slow gateway calls as lag** — saved-locations & notifications-preferences both ~1.6s.
3. **Role bleed** — a phone-only CUSTOMER sees jeeber tabs **Dashboard** and **Earnings**
   in the 5-item bottom nav; both dead-end on a "Become a Jeeber" upsell -> 2 of 5 nav
   slots wasted for customers.
4. **Notifications-prefs copy bugs** — "Wallet" category subtitle shows the screen header
   "Manage what you get notified about"; "Rating reminders" subtitle shows "Discounts and
   seasonal promotions" (copied from Offers).
5. **Phone-field editing fragility** — tapping mid-string inserts stray digits, no
   select-all affordance; easy to submit a malformed 9-digit number. Mitigated in
   `_register-send-code.yaml` by `eraseText: 15` before typing (see section 7 for the
   harder adb fallback).
6. **Onboarding language control ambiguous** — plain "English" text beside an Arabic
   pill; unclear which is the active/selectable state.

---

## 7. How to run on THIS device

Prereqs: `RFCX306JSRT` attached (`adb devices`), `psql` on PATH with line-of-sight to
`192.168.2.20:5432`, `JAVA_HOME` set.

```bash
cd .maestro/jeeb/devices/RFCX306JSRT

# One-shot live fastest path (recommended — handles OTP fetch for you):
helpers/grant-permissions.sh RFCX306JSRT      # optional: pre-grant, skip 2 OS dialogs
helpers/run-fastest-path.sh RFCX306JSRT 71963130

# Full customer tour (auth + every tab + create flow). OTP must be valid:
OTP=$(helpers/otp.sh 71963130)                # only valid if a code was just requested
~/.maestro/bin/maestro --device RFCX306JSRT test \
  flows/journeys/full-customer-tour.yaml \
  -e PHONE=71963130 -e OTP=$OTP -e DESC="Maestro automated test delivery"

# Any single page object standalone (drive to that screen first, then):
~/.maestro/bin/maestro --device RFCX306JSRT test flows/pages/_profile.yaml
```

**Phone-field stray-digit adb fallback** (bug 5, if `eraseText` under-clears on a run):

```bash
adb -s RFCX306JSRT shell input keyevent 123           # MOVE_END
for i in $(seq 1 20); do adb -s RFCX306JSRT shell input keyevent 67; done   # 20x DEL
# then re-type: adb -s RFCX306JSRT shell input text 71963130
```

### Validation status of these flows

- All 18 YAML files parse as valid two-document Maestro flows (config header + command
  list). Verified with a YAML multi-doc parser.
- Maestro 2.0.5 has **no** device-less `lint`/`--dry-run` subcommand, so structural
  parse is the strongest offline check available; full execution is left to the Validate
  phase on the attached device (per the run recipes above).
- `helpers/*.sh` pass `bash -n` syntax check; `otp.sh` verified against the live
  `jeeb-otpdb."Phones"` schema (`ID`, `PhoneNumber`, `OTP` — quoted PascalCase columns).

---

## 8. Directory layout

```
.maestro/jeeb/devices/RFCX306JSRT/
  config.yaml                     workspace config + shared-param reference
  FINDINGS-RFCX306JSRT.md         this file
  helpers/
    otp.sh                        read newest real OTP from jeeb-otpdb
    grant-permissions.sh          pm clear + pre-grant notifications/location
    run-fastest-path.sh           2-pass live orchestrator (send-code -> otp.sh -> continue)
  flows/
    pages/                        one page object per screen (coordinate-fraction, parameterized)
      _os-permissions.yaml  _onboarding.yaml  _register-send-code.yaml  _otp-verify.yaml
      _profile-name.yaml    _shell-home.yaml  _request-type.yaml        _client-location.yaml
      _waiting-no-coverage.yaml  _cancel-delivery-sheet.yaml  _delivery-history.yaml
      _become-jeeber-tab.yaml     _profile.yaml
    journeys/
      auth-send-code.yaml         phase-1 (fresh launch -> Send code)
      fastest-path-continue.yaml  phase-2 (no launch -> OTP -> waiting-no-coverage)
      fastest-path.yaml           single-file end-to-end (needs valid OTP in env)
      full-customer-tour.yaml     auth + all 5 tabs + create flow + cancel sheet
```
