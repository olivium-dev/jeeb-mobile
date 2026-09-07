# PLAN P01-dm-onboarding-route v2 — form-builder submit contract, persisted in user preferences through the gateway

> **Superseded by [P01 v3](PLAN-P01-dm-onboarding-route.v3.md) (2026-09-06).** Historical design only; execute nothing below. The current plan implements the owner's form-builder → mobile renderer → gateway → user-preferences direction, including the review corrections to deployment and template ownership.

Status: PLAN ONLY (no repo file changed). Author: Fable 5.1 principal, 2026-09-06. Supersedes v1
(`PLAN-P01-dm-onboarding-route.md`) after the owner answered OD-1 with free text:
**"Keep using the formbuilder, store the data in the user preferences (through gateway)"** and OD-2 with
`nobbox` ("Mechanism only, no Production bbox"). Repos: `olivium-dev/jeeb-gateway` (new branch off `origin/main`
`6679f6ee`), `olivium-dev/jeeb-mobile` (flip lands off post-merge `main`, never on PR #335 — deploy-order reason, see §5).
Never a new repo. Deploys are owner-gated: this plan PREPARES a deploy, never executes one.

---

## 0. What exists live today (measured 2026-09-06, `https://msi.olivium.space/gateway` = origin/main `6679f6e`)

| Surface | Live answer | Meaning |
|---|---|---|
| `POST /form-builder-service/v1/templates/jeeb_jeeber_v1/submit` no bearer | **401** `application/problem+json` (`rfc9110#section-15.5.2`) | L1 fallback auth policy fires before routing |
| same, minted jeeber bearer (Karim `106078a3…`, roles `jeeber,client`) | **404** `application/problem+json` (`rfc9110#section-15.5.5`) | genuine gateway 404 — no such route; not a Cloudflare drop |
| `POST /form-builder/templates/jeeb_jeeber_v1/submit` bearer | **404** problem+json | the gateway-native namespace has no submit route either |
| `GET /form-builder/templates/jeeb_jeeber_v1/schema` bearer | **200** — 11 KYC components (`id_document_front_url … tos_accepted_version`) | form-builder-service IS live behind the gateway |
| `GET /form-builder/templates` bearer | **500** `https://jeeb.dev/errors/internal-error` | live defect: `ListTemplatesAsync` binds `List<FormTemplateSummary>`, upstream emits `{ "jeeb_jeeber_v1": [...] }` (journal: `FormBuilderServiceClient.cs:46`) |
| `GET /form-builder/templates/nope` bearer | raw MSI: **502** problem+json `upstream-unavailable`; via Cloudflare: text/plain `error code: 502` | upstream 4xx → `HttpRequestException` → 502; Cloudflare replaces 502 bodies. v1's "Cloudflare dropped the connection" was this |
| `GET /api/UserPreferences/preferences` bearer | **200** `{}` | user-preferences endpoint FOUND, healthy, empty for Karim |
| `GET /api/UserPreferences/preferences/jeeb.saved_locations` bearer | **404** problem "Upstream user-preferences error" | per-key read; absent key = upstream 404 relayed |
| `GET /api/users/me/saved-locations` bearer | **200** `{"userId":"106078a3…","items":[],"defaultId":null}` | RUP-backed BFF path healthy |
| `GET /v1/notifications/preferences` bearer | **200** (six toggles) | RUP-backed BFF path healthy |
| `GET /health/ready` | overall Degraded; `form-builder-service Healthy`, `user-management Healthy` | — |
| MSI process | `jeeb-form-builder.service` → `python -m app.main --port 10070`, release `form-builder-service-801ef01-20260828`, `TEMPLATE_JSON_FILES=generated_jeeb_jeeber_v1.json`, `DATABASE_URL=…127.0.0.1:5442/jeeb_form_builder` | ONE registered template; upstream routes `POST /forms/jeeb_jeeber_v1`, `GET /forms/jeeb_jeeber_v1/{form_id}` generated per template at startup (`app/main.py:155-172`) |
| MSI gateway env | `FeatureFlags__UseUpstream__FormBuilder='true'`, `Services__FormBuilder__BaseUrl='http://127.0.0.1:10070/'`, `FeatureFlags__UseUpstream__RemoteUserPreferences='true'`, `RemoteUserPreferencesServiceApi__BaseUrl='http://127.0.0.1:10067'`, `ASPNETCORE_ENVIRONMENT='Production'` | both upstreams ON |
| RUP direct on MSI `GET 127.0.0.1:10067/preferences/106078a3…` | **200** `{}` | Rust remote-user-preferences up |

## 1. Problem (verified)

Unchanged from v1 §1 (E1–E12 stand): the jeeber onboarding wizard posts to a route nobody serves and swallows
the 404 as success, so nothing is persisted. New evidence for the re-plan:

| # | Fact | Where |
|---|---|---|
| E13 | "The formbuilder" = the fleet's `form-builder-service` (FastAPI, dynamic form templates, PG `jeeb_form_builder`), fronted by the gateway's `FormBuilderController` `[Route("form-builder")]`: `GET templates`, `GET templates/{t}`, `GET templates/{t}/schema`, `POST forms/{t}` (upstream PG insert → `submission_id`), `GET forms/{t}/{id}`, `GET languages`; class-level `[PublicEndpoint]` (L2), L1 auth still required; gated by `UseUpstream:FormBuilder` (Production `true`) | `src/JeebGateway/Controllers/FormBuilderController.cs:32-38,57,72,91,115,143,170`; `Services/Clients/IFormBuilderServiceClient.cs:12-21`; `appsettings.Production.json:34,158-160`; `tests/…/FallbackPolicyUniformAuthTests.cs:20-23,39` |
| E14 | The only registered template is `jeeb_jeeber_v1` = the Jeeb **KYC** field set; the KYC BFF reads it via `SchemaAsync` for `GET /v1/kyc/jeeb/form-schema`; KYC submit goes to kyc-service (`/v1/kyc/submit`), never to `POST /form-builder/forms/*` | `Controllers/KycBffController.cs:51,98,111`; `Controllers/KycSubmissionBffController.cs:239`; `product/form-builder/flavors/jeeb_jeeber_v1/national_id.json` (11 fields, no address/home-base); MSI `TEMPLATE_JSON_FILES` |
| E15 | Jeeb form templates are DATA owned by the gateway repo (`product/form-builder/flavors/**`, Golden Rule 2); registering one in form-builder-service = a JSON file + `TEMPLATE_JSON_FILES` + restart of the shared service | `product/form-builder/README.md:1-24`; `product/form-builder/README-jeeb-kyc.md:12-20`; form-builder-service `app/main.py:29-40,155-172` |
| E16 | "User preferences" = remote-user-preferences (Rust `:10067`) reached ONLY through the gateway: (a) generic me-scoped surface `UserPreferencesController` `/api/UserPreferences/preferences[/{pref_key}]` (GET/POST/PUT, string values, `[RequireCapability(NotificationPrefsSelf)]`, no flag gate, unused constants `fullName`/`address`), (b) typed BFF stores that keep one JSON blob per namespaced key (`jeeb.saved_locations`, `jeeb.notification_prefs`) | `Controllers/UserPreferencesController.cs:15-24,321-419`; `Program.cs:586-600,1704-1734`; `Users/SavedLocations/RemoteUserPreferencesSavedLocationStore.cs:8-48,204-256`; `NotificationPreferences/RemoteUserPreferencesNotificationPreferencesStore.cs:27-93`; contract `src/JeebGateway/contracts/remote-user-preferences.openapi.json` (`POST/PUT /preferences/{user_id}/{pref_key}`) |
| E17 | RUP values are free-form strings (`PreferenceValue.Value : string`); a key holds any JSON → the onboarding record fits with **no schema change** anywhere | `Services/Generated/ServiceRemoteUserPreferencesClient.cs:1872-1880`; live `GET /api/UserPreferences/preferences` → `{}` |
| E18 | The mobile path is the **jeeb-mock-backend** route: `POST /v1/templates/:templateId/submit` → 201 `{ submissionId }`, template registry = one KYC-shaped `jeeb_jeeber_v1`, no 409/coverage logic; the mobile constant is the already-prefixed mock path (mock-mode rewriting `/v1/templates → /form-builder-service/v1/templates` only applies when `useMockPrefixes`) | `jeeb-mock-backend/src/services/form-builder-service.ts:9-26,37-52`; mobile `lib/core/network/mock_gateway_client.dart:84,98-110`; `lib/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart:64-67` |
| E19 | Mobile `notification_prefs` talks to `/v1/notifications/preferences` (the typed BFF), not to `/api/UserPreferences/*`; no mobile code calls the generic preferences surface today | `lib/features/notification_prefs/data/dio_notification_prefs_repository.dart:13` |
| E20 | Saved-locations is the closest sibling of "address-like data in RUP": `ProfileReadSelf`/`ProfileWriteSelf` (§B any-authenticated), 502 `dependency-unavailable` on unanswered read, 504 `upstream-timeout` on write budget | `Controllers/SavedLocationsController.cs:16,27,68,136-148`; `Auth/Capabilities/Capabilities.cs:32-36` |
| E21 | Owner record: OD-1 = the sentence above; OD-2 = `nobbox`; OD-3 = `combined`; OD-0 = `widen` | mobile worktree `docs/ux-failure-states/DECISIONS.md:5-8` |

## 2. Root cause

As v1 §2: the wizard was built against the mock's `form-builder-service` submit path while the real gateway grew
KYC on `/v1/kyc/*` and never grew a home-base/address write; WP-8b's fail-safe made the gap silent. The re-plan
adds: the mock's `jeeb_jeeber_v1` was itself a KYC-shaped template, so the DM wizard has been posting address/home-base
into a KYC form name from day one — the template name, not only the route, was an accident.

## 2b. Reading the owner's sentence

| Reading | What it would mean | Fits what exists? |
|---|---|---|
| **A — gateway implements the form-builder submit contract, stores in preferences** | Mobile keeps posting a template-named submit in the form-builder namespace (`/form-builder/templates/{t}/submit`, 201 `{submissionId}` — the only contract the path ever had, E18). The gateway is the form-builder BFF (same controller namespace as E13) and persists the submission as one JSON blob per user in remote-user-preferences (E16 pattern). form-builder-service is NOT dialed on the write path. | **Yes.** Zero gateway DB, no new service, no ops change on a shared service, the coverage mechanism OD-2 asked for lives in the handler, "through gateway" = the established RUP pattern (gateway is the only writer). |
| B — mobile writes straight to `/api/UserPreferences/preferences/jeeb.jeeber_onboarding` | Zero gateway change, deployable today (E16a is live). | **No.** No server validation, no coverage mechanism (contradicts OD-2 "mechanism only" which still ships a mechanism), string-typed body, `notification.prefs.self`, and nothing "form-builder" remains — the owner's first clause would be empty. |
| C — form-builder-service validates a registered onboarding template, gateway stores in preferences | The gateway calls `SchemaAsync`/the upstream model on submit, then writes the blob. | **Only after an ops change:** the sole registered template is the KYC field set (E14); an onboarding template must be authored (`product/form-builder/flavors/…`, E15), generated, added to `TEMPLATE_JSON_FILES` and the shared service restarted on MSI **and** staging (owner-gated). `POST /forms/{t}` would also write to form-builder's PG, which the owner did not ask for. C = A + that prerequisite. |

**Chosen: A.** It is the smallest design that satisfies both clauses with what is deployed: the form-builder submit
contract (namespace, template-named route, 201 `{submissionId}`, `Idempotency-Key`) is kept and served by the gateway;
persistence is remote-user-preferences through the gateway, exactly like saved-locations and notification
preferences. C stays one confirmed "NO" away (§9) and is pre-planned so no rework is needed.

## 3. Decision

1. **Route** (gateway-native form-builder namespace): `POST /form-builder/templates/{templateName}/submit` (upsert)
   + `GET /form-builder/templates/{templateName}/submission` on a NEW controller `FormSubmissionsBffController`
   (`[Route("form-builder")]` — coexists with `FormBuilderController`, distinct templates). `me`-scoped via
   `UserIdentity.TryGetUserId`; no userId in the path. Template allow-list of one: **`jeeb_jeeber_onboarding_v1`**
   (unknown → 404). Rationale for the name: `jeeb_jeeber_v1` is the KYC template on both form-builder-service and
   `KycBffController` (E14); reusing it would make the gateway validate "jeeb_jeeber_v1" with rules that contradict its
   own schema and would block reading C later. Mobile changes one constant either way.
2. **Capability**: `Capabilities.ProfileWriteSelf` (POST) / `ProfileReadSelf` (GET) — mirrors the saved-locations
   sibling (E20); §B any-authenticated {client, jeeber, admin}, so a client upgrading to jeeber holds it. This closes
   v1's kyc-vs-profile question: the store, not the funnel, decides. (`NotificationPrefsSelf`, what
   `UserPreferencesController` uses, is the equally valid alternative — CTO default, no owner answer needed.)
