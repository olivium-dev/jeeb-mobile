# PLAN P04 — stray test request `defb1f07` + "leave no state" rule for device validations

Planner: Fable 5.1 (plan only, no repo file changed). Date: 2026-09-05.
Deadline: the request auto-expires **2026-09-06 11:21:56 UTC** (`offerDeadlineAt`); do Part A before then.

## 0. Verified current state (live, 2026-09-05 ~15:42 UTC)

All reads were done against `https://msi.olivium.space/gateway` with OpenMode-minted tokens
(`POST /auth/tokens` → 200 for both users; receipts in
`$SCRATCH/p04-mint.json`, `p04-karim-mint.json`, `p04-client-list.json`, `p04-client-legacy.json`,
`p04-karim-feed.json`, `p04-karim-notifs.json`). `$SCRATCH` =
`/private/tmp/claude-501/-Users-oudaykhaled-Desktop-olivium-jeeb/6a29e634-9ff5-4e5b-b358-a1a84368ab4f/scratchpad`.

| Fact | Value | Evidence |
|---|---|---|
| Request | `defb1f07-efa5-4b8f-bc1a-09d6fcd1140b`, `status: pending`, description `F8-resolve-probe-parcel`, tier `scheduled` ("Scheduled"), `displayId ORD-D1140B`, `createdAt 2026-09-05T11:21:56Z`, `offerDeadlineAt 2026-09-06T11:21:56Z`, `jeeberId null`, `conversationId 80e1018a-2e29-4507-9aaf-bd5963556c6b` | `GET /v1/requests/defb1f07…` 200 and `GET /requests/defb1f07…` 200 (this plan §0 run) |
| Owner | `devtool_client_1788592148874` = userId **`de520a28-a7a4-4e49-8da0-e92b6a1b7284`**, roles `["customer"]` | public roster `GET /api/User/super-login/users` (34 rows, `$SCRATCH/roster.json`) |
| **A live offer exists on it** (not in the run-3 report) | offer **`8bbea040-bd35-4f24-8911-38171cb51710`** by Karim TestJeeber (`106078a3-4758-45c1-9d31-71b503a3fce4`), fee 2, eta 80, created `2026-09-05T13:52:07Z`, `status: submitted` (request view) / `pending` (jeeber view) | `GET /v1/requests/defb1f07…/offers` 200; `GET /v1/jeebers/me/offers` as Karim 200 |
| Owner's request list | 4 rows: 1 `pending` (this one) + 3 `cancelled` (`8a87f41f`, `f26b3601`, `dc5d0f2e` — today's validation artifacts, already terminal) | `GET /v1/requests?role=client` 200, `GET /requests` 200 |
| Karim | `online: false`; feed `items: []`; inbox still holds the F8 `new_request` row `f5cab53e-…` (`read: true`) | `GET /jeebers/me/availability`, `GET /v1/jeebers/me/feed`, `GET /v1/notifications` |
| Gateway on MSI | `origin/main 6679f6ee` (2026-09-04, PR #576); `/health/ready` 200 **Degraded** — `credential-delivery-service-token` Degraded while `FeatureFlags:UseUpstream:Delivery` is true | `curl /gateway/health/ready` |
| Device | `RZCT505K7WF` attached (`adb devices`); last session on it = Karim TestJeeber; `dev.base_url_override` = MSI (run-3 REPORT §"Residual state") | `device-evidence-3/REPORT.md:98-103` |

Gateway routes (read from `git show origin/main:<path>` after `git fetch origin`; never the stale checkout):

- Mobile cancel = `DELETE /v1/requests/{id}` — `lib/features/cancel_request/data/dio_cancel_request_repository.dart:13-15`. On the gateway that path is served by **`DeliveriesController.Cancel`** (`src/JeebGateway/Controllers/DeliveriesController.cs:1214-1217`, attribute `[HttpDelete("/v1/requests/{deliveryId}")]`, body optional via `EmptyBodyBehavior.Allow`), which calls `CancellationService.CancelAsync` (`src/JeebGateway/Requests/Cancellation/CancellationService.cs:186`). `Pending` is in `ClientPrePickupPreAcceptLegacy` (`:50-55`) → owner client cancel is free and immediate (`CancelledImmediately`, `:281-315`) → `TryCancelAsync(… RequestStatus.Cancelled …)`. Counterparty push is skipped when `jeeberId` is null and the actor is the client (`DeliveriesController.cs:1418-1437`). Upstream propagation is best-effort and logs a warning on failure (`:1326-1350`) — expected to warn today because the delivery credential is Degraded.
- **Cancel does NOT close pending offers.** The only caller of `IPendingOffersStore.ExpireForRequestAsync` is `RequestExpiryObserver.cs:151` (expiry path). `CancellationService.CancelAsync` and `DeliveriesController.Cancel` never touch `_offers`. So cancelling first would leave Karim's offer `8bbea040` `pending` forever in `GET /v1/jeebers/me/offers` (`V1/JeebRequestsController.cs:473-590` filters only on the offer's own status). ⇒ **withdraw the offer first, then cancel.**
- Offer withdraw = `DELETE /v1/offers/{offerId}` (`RequestOffersController.cs:454`, twin `DELETE /offers/{offerId}` `:456`, and `DELETE requests/{requestId}/offers/{offerId}` `:406`), capability `OfferWithdraw`, only the owning jeeber, only while pending (`IPendingOffersStore.cs:117-129`). Mobile calls it from `JeeberPendingOffersScreen` (`lib/features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart:39`, route `/jeeber/pending-offers`, `app_router.dart:1724-1726`; row CTA `pending_offer_<i>_withdraw_cta`, `lib/features/jeeber_request_feed/presentation/pending_offer_row.dart:18,257`).
- Legacy `DELETE /requests/{id}` (`RequestsController.cs:394-450`) is `[RequireCapability(RequestCancelOwn)]` = **ClientOnly** (`Auth/Capabilities/CapabilityRolePolicy.cs:78`). There is **no admin cancel for a pending request**: `AdminCancellationsController` only decides post-pickup approvals (`:89-114`); `AdminDeliveriesController.Transition` (`:107-183`) relays to the delivery-owner canonical row, requires fresh MFA + `Idempotency-Key`, and this request has no accepted delivery. So the only non-UI path is the owner's own token, which OpenMode lets us mint without a credential (`TokensController.cs:162-169`; `AuthorizeMint()` returns null when `SuperLogin:OpenMode` is true — ON on MSI per memory 2026-09-04 and proven by today's 200 mint).
- Auto-expiry: `RequestExpiryObserver` projects expiry **from upstream** (`_delivery.ListExpiredDeliveriesAsync`, `:79`) and closes offers itself (`:151`). With the delivery credential Degraded the projection may never fire — do not rely on expiry as the cleanup.

