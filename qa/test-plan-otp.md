# Test Plan — OTP Handover Verification

Maps to: **FR-9.1**, **US-8.1**
Backend: `delivery-service` (OTP issuance + verification) — phone+OTP login uses `auth-service` and is covered separately
Owner: Mobile QA + Security
Status: Draft v1 — JEEB-110

## 1. Scope

The 4-digit, single-use, **handover** OTP that proves the right Jeeber
delivered to the right Client. NOT the SMS login OTP — that lives in
`test-plan-auth.md`.

In scope:
- OTP generation visibility (Client only)
- OTP entry on the Jeeber side
- Success, wrong-code, expiry, and lockout paths
- Side-channel and timing-attack resistance
- OTP regeneration after lockout reset

Out of scope:
- SMS login OTP (T-qa-002)
- Anti-fraud / device-fingerprint signals (post-MVP)

## 2. Architecture under test

```
[Client app]                    [delivery-service]               [Jeeber app]
   ▲                                  │                                │
   │ GET /v1/deliveries/{id}/otp ◄────┤                                │
   │ (returns 4-digit, displays in UI)│                                │
   │                                  │                                │
   │                                  │◄── POST /v1/deliveries/{id}/otp/verify
   │                                  │      body: {"code":"7293"}     │
   │                                  │                                │
   │                                  ├── 200 → status=delivered ─────►│
   │                                  ├── 400 wrong (n attempts left) ►│
   │                                  ├── 410 expired ────────────────►│
   │                                  └── 429 locked (unlock at ts) ───►│
```

Server-side rules (verified via curl smoke pack — see §6):

- OTP generated at offer-acceptance time, valid until `delivered`
  or 24 h, whichever comes first
- Max 5 attempts, then lock for **15 minutes** (configurable)
- All comparisons constant-time
- Verify endpoint is rate-limited at 1 request / second per delivery

## 3. Functional tests — Client side

| # | Step                                                                  | Expected                                                                            |
|---|-----------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| 1 | Open delivery detail after offer accepted                             | OTP card visible: 4 large digits + "Share with your Jeeber at handover"             |
| 2 | OTP card masking: take a screenshot                                   | Android `FLAG_SECURE` blocks screenshot in this view; iOS shows blurred preview      |
| 3 | OTP value persistence                                                 | Value identical across cold-launches until delivery completes                       |
| 4 | OTP after delivery completes                                          | Card replaced with "Delivered ✓" — OTP no longer displayed                          |
| 5 | OTP after delivery cancelled                                          | Card replaced with "Cancelled" — OTP invalidated server-side                        |
| 6 | OTP under accessibility (TalkBack / VoiceOver)                        | Read as four digits one-at-a-time ("seven, two, nine, three"), not "seven thousand…"|
| 7 | OTP under RTL Arabic                                                  | Digits remain LTR (per Unicode bidi); spacing matches LTR layout                    |

## 4. Functional tests — Jeeber side

### 4.1 Successful entry

| # | Step                                       | Expected                                                                          |
|---|--------------------------------------------|-----------------------------------------------------------------------------------|
| 1 | Tap "I'm here — confirm OTP"               | Modal with 4 separate digit boxes; auto-focus first; numeric keyboard             |
| 2 | Type "7293"                                | Each digit advances focus; confirm button enables only with 4 digits              |
| 3 | Tap Confirm                                | Spinner ≤ 2 s; success state; modal closes; status flips to delivered             |
| 4 | Tap Confirm twice (double-tap race)        | Second tap is no-op; only one verify request fires (idempotent on success)        |
| 5 | iOS: paste from clipboard "7293"           | Auto-fills all 4 boxes                                                            |
| 6 | Android: SMS auto-fill plugin              | NOT triggered — handover OTP is not delivered by SMS                              |

### 4.2 Wrong code

| # | Attempts                                    | Expected                                                                          |
|---|---------------------------------------------|-----------------------------------------------------------------------------------|
| 1 | First wrong code                            | Boxes shake; red border; helper text "Wrong code — 4 attempts left"; boxes cleared|
| 2 | Second wrong, third wrong, fourth wrong     | Counter decrements: "3 attempts left", "2 attempts left", "1 attempt left"        |
| 3 | Fifth wrong                                 | Modal shows lockout state (see §4.4)                                              |
| 4 | Wrong code with leading whitespace          | Trimmed before send; counts as one attempt                                        |
| 5 | Wrong code with non-digit (paste "1a23")    | Non-digit chars rejected by input mask; cannot submit; no attempt consumed        |