3. **Persistence**: one JSON blob under key **`jeeb.form.<templateName>`** (→ `jeeb.form.jeeb_jeeber_onboarding_v1`)
   in remote-user-preferences via a new `RemoteUserPreferencesFormSubmissionStore` (copy of the notification-prefs
   store idiom, E16b). Zero gateway DB, no InMemory owner (stateless roster unchanged), no new feature flag.
   The blob is readable today through the generic surface `GET /api/UserPreferences/preferences/jeeb.form.jeeb_jeeber_onboarding_v1`
   (E16a) — which is the live proof that "the data is in the user preferences".
4. **Coverage (OD-2 = mechanism only)**: `ZoneBoundary` list bound from `JeeberOnboarding:Coverage` with
   `FailOpenWhenUnconfigured=true`, **`Boundaries: []` in BOTH `appsettings.json` and `appsettings.Production.json`**.
   Every environment answers 201 with `coverage.checked=false` until an owner configures boundaries (env override
   `JeeberOnboarding__Coverage__Boundaries__0__{Key,Name,MinLatitude,…}` + restart, or a later appsettings PR). The 409
   path (`https://jeeb.dev/errors/out_of_coverage`) ships fully tested but is dormant live; no Nicosia curl proof.
5. **form-builder-service is not called on this path** (reading A). The FormBuilder feature flag does not gate it.
6. **Mobile**: `submitPath = '/form-builder/templates/jeeb_jeeber_onboarding_v1/submit'`; the 404/405/501 fail-safe is
   removed ONLY in the post-deploy flip PR; 409 discriminator = `typeSuffix == 'out_of_coverage' || reasonCode == 'out_of_coverage'`.
