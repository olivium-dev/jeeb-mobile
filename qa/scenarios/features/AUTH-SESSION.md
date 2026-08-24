# Authentication and session scenarios

> Suite result: **NOT RUN**
> Current model: phone OTP plus Apple/Google social on register; set-password is
> limited to an authenticated social-only account.

> Owner: Mobile QA
> Last verified: Never
> Source / AC: [current router](../../../lib/core/router/app_router.dart), current
> session/auth code, and the JM flows named per row

Every ID below is an individual record under the
[shared record contract](../RECORD-CONTRACT.md). Preconditions are the
[pre-run checklist](../checklists/PRE-RUN.md) plus the Given clause. Execute the
row with the [per-scenario checklist](../checklists/PER-SCENARIO.md); read back
session/account state, clear disposable auth state, and apply the
[evidence checklist](../checklists/EVIDENCE.md).

| ID | Priority / gate | Persona / mutation | Given / When / Then | Source / automation | Required variants and evidence |
|---|---|---|---|---|---|
| JMS-AUTH-001 | P0 / Smoke | New customer / R2 | Given a clean install and synthetic phone alias, when onboarding and a valid OTP complete, then one authenticated session lands on shell Requests. | jm-009, jm-010 | Walk vs skip onboarding; EN/AR; OTP absent from logs/screenshots; session read-back |
| JMS-AUTH-002 | P0 / Regression | New customer / R1–R2 | Given OTP entry, when empty, malformed, wrong, expired, resent, or locked attempts occur, then exact validation/lockout state appears and unauthorized access never occurs. | jm-009 partial | Countdown boundaries; wrong-code limit; no attempt consumed on transport failure; restart during lockout |
| JMS-AUTH-003 | P0 / Smoke | Returning customer / R0 | Given a valid stored session, when the process cold-starts, then the server-authoritative account reaches the correct shell without onboarding/register flicker. | jm-006 | Expired access token; refresh success; offline start; stale local user; app upgrade |
| JMS-AUTH-004 | P1 / Regression | Enrolled customer / R1 | Given biometric lock is enabled, when authentication succeeds, cancels, is unavailable, or fails, then access is granted only on success and recovery remains usable. | jm-005 | Background lock, OS enrollment change, sensor lockout, cold start, no biometric material in app logs |
| JMS-AUTH-005 | P1 / Regression | Authenticated social-only user / R2 | Given an authenticated account without a password, when valid new/confirm values are submitted, then password is set once and fields are cleared securely. | jm-022, jm-061 | Mismatch, weak password, timeout, duplicate tap, EN/AR, screen capture protection |
| JMS-AUTH-006 | P1 / RC | New/returning social user / R2 | Given Apple or Google is available, when sign-in succeeds or cancels, then returning users enter the shell and new users complete required phone identity without duplicate accounts. | jm-018 | Provider cancel/error; first-time vs returning; missing phone; provider account switch; iOS/Android |
| JMS-AUTH-007 | P0 / Regression | Suspended/locked/deleted user / R0–R3 | Given server account status is restricted, when any protected route is opened, then account-status blocks product data and exposes only allowed recovery/support actions. | jm-066 | Deep link, push tap, warm session, terminal status update, safe support handoff |
| JMS-AUTH-008 | P0 / RC | Authenticated user / R3 | Given an active session, when logout, deletion, terminal 401, or account switch occurs, then tokens, local grants, sensitive caches, and protected back stack are cleared before another account is shown. | jm-062 plus unit tests | Concurrent 401s; background loss; failed deletion; second-account login; Clarity session boundary |

## Suite execution checklist

- [ ] Only current phone/social entry points are tested; retired email login,
      sign-up, recover, and recover-verification routes are not reintroduced.
- [ ] Auth values are injected by alias and never written to Markdown, logs, or screenshots.
- [ ] Every protected-route rejection proves that no protected content flashed first.
- [ ] Session success is read back from the receiving shell/account surface.
- [ ] Logout/deletion/account-switch scenarios use disposable synthetic accounts.
- [ ] Clarity remains gated until authenticated consent and product context exist.
