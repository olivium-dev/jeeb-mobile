# PLAN-P15 — Wallet independence: landing `epic/wallet-guard-fix` without a breaking change (2026-09-06)

**Owner ruling (OD-15, verbatim):** "Strict hard rules, wallet should be independant does not produce a breaking changes for other projects."
Read as binding: (1) the wallet is an independent component; (2) landing the epic must not break any other project or service; (3) it answers OD-15 not with "rebaseline/mergemain" but with a rule the landing must satisfy. Plan only — no repo, env or data change was made while writing this.

Sources read: `plans/OD-15-EXPLANATION.md`, memory `jeeb-wallet-fee-guard-audit-2026-08-23`, `jeeb-gw-db-extraction-plan`, `jeeb-gateway-db-stateless-audit`, `PLAN-P10-pr-readiness.md §9 D4 / §Reconciled`. Everything below was re-verified today against `origin/*` (gateway `6679f6e`, epic `dfa9159`, mobile `ab610933` / epic `c4e343fe`, wallet-service `origin/master 1fa46a8`), the live MSI box (`ssh msi-ec2-cloudflare`, gateway.env, `/health/ready`, the `jeeb-wallet` database on `:5442`) and the wallet-service swagger at `127.0.0.1:10014`.

---

## 0. Findings that change the picture (read first)

| # | Finding | Evidence | Consequence |
|---|---|---|---|
| F1 | **The gateway no longer reads WalletPostgres directly — on main OR on the epic.** The W5-10/W5-11 legs deleted the projection and the seam; `src/` has **zero** non-comment `Npgsql` references; the only ledger reader is `WalletServiceJeebWalletLedgerReader` (HTTP) with `NullJeebWalletLedgerReader` as the unconfigured fallback. | gateway `origin/main:src/JeebGateway/Program.cs:1685-1692` ("W5-10: the WalletPostgres projection is deleted, so wallet-service is the only ledger source"); `git grep -E '^\s*using Npgsql|new NpgsqlConnection' origin/main -- src` = 0; staging workflow lists `WalletPostgres__ConnectionString` under `retired_gateway_env` (`.github/workflows/jeeb-staging-deploy.yml:902-906`); MSI `gateway.env` has the DSN line commented out and `WalletLedgerMigration__Authority='wallet-api'`; epic `Program.cs:1552` carries the same W5-10 comment. | The memory claim "gateway reads WalletPostgres directly — a coupling" is **stale**. Structural independence at the data layer is already done; the plan does not have to build it, only to *lock* it (gate item G2). |
| F2 | **The epic changes zero lines of wallet-service.** All 90 gateway files are gateway code + three `tools/*` programs; holds use wallet-service's existing two-phase `initiate → execute/abort` and the S-10 pending-netted holder read. | `git diff --stat origin/main...origin/epic/wallet-guard-fix` (no `wallet-service` path); `_wallet-guard-fix/exec/DECISION-holds-mechanism.md:8-22`; wallet-service `origin/master:Data/Repositories/WalletRepository.cs:91-111` (S-10 netting, landed `1acce94` 2026-06-20 #51, present in the MSI build `wallet-service-73f2cfe`); `/Transaction/{id}/abort`, `/by-external-reference/{ref}`, `/validate` all in `73f2cfe:Controllers/TransactionController.cs:35,118,182`. | **Sibling products (rahmah, saawt, salehly, thakii, creamati, jaiker) cannot be affected by this epic** — they share only the wallet-service *repo*, and each runs its own instance + DB (`wallet-service/.github/workflows/deploy-to-*.yml`, `db_name` input). The "other projects" half of the rule is satisfied by construction *for this epic*; the gate makes it permanent. |
| F3 | **The one truly breaking item is a config-default flip, and the epic makes it boot-blocking.** `PartnerWalletOptions.CurrencyId` 1→2 and `CommissionCollection.CurrencyId` 1→2 (+ new `CurrencyCode`), and `BffStartupValidator` now adds "fee-currency mismatch" / "CurrencyCode empty" to `problems` — which on main **throws `StartupConfigurationException`** in Production. | epic diff `src/JeebGateway/Partner/PartnerWalletOptions.cs:41` (`= 1` → `= 2`), `appsettings.json` hunk (`CommissionCollection.CurrencyId 1→2`, `CurrencyCode: "USD"`, `PartnerWallet.CurrencyId 1→2`), `BffStartupValidator.cs` hunk; main `BffStartupValidator.cs:134` throws. | Shipped as written: MSI (env `PartnerWallet__CurrencyId=2`, no Commission override) boots fine only *because* both defaults move together; but any environment that pins one and not the other **refuses to boot**. Staging pins neither. Fix in §4: validator degrades `/health/ready` first, throws only after all environments are pinned. |
| F4 | **Live currency-1 money exists and matches the committed census.** `jeeb-wallet` on MSI: currency 1 → `user`×4 = 25.00, `main`×1 = 5.00, `jeeb`×4 active = 0.00, `__SYSTEM__` = −30.00; currency 2 → `jeeb`×6 = 2.00, `partner`×1 = 3.00, `__SYSTEM__PRIMARY__` = −5.00; 12 holders; 7 transaction headers, **all `status=0` (executed) — zero pending holds today**; `fees` table empty. Catalog is config, not data: `GET /Fees/currencies` → `[{1,Credit,rate 0.1},{2,USD,rate 1}]`, base = USD. | psql on `:5442` (`select currencyid,type,isactive,count(*),sum(amount) from wallets …`); `curl 127.0.0.1:10014/Fees/currencies`; wallet-service `appsettings.json:11-27` (`FeesConversion` seed). | The 30.00 Credit / 5 holders in `tools/WalletCurrencyMigration/census-2026-08-24.json` is still the live truth (ccy-2 `jeeb` wallets grew from devtool funding, which the tool tolerates). Migration is a small, reversible data run — but it is the *only* thing that can strand value, so it is sequenced before any currency pin. |
| F5 | **Staging and MSI disagree on currency today.** MSI env pins `PartnerWallet__CurrencyId=2`; staging's deploy workflow sets no `PartnerWallet__`/`CommissionCollection__` key → staging runs the repo default **1** for both, against its own DB `jeeb-wallet_staging`. | MSI `gateway.env`; gateway `jeeb-staging-deploy.yml` (grep `Partner|Currency` = none; `WalletServiceApi__BaseUrl http://jeeb-staging-wallet-service:8080/` at L1108); wallet-service `jeeb-staging-deploy.yml:203`. | Staging needs its **own** census + migration run (different DB, unknown balances). "Flip the repo default" is the last step precisely because it silently flips staging. |
| F6 | **Replay collisions beyond the 4 code conflicts:** ADR number clash (`epic docs/adr/0012-w5-fee-refund-on-cancel.md` vs main `0012-international-e164-otp-ingress.md`, main already has `0013`); `tools/WalletHolderBackfill` accepts `--um-connection` (raw Npgsql into user-management's `Users` table — a cross-service DSN the extraction plan's riders forbid); epic's abort/by-external-reference wallet calls are **hand-written HTTP** in `WalletCommissionDebitClient.cs:125-300` while main's generated `ServiceWalletClient` lacks Abort/Execute/Validate even though the pinned slice has those paths. | `git ls-tree origin/main docs/adr/`; `tools/WalletHolderBackfill/Program.cs:132,185,236`; `scripts/regenerate-wallet-client.sh`; `src/JeebGateway/contracts/wallet-service.openapi.json` (`x-source-commit 5fa9f7b`, 28 paths incl. `/Transaction/{id}/abort`). | Renumber ADRs (0014 = this rule, 0015 = refund); drop `--um-connection` (file input only); regenerate the wallet client and route the new calls through it, with a freshness CI job (only state-service + OTP clients have one today: `ci.yml` jobs `nswag-freshness`, `nswag-otp-freshness`). |
| F7 | **A path/method OpenAPI compatibility checker already exists in the gateway and nothing calls it.** | `scripts/check-openapi-path-method-compatibility.sh` (jq: "candidate removes existing path/method contracts" → exit 1); `git grep -l check-openapi-path-method-compatibility origin/main -- .github scripts` = none. | Wire it (gate item G3) — the cheapest possible "no removed route" gate for both the wallet slice and the gateway's own `artifacts/openapi/jeeb-gateway.v1.json`. |