7. **Ordering**: gateway merged AND deployed (one combined MSI deploy + one staging dispatch, OD-3) BEFORE the mobile
   flip is built for any device; PR #335 keeps the fail-safe. OD-0 = `widen` does not move the flip onto #335 — the
   constraint is deploy order (a flipped build against a gateway without the route blocks the funnel), not scope.

## 4. Contract

### 4.1 `POST /form-builder/templates/{templateName}/submit`

Headers: `Authorization: Bearer <jeeb-clients token>`; optional `Idempotency-Key` (gateway-wide middleware replays
the first response verbatim, v1 E11); `Content-Type: application/json`.

Body = the template's component values, verbatim what mobile already sends (`DmOnboardingSubmission.toJson()`):
```json
{ "state": "Beirut", "country": "Lebanon", "street": "Hamra", "address": "Bldg 1",
  "home_base_lat": 33.8938, "home_base_lng": 35.5018, "home_base_label": "Hamra",
  "portrait_object_ref": "cdn/objects/portrait-1" }
```
Rules for `jeeb_jeeber_onboarding_v1` (gateway code, first violation wins, 400 `https://jeeb.dev/errors/validation`
+ `field` extension — `KycSubmissionBffController.FieldProblem` idiom): `state`, `country`, `address` non-blank ≤ 256
(`street` may be blank, ≤ 256); `home_base_lat` ∈ [-90, 90], `home_base_lng` ∈ [-180, 180], both required and finite;
`home_base_label` ≤ 256; `portrait_object_ref` optional ≤ 512. Null / non-object body → 400 `https://jeeb.dev/errors/invalid-request`.
Unknown `templateName` (not allow-listed, or > 256 chars) → 404 `https://jeeb.dev/errors/not-found` ("Unknown form template").