## 1. Problem

A real request created during device run 3 to probe gateway gap D1 (`device-evidence-3/REPORT.md:80,103`) is still `pending` on the live dev gateway, now with a live offer from Karim on it, and pollutes: the owner's Requests home (1 pending row), Karim's "Pending offers" list (1 pending offer), and any future validation that expects an empty pending list. Nothing in the programme records what was created or sweeps it afterwards; every run (`device-evidence/`, `device-evidence-2/cancel`, `device-evidence-3`) left state behind (3 cancelled requests + 1 pending + 2 sessions + minted tokens). FINAL-REPORT §7(d) lists it as owner item.

## 2. Part A — cancel `defb1f07` cleanly (do first; ≤ 20 min)

Order is load-bearing: **withdraw the offer, then cancel the request, then verify, then restore the phone.**

### A1. Preconditions (Mac)
1. `curl -s https://msi.olivium.space/gateway/health/ready | head -c 200` → HTTP 200 (Degraded is fine).
2. `adb devices` shows `RZCT505K7WF device`. Never `adb uninstall`; never tap Dev Tool "Clear Local Data".
3. Re-read live state before acting (same two GETs as §0; tokens in `$SCRATCH/p04-token.txt` / `p04-karim-token.txt` are valid until 2026-10-05). If `status` is already `cancelled`/`expired`, skip to A5.