---

## 1. The rule as an ADR (proposed `docs/adr/0014-wallet-independence-no-breaking-change.md`, gateway repo)

**Status:** proposed, owner-ruled 2026-09-06 (OD-15). **Supersedes** nothing; **constrains** ADR-0011 (commission collection) and the refund ADR (to be 0015).

**Decision.** The wallet is an independent component of the olivium fleet:

1. **Ownership.** wallet-service owns the wallet data (`jeeb-wallet` DB, one instance + one DB per product) and its HTTP API. No other service, tool or job opens a wallet database connection. The gateway's only wallet dependency is HTTP via the pinned OpenAPI slice `src/JeebGateway/contracts/wallet-service.openapi.json` and the client generated from it.
2. **Shared-repo discipline.** wallet-service source is shared by ~7 products. A change to it is allowed only if it is additive (no removed/renamed path, method, field, status, or error `type`; new fields optional with a default equal to today's behaviour), passes the G-28 vocabulary gate, and passes the path/method compatibility check against the previous published swagger. Product-specific behaviour never goes into wallet-service; it goes into that product's gateway.
3. **Consumer contracts are additive and versioned by extension.** The gateway's wallet-facing routes (`/v1/jeeb/wallet*`, `/v1/partner/wallet*`, `/v1/jeeb/earnings*`, offer submit/accept error surfaces, push payloads) may gain fields, `type` URIs, and push `type`s; they may not lose or rename any. Old app builds (N−2 store builds) must keep working with sane fallbacks; no change may require a forced app update.
4. **Behaviour behind flags whose repo default is today's behaviour.** Any change a user can notice (holds, caps, fail-closed modes, currency pin, new push wording) ships default-off / default-legacy, is flipped per environment by env (MSI → staging), and the repo default is changed only in a later, separate PR once every environment is pinned.
5. **Data migrations are tool-driven, HTTP-only, dry-run by default, idempotent, and reversible by compensating transaction.** They run *before* the code that depends on them, and the code must be correct both before and after the run.
6. **Startup validation never blocks the first boot of a new invariant.** A new config invariant is surfaced as `/health/ready` Degraded + WARN first; it may throw only in a later PR after every environment has been proven green against it.
7. **Each PR is independently deployable and reversible** (rollback = previous build + flag off), never requiring a coordinated deploy of another service.

**Checkable criteria** = the gate in §5. **Consequences:** the epic lands as a replayed PR train (§6), not as one merge; wallet-service authentication (deferred c5, SS-1/2) is recorded as the one remaining independence gap (§10, §12).

---

## 2. Consumer census — who touches the wallet today

"Wallet" = the jeeb wallet-service instance (`127.0.0.1:10014` on MSI, `jeeb-staging-wallet-service:8080` on staging) and its DB, plus the gateway's wallet-facing routes/pushes that the mobile app and CMS consume.

| Consumer | Mechanism | Exact surface | Citation | Touched by the epic? |
|---|---|---|---|---|
| **jeeb-gateway** (`6679f6e`) | HTTP wallet-service, via NSwag `ServiceWalletClient` + hand-written calls | `GET Wallet/holder/{id}/wallets` (guard/balance/projection), `PUT Wallet/holder/ensure` (provisioner), `POST Transaction/initiate` (commission debit, partner transfers), `GET Transaction/holder/{id}/ledger[/{detailId}]` (ledger reader), `GET Transaction/holder/{id}/credit-revenue` (earnings), `GET Fees/currencies`, `GET /system-wallet` | `Financials/WalletCommissionDebitClient.cs:124`; `JeebWallet/JeebWalletLedgerReader.cs:60`; `Program.cs:1668-1692`; generated client method list (`ServiceWalletClient.cs`); MSI `gateway.env` `WalletServiceApi__BaseUrl`, `Services__Wallet__BaseUrl` | **Yes** — adds `Transaction/validate`, `Transaction/{id}/abort`, `Transaction/by-external-reference/{ref}` (all exist in wallet-service `73f2cfe`), more `holder/ensure` sites, pending headers `ServiceName=jeeb-gateway, Tag=hold` |
| jeeb-gateway → **jeeb-state-service** | HTTP (existing idempotency-key KV API) | `UpsertIdempotencyKeyWithResultAsync`, `FindIdempotencyKeysByPrefixAsync` under new prefixes `wgf:hold:` / refund | epic `Financials/Holds/HoldIntentStore.cs:63,113`; both methods already have callers on main (2 files) | **Yes, additive** — new key namespace only; no state-service code change |
| jeeb-gateway → **notification-service** | HTTP generic events `POST /notifications/events` (`event_type: string`, `data: object`, no enum) | new `event_type = jeeb.offer_withdrawn_insufficient_balance`, `data.category = wallet`, deep link `jeeb://wallet` | notification-service `openapi.json` (`GenericEventNotification`); gateway `Notifications/GenericEventDispatcher.cs:67,134`; epic `OfferPushNotifier.cs` hunk | **Yes, additive** — free-text type; notification-service has no allow-list (grep = none) |
| **jeeb-mobile** (store builds `26090403`/`26090402` = main) | Gateway routes + RFC 7807 `type` URIs + push `type`s | `GET /v1/jeeb/wallet` (+`/ledger`, `/ledger/{id}`); offer submit `402 insufficient-wallet-balance {needed,available,currency}`, `409` cap; accept `409 offer-jeeber-insufficient-balance`; push `offer_lost`, `offer_withdrawn_insufficient_balance`, `wallet_insufficient_balance` | mobile `origin/main:lib/features/offers/data/dio_offer_submission_repository.dart:59-118`; `lib/features/client_offers/data/dio_offers_repository.dart:263-279`; `lib/core/notifications/domain/notification_message.dart:61,75-76` (handled since `911ef641` #231, 2026-08-08); gateway `Controllers/JeebWalletController.cs:44,124,168` | **Yes** — new `type` URIs on existing routes, 402 gains `thisOffer`/`outstanding`, accept auto-withdraw push switches from `offer_lost` to `offer_withdrawn_insufficient_balance` |
| **Partner portal** (web) | Gateway `PartnerWalletController` | `/v1/partner/wallet/{balance,ledger,transfers,transfers/predict,transfers/otp/challenge}`; wallet chosen by `PartnerWallet:CurrencyId` | `Controllers/PartnerWalletController.cs:33-227`; MSI env `PartnerWallet__CurrencyId=2` | **Yes** — default currency 1→2 (already 2 on MSI by env; 1 on staging) |
| **jeeb-cms** (`186b6f1`) | Gateway routes only (browser SPA) | `GET/POST /wallet-service/v1/admin/earnings*` (no gateway backing yet → 404 by design), settlement routes `/admin/settlements*` | `jeeb-cms/packages/gateway-client/src/generated/gateway-client.ts:985,1054,1117`; `.env.example:19-21`; `settlements.ts:143-182` | **No** |
| **unified_payment_gateway** (`a890751`) | Outbound webhook to a wallet URL | `WALLET_WEBHOOK_URL` default `http://192.168.2.50:10014/api/payments/webhook` — a route wallet-service does not expose; `CASH_GATEWAY_ENABLED` must stay off | UPG `.github/workflows/deploy-to-jeeb.yml:25`; `lib/.../payment_service.ex:317-318,445-465` | **No** (pre-existing dangling integration; note only) |
| **settlement-service** (`6f40288`) | None (owns its own DB; `external_ref` first-stamp slot for a wallet tx id) | — | settlement `README.md:4,20-23`; `Migrations/migrations.sql:135`; USD-string + flat 10% (`Domain/CommissionPolicy.cs:7-17`) | **No** |
| notification-service profile | Deep link only | `jeeb.settlement_paid` → `jeeb://wallet/settlements/{id}` | `.github/profiles/notification/notification_config.json:282-286` | **No** |
| push-notification, user-management, kyc, delivery, offer-service | None (deploy-matrix boilerplate only; offer-service has no balance logic) | — | census sweep (13 repos) | **No** |
| **Sibling products** (rahmah, saawt, salehly, thakii, creamati, jaiker) | Own wallet-service instance + own DB from the shared repo | — | wallet-service `deploy-to-ec2-rahmah.yml`, `deploy-to-fds2-saawt.yml`, `deploy-to-salehly.yml`, `deploy-to-thakii.yml`, `deploy-to-vps-creamati.yml`; 3 different `/Fees` datasets proven 2026-08-24 | **No** (no wallet-service source change) |
| Ops tools (epic) | `tools/WalletCurrencyMigration` (HTTP only), `tools/WalletHolderBackfill` (HTTP + optional user-management DSN), `tools/HoldsAbort` (HTTP state + wallet) | — | tool READMEs / `Program.cs` | New; see G2 |

Wallet-service itself (`origin/master 1fa46a8`): **no auth at all** (`Program.cs:213` `UseAuthorization()` with nothing registered), no API versioning (only the earnings routes carry a literal `/v1/`), no CHANGELOG, no committed openapi (runtime `/swagger/v1/swagger.json`, published by `update-api-docs.yml` to `olivium-dev/olivium-api-docs`), idempotency only on `POST Transaction/initiate` (`Idempotency-Key`, 409 `idempotency-conflict`), wallet identity `(HolderId, CurrencyID, Type)` unique.

---

## 3. Every contract the epic changes, and whether it breaks a consumer

| # | Contract change (epic as written) | Consumer(s) | Breaks if shipped as-is? | How it becomes non-breaking (this plan) |
|---|---|---|---|---|
| C1 | `PartnerWallet:CurrencyId` default 1→2; `CommissionCollection:CurrencyId` 1→2 + new `CurrencyCode` (code default + `appsettings.json` + `appsettings.Production.json`) | partner portal, mobile balance/guard, migration data | **YES.** Currency-1 balances (30.00 Credit / 5 holders on MSI; unknown on staging) stop counting until migrated; staging flips silently (F5). | Keep repo defaults = 1 in PR-G1; add `CurrencyCode` as optional (null = today); flip **by env** per environment *after* the owner-run migration for that environment's DB; flip the repo default in PR-G6 last. Rollback = env revert + the tool's documented compensating reverse transaction. |
| C2 | `BffStartupValidator` throws on `Commission≠Partner` currency or empty `CurrencyCode` (Production) | every gateway deploy | **YES (boot).** Any env pinning one key only (MSI today pins only Partner) fails to start. | Ship as a `/health/ready` **Degraded** check + WARN (PR-G1); promote to throw in PR-G6 after MSI+staging are pinned and green. |
| C3 | New RFC 7807 `type`s on existing routes: `403 wallet-holder-unresolved`, `503 offer-fee-unresolvable`, `503 offer-exposure-unresolvable`, `409 offer-live-limit-reached`; 402 gains `thisOffer`, `outstanding`; `needed` = aggregate | mobile (old + new builds) | **No crash.** Old mapper: 402 parses `needed/available/currency` and ignores extras; 409 with "limit"/"20" in the body → `offerCapReached` copy; 403/503 → generic `server` "HTTP n"; accept-409 unknown → `offerNotPending`. | Additive by construction; pin every URI + the 402 shape in a gateway contract test and in the mobile `wallet_guard_copy_contract_test.dart`; the *behaviour* (fail-closed on fee blip, aggregate needed) sits behind `WalletGuard:Mode` (default `legacy`) so an env flip, not a deploy, turns it on. |
| C4 | Accept auto-withdraw push: `offer_lost` → `offer_withdrawn_insufficient_balance`, category `wallet`, deep link `jeeb://wallet`, gateway-rendered EN bytes | mobile, notification-service, push-notification | **No.** Both keys handled on mobile main since #231 (2026-08-08, before every current store build); pre-#231 builds show the EN bytes verbatim; notification-service accepts any `event_type`; push-notification has no wallet keys. | Emit the new type only when `WalletGuard:Mode≠legacy` (PR-G4); keep `offer_lost` unchanged for the "not selected" case; add the wire bytes to `push_payload_contract_test.dart` (mobile) + `OfferPushNotifierTests` (gateway). |
| C5 | `Holds:Enabled=true` default → one pending wallet header per live offer; balance visibly drops; `HoldSweeper` hosted service | mobile balance strip, wallet DB (jeeb instance), state-service KV | Behaviour change, not a wire break; but default-ON violates rule 4. Sweeper needs state-service (already `Enabled=true` on MSI). | `Holds:Enabled` default **false**; `WalletGuard:Mode=holds` by env on MSI first, then staging; repo default flipped in PR-G6. `tools/HoldsAbort` is the documented drain for rollback (zero pending headers exist today, so rollback from the first flip is trivial). |
| C6 | `Offers:MaxLiveOffersPerJeeber=20` → new 409 | mobile | No wire break (old builds render "cap reached"); behaviour change. | Default `0` (= unlimited, today) in code; env `Offers__MaxLiveOffersPerJeeber=20` with the Mode flip; owner's ruled value 20 becomes the repo default in PR-G6. (OD-15b if the owner prefers 20 baked from day one — it is non-breaking either way.) |
| C7 | Signup/role-switch best-effort `PUT Wallet/holder/ensure` (+ `WalletHolderBackfill`) | wallet DB rows (jeeb instance only), user-management (tool DSN) | Additive data; **but** the tool's `--um-connection` opens user-management's DB directly (rider R: backfills = HTTP ingest only). | Keep the seam; ship the tool with `--users-file` only (ids exported by the owner from user-management); drop the Npgsql path. |
| C8 | `FeeRefunder` + `RefundIntentStore` (refund on every post-accept cancel) | wallet, state-service | Dormant while `CommissionCollection:Enabled=false` (both branches). | Additive; ADR renumbered to 0015; required before the c1b collection flip (OD-P1) — unchanged. |
| C9 | `WalletGuard:FailMode` semantics widened (fee-resolution blip now 503, symmetric) | mobile | Behaviour change; `FailMode` already exists on main = `fail-closed` for wallet outage. | Fold the symmetric part under `WalletGuard:Mode` (legacy keeps today's asymmetry) — owner-ruled strict mode is reached by the same env flip. |
| C10 | ADR `0012-w5-fee-refund-on-cancel.md` | docs | Collides with main's ADR-0012 (E.164 OTP). | Renumber on replay (0014 = this ADR, 0015 = refund). |
| C11 | Hand-written HTTP for abort / by-external-reference / validate | gateway↔wallet contract | Not breaking, but bypasses the pinned slice/generated client (rule 1). | Regenerate `ServiceWalletClient` from the slice (`scripts/regenerate-wallet-client.sh`) and call the generated methods; add a `nswag-wallet-freshness` CI job. |
| C12 | No new `[Http*]` routes, no gateway DB migrations (gateway has no DB), no wallet-service change, `CommissionCollection:Enabled` stays false | all | — | Re-verified: `git diff origin/main...epic -- src | grep '\[Http'` adds none; wallet-service untouched. |

**Net:** two items are truly breaking as written (C1 data/currency, C2 boot); both become non-breaking by ordering (migrate → env-pin → default) and by degrading instead of throwing. Everything else is additive or a flag-default question.

---

## 4. What "wallet independent" requires structurally — done vs. missing

| Requirement | State today | Action in this plan |
|---|---|---|
| wallet-service owns its data + API; nobody else opens its DB | **Done** on gateway main (F1); staging DSN retired; MSI DSN commented out. Only `oudaykhaled@127.0.0.1` sessions on `jeeb-wallet` (the service's own pool). | Lock with gate G2 (`zero-dsn-cold-boot.yml` promoted to gating for the wallet DSN key; `git grep Npgsql src` = 0 assertion; tools HTTP-only). |
| Gateway reads only via the wallet read-API | **Done** (`WalletLedgerMigration:Authority=wallet-api` on MSI and in `appsettings.Production.json:185-189`). | Delete the `WalletPostgres` comment residue + `ShadowCompareEnabled` in PR-G0 (docs only). |
| Pinned, versioned contract between gateway and wallet | **Partial**: slice pinned at wallet `5fa9f7b` (28 paths) but the generated client is behind the slice; no freshness CI; `SPECS-STATUS.md:23` still says "placeholder". | PR-G0: regenerate, add `nswag-wallet-freshness`, wire `check-openapi-path-method-compatibility.sh` (wallet slice vs published swagger; gateway v1 spec vs main). |
| Additive-only wallet-service evolution across ~7 products | **Partial**: G-28 vocabulary gate exists; `WalletOpenApiContractTests` pins one default; no path/method compat gate; no auth; no versioning. | Gate G1 applies the same compat script inside wallet-service CI (one-file PR to the shared repo, additive, owner-gated); auth = deferred c5 (§12). |
| Feature flags default-off, env-flipped per environment | Pattern exists (`FeatureFlags__*`, `WalletLedgerMigration__Authority`, `gwdbx-flag-registry-gate` G-22). | Register `WalletGuard:Mode`, `Holds:Enabled`, `Offers:MaxLiveOffersPerJeeber`, `CommissionCollection:CurrencyCode` in the flag registry; `forward-only-authority-audit.yml` guards against reverting a flipped authority. |
| Backward-compatible data migration for the currency change | Tool exists, HTTP-only, dry-run default, idempotent, compensating-tx rollback (`tools/WalletCurrencyMigration/README.md`). "Dual-read" here means: both currencies' data coexist and the gateway never blends them (OD-C3-5), so the safe order is **migrate first, pin second** — not a cross-currency sum. | §6 steps 2–3; staging needs its own census file. |
| No forced app update | Old builds degrade sanely (C3/C4). | Contract tests on both sides; N−2 build smoke on real devices (§8). |
| Independence gap that remains | **wallet-service has no auth** (`:10014` loopback-only mitigates on MSI; Saawt's is public). Gateway `api/Wallet` passthrough shows an explicit `[Authorize]` only on `holder/wallets` (`Controllers/WalletController.cs:169-170`) — confirm the global fallback policy covers the mutating passthroughs. | Out of epic scope by the owner's 2026-08-24 deferral; listed in §12 as the next independence PR (sender-first: tolerate → send → require). |

---

## 5. Breaking-change gate — every future wallet PR (gateway, mobile, wallet-service, tools) must pass all 8

| G | Criterion | How it is checked (mechanical where possible) |
|---|---|---|
| **G1** | **Shared wallet-service source changes are additive and product-agnostic.** No removed/renamed path, method, field, status or error `type`; new request fields optional with today's default; no product vocabulary. | wallet-service CI: `vocabulary-gate.yml` (G-28) + `check-openapi-path-method-compatibility.sh <published swagger> <candidate swagger>` (new job, base = `olivium-api-docs/wallet-service/swagger.json`) + `WalletOpenApiContractTests`. Sibling deploys are never dispatched by a jeeb change. |
| **G2** | **No wallet DB access outside wallet-service.** Gateway `src/` and every `tools/*` project contain no Npgsql/DSN to the wallet DB; every wallet call goes through the pinned slice's generated client. | `git grep -E 'using Npgsql|NpgsqlConnection' -- src tools` = 0 for wallet targets; `zero-dsn-cold-boot.yml` gating; `nswag-wallet-freshness` job (regenerate → `git diff --exit-code`); PR review rejects hand-written wallet HTTP. |
| **G3** | **Consumer-facing gateway contract is additive.** No route/status/`type` URI/push `type`/JSON field removed or renamed; new fields optional. | `check-openapi-path-method-compatibility.sh artifacts/openapi/jeeb-gateway.v1.json <candidate>` in `ci.yml`; gateway contract test pinning the wallet-guard `type` URIs, 402 shape and push wire bytes; mobile `wallet_guard_copy_contract_test.dart` + `push_payload_contract_test.dart` pin the same bytes. |
| **G4** | **Old apps keep working; no forced update.** The two previous store builds (currently Play `26090403`, TestFlight `26090402`) render every new error/push with a sane fallback. | Real-device smoke of the N−1 build against the flipped MSI (offer submit 402/409/503 paths + the withdrawn push) recorded in `scratchpad/device-evidence-*/p15/`. |
| **G5** | **Behaviour changes are flag-gated with repo default = today.** Flip by env per environment; the repo default changes only in a later PR after all environments are pinned; flag registered in the gwdbx registry. | `gwdbx-flag-registry-gate` (G-22); PR template line "repo default unchanged: yes/no"; `forward-only-authority-audit.yml` blocks reversion. |
| **G6** | **Data migrations run before dependent code, HTTP-only, dry-run default, idempotent, reversible.** | Tool README documents dry-run, execute, re-run-as-no-op and the compensating reverse; owner runs dry-run → execute → dry-run(no-op) and files the JSON summaries; the PR that pins on the migrated shape merges only after the summaries exist for that environment. |
| **G7** | **Startup validators degrade before they throw.** A new invariant first appears as a `/health/ready` Degraded entry; throwing lands in a later PR with proof every environment is green. | Health roster count bumped in the same PR (`GatewayHealthRoster.cs`); the throw PR cites the green `/health/ready` from MSI + staging. |
| **G8** | **Independently deployable and reversible.** Rollback = previous build + env flag off; no coordinated deploy of another service; drains documented (holds → `tools/HoldsAbort`). | PR description carries the rollback line and the staging run id; MSI deploy keeps the previous `jeeb-native-builds/<date>/jeeb-gateway-<sha>` dir. |

---

## 6. Landing strategy — replay as a PR train (working assumption confirmed)

Re-baseline-as-replay stands: 5 gateway commits replay onto today's main with 4 known conflicts (`JeebWalletController.cs`, `JeebWalletProjection.cs`, `OfferPushNotifier.cs`, `JeebWalletProjectionTests.cs`); 74/90 files untouched by main. Merging main into the epic would carry two currency implementations and hand-merged ARB files (OD-15 §4) and cannot express the flag-default and ordering rules above. Each PR below is cut from `origin/main`, stacked only where noted, and must pass §5.

Branch names: gateway `wgf2/g0-gate` … `wgf2/g6-defaults`; mobile `wgf2/m1-guard-ui`. Cherry-pick source: `77f586b` (c3) → `def0f7c` (c2) → `2ad3ba8` (c1) → `86c33a9` (c4) → `dfa9159` (refund); mobile `c4e343fe` rewritten, not cherry-picked.

| Step | PR | Content (replayed commit → adjustments for the rule) | Files / repos | Deploy + verify | Rollback |
|---|---|---|---|---|---|
| 0 | **PR-G0 gate** (gateway) — no behaviour | ADR-0014 (§1); wire `check-openapi-path-method-compatibility.sh` into `ci.yml` for the gateway v1 spec and the wallet slice; add `nswag-wallet-freshness` (regenerate `ServiceWalletClient` from the slice, fail on drift); register the four flags in the gwdbx registry; contract test `WalletGuardContractTests` pinning today's 402 shape, `insufficient-wallet-balance`, `offer-jeeber-insufficient-balance`, `offer_lost` bytes; delete W5-10 comment residue. | `docs/adr/0014-*.md`, `.github/workflows/ci.yml`, `scripts/`, `src/JeebGateway/Services/ServiceWalletClient.cs` (regenerated), `tests/JeebGateway.IntegrationTests/WalletGuardContractTests.cs`, flag registry file | CI only; rides the next combined MSI deploy (P10 C14) | revert PR |
| 1 | **PR-G1 currency** (replay `77f586b`) | Keep `CurrencyId` defaults **1**; add `CommissionCollection:CurrencyCode` (null = today; when set, resolve id by code from `GET Fees/currencies`, cached at boot; explicit `CurrencyId` env still wins); projection pin to the fee currency **only when a code/id is configured**; validator entries as **Degraded** health (`fee-currency-config`), no throw; `tools/WalletCurrencyMigration` as committed (HTTP-only). | `Partner/PartnerWalletOptions.cs` (unchanged default), `Financials/CommissionCollectionOptions.cs`, `JeebWallet/JeebWalletProjection.cs` (conflict: take main's `(currencies, currencyId)` signature, keep epic's spendable/COD filter), `Services/Bff/BffStartupValidator.cs` → health check, `Extensions/GatewayHealthRoster.cs` (+1), `appsettings*.json` (comments only), `tools/WalletCurrencyMigration/**`, tests | **MSI:** owner data run — `WalletCurrencyMigration` dry-run → execute `--confirm currency-one-usd-migration --deactivate-drained` → dry-run reports `holders_skipped=5`; then set env `CommissionCollection__CurrencyId=2`, `CommissionCollection__CurrencyCode=USD` (Partner already 2) → deploy → `/health/ready` `fee-currency-config` Healthy; real-device: balance strip shows USD, offer submit 402 shows USD. **Staging:** new census (`census-staging-<date>.json`) → same run against `jeeb-wallet_staging` → add the two env keys in `jeeb-staging-deploy.yml` → dispatch. | env revert; compensating reverse transaction per tool README (`re-mint ccy-1 wallet with holder/ensure` first if deactivated) |
| 2 | **PR-G2 fail-closed + provisioning** (replay `def0f7c`) | Introduce `WalletGuard:Mode = legacy|aggregate|holds` (default `legacy`); `403 wallet-holder-unresolved` + `503 offer-fee-unresolvable` emitted for Mode≠legacy (legacy keeps today's skip/asymmetry); signup + role-switch best-effort `holder/ensure` (always on — additive, never fails login); `tools/WalletHolderBackfill` with `--users-file` only (delete `--um-connection`/Npgsql). | `Financials/WalletSufficiencyGuard.cs`, `Controllers/{RequestOffersController,OffersController,V1/JeebOffersController}.cs` (type constants + Mode switch), `Auth/OtpSignIn/UsersMeController.cs` (conflict), `Users/WalletProvisioningDualRoleClient.cs`, `Services/Clients/{IOfferServiceClient,OfferServiceClient}.cs` (discriminated fee reads), `tools/WalletHolderBackfill/**`, tests | **MSI:** owner data run `WalletHolderBackfill` dry-run (expect users≈27, incomplete≈22 per w0 census — re-census first) → `--apply` → dry-run `incomplete=0`; deploy with Mode still `legacy`; then env `WalletGuard__Mode=aggregate` → real-device: a jeeber with two open offers gets the aggregate 402 with `outstanding`. Staging: same sequence. | env `WalletGuard__Mode=legacy` |
| 3 | **PR-G3 holds + cap + sweeper** (replay `2ad3ba8`, the 6,025-line commit) | `Holds:Enabled` default **false**, only honoured when Mode=`holds`; `Offers:MaxLiveOffersPerJeeber` default **0** (unlimited); `HoldManager`/`HoldIntentStore`/`HoldSweeper`/`JeeberSubmitSerializer`/`JeeberExposureCalculator` as written; hold calls through the regenerated client (abort/validate/by-external-reference); `tools/HoldsAbort`. Conflict: `JeebWalletController.cs` (take main's currency-resolved balance, keep epic's netted/gross reporting). | `Financials/Holds/**`, `Financials/{JeeberExposureCalculator,JeeberSubmitSerializer,OfferLimitsOptions,WalletCommissionDebitClient}.cs`, `Availability/{AutoOfflineSweeper,IPendingOffersStore,UpstreamPendingOffersStore}.cs`, `Requests/RequestExpiryObserver.cs`, `Program.cs` (DI + hosted service), `Controllers/*` release sites, `tools/HoldsAbort/**`, `WalletGuardConcurrencyTests`, `FakeWalletHoldEngine` | **MSI:** deploy (no behaviour); env `WalletGuard__Mode=holds`, `Holds__Enabled=true`, `Offers__MaxLiveOffersPerJeeber=20` → restart; verify: `select status,count(*) from transactionheader` shows `-1` rows while offers are live and returns to 0 after withdraw/expiry; real-device balance drops while an offer is open; 21st offer → 409 cap copy on the current build **and** on the N−1 build (G4). Staging: same. | env back to `aggregate`; `tools/HoldsAbort` drains pending headers (README) |
| 4 | **PR-G4 truthful push** (replay `86c33a9`) | `NotifyOfferWithdrawnInsufficientBalanceAsync` + `CategoryWallet` (`ShadeAndStored`); emitted only for Mode≠legacy (legacy path keeps `offer_lost`); de-leaked accept-409. Conflict: `OfferPushNotifier.cs` (keep main's four tidy-ups, add the new method). | `Notifications/{OfferPushNotifier,PushSilencePolicy}.cs`, `Observability/BusinessOutcomeTelemetry.cs`, `OfferPushNotifierTests` | MSI deploy; real 2-device proof: accept with an under-funded winner → jeeber sees "Offer withdrawn — top up to keep bidding" (current build) / same EN bytes verbatim (N−1) | env Mode back; nothing to drain |
| 5 | **PR-G5 refund** (replay `dfa9159`) | `FeeRefunder` + `RefundIntentStore` + cancellation/expiry hooks; ADR renumbered **0015**; dormant while `CommissionCollection:Enabled=false`. | `Financials/Refunds/**`, `Requests/Cancellation/CancellationService.cs`, `Controllers/{DeliveriesController,RequestsController}.cs`, `docs/adr/0015-*.md`, tests | MSI deploy; telemetry counter `settlement.refund.skipped-no-capture` increments on a post-accept cancel | revert PR (no data) |
| 6 | **PR-G6 defaults flip (last)** | Repo defaults: `CurrencyId=2`, `CurrencyCode=USD`, `WalletGuard:Mode=holds`, `Holds:Enabled=true`, `MaxLiveOffersPerJeeber=20`; validator promoted from Degraded to throw. Merges only with green `/health/ready` from MSI **and** staging captured under the env pins, and both migration summaries filed. | `appsettings.json`, `appsettings.Production.json`, options classes, `BffStartupValidator.cs` | Deploy; remove the now-redundant env pins in a follow-up (forward-only audit must accept it) | revert PR + re-add env pins |
| M1 | **PR-M1 mobile** (after #335 merges) | Rewrite `c4e343fe` on the `AppFailure` path: type-URI parsing (`kWalletGuardType*`), aggregate sheet (`thisOffer`/`outstanding`), blank currency when absent (no fabricated "USD" — safe because main's gateway already sends `currency`), 9 EN+AR strings + `notificationsKindWalletWithdrawnLabel`, push pins; `wallet_guard_copy_contract_test.dart`, `push_payload_contract_test.dart`. Independent of gateway steps: against an old gateway every new field is null and every new type simply never arrives. | `lib/features/offers/**`, `lib/features/client_offers/**`, `lib/features/notifications/**`, `lib/core/notifications/**`, `lib/l10n/app_{en,ar}.arb` + `app_localizations.dart` (hand-authored — parity script, never one-sided resolution), tests | Ships on the normal internal RC lane (`trusted-*-rc.yml` → `distribute-*`), build numbers > `26090403`/`26090402` | forward-only store rollback (revert PR → new RC) |

Ordering rule restated: **migrate (owner) → deploy additive code with defaults = today → env flip per environment → verify → repo default last.** Steps 0–2 can ride the P10 C14 combined MSI deploy (with P01/P02/P03) because they change no behaviour under default env; step 3 onward gets its own deploy so a rollback never drags an unrelated PR.

---

## 7. Per-consumer compatibility table (state after each step, default env unless flipped)

| Consumer | G0 | G1 (+migration, env pin) | G2 (Mode=aggregate) | G3 (Mode=holds, cap) | G4 | G5 | G6 | M1 |
|---|---|---|---|---|---|---|---|---|
| Mobile current build (main / #335) | unchanged | balance/402 show USD instead of "Credit"/fabricated USD | new 403/503 → #335 `AppFailure` generic copy with retry; 402 `outstanding` ignored | balance drops while offers open; cap 409 → existing cap copy | withdrawn push routed (since #231) | — | — | full copy |
| Mobile N−1 / N−2 builds | unchanged | same | 403/503 → "HTTP n" server error; no crash | cap 409 → cap copy (`limit`/`20` haystack) | EN bytes shown verbatim on pre-#231 builds only | — | — | n/a |
| Partner portal | unchanged | MSI: unchanged (already 2); staging: top-ups move to USD **after** its migration | — | — | — | — | default = env | — |
| jeeb-cms | unchanged (earnings routes still unbacked) | — | — | — | — | — | — | — |
| jeeb-state-service | unchanged | — | — | new `wgf:hold:*` keys (existing KV API) | — | new refund keys | — | — |
| notification-service / push-notification | unchanged | — | — | — | new free-text `event_type` + `category=wallet` | — | — | — |
| wallet-service (jeeb instance) | slice regenerated, no call change | new USD wallets minted by the tool; ccy-1 drained to `__SYSTEM__` | more `holder/ensure` calls | pending headers (`status=-1`, `Tag=hold`) while offers live; `abort` on release | — | refund tx only when collection ON | — | — |
| wallet-service siblings (rahmah, saawt, …) | none | none | none | none | none | none | none | none |
| settlement-service, UPG, delivery, offer-service | none | none | none | none | none | none | none | none |

---

## 8. Tests — contract tests per consumer (fail-before / pass-after, deterministic)

| Consumer boundary | Test (repo) | Pins |
|---|---|---|
| gateway ↔ wallet-service | `tests/JeebGateway.IntegrationTests/WalletContractSliceTests.cs` (new, G0): the generated client's operations ⊆ the pinned slice; slice ⊆ published swagger (path/method script in CI) | no hand-written wallet HTTP; abort/validate/by-external-reference present |
| gateway ↔ wallet-service (holds) | `WalletGuardConcurrencyTests` + `FakeWalletHoldEngine` (epic, replayed): `Reserve_OnSubmit_DecrementsAvailable_ForNextConcurrentSubmit`, `Release_OnWithdraw_RestoresAvailable`, `Capture_OnAccept_ConvertsHoldToDebit` | S-10 netting semantics; I3 (no `execute` while collection off) |
| gateway ↔ mobile | `WalletGuardContractTests` (new, G0, extended per step): exact `type` URIs, 402 extension keys, status codes per Mode; `OfferPushNotifierTests`: wire `type`, `deepLink`, category, EN bytes | additive-only; legacy Mode byte-identical to today |
| mobile ↔ gateway | `test/l10n/wallet_guard_copy_contract_test.dart`, `test/push_payload_contract_test.dart`, `dio_offer_submission_repository_test.dart`, `wallet_withdrawn_inbox_test.dart` (epic, rewritten on `AppFailure`) | same bytes as the gateway tests (copy the constants, never re-type them) |
| old app builds | device smoke, not unit: N−1 APK from `scratchpad/rollback/` against flipped MSI | G4 evidence |
| gateway ↔ state-service | existing idempotency-key tests + `HoldIntentStoreTests` (epic) | prefix-scan + revision semantics unchanged for other users of the KV |
| gateway ↔ notification-service | `GenericEventDispatcherTests` extension: new event type passes the routing/category path; no allow-list assumption | free-text contract |
| config invariants | `BffStartupValidatorTests`: Degraded (G1) → throw (G6) | G7 |
| tools | `WalletCurrencyMigration` dry-run against the committed census (unit: rate derived from catalog, never hard-coded; census drift exit 3); `WalletHolderBackfill` rejects any DSN option | G6, G2 |
| wallet-service (shared) | existing `WalletOpenApiContractTests`, `vocabulary-gate`, plus the compat script job (G1) | additive evolution |

Baselines to respect: gateway CI (`dart`-free) is the `.NET` suite + the five provider/stateless/flag gates in `ci.yml`; mobile main is green at 8257/0 on Flutter 3.44.2 with 16 wall-clock catalog goldens excluded via `--exclude-tags capture` — never blanket `--update-goldens`.

---

## 9. Validation — staging first, then MSI, via the owner-gated paths

1. **CI** on every PR: gateway `ci.yml` + `forward-only-authority-audit.yml` + `zero-dsn-cold-boot.yml` + the two new jobs; mobile `ci-flutter-stage.yml`.
2. **Staging** (`.20` Swarm, `app.jeeb.fds-1.com`): owner dispatches `jeeb-staging-deploy.yml` (protected `environment: staging`, mode + confirm-string inputs) per step. Data runs for staging use the wallet-service loopback on the staging host over the same Cloudflare SSH path the workflow uses; census file committed as `tools/WalletCurrencyMigration/census-staging-<date>.json` before execute. Verify `/health/ready` (expect 27 → 28 entries after G1, `fee-currency-config` Healthy after the pin) and the public probe script `scripts/probe-staging-public-gateway-contract.sh`.
3. **MSI** (dev, `192.168.2.39:10090` / `msi.olivium.space/gateway`): native build into `jeeb-native-builds/<date>/jeeb-gateway-<sha>`, repoint, restart (`Restart=always`), previous dir kept; env keys added to the `90-jeeb-staging-20260828.conf` drop-in or `gateway.env` with a `.pre-<date>` backup (sanctioned recipe in memory `jeeb-live-backend-on-msi`). Steps 0–2 ride the P10 C14 combined deploy; steps 3–6 are separate dispatches.
4. **Real-flow proof** (owner mandate): two physical phones, real OTP/taps, super-login allowed for non-login features. Scenarios per step are in §6 "Deploy + verify"; evidence under `scratchpad/device-evidence-*/p15/<step>/` with the gateway SHA, env diff, `/health/ready` JSON, and the wallet-DB pending-header counts before/after.
5. **Order of environments:** the rule says staging then MSI for *validation*; for the **data runs** the smaller, better-known DB is MSI (census already committed), so: MSI data run → MSI env pin → staging census → staging data run → staging env pin. Code deploys follow staging → MSI as usual. Neither order can strand value because the tool is independent of the gateway setting.

---

## 10. Risks

| Risk | Likelihood / impact | Mitigation |
|---|---|---|
| Validator throws on an environment that pins only one currency key (C2) | High if replayed as-is / gateway down | Degrade-first (G7); throw only in G6 |
| Currency migration executed before its census is re-verified → `census_drift` exit 3 or value moved for the wrong holder | Low / money | Tool refuses on drift; owner runs dry-run twice; compensating reverse documented |
| Staging DB balances unknown (F5) | Medium / silent flip on G6 | Staging census + run gated before G6; G6 cites both summaries |
| Holds leak if the gateway dies between `initiate` and the intent write | Low / frozen funds | I2 (intent written first) + `HoldSweeper` + `tools/HoldsAbort`; zero pending headers today makes the first flip trivially drainable |
| Old app shows "cap reached" for the live-limit 409 (haystack match) — acceptable but imprecise | Certain on N−1 | Copy is truthful enough; M1 fixes on the current lane |
| `app_localizations.dart` hand-merge drops an accessor | Medium / silent | Parity script + `wallet_guard_copy_contract_test.dart`; never one-sided ARB resolution |
| wallet-service still unauthenticated → any LAN-proxied caller can mint/move money; `api/Wallet` passthrough auth unverified | Pre-existing / high | Out of scope by owner deferral; §12 item; the epic does not widen exposure (loopback-only, same host) |
| Regenerated `ServiceWalletClient` (+1,574 lines on main) drifts again | Medium / build break | `nswag-wallet-freshness` job (G2) |
| Shared-repo change to wallet-service CI (compat job) is itself a change to a shared repo | Low / none at runtime | CI-only, additive; sibling deploys untouched |
| UPG `WALLET_WEBHOOK_URL` targets a non-existent wallet route | Pre-existing, dormant (`CASH_GATEWAY_ENABLED` off) | Not in this plan; note for the UPG owner |

---

## 11. Effort

| Work | Estimate |
|---|---|
| PR-G0 gate wiring + regenerate client + contract test skeleton | 0.5 d |
| PR-G1 currency (replay c3, Mode/code resolver, validator→health, tool) | 1.0 d |
| PR-G2 fail-closed + provisioning (replay c2, Mode flag, backfill file-only) | 1.0 d |
| PR-G3 holds/cap/sweeper (replay c1, 6k lines, generated-client calls, 2 conflicts) | 1.5–2.0 d |
| PR-G4 push (replay c4, 1 conflict) | 0.5 d |
| PR-G5 refund (replay, ADR renumber) | 0.5 d |
| PR-G6 defaults flip | 0.25 d |
| PR-M1 mobile rewrite on `AppFailure` + strings + tests (after #335) | 1.0 d |
| Contract tests both sides beyond what the epic carries | 0.5–1.0 d |
| Validation: staging + MSI, two devices, N−1 smoke, evidence | 1.0–1.5 d |
| **Engineering total** | **≈ 8–10 dev-days** (vs. ≈1 day for a bare replay — the difference is the rule: flags, degrade-first, gate wiring, per-env runs) |
| Owner time | ≈ 2 h: 4 data runs (2 tools × 2 environments), ~7 deploy dispatches, 3 decisions below |

---

## 12. What still needs the owner

| ID | Question | Recommended answer |
|---|---|---|
| OD-15a | Confirm the PR-train landing (§6) as the implementation of the hard rule (replaces the rebaseline/mergemain choice). | yes |
| OD-15b | Cap 20: repo default only in PR-G6 (env-only until then, consistent with rule 4) or baked from PR-G3 (non-breaking either way since old apps render it)? | env-only until G6 |
| OD-15c | Data runs (owner-executed per RULINGS 8/11): `WalletCurrencyMigration` + `WalletHolderBackfill` on MSI, then a staging census + the same runs against `jeeb-wallet_staging`. | approve, in that order |
| OD-15d | `WalletHolderBackfill`: drop `--um-connection` (user ids supplied as a file exported from user-management) to honour "no cross-service DSN". | yes |
| OD-15e | Wallet-service authentication (deferred c5 / SS-1, SS-2) remains the one structural independence gap; also confirm the gateway `api/Wallet` passthrough is covered by the global auth policy. Schedule as the next wallet PR after G6 (sender-first rollout: tolerate → send → require; shared repo, additive, per-product deploy). | schedule after G6 |
| OD-15f | Deploy dispatches: G0–G2 on the P10 C14 combined MSI deploy + one staging dispatch; G3–G6 as separate dispatches (so a rollback never drags P01/P02/P03). | yes |

Nothing in this plan requires a change to any sibling product, to settlement-service, delivery-service, offer-service, notification-service, push-notification, jeeb-state-service, jeeb-cms, or to wallet-service runtime code; the single shared-repo touch is the additive CI compatibility job (G1), which is itself optional for landing the epic.

---

## Appendix — evidence commands (read-only, re-runnable)

```bash
# gateway: epic vs main, conflicts, no DSN
git -C jeeb-gateway rev-list --count origin/main..origin/epic/wallet-guard-fix   # 5
git -C jeeb-gateway merge-tree --write-tree origin/main origin/epic/wallet-guard-fix  # 4 conflicts
git -C jeeb-gateway grep -nE '^\s*using Npgsql|new NpgsqlConnection' origin/main -- src | wc -l  # 0
git -C jeeb-gateway show origin/main:.github/workflows/jeeb-staging-deploy.yml | sed -n 902,906p  # WalletPostgres retired
# wallet-service: pending netting + hold primitives in the deployed build
git -C wallet-service show 73f2cfe:Data/Repositories/WalletRepository.cs | sed -n 91,111p
git -C wallet-service show 73f2cfe:Controllers/TransactionController.cs | grep -nE 'abort|by-external-reference|validate'
# live MSI (ec2-user; no sudo needed)
ssh msi-ec2-cloudflare "grep -iE 'Wallet|Commission' ~/iter5-native/env/gateway.env; curl -s 127.0.0.1:10014/Fees/currencies"
ssh msi-ec2-cloudflare "psql -h 127.0.0.1 -p 5442 -U postgres -d jeeb-wallet -Atc \"select currencyid,type,isactive,count(*),sum(amount) from wallets group by 1,2,3 order by 1,2,3\""
ssh msi-ec2-cloudflare "psql -h 127.0.0.1 -p 5442 -U postgres -d jeeb-wallet -Atc \"select status,count(*) from transactionheader group by 1\""  # 0|7
# mobile: old-build fallbacks and push handling
git -C jeeb-mobile-worktrees/ux-api-errors show origin/main:lib/features/offers/data/dio_offer_submission_repository.dart | sed -n 59,118p
git -C jeeb-mobile-worktrees/ux-api-errors log -S offer_withdrawn_insufficient_balance --format='%h %ad %s' --date=short origin/main -- lib/core/notifications/domain/notification_message.dart | tail -1  # 911ef641 2026-08-08 (#231)
```