Coverage: only when `JeeberOnboarding:Coverage:Boundaries` is non-empty and no box contains the point →
```json
{ "type": "https://jeeb.dev/errors/out_of_coverage", "title": "Outside the service area", "status": 409,
  "detail": "The home base is outside every served zone.", "reasonCode": "out_of_coverage", "zonesConfigured": 1 }
```
With OD-2 this never fires in any environment until boundaries are configured.

Success **201** (upsert — a re-run of the wizard replaces the record; a replayed `Idempotency-Key` returns the same body):
```json
{ "submissionId": "9f0c2b6e-…", "templateName": "jeeb_jeeber_onboarding_v1", "userId": "106078a3-…",
  "data": { "state": "Beirut", "country": "Lebanon", "street": "Hamra", "address": "Bldg 1",
            "home_base_lat": 33.8938, "home_base_lng": 35.5018, "home_base_label": "Hamra",
            "portrait_object_ref": "cdn/objects/portrait-1" },
  "coverage": { "checked": false, "zoneKey": null },
  "submittedAt": "2026-09-06T07:00:00Z" }
```
(Envelope camelCase like every gateway BFF response; `data` echoes the form's component names verbatim, as
`FormBuilderController` carries form bodies verbatim. `coverage.checked=true, zoneKey="<Key>"` once boundaries exist.)
Upstream: 502 `https://jeeb.dev/errors/dependency-unavailable` (store threw `UserPreferencesUnavailableException`),
504 `https://jeeb.dev/errors/upstream-timeout` (write budget exceeded → `TimeoutException`) — exactly `SavedLocationsController`.
401 no identity. 403 only for a principal outside {client, jeeber, admin} (capability guard).

### 4.2 `GET /form-builder/templates/{templateName}/submission`
200 with the §4.1 success body; 404 `https://jeeb.dev/errors/not-found` ("No submission for this template") when the blob is
absent; 404 unknown template; 502 as above. Consumers: §7 proof and a future resume; mobile does not call it in this plan.

### 4.3 Stored blob (`jeeb.form.jeeb_jeeber_onboarding_v1`, version 1)
```json
{ "version": 1, "submissionId": "…", "templateName": "jeeb_jeeber_onboarding_v1",
  "data": { "state": "…", "country": "…", "street": "…", "address": "…",
            "home_base_lat": 0, "home_base_lng": 0, "home_base_label": "", "portrait_object_ref": null },
  "coverage": { "checked": false, "zoneKey": null }, "submittedAt": "…" }
```
Read back through the generic surface as `{"value": "<this JSON as a string>"}` (E16a/E17).

## 5. Fix steps (ordered)

### Gateway — repo `jeeb-gateway`, branch `feat/form-submissions-preferences` off `origin/main`

Prereq (C14, worktree not `switch`; the local checkout is 515 commits stale):
`git -C jeeb-gateway fetch origin && git -C jeeb-gateway worktree add ../jeeb-gateway-worktrees/p01-onboarding -b feat/form-submissions-preferences origin/main`

G1. `src/JeebGateway/FormSubmissions/FormSubmissionRecord.cs` (new): stored blob of §4.3 (`Version`, `SubmissionId`,
   `TemplateName`, `Data : JsonElement`, `Coverage`, `SubmittedAt`) + response DTO `FormSubmissionResponse` (§4.1 envelope,
   `[JsonPropertyName]` camelCase) + `CoverageDto { Checked, ZoneKey }`.
G2. `src/JeebGateway/FormSubmissions/IFormSubmissionStore.cs` (new):
   `Task<FormSubmissionRecord?> GetAsync(string userId, string templateName, CancellationToken ct);`
   `Task SetAsync(string userId, string templateName, FormSubmissionRecord record, CancellationToken ct);`
G3. `src/JeebGateway/FormSubmissions/RemoteUserPreferencesFormSubmissionStore.cs` (new): copy the shape of
   `NotificationPreferences/RemoteUserPreferencesNotificationPreferencesStore.cs` — `IServiceScopeFactory` + lazily
   scoped `ServiceRemoteUserPreferencesClient`; key `$"jeeb.form.{templateName}"`; read budget 1500 ms / write 2000 ms;
   `Data_GetSinglePreferenceAsync` (ApiException 404 → null); write = `Data_UpdatePreferenceAsync`, on ApiException 404 →
   `Data_SetSinglePreferenceAsync` (whole-record upsert, no pre-read). Unanswered read → `UserPreferencesUnavailableException`;
   write budget → `TimeoutException`. Never log the blob body.
   ```csharp
   // Whole-record upsert: PUT first, POST on 404 (same idiom as the notification-prefs store).
   try { await client.Data_UpdatePreferenceAsync(userId, key, new PreferenceValue { Value = json }, budget.Token); }
   catch (ApiException ex) when (ex.StatusCode == 404)
   { await client.Data_SetSinglePreferenceAsync(userId, key, new PreferenceValue { Value = json }, budget.Token); }
   ```
