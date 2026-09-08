# PLAN P08 — non-timeout outage scenarios on the real device

Pending point: `P08-non-timeout-outage-scenarios`. Programme: `ux/api-error-handling-empty-states`
(worktree `/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile-worktrees/ux-api-errors`, HEAD `ecfd3cc1`,
draft PR https://github.com/olivium-dev/jeeb-mobile/pull/335). Planning only — no repo file was changed.

## 1. Problem (what is wrong today)

Every device run of this programme simulated "outage" as ONE thing: `dev.base_url_override = http://10.255.255.1:9`,
a TCP blackhole that yields `DioExceptionType.connectionTimeout` → `TimeoutFailure` after 30–60 s
(`device-evidence-2/outage-jeeber/REPORT.md` "Outage injected"; `device-evidence-3/REPORT.md` Scenario A;
`device-evidence/JUDGE-RUN1.md` gaps: "Outage was only simulated as a connect-timeout … No 5xx, 4xx, 401/403/session-expiry,
429, RFC 7807 problem body, or malformed-body scenario was run; the 'rate-limit' probe produced only HTTP 200s").
`FINAL-REPORT.md` §7(f) repeats it as an open follow-up.

So on a real phone the following has NEVER been observed, although it is the core of what the branch built
(`AppFailure` model, `GatewayProblem` parser, `RetryInterceptor`, per-scope `RateLimitInterceptor`, NET-17 "recovering" 401 lane):

| Branch behaviour | Code | Device-proven? |
|---|---|---|
| 5xx → `ServerFailure`, 502/503/504 = `unavailable`, `Retry-After` countdown | `lib/core/network/app_failure_mapper.dart:119-124`, `lib/core/widgets/jeeb/app_failure_copy.dart:31-39` | no |
| bounded replay of 502/503/504 GETs (3 wire attempts, 300 ms·2ⁿ + jitter) | `lib/core/network/retry_interceptor.dart:57-101` | no |
| 429 → `RateLimitedFailure` + per-path-prefix local suppression window, countdown copy | `rate_limit_interceptor.dart:88-140`, `app_failure_copy.dart:89-95` | no |
| 401 → refresh → replay → logout → `/register` + `registration_session_expired_note` | `auth_interceptor.dart:121-194`, `app_router.dart:483-485`, `registration_screen.dart:393-408` | no |
| 401 while refresh is transiently failing → `UnauthorizedFailure(recovering:true)` → "Renewing your session" + Retry, session kept | `auth_interceptor.dart:169-175, 228-236`, `app_failure_copy.dart:40-47` | no |
| 403/404/410 → non-retryable, exit CTA never inert Retry | `app_failure_copy.dart:54-81`, `jeeb_failure_block.dart:112-129` | no |
| 400/413/415/422 → `ValidationFailure` (+ `errors{}`) | `app_failure_mapper.dart:108-113` | no |
| RFC 7807 body parsed: `type` suffix, `traceId`, `retryAfter`, `reasonCode`… | `gateway_problem.dart:19-55` | no (unit only) |
| malformed / wrong-shape / HTML 200 body → `UnknownFailure(parse:true)`, never a stuck spinner or a placeholder profile | `app_failure_mapper.dart:69-76`, `app_failure.dart:26-30` | no |

## 2. Root cause (why it was never run)

There is no fault-injection seam anywhere in the delivery chain:

- **Gateway `origin/main` (`6679f6e`, fetched 2026-09-05):** `git ls-tree -r origin/main --name-only | grep -iE 'fault|chaos'` → nothing;
  the middleware set is `CorrelationIdMiddleware`, `RequestLatencyMiddleware`, `RequestValidationMiddleware`,
  `SecurityHeadersMiddleware`, `DevOnlyEndpointGuardMiddleware`, `UseRateLimiter` (`src/JeebGateway/Program.cs:3100-3245`).
  `Features:DevEndpoints` only un-404s `/dev/*` seeding routes. A gateway fault toggle would be a gateway code change **plus an
  owner-gated Actions deploy** — not executable inside this programme.
- **Mobile branch:** `grep -rliE 'fault ?inject|chaos' lib test` → only a colour-role file. The Dev Tool has a Server URL override
  (`lib/core/config/dev_base_url.dart:8`, `lib/devtool/dev_settings_page.dart:20,99-118`, "Apply & Restart" in
  `lib/devtool/shake/devtool_shake.dart:401`) and nothing else that can shape a response.
- **The Mac is off the MSI LAN**, so the previous runs had only two reachable hosts: the real gateway through Cloudflare
  (`https://msi.olivium.space/gateway`) and an unroutable blackhole. Nothing in between could return a 4xx/5xx.

## 3. Verified facts the plan relies on (evidence)

1. **Live problem shapes (curl 2026-09-05 against `https://msi.olivium.space/gateway`):**
   - `GET /v1/users/me` (no token) → `401 application/problem+json`
     `{"type":"https://tools.ietf.org/html/rfc9110#section-15.5.2","title":"Unauthorized","status":401,"traceId":"00-…-01"}`
   - `POST /v1/auth/otp/request` body `{"phone":` → `400 application/problem+json`
     `{"type":"https://tools.ietf.org/html/rfc9110#section-15.5.1","title":"One or more validation errors occurred.","status":400,"errors":{"$.phone":["Expected depth to be zero …"]},"traceId":"…"}`
   - `POST /v1/auth/otp/request` body `{}` → `400` domain problem
     `{"type":"https://problems.jeeb.lb/auth/invalid_phone","title":"Invalid phone number","status":400,"detail":"phone is required.","instance":"/v1/auth/otp/request"}`
   - `Content-Type: text/plain` → `415 application/problem+json` `{"type":"https://httpstatuses.com/415","title":"Unsupported Media Type","status":415,"detail":"The request content type is not supported."}`
   - 429 is hand-written in `src/JeebGateway/Security/RateLimitingExtensions.cs` (OnRejected): header `Retry-After: <int seconds>` +
     body `{"type":"https://httpstatuses.com/429","title":"Too Many Requests","status":429,"detail":"Rate limit exceeded. Retry after the duration in the Retry-After header."}`.
     Limits (`Security/SecurityOptions.cs:81-118`): user 100/min, IP 1000/min, sensitive 30/60 s per IP, auth bucket 20.
   - Unauthenticated unknown routes answer 401 (auth runs before routing), so a real 404 needs a token; every anonymous
     `/health/*` path answers 200 — root-path false positives as memory warns.
2. **Phone can reach a Mac-local server:** `adb -s RZCT505K7WF reverse tcp:18089 tcp:18089` + `python3 -m http.server 18089 --bind 127.0.0.1`;
   `adb shell "printf 'GET / HTTP/1.0\r\n\r\n' | /system/bin/nc 127.0.0.1 18089"` → server log `127.0.0.1 - - [05/Sep/2026 18:45:37] "GET / HTTP/1.0" 200 -`
   (`scratchpad/p08probe/srv.log`). Reverse removed afterwards (`adb reverse --list` empty). The phone has `nc`, no `curl`/`wget`.
3. **Cleartext `http://127.0.0.1` is allowed by the dev flavour:** `android/app/src/dev/res/xml/network_security_config.xml:6-11`
   whitelists `localhost`, `127.0.0.1`, `10.0.2.2`, `192.168.2.39`; and the blackhole runs already proved `dev.base_url_override`
   accepts an `http://` URL (Dart's `HttpClient` does not consult NSC anyway).
4. **Base URL carries the `/gateway` prefix** (`https://msi.olivium.space/gateway`), so the override for this plan is
   `http://127.0.0.1:8089/gateway` and the proxy upstream is `https://msi.olivium.space` with the path forwarded verbatim.
5. **Tooling on the Mac:** `python3` 3.14.7 (`/opt/homebrew/bin/python3`), `mitmdump` 12.2.3, `adb`, `jq`. Device
   `RZCT505K7WF` attached over USB; **`getprop ro.build.version.release` = 16 (SDK 36)** — the OS moved since the run-2/3
   reports (Android 14). Re-verify `install -r` and uiautomator dumps still behave before spending time on scenarios.
6. **Screens ↔ endpoints (live paths):**
   Profile `GET /v1/users/me` (`lib/features/customer_profile/data/dio_customer_profile_repository.dart:16`);
   Deliveries client `GET /v1/requests…` / jeeber `GET /v1/deliveries…` (`order_history/data/dio_order_repository.dart:17-18`);
   Earnings `GET /v1/jeeb/earnings` (`earnings/data/dio_earnings_repository.dart:13`);
   Jeeber home availability `GET /jeebers/me/availability` — **unversioned live path**, and **404 there means "not registered" by design**
   (`jeeber_home/data/dio_availability_gateway.dart:41,48-52`), so never inject 404 on it;
   Feed `GET /v1/jeebers/me/feed?status=pending` (`jeeber_request_feed/data/dio_request_feed_repository.dart:35`);
   Notifications `GET /v1/notifications` (`notifications/data/dio_notifications_repository.dart:23`);
   Refresh `POST /v1/auth/refresh` (`auth_interceptor.dart:45`).
7. **Replay behaviour that changes proxy hit counts:** `UnversionedPathFallbackInterceptor` replays a 404/405 on `/v1/x` as `/x`
   (`unversioned_path_fallback_interceptor.dart:23,41`), so 404 rules must match both spellings; `RetryInterceptor` replays
   502/503/504 GETs up to 2 more times (`retry_interceptor.dart:29,65`) but never 500; a 429 opens a local window keyed on the first
   path segment after `/v1` (`rate_limit_interceptor.dart:44-60`), so `/users/me` and `/deliveries` are independent scopes (NET-04).
8. **Session-loss route:** `_logout()` clears the store and signals `AuthLossSignals` (`auth_interceptor.dart:281-294`);
   the router sends an onboarded-but-unauthenticated user to `/register` (`app_router.dart:483-485`); the note id is
   `registration_session_expired_note` (`registration_screen.dart:401`).
9. **Debug builds print every wire result:** `[http←] <status> <METHOD> <path>` / `[http✗] <status> …`
   (`lib/core/network/redacting_log_interceptor.dart:35-55`, `kDebugMode` only, `mock_gateway_client.dart:206-208`) →
   `adb logcat -s flutter` is the app-side ledger for every assertion below.
10. **Exit-CTA wiring that the assertions depend on:** Profile → `customer_profile_error_signin_cta` for unauthorized, else
    derived `customer_profile_load_exit_cta` "Go back" → shell (`customer_profile_status_block.dart:66-84`); jeeber tabs →
    Forbidden = "Start KYC" → `offer-kyc-gate`, NotFound/Gone = pop, others none
    (`jeeber_request_feed/presentation/jeeber_failure_exit.dart:21-37`); Order history has **no** `onExit`
    (`order_history_screen.dart:400-404`) — a non-retryable kind there renders a CTA-less block, which is a finding to record, not to fix here.

## 4. Decision — mechanism

**Chosen: a Mac-local fault-injecting reverse proxy, reached from the phone through `adb reverse`, selected in the app via the existing Dev Tool Server URL override.**

| Option | Verdict | Why |
|---|---|---|
| Local proxy on the Mac + `adb reverse` (chosen) | **do it** | zero product-code change, zero deploy, works off-LAN (proven §3.2), deterministic per-route/per-count faults, the proxy log is an independent wire ledger (retry counts, replay paths), same phone/account/UI as runs 1-3 |
| In-app Dev Tool fault injector (a `FaultInjectionInterceptor` behind `kDevAffordancesAllowed`) | not now | touches `lib/core/network/mock_gateway_client.dart` interceptor order, near the PR #330 refresh chain; cannot fake transport-level shapes (HTML from Cloudflare, chunked garbage); needs its own tests/previews/ratchets. Revisit only if the owner wants faults without a laptop (§10) |
| Gateway fault toggle on MSI | no | gateway code change + owner-gated Actions deploy; affects every tester on the shared dev gateway; cannot be scoped to one phone |
| `jeeb-ephemeral-deploy` / `olivium-ephemeral-manager` | no | they lease whole environments (owner-gated dispatch); still no way to return a 503 to one phone. `jeeb-device-e2e` is "PREPARED / NOT EXECUTED", lease-gated — reuse its evidence-journal ideas, not its machinery |
| Natural 429 by hammering the real gateway | no (optional owner-gated variant) | `ResolveClientIp` partitions per trusted IP; through the Cloudflare tunnel every tester may share one IP, so a 31-request burst on a `sensitive_fixed` route throttles everybody for 60 s |

The proxy is **pure Python stdlib** (`http.server.ThreadingHTTPServer` + `http.client.HTTPSConnection`), not a mitmproxy addon, so
`tool/test_fault_proxy.sh` runs on any machine with python3 (CI runners included) and the implementer has nothing to install.
`mitmdump --mode reverse:https://msi.olivium.space` is a one-line fallback if the stdlib proxy ever misbehaves on a body shape.

## 5. Deliverables (all in `olivium-dev/jeeb-mobile`, new branch `ux/p08-fault-proxy` from `ecfd3cc1`; never a new repo)

| # | Path | What |
|---|---|---|
| D1 | `tool/fault_proxy/fault_proxy.py` | the proxy (§6) |
| D2 | `tool/fault_proxy/scenarios/S00-passthrough.json … S14-…json` | one rules file per scenario, bodies copied verbatim from §3.1 (§7) |
| D3 | `tool/fault_proxy/test_fault_proxy.py` + `tool/test_fault_proxy.sh` | device-free unit tests (stub upstream) — same shape as the existing `tool/test_*.sh` |
| D4 | `test/core/network/fault_proxy_scenarios_test.dart` | contract test: for every scenario JSON, build the `DioException` the proxy would produce and assert `mapDioException` → the `expect{}` block in that file (kind, unavailable, retryAfterSeconds, copy title/body keys). Keeps unit truth and device truth byte-identical |
| D5 | `tool/fault_proxy/device/dump.sh`, `tool/fault_proxy/device/run_preflight.sh`, `tool/fault_proxy/device/run_teardown.sh` | the adb helpers from runs 1-3 (`scratchpad/dump.sh`, `ui.sh`) generalised: dump ui.xml+png, print `(cx,cy) id|desc|text`, logcat slice, proxy-log slice |
| D6 | `tool/fault_proxy/README.md` | the runbook = §8 of this plan, verbatim, so an implementer needs no other document |
| D7 | evidence (NOT in repo): `scratchpad/device-evidence-4/<Sxx>/` + `scratchpad/device-evidence-4/REPORT.md` in the run-2/run-3 table format |

No file under `lib/` changes. PR #330 invariants untouched (the proxy only observes them from the wire).

## 6. D1 — `tool/fault_proxy/fault_proxy.py` specification

```
usage: python3 tool/fault_proxy/fault_proxy.py --listen 127.0.0.1:8089 --upstream https://msi.olivium.space \
         --rules /path/rules.json --log /path/proxy.log
```
- `ThreadingHTTPServer`, `protocol_version = "HTTP/1.1"`, one handler for every method (`do_GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS` → `_handle`).
- Control plane, never forwarded upstream: `GET /__fault/rules` (current rules JSON), `PUT /__fault/rules` (replace; body = rules JSON),
  `DELETE /__fault/rules` (clear), `GET /__fault/log?n=200` (last n events), `GET /__fault/health` → `{"ok":true,"upstream":…}`.
  The rules file is also re-read whenever its mtime changes, so `cp scenarios/S03.json rules.json` is enough.
- Rules file shape:
  ```json
  { "scenario": "S03", "rules": [
      { "id": "profile-503", "match": { "method": "GET", "path": "^/gateway/(v1/)?users/me(\\?.*)?$" },
        "times": 0,
        "respond": { "status": 503, "headers": { "Content-Type": "text/html", "Retry-After": "20" }, "body_file": "bodies/cloudflare-503.html" } } ],
    "expect": { "kind": "server", "unavailable": true, "retryAfterSeconds": 20,
                "copyTitle": "errorServerTitle", "copyBody": "errorRateLimitedRetryIn", "retryable": true } }
  ```
  `times`: 0 = every match; N = first N matches then pass-through (counter per rule, reset on rules reload).
  `respond.body` (inline string) or `respond.body_file` (relative to the rules file); `respond.delay_ms` optional; `respond.drop: true` closes the socket (RST) — not used by any scenario below but cheap.
  `match.path` is a regex over the raw request target (path + query); `match.method` optional; `match.header` optional `{ "name": "...", "regex": "..." }`.
- Pass-through: copy method, path+query, headers minus hop-by-hop (`Host`, `Connection`, `Keep-Alive`, `Transfer-Encoding`, `Proxy-*`),
  set `Host: msi.olivium.space`, forward the body by `Content-Length`; relay status, headers (drop `Transfer-Encoding`, `Connection`; set exact `Content-Length`), raw bytes (no gzip handling — bytes and `Content-Encoding` pass untouched). Upstream timeout 60 s → on failure answer `502` with `application/problem+json` `{"type":"about:blank","title":"fault-proxy upstream failure","status":502}` and log `[upstream-error]`.
- Log line per request, stdout + `--log` file:
  `2026-09-05T15:04:05.123Z  PASS  200  GET  /gateway/v1/users/me  12ms` or `…  FAULT(profile-503 #2)  503  GET  /gateway/v1/users/me`.
- Adds `X-Fault-Proxy: <rule id>` to injected responses so a logcat/ui investigation can tell injected from real (the app ignores it).

## 7. D2 — scenario catalogue (bodies verbatim from §3.1; `<TRACE>` = `00-` + 32 hex + `-` + 16 hex + `-01`)

Target screen is Profile (`GET /v1/users/me`) unless stated — it has loading/error/retry/exit/refresh surfaces all under one id family
(`customer_profile_*`), its baseline is known ("Karim TestJeeber / 2 Reviews"), and the F4 placeholder regression is the thing a
parse failure would most plausibly bring back. Deliveries (`/v1/deliveries`) is the second surface for rate-limit scoping and the
refresh-note path.

| Sxx | Injected (rule) | Failure kind expected | EN copy expected (AR in `app_ar.arb` same keys) | CTA | Proxy hits expected |
|---|---|---|---|---|---|
| S00 | no rules | — | real profile | — | PASS lines only; proves the proxy is transparent |
| S01 | `500` `application/problem+json` `{"type":"https://tools.ietf.org/html/rfc9110#section-15.6.1","title":"An error occurred while processing your request.","status":500,"traceId":"<TRACE>"}` | `ServerFailure(status:500, unavailable:false)` | "Something went wrong" / "We couldn't complete that. Try again in a moment." | `customer_profile_retry_cta` | **1** per load (500 is not transient) |
| S02 | `503` `application/problem+json` `{"type":"https://httpstatuses.com/503","title":"Service Unavailable","status":503}` no Retry-After | `ServerFailure(unavailable:true, retryAfter:null)` | "Something went wrong" / "Jeeb is briefly unavailable. Try again in a moment." | Retry | **3** per load (RetryInterceptor: 2 replays) |
| S03 | `503` `text/html` Cloudflare-style page `<html><body><h1>Error 1016</h1></body></html>` + `Retry-After: 20` | `ServerFailure(unavailable:true, retryAfter:20s)`, `problem == null` | "Something went wrong" / "Try again in 20 seconds." | Retry | 3 |
| S04 | `502` `text/html` no Retry-After | `ServerFailure(unavailable:true)` | as S02 | Retry | 3 |
| S05 | `429` + `Retry-After: 30` + gateway body (§3.1) | `RateLimitedFailure(retryAfter:30s)` | "Too many attempts" / "Try again in 30 seconds." (count drops on later renders) | Retry | 1, then **0** while Retry is tapped inside the 30 s window (local suppression); Deliveries tab still loads (`/deliveries` scope untouched) |
| S06 | `401` live body (§3.1) on `/v1/users/me` only; refresh passes through | terminal `UnauthorizedFailure` → logout | `/register` with `registration_session_expired_note` "Sign in again to continue." | none (login screen) | `[http✗] 401` ×1–2, optional `POST /v1/auth/refresh` PASS in between; run LAST (kills the session) |
| S07 | `401` on `/v1/users/me` **and** `503` on `POST /gateway/v1/auth/refresh` | `UnauthorizedFailure(recovering:true)` (NET-17), tokens kept | "Something went wrong" / "Renewing your session. Try again in a moment." | Retry | refresh hit 1 (503 is on POST without Idempotency-Key → not replayed); no `/register` |
| S08 | `403` domain body `{"type":"https://problems.jeeb.lb/auth/forbidden","title":"Forbidden","status":403,"detail":"Role mismatch.","reasonCode":"role_mismatch","accountStatus":"active","instance":"/v1/users/me"}` | `ForbiddenFailure(reasonCode:'role_mismatch')` | "You don't have access" / "This isn't available on your account." | exit `customer_profile_load_exit_cta` "Go back" → shell; no Retry node | 1 |
| S09 | `404` `{"type":"https://tools.ietf.org/html/rfc9110#section-15.5.5","title":"Not Found","status":404,"traceId":"<TRACE>"}` rule matches `^/gateway/(v1/)?users/me` | `NotFoundFailure` | "Not found" / "This is no longer available." | exit "Go back" | 1 or 2 (record; 2 = unversioned replay observed) |
| S10 | `410` `{"type":"https://problems.jeeb.lb/requests/request-expired","title":"Gone","status":410}` | `GoneFailure` | "Not found" / "This expired before we could open it." | exit "Go back" | 1 |
| S11 | `409` `{"type":"https://problems.jeeb.lb/requests/offer-already-exists","title":"Conflict","status":409,"detail":"…"}` | `ConflictFailure(typeSuffix:'offer-already-exists')` | "Something went wrong" / "Something changed while you were working. Refresh and try again." | Retry | 1 |
| S12 | `400` ASP.NET `errors{}` body (§3.1, `$.phone`) on the GET | `ValidationFailure(fieldErrors:{'$.phone':[…]})` | "Something went wrong" / "Check the details and try again." | Retry | 1 |
| S13 | `200 application/json` body `{"id":"106078a3","displayName":"Karim TestJeeber",` (truncated) | Dio `FormatException` → `UnknownFailure(parse:true)` | "Something went wrong" / "We couldn't complete that. Try again." | Retry; **no** `customer_profile_name`="Add your name", no "?" avatar, no spinner past t≈8 s | 1 |
| S14 | `200 text/html` `<html>captive portal</html>` and variant `200 application/json` `[]` | repository `TypeError` → `AppFailure.of` → `UnknownFailure` | as S13 | as S13 | 1 |
| S15 (warm) | S01 rule applied **after** Profile loaded; trigger refresh (leave/re-enter tab or pull) | `refreshError` | stale "Karim TestJeeber / 2 Reviews" stays; `customer_profile_refresh_failed_*` note (record exact id from dump) with Retry + Dismiss; NO `customer_profile_loading`, NO error block | note CTAs | 1 |
| S16 (Deliveries, warm) | `503` on `^/gateway/(v1/)?deliveries` after the list loaded; pull-to-refresh | refresh failure | 5 `order_history_card_*` stay; `order_history_refresh_failed_snack` "Jeeb is briefly unavailable…" + Retry; auto-dismiss ≤10 s | — | 3 per pull |
| S17 (AR) | DROPPED — Reconciled (C17): Arabic on-device is P07's authority (`device-evidence-4/p07-ar/`), which reuses these scenario files with path-scoped rules. Keep the `S17-ar.json` file out of D2. | — | — | — | — |

Each scenario JSON carries the `expect{}` block that D4 asserts, plus a `device{}` block listing the target screen, the ids to
assert, and the expected proxy hit count — the runbook (§8) is generated from those blocks, so the truth lives in one place.

## 8. D6 — device runbook (an implementer with no context executes this verbatim)

Device `RZCT505K7WF` (SM-A336B), app id `app.jeeb.mobile.dev`, product activity `com.olivium.jeeb.MainActivity`,
Dev Tool `app.jeeb.mobile.dev/com.olivium.jeeb.LegacyDevToolLauncher`. **Never uninstall, never "Clear Local Data"; `adb install -r` only.**

**Build** (worktree `ux-api-errors`, HEAD of `ux/p08-fault-proxy`): copy the two gitignored files exactly as `device-evidence-3/REPORT.md`
"Build note" says (`android/app/google-services.json`, `android/app/src/dev/google-services.json` — project `jeeb-5a293`, never alrahmah —
and `MAPS_API_KEY` in `android/local.properties`), then `flutter build apk --debug --flavor dev` → `adb -s RZCT505K7WF install -r build/app/outputs/flutter-apk/app-dev-debug.apk`.
Record the APK sha256 and `git rev-parse HEAD` in `REPORT.md`.

**Preflight (`run_preflight.sh`):**
1. `curl -sS -m 20 https://msi.olivium.space/gateway/health/ready` → 200 (real gateway alive).
2. `python3 tool/fault_proxy/fault_proxy.py --listen 127.0.0.1:8089 --upstream https://msi.olivium.space --rules $EV/rules.json --log $EV/proxy.log &`
   with `rules.json` = `scenarios/S00-passthrough.json`. `curl -s http://127.0.0.1:8089/__fault/health` → `{"ok":true}`.
3. `adb -s RZCT505K7WF reverse tcp:8089 tcp:8089`; `adb -s RZCT505K7WF reverse --list` shows the mapping (re-run after any USB re-plug).
4. On the phone: Dev Tool → Server URL → type `http://127.0.0.1:8089/gateway` (the two preset chips are `.invalid` placeholders) → Save → **Apply & Restart**.
   Dump `00-devtool-override.xml` showing "Server URL override active — http://127.0.0.1:8089/gateway".
5. Session: Dev Tool → Super Login → Super Login Plus → search "Karim" → `Karim TestJeeber / driver` (dual-role, 5 active deliveries).
   Launch the product app; dump `01-baseline-home.xml` ("Ahlan, Karim"), `02-baseline-deliveries.xml` (5 `order_history_card_*`),
   `03-baseline-profile.xml` (`customer_profile_name` = "Karim TestJeeber", `customer_profile_rating` = "2 Reviews").
   `proxy.log` must show only `PASS 200` lines → S00 PASS. If S00 fails, stop: the proxy is not transparent.
6. `adb logcat -c` then keep `adb -s RZCT505K7WF logcat -s flutter > $EV/logcat.txt &` running for the whole session.

**Per scenario Sxx (cold path, S01–S14):**
1. `cp tool/fault_proxy/scenarios/Sxx.json $EV/rules.json`; `curl -s http://127.0.0.1:8089/__fault/rules | jq .scenario` prints `Sxx`. Note the proxy-log line count `L0`.
2. `adb shell am force-stop app.jeeb.mobile.dev`; `adb shell am start -n app.jeeb.mobile.dev/com.olivium.jeeb.MainActivity`; tap the Profile tab by id from a fresh dump.
3. Dump at t≈2 s (`Sxx-10-t2`), t≈6 s (`Sxx-11-t6`), t≈12 s (`Sxx-12-settled`) — PNG + XML each (`dump.sh`).
4. Assert (all by `resource-id`, EN text via `content-desc`):
   - t≈2 s: `customer_profile_loading` present, OR the error block already present (fast failures land <1 s). **Never** `customer_profile_name`="Add your name", `customer_profile_rating`="No reviews yet", avatar "?" (F4 regression guard, every scenario).
   - settled: the block id `customer_profile_load_error` + `customer_profile_load_error_headline` == expected title + `customer_profile_load_error_body` == expected body (table §7).
   - retryable kinds: `customer_profile_retry_cta` present and **no** `*_exit_cta`; non-retryable kinds (S08/S09/S10): exit CTA present with label "Go back" (S06: none — see below) and **no** retry node.
   - proxy: `grep -c 'FAULT(' proxy.log` minus L0 == expected hits; logcat: matching `[http✗] <status> GET /v1/users/me` lines, and for S02–S04 exactly three of them per load.
   - copy hygiene: `grep -iE 'exception|dio|socket|status ?code|http://|127\.0\.0\.1|traceId' Sxx-*.xml` → no match.
5. Retry path: tap `customer_profile_retry_cta` (rules still active) → dump t≈2 s → `customer_profile_loading` (or immediate error), no placeholders; settled → same error. For S05 the proxy-log count must NOT grow (local window) and the body counts down ("Try again in 2x seconds").
6. Exit path (S08/S09/S10): tap the exit CTA → dump → `client_home_root`/`jeeber_home_root` (shell). Re-enter Profile for the next scenario.
7. Recovery: `cp scenarios/S00-passthrough.json $EV/rules.json` → tap Retry (or re-enter the tab) → dump `Sxx-20-recovered` → real identity back (`customer_profile_name` = "Karim TestJeeber", `customer_profile_rating` = "2 Reviews", avatar "K").
8. Copy the proxy-log and logcat slices for the scenario into `$EV/Sxx/proxy.log`, `$EV/Sxx/logcat.txt`.

**S05 extra:** while the 30 s window is open, open Deliveries → 5 cards load (`PASS 200 GET /gateway/v1/deliveries…` in proxy.log) — proves per-scope suppression. After 30 s, Retry on Profile → pass-through → recovered.

**S06 (LAST):** apply the rule; open Profile. Expected within ~5 s: route `/register` with `registration_session_expired_note`
("Sign in again to continue."), no `customer_profile_*` nodes. Proxy log: `FAULT 401 GET /gateway/v1/users/me`, optionally
`PASS 200 POST /gateway/v1/auth/refresh` then a second `FAULT 401` (refresh-token present) — record which branch ran. Then clear
rules, Dev Tool → Super Login Plus → Karim again (allowed: this is not a login-feature test), and confirm `01-baseline-home` again.

**S07:** apply; open Profile → block "Something went wrong / Renewing your session. Try again in a moment." + Retry; **no** `/register`;
proxy shows `FAULT 401 …users/me` then `FAULT 503 POST …/auth/refresh` (×1). Tap Retry inside 20 s → same copy, no new refresh hit
(cooldown). Clear rules, wait 20 s, Retry → recovered, still Karim (session survived — assert `customer_profile_name`).

**S15/S16 (warm):** load the screen with no rules, then apply the rule, then trigger refresh (re-enter tab / pull-to-refresh). Assert the
stale content stays (5 cards / real name), the refresh note/snack id and copy, `*_retry_cta` and `*_dismiss_cta`, and that the snack
self-dismisses ≤10 s (poll dumps at 2/6/11 s, as in `device-evidence-2/offline-a11y/REPORT.md` assertion 7).

**S17 (AR):** Settings → tap `settings_language_ar_option` → re-run S01, S05, S08 cold. Assert the AR strings listed in §7 and that
RTL layout shows the exit/retry button (bounds inside the screen). Switch back to EN (`settings_language_en_option`) afterwards.

**Teardown (`run_teardown.sh`):** rules → S00; Dev Tool → Server URL → `https://msi.olivium.space/gateway` → Save → Apply & Restart;
dump `99-serverurl-restored.xml`; `adb reverse --remove-all`; kill the proxy; confirm Deliveries/Profile on real data
(`99-recovered-profile.xml`); leave Karim logged in and Offline (as runs 2/3 left him). Note in REPORT.md whether the
"F8-resolve-probe-parcel" request (`defb1f07-…`, auto-expires 2026-09-06 11:21 UTC) is still pending.

**REPORT.md** (`$EV/REPORT.md`): header (build SHA, APK sha256, device + Android version, gateway 200 check, proxy version line), the
§7 table with an "Observed" and "Verdict" column per row, the proxy-hit table, the copy-hygiene grep result, the residual-state section.
Any row that is not PASS is a defect for a follow-up fix commit on `ux/api-error-handling-empty-states`, exactly like F1–F9.

## 9. Ordered fix steps (implementer checklist)

1. `git -C jeeb-mobile-worktrees/ux-api-errors checkout -b ux/p08-fault-proxy ecfd3cc1` (jeeb-mobile). Never a new repo.
2. Write `tool/fault_proxy/fault_proxy.py` per §6 (jeeb-mobile). Keep comments ≤2 lines each.
3. Write the 18 scenario files under `tool/fault_proxy/scenarios/` + `tool/fault_proxy/bodies/` per §7 (jeeb-mobile). Bodies are byte-copies of §3.1.
4. Write `tool/fault_proxy/test_fault_proxy.py` (stdlib `unittest`; starts a stub upstream on an ephemeral port and the proxy in a thread): pass-through of headers/body/status; rule match + `times` countdown; `body_file` + `Retry-After` emitted; regex matches `/v1/users/me` and `/users/me`; control endpoints; upstream failure → 502 problem; hop-by-hop headers stripped. Add `tool/test_fault_proxy.sh` that runs it (jeeb-mobile).
5. Write `test/core/network/fault_proxy_scenarios_test.dart` (jeeb-mobile): iterate `Directory('tool/fault_proxy/scenarios')`, build `DioException(type: badResponse, response: Response(statusCode, headers, data: decoded-or-raw))` per file (for S13 build `DioExceptionType.unknown` with a `FormatException`; for S14 call `AppFailure.of(TypeError)`), assert `mapDioException(...)` kind / `unavailable` / `retryAfter` / `failureCopy(...)` title+body against `expect{}` using `AppLocalizations` EN and AR. `git add` every new file BEFORE `flutter test` (mb1 residual-receipts test).
6. Write `tool/fault_proxy/device/{dump.sh,run_preflight.sh,run_teardown.sh}` and `tool/fault_proxy/README.md` (= §8) (jeeb-mobile).
7. Gates on the worktree: `dart analyze --fatal-infos .`, `flutter test --exclude-tags capture` (baseline 10539 pass / 0 fail / 109 skip, coverage ≥79%; expect +1 test file), `tool/l10n_parity_check.sh --analyze`, `tool/ar_plurals_check.sh`, `tool/check_design_tokens.sh`, `bash tool/test_fault_proxy.sh`. `dart run tool/preview_coverage.dart` is unaffected (no widgets added).
8. Execute §8 on the phone; write `device-evidence-4/REPORT.md`. Fix any FAIL as a separate commit on `ux/api-error-handling-empty-states` with its own re-run (runs 1-3 pattern).
9. Push `ux/p08-fault-proxy`. Reconciled (C1): #335 is scope-frozen — after its squash merge run `git rebase --onto origin/main ux/api-error-handling-empty-states ux/p08-fault-proxy` and open the PR against `main` with the REPORT summary. Build D1–D6 in wave 0: P06 §5.3, P07 C-rows and P09 §1 all consume this proxy (C2).

## 10. Risks

- **Android 16 drift:** the phone now reports Android 16 / SDK 36; run-2/3 reports say 14. If `uiautomator dump` or `install -r` misbehave, that is an environment finding, not a scenario finding — record and stop.
- **Refresh-token presence for super-login sessions is unknown**: S06 may skip the refresh POST and log out directly (`auth_interceptor.dart:162-166`). Both branches end at `/register` + note; record which.
- **`adb reverse` dies on USB re-plug / adb restart** → the app sees a connection refusal (`NetworkFailure(offline:false, reason: refused)`). Reconciled (C3): on a build with P13 that renders "Can't reach Jeeb" (`errorUnreachableBody`); on `ecfd3cc1` it renders "No connection". Either copy appearing in a 4xx/5xx scenario means the tunnel died — check `adb reverse --list` first; never count it as a scenario result.
- **`proactiveWindow` refresh** (`auth_interceptor.dart:100-118`) may fire a real `POST /v1/auth/refresh` before a scenario request when the JWT is near expiry — harmless, but it explains stray PASS lines.
- **Unversioned replay** doubles the 404 hit; per-scope 429 windows persist in-process for up to 120 s (`rate_limit_interceptor.dart:13`) — always run S05 before any scenario that reads `/users/me` again, or force-stop the app in between (the window is in memory only).
- **S13/S14 depend on Dio's JSON transformer** raising `FormatException` for truncated JSON and on the repository casting a `String`/`List` — if the repository swallows the cast, the screen would show a stuck spinner; that is exactly the defect class this scenario exists to catch (audit §1 item 3).
- **Order history has no exit CTA** for non-retryable kinds (`order_history_screen.dart:400-404`); a 403/404 there would render an inert block. Not injected in this plan; listed for WP-3 follow-up.
- **Cleartext**: only the dev flavour whitelists 127.0.0.1; the release/internal flavours would refuse `http://` — this plan targets `app-dev-debug.apk` only.

## 11. Dependencies

- Real gateway `https://msi.olivium.space/gateway` reachable (it is, `/health/ready` 200 on 2026-09-05) — the proxy is a pass-through for every un-faulted route.
- Phone on USB with adb; Karim TestJeeber account still approved with 5 active deliveries.
- Nothing owner-gated: no deploy, no gateway change, no new repo. Super-login re-entry after S06 falls under the existing A17 allowance.
- Optional only: the "natural 429" variant (hammering `sensitive_fixed` routes) needs an owner OK because it can throttle every tester behind the tunnel IP.

## 12. Effort

**L** — proxy + tests ≈ 0.5 day, scenario files + Dart contract test ≈ 0.5 day, 18 device scenarios with dumps/REPORT ≈ 1 day (each cold scenario is ~3 min now that failures are fast; S05/S07 wait on 30 s/20 s windows), fix loop for any FAIL extra.

## 13. Owner decision

Confirm the mechanism: **proxy-only** (no in-app Dev Tool fault injector in `lib/`, no gateway fault toggle, no ephemeral environment). Yes = execute §9 as written; No = say which alternative and this plan's §7/§8 assertions still apply unchanged (only the injection step differs).

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C2): `tool/fault_proxy/fault_proxy.py` is the ONLY fault tool in the repo. P07-F8 (`tool/fault_gateway.py`)
  and `plans/p06-proxy.py` are dropped; P09's mitmdump addon (`p09-probe/fault_addon.py`) is an interim/fallback only.
  Conventions every plan now shares: listen `127.0.0.1:8089`, `adb reverse tcp:8089 tcp:8089`, device override
  `http://127.0.0.1:8089/gateway`, rule paths anchored `^/gateway/…`, `respond.drop: true` for TCP reset (P09 needs it),
  rules hot-reloaded from the file or `PUT /__fault/rules`. Never emit 401/403 outside P08's own S06/S07/S08.
- Reconciled (C17): S17 removed (P07 owns AR). D2 therefore ships S00–S16.
- Reconciled (C3): scenario `expect{}` blocks for S13/S14 (parse) and the "No connection" risk note assume P13 may or
  may not be on the build under test — record the head SHA and read `NetworkFailure(offline:false)` copy accordingly.
- Reconciled (P11): if P11 landed on #335 before this run, `snack_shown`/`snack_closed` Diag lines are available for
  S16's auto-dismiss assertion — cite them instead of polling only.
- Reconciled (C12/C13): evidence dir `scratchpad/device-evidence-4/p08/<Sxx>/` + `p08/REPORT.md`; this run sits in the
  serial device queue after P04-A and the #335 smoke; S06 (logout) last, then Super Login Plus re-entry.
- Owner decision renumbered: OD-8 (proxy-only mechanism — now also covers P06/P07/P09).