### 4.3 Expiry

| # | Scenario                                                         | Expected                                                                                                  |
|---|------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| 1 | Server returns 410 (delivery cancelled mid-entry)                | Modal closes; toast "This delivery was cancelled"; navigates back to job list                             |
| 2 | Server returns 410 (24-hour OTP expiry)                          | Modal: "OTP expired. Ask the Client to refresh." with a "Request new OTP" CTA                              |
| 3 | Client tap "Refresh OTP" (in §3 card)                            | New 4-digit code shown; old code rejected on Jeeber side (verify §3 row 1 still works on the new one)     |

### 4.4 Lockout

| # | Scenario                                                                                            | Expected                                                                                              |
|---|-----------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| 1 | 5 wrong attempts in a row                                                                           | Modal switches to lockout state with countdown "Try again in 14:59"; entry boxes disabled             |
| 2 | Counter persists across app kill / relaunch                                                         | Reopening modal still shows live countdown (server-driven via `unlock_at`)                            |
| 3 | Lockout countdown elapses                                                                           | Boxes re-enable automatically; counter resets to 5 attempts                                            |
| 4 | Wrong code response time — correct vs always-wrong                                                  | Difference ≤ 50 ms over 100 trials (server is constant-time; mobile QA verifies UI does not leak)     |
| 5 | Lockout response body does NOT contain attempt history                                              | Mobile only renders generic "Too many wrong attempts. Try again in {n}." — never "Last code was 1234" |
| 6 | Concurrent lockout: two Jeeber devices logged into same account                                     | Both see lockout from any device after 5 combined attempts (server-enforced; UI shows the same banner)|
| 7 | After unlock, first wrong attempt                                                                   | Counter shows "4 attempts left" — not "9 attempts left"                                                |

### 4.5 Network and concurrency

| # | Scenario                                                            | Expected                                                                                  |
|---|---------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| 1 | Tap Confirm with no network                                         | Inline error "No connection — check your data and retry"; attempt NOT consumed             |
| 2 | Verify request times out at 5 s                                     | Spinner replaced with "Slow network — tap to retry"; attempt NOT consumed                  |
| 3 | Server returns 5xx                                                  | Toast "Something went wrong — try again"; attempt NOT consumed                             |
| 4 | Server returns 200 but response is malformed                        | Treated as failure; attempt NOT consumed; logged to Sentry                                 |
| 5 | Verify succeeds but mobile loses connection before reading response | On reconnect, status fetch reveals `delivered`; modal closes silently — no double-charge   |

## 5. Security tests

Per `auth-jwt-pitfalls`, `owasp-api-top-10-2023`, and the OTP-specific
controls listed below. These are PR-blocking.

| # | Attack                                                                       | Expected mobile/server behaviour                                       |
|---|------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| 1 | Brute-force: 10000 random codes via mitmproxy in a script                    | Rate-limit kicks at request 2 (1 req/s); lockout at 5; no codes accepted |
| 2 | Replay attack: capture a successful verify; replay 10 s later                | Rejected — OTP single-use, server marks delivery `delivered`, replays 410|
| 3 | Cross-delivery: try a valid OTP from delivery A on delivery B's verify endpoint| 400 wrong; counts toward delivery B's attempts                         |
| 4 | Tampered JWT (Jeeber A's token used to confirm Jeeber B's delivery)          | 403 Forbidden; logged as security event; mobile shows generic error    |
| 5 | OTP visible in Sentry breadcrumbs / logs                                     | NEVER — verified by inspecting `Sentry.replay()` output and `flutter logs` during a successful flow |
| 6 | OTP in app-switcher snapshot                                                 | iOS: blurred via `applicationWillResignActive`; Android: `FLAG_SECURE` |
| 7 | Deeplink injection: `jeeb://verify?code=1234`                                | Deeplink ignored / requires authenticated session; never auto-submits  |

## 6. Backend smoke (curl) — pre-mobile gate