G4. `src/JeebGateway/FormSubmissions/JeeberOnboardingFormTemplate.cs` (new): `public const string Name = "jeeb_jeeber_onboarding_v1";`,
   `JeeberOnboardingSubmitBody` (`[JsonPropertyName]` snake_case fields of §4.1) and
   `static (string field, string detail)? Validate(JeeberOnboardingSubmitBody b)` implementing the §4.1 rules.
   `src/JeebGateway/FormSubmissions/FormTemplateRegistry.cs` (new, tiny): `IsKnown(templateName)` → allow-list `{ Name }`.
   ```csharp
   // Allow-list of templates the gateway persists into user preferences; anything else is 404.
   private static readonly HashSet<string> Known = new(StringComparer.Ordinal) { JeeberOnboardingFormTemplate.Name };
   ```
G5. `src/JeebGateway/FormSubmissions/JeeberOnboardingCoverageOptions.cs` + `JeeberOnboardingCoverageResolver.cs` (new) —
   verbatim v1 G4: `SectionName = "JeeberOnboarding:Coverage"`, `List<ZoneBoundary> Boundaries`,
   `bool FailOpenWhenUnconfigured = true`; `Resolve(lat, lng)` → `(inCoverage, checked, zoneKey)`; empty + FailOpen →
   `(true, false, null)`; empty + !FailOpen → `(false, true, null)`.
G6. `src/JeebGateway/Controllers/FormSubmissionsBffController.cs` (new): `[ApiController]`, `[Route("form-builder")]`,
   `[HttpPost("templates/{templateName}/submit")]` `[RequireCapability(Capabilities.ProfileWriteSelf)]`,
   `[HttpGet("templates/{templateName}/submission")]` `[RequireCapability(Capabilities.ProfileReadSelf)]`,
   `[Consumes("application/json")]`, `ProducesResponseType` rows 200/201/400/401/403/404/409/502/504.
   Flow: template known? → identity (`UserIdentity.TryGetUserId`) → bind body to `JeeberOnboardingSubmitBody` →
   `Validate` → coverage → `SetAsync` → 201. Problem helpers as §4.1/4.2 (types `https://jeeb.dev/errors/<code>`).
   `submissionId = Guid.NewGuid()` per write (replay returns the captured response, so the id is stable per key).
   Two-line comments max.
G7. `src/JeebGateway/Program.cs`: after `builder.Services.AddSavedLocations();` (~line 1734) add
   `builder.Services.Configure<JeeberOnboardingCoverageOptions>(builder.Configuration.GetSection(JeeberOnboardingCoverageOptions.SectionName));`
   `builder.Services.AddSingleton<IJeeberOnboardingCoverageResolver, JeeberOnboardingCoverageResolver>();`
   `builder.Services.AddSingleton<IFormSubmissionStore, RemoteUserPreferencesFormSubmissionStore>();`
   (unconditional, like `UserPreferencesController`'s client — the store degrades to 502 when `:10067` is absent; no
   InMemory fallback, so `scripts/stateless-gateway-ownership-roster.txt` needs NO row and `check-stateless-gateway.sh`
   stays green — its scan only matches `InMemory*`/`Postgres*` type names).
G8. `scripts/gwdbx-flag-registry.txt` (G-22 one-way containment, `setting -` shape as rows 133-134):
   `JeeberOnboarding:Coverage:Boundaries                  setting - # P01 bbox list; empty = fail-open (OD-2: empty in Production)`
   `JeeberOnboarding:Coverage:FailOpenWhenUnconfigured    setting - # P01 default true`
   Run `bash scripts/check-gwdbx-flag-registry.sh` until OK.
G9. `src/JeebGateway/appsettings.json` AND `appsettings.Production.json`: add
   `"JeeberOnboarding": { "Coverage": { "Boundaries": [], "FailOpenWhenUnconfigured": true } }` — identical in both
   (OD-2 `nobbox`). No `gateway.env` change.