### A2. Withdraw Karim's offer through the real app (primary)
Phone is already logged in as Karim (run-3 residual). Semantics ids only — dump with `$SCRATCH/dump.sh <file>`.
1. `adb -s RZCT505K7WF shell am start -n app.jeeb.mobile.dev/com.olivium.jeeb.MainActivity` → expect `jeeber_home_root` with "Ahlan, Karim". If a different account is shown, use Dev Tool → Super Login Plus → `super_login_plus_picker_search` "Karim" → `super_login_plus_user_106078a3-4758-45c1-9d31-71b503a3fce4`, then force-stop + relaunch.
2. Navigate to Pending offers: route `/jeeber/pending-offers` (from the jeeber feed's pending-offers entry; if no visible entry, the jeeber feed tab view hosts the rows — `lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart`). Expect `jeeber_pending_offers_root` with `pending_offer_0` whose `pending_offer_0_price` = 2 and request title `F8-resolve-probe-parcel`.
3. Tap `pending_offer_0_withdraw_cta`. Expect the row to leave the list (`jeeber_pending_offers_empty_state` if it was the only one) and **no** `pending_offers_withdraw_failed_snack`. Capture `p04-a2-before.xml/.png` and `p04-a2-after.xml/.png` into `$SCRATCH/device-evidence-4/`.
4. Verify from the Mac: `GET /v1/requests/defb1f07…/offers` with the client token → `8bbea040` absent or `status: withdrawn`; `GET /v1/jeebers/me/offers` with Karim's token → `8bbea040` not `pending`.

Fallback (only if the CTA is absent — `pending_offer_row.dart:67` hides it for some states): `curl -X DELETE https://msi.olivium.space/gateway/v1/offers/8bbea040-bd35-4f24-8911-38171cb51710 -H "Authorization: Bearer $(cat $SCRATCH/p04-karim-token.txt)"` → expect **204**; 409 `offer-not-pending` means already withdrawn/accepted — re-read the request; if `jeeberId` is now non-null the request was accepted and this plan stops (owner call).

### A3. Cancel the request through the real app as the owner (primary)
1. Dev Tool (2nd launcher icon `com.olivium.jeeb.LegacyDevToolLauncher`, or shake) → "Super Login" → "Super Login Plus" (`super_login_plus_button`) → `super_login_plus_picker_search` type `devtool_client_1788592148874` → tap `super_login_plus_user_de520a28-a7a4-4e49-8da0-e92b6a1b7284` → `am force-stop app.jeeb.mobile.dev` → relaunch `MainActivity`. Expect `client_home_root` with header "Hello, devtool_clie…".
2. After A2 the request has no live offer, so `DioClientHomeRepository` buckets it as **Pending** (`dio_client_home_repository.dart:16-22`): expect `pending_requests_item_defb1f07-efa5-4b8f-bc1a-09d6fcd1140b` (wrapped in `orders_home_request_row_0`). If A2 was skipped and the offer is still live, the row is in **Replies** instead: tap `replies_check_offers_cta` → `offer_review_list_root` → `offer_review_cancel_cta` (`client_offers_screen.dart:631`) and continue at step 4.
3. Tap the pending row → `waiting-no-coverage` (`/requests/:id/waiting`, `app_router.dart:923-926`) → `waiting_cancel_cta` (`no_offer_timeout_screen.dart:617`).
4. `cancel_request_sheet` → tap `cancel_request_confirm_cta` (`cancel_request_sheet.dart:240`). This issues `DELETE /v1/requests/defb1f07…` (`dio_cancel_request_repository.dart:13`). Expect: home returns with `_request_empty_state_root` immediately (the run-2 proven behaviour, `device-evidence-2/cancel/REPORT.md` assertions 6a/6b). Capture `p04-a3-pending.xml/.png`, `p04-a3-sheet.xml/.png`, `p04-a3-after.xml/.png`.
5. `shell_tab_delivery` → `order_history_cancelled_tab` → expect `order_history_card_defb1f07-efa5-4b8f-bc1a-09d6fcd1140b` first (badge "Cancelled 4"). Capture `p04-a3-cancelled-tab.xml/.png`.

Fallback (phone unavailable or Super Login Plus broken): `curl -X DELETE https://msi.olivium.space/gateway/v1/requests/defb1f07-efa5-4b8f-bc1a-09d6fcd1140b -H "Authorization: Bearer $(cat $SCRATCH/p04-token.txt)"` → expect **200** `{"deliveryId":"defb1f07…","status":"cancelled","previousStatus":"pending","pendingApproval":false,…}` (`DeliveriesController.cs:1295-1305`); 409 `not-cancellable` = already terminal (fine); 403 = wrong owner token (re-mint with `userId de520a28…`); 401 = OpenMode is off → stop, hand to owner.

### A4. Verify on the gateway (Mac, both tokens)
- `GET /v1/requests/defb1f07…` → `status: "cancelled"` (legacy `GET /requests/defb1f07…` shows `cancelled` too; `RequestStatus.IsTerminal` set `RequestsDtos.cs:97-104`).
- `GET /v1/requests?role=client` → 0 non-terminal rows for `de520a28…` (expect 4 rows, all cancelled).
- `GET /v1/requests/defb1f07…/offers` → no `submitted`/`pending` offer; `GET /v1/jeebers/me/offers` (Karim) → `8bbea040` not pending.
- `GET /v1/jeebers/me/feed` (Karim) → `items: []` still.
- Gateway log (optional, off-LAN): `ssh msi-ec2-cloudflare` → `sudo journalctl -u "$(systemctl list-units --type=service | awk '/gateway/{print $1;exit}')" --since "-1h" | grep -i defb1f07` — expect the cancel commit line and, acceptably, the `Cancellation upstream propagation failed … canonical row may lag` warning (`DeliveriesController.cs:1339-1345`) because `credential-delivery-service-token` is Degraded. Record it; it is a known live degrade, not a blocker.

### A5. Restore the phone to its pre-run state
1. Super Login Plus → Karim (`super_login_plus_user_106078a3-…`) → force-stop + relaunch → `jeeber_home_root` "Ahlan, Karim". Karim stays **Offline** (`GET /jeebers/me/availability` → `online:false`).
2. Dev Tool → Server URL → confirm `https://msi.olivium.space/gateway` (no change needed; dump it anyway as `p04-a5-baseurl.xml`).
3. Optional hygiene: revoke the two 30-day sessions minted today (`POST /auth/tokens/revoke`, `TokensController.cs:135`; refresh tokens in `$SCRATCH/p04-mint.json` / `p04-karim-mint.json`). If the body shape is not obvious from `git show origin/main:src/JeebGateway/Controllers/TokensController.cs` lines 135-160, skip — they are dev-only and expire 2026-10-05.
4. Write `$SCRATCH/device-evidence-4/p04/REPORT.md` (Reconciled C12: per-plan subdir; the root holds only the shared `CREATED.jsonl`) with a mandatory **"Residual state"** section listing: request status, offer status, sessions on the phone, base URL, tokens minted (ids only), and "nothing else created". Karim's read inbox row `f5cab53e` and conversation `80e1018a` cannot be deleted through any route (no delete on `JeebNotificationsInboxController`; conversations are request-scoped) — list them as known immutable residue.

## 3. Part B — standing rule + tooling so validations clean up after themselves

Repo: **jeeb-mobile**, new branch `chore/device-validation-leave-no-state` cut from `origin/main` (NOT on `ux/api-error-handling-empty-states`; PR #335 stays draft and untouched). Separate PR. No app code, no `lib/**` changes, so none of the `implements`/PR #330 invariants are touched.

### B1. `tool/device_validation_cleanup.sh` (new, bash, `set -euo pipefail`, `jq` + `curl` + `python3` only — same toolchain as `tool/firebase_doctor.sh`)
Subcommands, all driven by env `JEEB_GATEWAY` (default `https://msi.olivium.space/gateway`) and `JEEB_DEVICE_EVIDENCE_DIR` (required; the run's evidence directory):
- `record <kind> <id> <ownerUserId> [note]` — appends one JSON line `{ts,kind,id,ownerUserId,note}` to `$JEEB_DEVICE_EVIDENCE_DIR/CREATED.jsonl`. Kinds: `request`, `offer` (needs `--request <requestId>`), `session` (userId only; informational). Validators call it the moment a `POST /v1/requests` / offer submit succeeds (the request id is visible in `pending_requests_item_<id>` / `waiting_*` dumps and in the `[jeeb-diag]` stream).
- `sweep` — for each ledger line, newest first: `offer` → mint owner token (`POST /auth/tokens {userId, roles:["customer","driver"]}`) → `DELETE /v1/offers/{id}`; `request` → mint `{userId, roles:["customer"]}` → `GET /v1/requests/{id}`; if status ∉ {cancelled,expired,delivered,rated,disputed} → first `GET /v1/requests/{id}/offers` and withdraw every `submitted` offer as its jeeber (needs per-jeeber mint), then `DELETE /v1/requests/{id}`; then re-`GET` and assert `cancelled`. 409 `request-terminal` / `not-cancellable` / `offer-not-pending` count as clean. Prints a table and exits **1 if any ledger item is still non-terminal**. Exits 2 with "OpenMode off — hand to owner" on a 401/403 from the mint.
- `audit <ownerUserId>...` — for each user: mint, `GET /v1/requests?role=client` and `GET /v1/jeebers/me/offers`; print every non-terminal request / pending offer **not** in the ledger. Exit 1 if any. This is the "did the run leave anything it did not record" check.
- Safety: refuse any `JEEB_GATEWAY` host not in the allowlist `{msi.olivium.space, 192.168.2.39}` unless `--allow-host <host>` is given explicitly; hard-refuse `jeeb.fds-1.com` (prod) always. Never print tokens (log `tok:<last4>` like `docs/diagnostics.md` redaction). Never call `/dev/seed/user` or any `/admin/*` route.

### B2. `tool/test_device_validation_cleanup.sh` (new, device-free; follow `tool/test_validate_android_e2e_manifest.sh` style)
Starts a `python3 -m http.server`-style stub gateway (single Python file inline via heredoc, `http.server.BaseHTTPRequestHandler`) on `127.0.0.1:<random>` that models: `POST /auth/tokens` (200, or 401 when `STUB_OPENMODE=0`), `GET /v1/requests/{id}` (state machine in memory), `GET /v1/requests/{id}/offers`, `DELETE /v1/offers/{id}` (204 → status withdrawn; 409 if not pending), `DELETE /v1/requests/{id}` (200 cancelled; 409 `request-terminal` if terminal), `GET /v1/requests?role=client`, `GET /v1/jeebers/me/offers`. Assertions (each a named case, `printf 'PASS %s'`):
1. `sweep` withdraws the offer **before** cancelling the request (stub records call order).
2. A request already `cancelled` → sweep reports clean, exit 0.
3. Stub returns `pending` after DELETE → sweep exit 1 with the id in the output.
4. `STUB_OPENMODE=0` → exit 2 and the "hand to owner" line.
5. `JEEB_GATEWAY=https://jeeb.fds-1.com` → refused before any HTTP call (stub sees zero requests); `https://example.test` refused without `--allow-host`, accepted with it.
6. `audit` flags a pending request absent from the ledger; passes when the ledger contains it.
7. Output never contains the stub's token string.

### B3. `docs/device-validation.md` (new) — the standing rule
Sections: (1) **Leave no state**: every device validation runs with `JEEB_DEVICE_EVIDENCE_DIR` set, records every created request/offer/session via `record` at creation time, and ends with `sweep` + `audit <every account used>`; the run's `REPORT.md` must contain a **"Residual state"** section that pastes the `sweep`/`audit` output and lists immutable residue (inbox rows, conversations, minted sessions). A run without that section is not accepted. (2) **Restore the phone**: `dev.base_url_override` back to the value dumped at start; the session that was on the phone at start re-entered via Super Login Plus; jeebers returned to their starting online/offline state; `install -r` only, never uninstall, never "Clear Local Data". (3) **Accounts**: prefer existing accounts (`Karim TestJeeber`, `devtool_client_1788592148874`); minting new Scenario Users requires a ledger `session` line. (4) **Why**: link this plan's §0 facts (cancel does not close offers; expiry depends on the Degraded delivery credential). (5) Cross-link from `README.md` §"Backend route compatibility" neighbour: one line "Device validations: see docs/device-validation.md".

### B4. CI wiring
`.github/workflows/ci-android-stage.yml` — add `run: bash tool/test_device_validation_cleanup.sh` next to the existing tool tests at lines 103-106 (`test_android_release_signing.sh`, `test_android_firebase_config.sh`). No other workflow change; no deploy.

### B5. Agent memory (in-repo) — `.claude/agent-memory/Guardrail-Agent/device-validation-leaves-no-state.md` + one index line in that directory's `MEMORY.md`: "Every device run records created ids to `CREATED.jsonl` and ends with `tool/device_validation_cleanup.sh sweep && audit`; a REPORT without a Residual-state section is rejected." (Two-line comment rule does not apply to markdown, but keep it to ≤ 8 lines.)

### B6. Outside the repo (orchestrator, not a file in any repo)
Append to the user memory `jeeb-realflow-validation-standard.md`: "Cleanup is part of validation — run `tool/device_validation_cleanup.sh sweep`+`audit` and write a Residual-state section; cancel does NOT close offers on the gateway (withdraw first)."

### B7. Gates on the branch
`git add` every new file before testing; `dart analyze --fatal-infos .` (unaffected, no Dart change); `flutter test --exclude-tags capture` (unaffected — run anyway, baseline 8257/0); `bash tool/test_device_validation_cleanup.sh` green; `tool/check_design_tokens.sh` unaffected. PR title `chore(tool): device-validation cleanup ledger + sweep/audit + leave-no-state rule`. Then, as the first real use, run **`sweep` against the Part-A ledger** (record `defb1f07`/`8bbea040` retroactively) — it must report both already clean.

## 4. Gateway follow-up (file, do not fix here)
Issue against `olivium-dev/jeeb-gateway`: "Client pre-accept cancel leaves submitted offers pending" — `CancellationService.CancelAsync` client path (`CancellationService.cs:281-315`) and `DeliveriesController.Cancel` (`:1214-1305`) never call `IPendingOffersStore.ExpireForRequestAsync` (only `RequestExpiryObserver.cs:151` does). Repro: today's `8bbea040` on `defb1f07`. Also note the OpenAPI method/path duplication between `RequestsController` `DELETE /requests/{id}` and `DeliveriesController` `DELETE /v1/requests/{id}`.

## 5. Risks
- Cancelling before withdrawing leaves Karim's offer pending forever (verified in code) — order in §2 is mandatory.
- The offer may get **accepted** by an agent/validator between now and execution (`POST /v1/offers/{id}/accept`); then `jeeberId` is set, cancel still succeeds pre-pickup but sends a push to Karim and mints a cancelled delivery. Re-read state first (A1.3).
- Delivery-service credential Degraded → upstream propagation warning; canonical row may lag. Accept; note in the report.
- Super Login Plus re-mints roles from the roster (`roles:["customer"]` for the client) — fine for cancel (`Roles.Client`); for Karim the roster carries `customer,driver`, so his session can withdraw.
- Auto-expiry could race the execution if done after 2026-09-06 11:21 UTC — then the request is `expired` and offers are closed by the observer; the sweep must treat `expired` as clean (it does).
- OpenMode could be switched off by the owner at any time (SEC-13 intent) — the script degrades to "hand to owner" rather than failing silently.
- The `sweep` mints 30-day sessions for each owner; keep counts low and never on prod (allowlist).

## 6. Effort / owner decision
- Part A: **S** (≤ 20 min on device + Mac). Part B: **M** (script + stub test + doc + CI line, ~half a day). Overall **M**.
- Owner decision needed: **Approve the OpenMode-minted owner-token API path (`DELETE /v1/offers/{id}` then `DELETE /v1/requests/{id}`) as the sanctioned cleanup fallback and as the mechanism of `tool/device_validation_cleanup.sh sweep`, restricted to the MSI host allowlist — yes/no.** If "no", Part A still executes through the real app (A2/A3 primary) and Part B ships as ledger + `audit` only (report-only, no automatic sweep).

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C7): Part A is the FIRST device action of the whole programme (deadline 2026-09-06 11:21 UTC) and it
  removes `defb1f07` + Karim's offer `8bbea040` that P02 V1, P09 S3.2/S5.0/S8.2 and P12 §7.6 were counting on. Those
  plans now create fresh, ledgered requests (or expect Karim's pending list to have 4 rows) — edited there.
- Reconciled (C12): one shared ledger for every run-4 plan: `JEEB_DEVICE_EVIDENCE_DIR=$SCRATCH/device-evidence-4`
  (→ `device-evidence-4/CREATED.jsonl`); each plan writes its own `device-evidence-4/<key>/REPORT.md`. Every later
  run that mutates the dev gateway records via `record`: P02 V1 (request), P03 Phase B(4) (request), P09 §2.1
  (session for EmptyJeeber), S5.0 (offer), S1.5 (chat message — note-only kind), P01 §7B (session).
- Reconciled (C13): Part B tooling (`tool/device_validation_cleanup.sh`) is needed by the wave-3 device runs before
  its PR merges — run it from the branch checkout; the PR itself lands off `main` independent of #335 (C1 unaffected).
- Owner decision renumbered: OD-6 (OpenMode-minted API cleanup path). Part A's real-app path needs no decision.