These run as part of `principal-api-qa` CI before mobile tests are scheduled. Failure here blocks the mobile pipeline.

```bash
# 1) generate
curl -sf -H "Authorization: Bearer $CLIENT_JWT" \
  "$API/v1/deliveries/$DID/otp" | jq -e '.code | test("^[0-9]{4}$")'

# 2) wrong code increments counter
for i in 1 2 3 4 5; do
  curl -sS -H "Authorization: Bearer $JEEBER_JWT" -H "Content-Type: application/json" \
    -d '{"code":"0000"}' "$API/v1/deliveries/$DID/otp/verify" \
    -w 'http=%{http_code} time=%{time_total}\n'
done | tee attempts.log

# 3) sixth attempt is locked
curl -sS -o body.json -w '%{http_code}' \
  -H "Authorization: Bearer $JEEBER_JWT" -H "Content-Type: application/json" \
  -d '{"code":"0000"}' "$API/v1/deliveries/$DID/otp/verify" \
  | grep -q 429
jq -e '.unlock_at' body.json
```

Use `curl-w-format-timing-assertions` to assert `time_total` of correct vs
incorrect responses falls within ± 50 ms (constant-time check).

## 7. Test inventory

### 7.1 Unit (`test/features/otp/`)

- `otp_input_validator_test.dart` — accepts "0000".."9999", rejects everything else
- `lockout_state_test.dart` — countdown reducer + persistence across app kill
- `attempt_counter_test.dart` — server response → mobile state mapping

### 7.2 Widget (`test/features/otp/presentation/`)

- `otp_card_widget_test.dart` (Client side) — masked-screenshot flag set, RTL digits, semantics labels
- `otp_modal_widget_test.dart` (Jeeber side) — every error state renders + transitions
- `lockout_countdown_widget_test.dart` — ticks every 1 s, formats m:ss

### 7.3 Integration (`integration_test/otp/`)

- `flow_success_test.dart` — Patrol-driven happy path with mocked verify endpoint
- `flow_lockout_test.dart` — 5 wrong attempts → lockout → wait → unlock
- `flow_offline_test.dart` — verify never consumes attempts on network failure

### 7.4 E2E (`qa/maestro/otp/`) — added in T-qa-009

- `flow_handover_success.yaml` — two-device Maestro Cloud
- `flow_handover_wrong_code.yaml` — single device drives wrong codes against staging

## 8. Test data

Seeded in `jeeb-infrastructure/seeds/qa-otp.sql`:

| Fixture                  | State                                                                       |
|--------------------------|-----------------------------------------------------------------------------|
| `qa-delivery-otp-fresh`  | Just-accepted offer with a known OTP `7293`                                 |
| `qa-delivery-otp-locked` | 5 wrong attempts already consumed, `unlock_at` 5 minutes in future          |
| `qa-delivery-otp-expired`| Generated > 24 h ago, server returns 410 on verify                          |
| `qa-delivery-otp-done`   | Already delivered (verified) — replay attempt should 410                    |

## 9. Acceptance gate for the OTP feature

A build is allowed to ship to staging only when **all** of the following are true:

- All §3, §4 cases pass on Tier 1 devices.
- All §5 security cases pass; no OTP found in any log surface.
- Backend smoke pack §6 green for ≥ 7 consecutive runs.
- Crash-free sessions for the verify modal ≥ 99.9% over the prior 24 h.

## 10. Risks and assumptions

- **Assumption**: lockout duration is 15 minutes. If product changes
  this to 5 or 30 minutes, only §4.4 row 1's text changes.
- **Assumption**: backend exposes `unlock_at` as an ISO timestamp; if
  it returns `seconds_remaining`, the UI must compute its own
  unlock-at from device clock — flag this as a Sev-3 risk because
  countdown will drift if the user changes their clock.
- **Risk**: iOS app-switcher snapshot blur is only correct if the
  OTP card mounts a `WindowSceneDelegate` blur overlay. The current
  Flutter app uses `flutter_secure_application` — verify this still
  works on iOS 17 (regression seen in plugin v1.0.4).
- **Risk**: Constant-time server comparison is the server team's
  responsibility, but mobile QA must verify no UI side-channel — e.g.,
  spinner spinning longer for a correct-but-late code. Tested in §4.4.4.