G10. Tests (xUnit + FluentAssertions, `WebApplicationFactory<Program>`, `X-User-Id` + `X-User-Roles` headers as in
   `tests/JeebGateway.IntegrationTests/SavedLocationsEndpointTests.cs:26-32`):
   - `tests/JeebGateway.IntegrationTests/FormSubmissions/FormSubmissionsEndpointTests.cs` (new): nested `Factory`
     that `RemoveAll<IFormSubmissionStore>()` + `AddSingleton<IFormSubmissionStore, FakeFormSubmissionStore>()` (dictionary
     keyed `(userId, templateName)`), and for the 409 cases `UseSetting("JeeberOnboarding:Coverage:Boundaries:0:Key","beirut")`
     … `MinLatitude 33.80 / MaxLatitude 34.00 / MinLongitude 35.40 / MaxLongitude 35.60`. Cases: 401 no identity;
     201 `driver` (+ blob persisted under `jeeb.form.jeeb_jeeber_onboarding_v1`, `coverage.checked == false` with default
     config); 201 `customer`; 201 `admin` (self-scoped, §B); 404 unknown template on POST and GET; 400 missing `state`
     (`field == "state"`); 400 `home_base_lat` 95; 400 non-object body → `invalid-request`; GET 404 before / 200 after
     POST with the same `submissionId`; 409 outside the configured box (`type` + `reasonCode` + `zonesConfigured == 1`);
     201 inside the box with `coverage.zoneKey == "beirut"`; 502 `dependency-unavailable` when the fake throws
     `UserPreferencesUnavailableException`; 504 `upstream-timeout` when it throws `TimeoutException`.
   - `tests/JeebGateway.UnitTests/JeeberOnboardingCoverageResolverTests.cs` (new): empty+failOpen, empty+!failOpen,
     inside, outside, edge-inclusive. `tests/JeebGateway.UnitTests/JeeberOnboardingFormTemplateTests.cs` (new): each rule.
   - `CapabilityCoverageGuardTests` needs no edit (both actions carry `[RequireCapability]`) — run it.
G11. `bash scripts/export-openapi.sh` then `bash scripts/check-openapi-path-method-compatibility.sh <base> <candidate>`
   (the gate only forbids REMOVED path/methods; two additive paths pass). Commit the regenerated
   `artifacts/openapi/jeeb-gateway.v1.json` if its diff is only the two new paths.
G12. Gate: `dotnet restore src/JeebGateway/JeebGateway.csproj --locked-mode`, `dotnet build`, `dotnet test tests/JeebGateway.UnitTests`,
   `dotnet test tests/JeebGateway.IntegrationTests`, `bash scripts/check-stateless-gateway.sh`, `bash scripts/check-gwdbx-flag-registry.sh`.
   PR to `main`: `feat(form-builder): POST/GET /form-builder/templates/{t}/submit|submission — persisted in user preferences (P01 v2)`.
G13. PREPARE deploy (do not execute): rides the OD-3 combined deploy — MSI native = the owner's standard gateway deploy of
   the merged SHA (`~/jeeb-native-builds/<date>/jeeb-gateway-<sha>` + systemd drop-in; no env change); staging =
   `.github/workflows/jeeb-staging-deploy.yml` dispatch (protected env + confirm string). Hand the owner §7A.

### Mobile — repo `jeeb-mobile`, branch `fix/dm-onboarding-route` off post-merge `main`

Land ONLY after G13 is live on MSI and staging (§3(7)). PR #335 keeps the fail-safe unchanged.

M1. `lib/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart:64-67`:
   `static const String submitPath = '/form-builder/templates/jeeb_jeeber_onboarding_v1/submit';`
   `static const String outOfCoverageReason = 'out_of_coverage';` Replace the "NOT deployed" doc comment with a
   two-line pointer to this plan / gateway PR #. Interface unchanged (R3: 5 `implements` sites incl.
   `lib/devtool/catalog/fixtures/dm_onboarding_screen_fixtures.dart:18,118,127`, `FakeDmOnboardingGateway`, `_RecordingGateway`).
M2. `lib/features/jeeber_onboarding/data/dio_dm_onboarding_gateway.dart:29-44`: delete the `return;` on 404/405/501 —
   keep `Diag.event('dm_onboarding_submit_route_absent', {'status': status})`, then fall through to
   `throw DmOnboardingGatewayException(AppFailure.of(e))`. Discriminator:
   `failure is ConflictFailure && (problem?.typeSuffix == outOfCoverageReason || problem?.reasonCode == outOfCoverageReason)`;
   delete `_reasonOf`/`_lastSegment` and their D1 comment (the gateway emits `…/errors/out_of_coverage`, which `typeSuffix` reads).
   Cubit and screen need NO change (`submitFailed` snack + `outOfCoverage` note already wired, `dm_onboarding_cubit.dart:99-119`,
   `dm_onboarding_screen.dart:158-170`).
M3. Optional mock-mode parity: `lib/core/network/mock_gateway_client.dart:84` add
   `'/form-builder/templates': '/form-builder-service/v1/templates',` ONLY if `rewritePath` is applied by the shared Dio
   interceptor at `mock_gateway_client.dart:142-170` (verify at implementation); the mock's registry would also need the
   new template name (`jeeb-mock-backend/src/services/form-builder-service.ts:9`). Skip both if mock mode is no longer exercised.
M4. `test/dio_dm_onboarding_gateway_test.dart`: `request.path` follows the constant (line 63); rewrite the 404/405/501 loop
   (78-88) to `throwsA(isA<DmOnboardingGatewayException>())` and, for 404, assert the Diag line
   (`Diag.enabledOverride = true; Diag.sink = lines.add;` … `expect(lines, anyElement(contains('dm_onboarding_submit_route_absent')))`,
   `Diag.resetForTest()` in tearDown). Replace the `problems.jeeb.lb` fixtures (139, 154, 184) with
   `https://jeeb.dev/errors/out_of_coverage` / `…/errors/already_onboarded`; add a case where `type` is generic but
   `reasonCode: 'out_of_coverage'` → typed exception; add 404 unknown-template → `DmOnboardingGatewayException` (not-found kind).
M5. `git add -A` before testing (R6). Gate: `dart analyze --fatal-infos .`, `flutter test --exclude-tags capture` (79 % floor),
   `qa/t-mob-fix-002/l10n_parity_check.sh --analyze`, `qa/t-mob-fix-002/ar_plurals_check.sh`, `tool/check_design_tokens.sh`.
   No ARB change (`dmOnboardingOutOfCoverage`, `dmOnboardingCoverageCheckFailed` exist EN+AR). PR body records the OD-1
   outcome and notes in `docs/build-out/20_GAP__jeeber-onboarding.md:118` that the mock path is superseded (one line).

## 6. Tests summary
Gateway: `FormSubmissionsEndpointTests` (15 cases), `JeeberOnboardingCoverageResolverTests` (5), `JeeberOnboardingFormTemplateTests`
(≈8), existing `CapabilityCoverageGuardTests` + full unit/integration suites, both shell gates. Mobile: rewritten
`test/dio_dm_onboarding_gateway_test.dart` (path, 404→exception+Diag, 405/501→exception, 404 unknown template, 409 typeSuffix,
409 reasonCode, 409 other → generic, 500 → server, Idempotency-Key cases), full `flutter test --exclude-tags capture`.

## 7. Validation on the live gateway and the real device

A. Post-deploy contract proof (from this Mac over Cloudflare; run for MSI, repeat for staging with its host). Prefer
Karim TestJeeber `106078a3-4758-45c1-9d31-71b503a3fce4` (C19) or the fresh `devtool_client_<ts>` from §7B:
```
B=https://msi.olivium.space/gateway; T=jeeb_jeeber_onboarding_v1
A=$(curl -s -X POST $B/auth/tokens -H 'Content-Type: application/json' \
  -d '{"userId":"106078a3-4758-45c1-9d31-71b503a3fce4","roles":["jeeber","client"]}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["accessToken"])')
# 201, coverage.checked=false (OD-2)
curl -s -w '\nHTTP %{http_code}\n' -X POST $B/form-builder/templates/$T/submit -H "Authorization: Bearer $A" -H 'Content-Type: application/json' -H 'Idempotency-Key: p01v2-a' \
  -d '{"state":"Beirut","country":"Lebanon","street":"Hamra","address":"Bldg 1","home_base_lat":33.8938,"home_base_lng":35.5018,"home_base_label":"Hamra"}'
# replay → identical 201 body (same submissionId)
# 200 read-back through the new route
curl -s -w '\nHTTP %{http_code}\n' $B/form-builder/templates/$T/submission -H "Authorization: Bearer $A"
# 200 {"value":"{...}"} — the SAME record through the generic user-preferences surface = "stored in user preferences"
curl -s -w '\nHTTP %{http_code}\n' $B/api/UserPreferences/preferences/jeeb.form.$T -H "Authorization: Bearer $A"
# 404 not-found unknown template; 401 without bearer; 400 field=home_base_lat with lat 95
curl -s -w '\nHTTP %{http_code}\n' -X POST $B/form-builder/templates/nope/submit -H "Authorization: Bearer $A" -H 'Content-Type: application/json' -d '{}'
```
Expected: 201 / 201 (same id) / 200 / 200 / 404 / 401 / 400. No 409 proof live (OD-2); the 409 branch is proven by
`FormSubmissionsEndpointTests`. Sanity first: `GET $B/api/users/me/saved-locations` must be 200 (RUP path up).

B. Real device SM-A336B (`RZCT505K7WF`), Dev Tool alias `app.jeeb.mobile.dev`, `adb install -r` only, never uninstall.
Dev Tool → Server URL → `dev.base_url_override = https://msi.olivium.space/gateway` → Apply & Restart. Scenario Users →
Super Login Plus → fresh `devtool_client_<ts>` (non-login feature, super-login OK per A17). Serial device queue after P04
Part A (C13); `session` line in `device-evidence-4/CREATED.jsonl`; evidence → `scratchpad/device-evidence-4/p01/`.
1. Delivery tab → Register (`dashboard_tab.dart:170`) → photo (gallery) → Continue → address: State/Country/Street/Address →
   Continue → service area: pin anywhere (no boundary is configured) → Continue. Expect: KYC wizard opens (`/profile/kyc`);
   `adb logcat -s flutter | grep '\[jeeb-diag\]'` shows `POST /form-builder/templates/jeeb_jeeber_onboarding_v1/submit` 201
   and NO `dm_onboarding_submit_route_absent`; §7A read-back with that user's token returns the pinned lat/lng.
2. Re-enter the wizard, change the address, Continue again: read-back shows the NEW record and a NEW `submissionId` (upsert).
3. Out-of-coverage on device: NOT reproducible live under OD-2 (documented as such); the Dev Tool catalog fixture
   `DmOnboardingScreenOutOfCoverageGateway` remains the UI proof of the note. If the owner later configures a boundary on MSI
   (env override + restart), rerun v1 §7B step 2 (Nicosia 35.17, 33.36).
4. Outage: set base URL to a blackhole host, Continue: `dm_onboarding_error_snack` with `dmOnboardingCoverageCheckFailed`,
   wizard stays. Restore the URL and locale.

## 8. Risks
- Deploy-order coupling (unchanged): a flipped mobile build against a gateway without the route now shows a visible failure
  snack instead of a silent no-op — by design; the flip must not reach any store lane before staging has the route.
- Template rename: mobile docs/mock say `jeeb_jeeber_v1`; the plan uses `jeeb_jeeber_onboarding_v1` (E14 collision). Reverting
  is one constant per side (`JeeberOnboardingFormTemplate.Name`, `DmOnboardingGateway.submitPath`) — but it would make reading C impossible later.
- The record is invisible to CMS/ops (me-scoped read only, opaque blob in RUP); KYC review cannot see the address/home base
  until an admin reader exists — follow-up, not in scope.
- remote-user-preferences down → 502/504, the wizard cannot advance (same dependency as saved-locations; retryable snack).
- Cloudflare replaces 502 bodies with text/plain (§0): over the public host mobile sees a body-less 502; `AppFailure.of` still
  classifies by status. Not specific to this route.
- Two controllers share `[Route("form-builder")]`; templates are distinct — the startup guard and `CapabilityCoverageGuardTests` cover it.
- `ProfileWriteSelf` admits admin tokens (self-scoped, harmless; differs from v1's 403).
- Live side-defects seen while probing, NOT in scope: `GET /form-builder/templates` → 500 (list-vs-dict bind, `FormBuilderServiceClient.cs:46`);
  upstream 4xx on `/form-builder/*` → 502 `upstream-unavailable` rather than the upstream's status.
- gwdbx registry / stateless gate false-fail on spelling — run both scripts before pushing.

## 9. Owner must confirm (ONE yes/no)

**Q: The gateway will serve the form-builder submit route itself and write the submission straight into user
preferences — WITHOUT calling form-builder-service on the write path and WITHOUT registering a new template in
form-builder-service (so no ops change on the shared service on MSI/staging; the field rules live in gateway code).
Is that acceptable — YES / NO?**

- **YES** (recommended, reading A): execute §5 as written. Effort M.
- **NO** (reading C — "the form-builder must validate it"): add a wave-0 prerequisite before G6: (1) author
  `jeeb-gateway/product/form-builder/flavors/jeeb_jeeber_onboarding_v1/default.json` (fields of §4.1, `i18n_label_key` per
  field; `qa/i18n-key-check.sh` enforces the `kyc.jeeb.v1.<field>.<slot>` prefix — extend the script's prefix rule in the same PR);
  (2) generate `generated_jeeb_jeeber_onboarding_v1.json` with the generator in the MSI checkout
  `/home/ec2-user/iter5-services/form-builder-service/scripts/`, add it to `TEMPLATE_JSON_FILES` in
  `/home/ec2-user/iter5-native/env/form-builder-service.env` (list per `app/config.py:get_template_files` — verify separator)
  and restart `jeeb-form-builder.service` (owner-gated; staging via its deploy workflow); (3) G6 gains
  `if (!_flags.CurrentValue.FormBuilder) return 503` + `await _formBuilder.SchemaAsync(templateName, "en", ct)` to confirm the
  template and check the schema's `required` components against the body (upstream 404 → 404 not-found, upstream down →
  502 `upstream-unavailable`); test double = `FakeFormBuilder` pattern from `tests/…/Kyc/KycSubmissionWiringEndpointTests.cs:115`.
  Effort becomes L (+~1 day gateway, + one owner-gated ops change per environment) and wave 4 waits on the restart.

Defaults that need NO answer (CTO calls, one-line reversals): template name `jeeb_jeeber_onboarding_v1`; capability
`profile.write.self`/`profile.read.self`; key `jeeb.form.<templateName>`; route shape `/form-builder/templates/{t}/submit`
(the literal mock path `/form-builder-service/v1/…` is deliberately not mirrored on the gateway — it is a mock convention).

## 10. Effort
Gateway **M** (controller + store + template rules + resolver + ~28 tests + config/registry, ~1 day). Mobile **S** (2 files +
1 test, ~2 h). Overall **M** on YES; **L** on NO (§9).

## 11. Dependencies
- OD-3 = `combined`: this gateway PR merges independently of P02-G/P03-G (different files; C14 worktree) and rides the ONE MSI
  deploy + ONE staging dispatch that opens wave 4; §7A runs after that single deploy; the mobile flip + §7B only after
  staging also has the route.
- OD-2 = `nobbox`: honoured by G9 (empty boundaries everywhere); the 409 mechanism ships dormant.
- OD-0 = `widen`: irrelevant to P01-mobile — the flip stays off #335 for deploy-order reasons (§3(7)).
- PR #330 invariants untouched (no `auth_interceptor.dart` edit); `implements` sites unchanged (M1); comments ≤ 2 lines.
- C19 demo-account caveat and C12/C13 evidence/queue rules carried over from v1.

## Reconciled (carried from v1's 2026-09-05 conflict review)
- (C1/C20) mobile M1–M5 on `fix/dm-onboarding-route` off post-merge `main`, never on PR #335.
- (C14) gateway worktree `jeeb-gateway-worktrees/p01-onboarding`; one combined deploy pair (OD-3).
- (C19) §7A prefers Karim `106078a3…` or the fresh devtool client over `d1000000-…-0002`.
- (C12/C13) evidence dir `device-evidence-4/p01/`, shared ledger `CREATED.jsonl`, serial queue after P04 Part A.
- OD-1 is now answered by this v2 (reading A) pending the single §9 question; OD-2 answered (`nobbox`); OD-3 answered (`combined`).
