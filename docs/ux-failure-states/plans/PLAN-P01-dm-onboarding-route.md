# PLAN P01-dm-onboarding-route — DM-onboarding submit route, end to end

Status: PLAN ONLY (no repo file changed). Author: Fable 5.1 planner, 2026-09-05.
Repos: `olivium-dev/jeeb-gateway` (new branch off `origin/main`), `olivium-dev/jeeb-mobile`
(commit on `ux/api-error-handling-empty-states` while PR #335 is unmerged, else a new branch off main).
Never a new repo. Deploys are owner-gated: this plan PREPARES a deploy, never executes one.

---

## 1. Problem (verified)

The jeeber onboarding wizard (`/jeeber/onboarding`, `DmOnboardingScreen`: photo → address → service-area)
submits its result to a route that does not exist on the gateway, so the funnel silently no-ops.

Evidence:

| # | Fact | Where |
|---|---|---|
| E1 | Mobile submits `POST /form-builder-service/v1/templates/jeeb_jeeber_v1/submit` | `jeeb-mobile-worktrees/ux-api-errors/lib/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart:66-67` |
| E2 | 404/405/501 are swallowed as success (`return;` + `Diag.event('dm_onboarding_submit_route_absent')`) | `lib/features/jeeber_onboarding/data/dio_dm_onboarding_gateway.dart:30-34` |
| E3 | On resolve the cubit sets `coverageReady: true` and the screen `goNamed('kyc-status')` — the user is moved on with nothing persisted | `dm_onboarding_cubit.dart:99-103`, `presentation/dm_onboarding_screen.dart:158-165` |
| E4 | The documented path is **mock-only** (jeeb-mock-backend `form-builder-service`), never a gateway contract | `docs/build-out/20_GAP__jeeber-onboarding.md:118,153-156`, `docs/build-out/30_BACKLOG.md:248` |
| E5 | Gateway `origin/main` (`6679f6ee`, 2026-09-04) has no jeeber-onboarding controller; `FormBuilderController` is `[Route("form-builder")]` with `POST forms/{templateName}` (generic template-value write, no coverage semantics, never 409) and `jeeb_jeeber_v1` is the **KYC** template | `git show origin/main:src/JeebGateway/Controllers/FormBuilderController.cs` lines 29-33, 106-135 |
| E6 | Live, with a minted jeeber bearer (`POST /auth/tokens` OpenMode, Karim `d1000000-…-000000000002`, roles `["jeeber","client"]`): `POST /form-builder-service/v1/templates/jeeb_jeeber_v1/submit` → **404** `application/problem+json`; `POST /v1/jeebers/me/onboarding` → 404; `GET /api/users/me/saved-locations` → 200 (remote-user-preferences path healthy) | this planner's probe 2026-09-05 against `https://msi.olivium.space/gateway`; MSI runs build `jeeb-native-builds/20260904/jeeb-gateway-6679f6e` = origin/main |
| E7 | Programme record of the gap and the fail-safe contract | `scratchpad/stage1/OWNER-CONFIRM.md`, `scratchpad/FINAL-REPORT.md` §7(a), `analysis/RULINGS.md` R7 (last bullet) |
| E8 | Coverage primitive already exists on the gateway: `ZoneBoundary` (WGS84 bbox, `Contains(lat,lng)`) bound from `Admin:Zones` for the ops map; **live MSI has no `Admin__Zones` env** (grep of `~/iter5-native/env/gateway.env` and the process environ, 2026-09-05) | `src/JeebGateway/Availability/ZoneOptions.cs:35-47`, `Program.cs:2608` |
| E9 | Sanctioned per-user durable store with zero gateway DB: remote-user-preferences (Rust `:10067`, `FeatureFlags__UseUpstream__RemoteUserPreferences='true'` on MSI, `RemoteUserPreferencesServiceApi__BaseUrl='http://127.0.0.1:10067'`) via `ServiceRemoteUserPreferencesClient.Data_{Get,Set,Update}…PreferenceAsync`, one JSON blob per namespaced key (`jeeb.saved_locations`, `jeeb.notification_prefs`) | `Users/SavedLocations/RemoteUserPreferencesSavedLocationStore.cs:8-40`, `NotificationPreferences/RemoteUserPreferencesNotificationPreferencesStore.cs:27-160`, `Program.cs:1704-1732` |
| E10 | RFC 7807 type namespace on this gateway is `https://jeeb.dev/errors/<code>` (e.g. `…/errors/validation` + `field` extension, `…/errors/not-found`, `…/errors/dependency-unavailable`, `…/errors/upstream-timeout`); mobile `GatewayProblem.typeSuffix` recognises exactly `…/errors/<code>` | `KycSubmissionBffController.cs:684-695`, `SavedLocationsController.cs:136-148`; mobile `lib/core/network/gateway_problem.dart:72-84` |
| E11 | Gateway-wide `Idempotency-Key` replay is middleware, not per-controller | `StateService/Idempotency/IdempotencyMiddleware.cs:1-30` |
| E12 | Every action must carry `[RequireCapability]` or `[PublicEndpoint]` (startup guard, Enforce=true) | `Auth/Capabilities/CapabilityCoverageGuard.cs`, `Program.cs:433-446` |

Side observations (NOT in scope, report to owner): with the same minted token `GET /v1/users/me` and
`POST /form-builder/forms/jeeb_jeeber_v1` returned a Cloudflare text/plain **502** (origin dropped the
connection) — a separate live defect on the users/me and form-builder upstream paths.

## 2. Root cause

There was never a gateway contract for the DM-onboarding step: the Flutter wizard was built against
the mock backend's `form-builder-service` path (E4) while the real gateway moved KYC to `/v1/kyc/*`
(K1 reconciliation) and never grew a jeeber-profile/home-base write. The programme's WP-8b landed a
deliberate fail-safe (E2) so an undeployed route would not block the funnel — which is exactly the
silent no-op that must now end.

## 3. Decision

1. **Route**: `POST /v1/jeebers/me/onboarding` (upsert) + `GET /v1/jeebers/me/onboarding` on a new
   thin BFF controller. `me`-scoped (identity from the validated principal via `UserIdentity.TryGetUserId`),
   no userId in the path. Capability `Capabilities.KycSubmitSelf` (`kyc.submit.self`, Participant =
   {client, jeeber}) — the same capability as the KYC funnel this step feeds; a client upgrading to
   jeeber holds `{client}` and is authorised.
2. **Persistence**: one JSON blob under key **`jeeb.jeeber_onboarding`** in remote-user-preferences
   (E9). Zero gateway DB, no in-memory local owner (R9 roster unchanged), no new feature flag
   (rides the existing `UseUpstream:RemoteUserPreferences`).
3. **Coverage**: bounding-box check reusing the existing `ZoneBoundary` type, bound from a NEW
   section `JeeberOnboarding:Coverage` (not `Admin:Zones`, so the CMS ops-map grouping is untouched).
   `Boundaries` empty → **fail-open** (in coverage, one Information log) so an unconfigured
   environment never blocks sign-ups. Outside every box → **409** `https://jeeb.dev/errors/out_of_coverage`.
   Ship a Lebanon bbox in `appsettings.Production.json` so MSI/staging return a real 409.
4. **Mobile**: flip `DmOnboardingGateway.submitPath` to `/v1/jeebers/me/onboarding`; 404/405/501
   become a real `DmOnboardingGatewayException` (Diag event kept) — the funnel can no longer silently
   no-op; 409 discriminator = `typeSuffix == 'out_of_coverage'` OR `reasonCode == 'out_of_coverage'`.
5. **Ordering**: gateway merged AND deployed (MSI + staging, owner-gated) BEFORE the mobile flip is
   built for any device; the fail-safe stays in place on mobile until then.

Why not the documented path: it is a mock artefact (E4); on the real gateway `form-builder` is a generic
template-value store whose `jeeb_jeeber_v1` template is the KYC schema (E5). Home base + address is a
jeeber-profile fact with a coverage decision — not a form submission.

## 4. Contract

### 4.1 `POST /v1/jeebers/me/onboarding`

Headers: `Authorization: Bearer <jeeb-clients token>`; optional `Idempotency-Key` (middleware replays
the original response verbatim, E11); `Content-Type: application/json`.

Body (snake_case, exactly what mobile already sends — `DmOnboardingSubmission.toJson()`):
```json
{
  "state": "Mount Lebanon", "country": "Lebanon", "street": "Main St", "address": "Bldg 4",
  "home_base_lat": 33.8938, "home_base_lng": 35.5018, "home_base_label": "Beirut",
  "portrait_object_ref": "cdn/objects/portrait-1"
}
```
Validation (400 `https://jeeb.dev/errors/validation`, `field` extension, first violation wins —
same idiom as `KycSubmissionBffController.FieldProblem`): `state`, `country`, `address` non-blank
(`street` may be blank), each ≤ 256 chars; `home_base_lat` ∈ [-90,90], `home_base_lng` ∈ [-180,180],
both required and finite; `home_base_label` ≤ 256; `portrait_object_ref` optional ≤ 512.
Null body → 400 `https://jeeb.dev/errors/invalid-request`.

Coverage: 409 when boundaries are configured and none contains the point:
```json
{ "type": "https://jeeb.dev/errors/out_of_coverage", "title": "Outside the service area",
  "status": 409, "detail": "The home base is outside every served zone.",
  "reasonCode": "out_of_coverage", "zonesConfigured": 1 }
```
Success: **201** (upsert; a re-run of the wizard replaces the record) with
```json
{ "userId": "…", "state": "…", "country": "…", "street": "…", "address": "…",
  "home_base": { "lat": 33.8938, "lng": 35.5018, "label": "Beirut" },
  "portrait_object_ref": "cdn/objects/portrait-1",
  "coverage": { "checked": true, "zone_key": "lebanon" },
  "submitted_at": "2026-09-05T12:00:00Z" }
```
(`coverage.checked=false, zone_key=null` when fail-open.)
Upstream: 502 `https://jeeb.dev/errors/dependency-unavailable` (store threw
`UserPreferencesUnavailableException`) / 502 `https://jeeb.dev/errors/upstream-timeout` (`TimeoutException`),
mirroring `SavedLocationsController`. 401 no identity; 403 wrong user type (admin-only token).

### 4.2 `GET /v1/jeebers/me/onboarding`
200 with the same record; 404 `https://jeeb.dev/errors/not-found` ("No onboarding record") when the
blob is absent; 502 as above. (Consumer today: validation + a future resume/CMS read; mobile does not
call it in this plan.)

### 4.3 Stored blob (`jeeb.jeeber_onboarding`, version 1)
```json
{ "version": 1, "state": "…", "country": "…", "street": "…", "address": "…",
  "home_base": { "lat": 0, "lng": 0, "label": "" }, "portrait_object_ref": null,
  "coverage": { "checked": true, "zone_key": "lebanon" }, "submitted_at": "…" }
```

## 5. Fix steps (ordered)

### Gateway — repo `jeeb-gateway`, branch `feat/jeeber-onboarding-route` off `origin/main`

Prereq: `git -C jeeb-gateway fetch origin && git -C jeeb-gateway worktree add ../jeeb-gateway-worktrees/p01-onboarding -b feat/jeeber-onboarding-route origin/main`
(the local checkout/main are 515 commits stale — never branch from them).
Reconciled: a worktree, not `switch`, so P01/P02/P03 gateway branches can be built in parallel from one clone (C14).

G1. `src/JeebGateway/Onboarding/JeeberOnboardingDtos.cs` (new): `JeeberOnboardingSubmitBody`
   (`[JsonPropertyName]` snake_case fields of §4.1), `JeeberOnboardingResponse`, `HomeBaseDto`,
   `CoverageDto`, and the stored `JeeberOnboardingRecord` (§4.3).
G2. `src/JeebGateway/Onboarding/IJeeberOnboardingStore.cs` (new):
   `Task<JeeberOnboardingRecord?> GetAsync(string userId, CancellationToken ct);`
   `Task SetAsync(string userId, JeeberOnboardingRecord record, CancellationToken ct);`
G3. `src/JeebGateway/Onboarding/RemoteUserPreferencesJeeberOnboardingStore.cs` (new): copy the
   shape of `NotificationPreferences/RemoteUserPreferencesNotificationPreferencesStore.cs` —
   `IServiceScopeFactory` + lazy scoped `ServiceRemoteUserPreferencesClient`, `BlobKey = "jeeb.jeeber_onboarding"`,
   read budget 1500 ms / write budget 2000 ms, `Data_GetSinglePreferenceAsync` (404 → null),
   write = `Data_UpdatePreferenceAsync` then on `ApiException 404` → `Data_SetSinglePreferenceAsync`.
   No pre-read on write (whole-record upsert). Unanswered read → throw `UserPreferencesUnavailableException`;
   write budget exceeded → `TimeoutException`. Never log the blob body.
G4. `src/JeebGateway/Onboarding/JeeberOnboardingCoverageOptions.cs` (new):
   `SectionName = "JeeberOnboarding:Coverage"`, `List<ZoneBoundary> Boundaries`, `bool FailOpenWhenUnconfigured = true`.
   `src/JeebGateway/Onboarding/JeeberOnboardingCoverageResolver.cs` (new): `IJeeberOnboardingCoverageResolver.Resolve(lat,lng)`
   → `(bool inCoverage, bool checked, string? zoneKey)`; empty boundaries + FailOpen → `(true,false,null)`;
   empty + !FailOpen → `(false,true,null)`.
G5. `src/JeebGateway/Controllers/JeeberOnboardingBffController.cs` (new): `[ApiController]`,
   class-level `[RequireCapability(Capabilities.KycSubmitSelf)]`, `[HttpPost("v1/jeebers/me/onboarding")]`
   + `[HttpGet("v1/jeebers/me/onboarding")]`, `[Consumes("application/json")]`, `ProducesResponseType`
   rows for 200/201/400/401/403/404/409/502. Identity via `UserIdentity.TryGetUserId(HttpContext, out userId, out problem)`.
   Validation → coverage → `SetAsync` → 201. Problem helpers exactly as §4.1/4.2. Two-line comments max.
G6. `src/JeebGateway/Program.cs`: next to the saved-locations block (~line 1720) add
   `builder.Services.Configure<JeeberOnboardingCoverageOptions>(builder.Configuration.GetSection(JeeberOnboardingCoverageOptions.SectionName));`
   `builder.Services.AddSingleton<IJeeberOnboardingCoverageResolver, JeeberOnboardingCoverageResolver>();`
   `builder.Services.AddSingleton<IJeeberOnboardingStore, RemoteUserPreferencesJeeberOnboardingStore>();`
   (unconditional — the store already degrades to 502 when the upstream is off/unset; no InMemory fallback,
   so `scripts/stateless-gateway-ownership-roster.txt` needs NO row).
G7. `scripts/gwdbx-flag-registry.txt`: append rows (G-22 one-way containment, `setting -` shape, see
   rows 133-134 for `Admin:Zones:*`):
   `JeeberOnboarding:Coverage:Boundaries                  setting - # P01 bbox list; empty = fail-open`
   `JeeberOnboarding:Coverage:FailOpenWhenUnconfigured    setting - # P01 default true`
   Run `bash scripts/check-gwdbx-flag-registry.sh` locally until OK.
G8. `src/JeebGateway/appsettings.json`: add `"JeeberOnboarding": { "Coverage": { "Boundaries": [], "FailOpenWhenUnconfigured": true } }`
   (test/dev default = fail-open). `src/JeebGateway/appsettings.Production.json`: same section with
   `Boundaries: [{ "Key": "lebanon", "Name": "Lebanon", "MinLatitude": 33.05, "MaxLatitude": 34.70, "MinLongitude": 35.10, "MaxLongitude": 36.65 }]`.
G9. Tests (xUnit + FluentAssertions, `WebApplicationFactory<Program>`, headers `X-User-Id` + `X-User-Roles`
   as in `tests/JeebGateway.IntegrationTests/SavedLocationsEndpointTests.cs:26-32` / `Kyc/KycSubmissionBffEndpointTests.cs:304-346`):
   - `tests/JeebGateway.IntegrationTests/JeeberOnboardingEndpointTests.cs` (new) with a nested
     `Factory : WebApplicationFactory<Program>` that `RemoveAll<IJeeberOnboardingStore>()` + `AddSingleton<IJeeberOnboardingStore, FakeJeeberOnboardingStore>()`
     (dictionary double in the test project — GW3 pattern) and `UseSetting("JeeberOnboarding:Coverage:Boundaries:0:Key","beirut")`
     … `MinLatitude 33.80 / MaxLatitude 34.00 / MinLongitude 35.40 / MaxLongitude 35.60` for the 409 cases.
     Cases: 401 no identity; 403 `X-User-Roles: admin`; 201 `driver` inside box (+ blob persisted, `coverage.zone_key == "beirut"`);
     201 `customer` inside box; 409 outside box with `type` + `reasonCode`; 400 missing `state` (`field == "state"`);
     400 `home_base_lat` 95; GET 404 before / 200 after POST; 201 fail-open when no boundaries (`coverage.checked == false`);
     502 `dependency-unavailable` when the fake store throws `UserPreferencesUnavailableException`.
   - `tests/JeebGateway.UnitTests/JeeberOnboardingCoverageResolverTests.cs` (new): empty+failOpen, empty+!failOpen, inside, outside, edge-inclusive.
   - `CapabilityCoverageGuardTests` needs no edit (class-level attribute covers both actions) — run it.
G10. `bash scripts/export-openapi.sh` then `bash scripts/check-openapi-path-method-compatibility.sh`; if the
   regenerated `artifacts/openapi/jeeb-gateway.v1.json` diff is only the two new paths, commit it.
G11. Gate: `dotnet restore src/JeebGateway/JeebGateway.csproj --locked-mode`, `dotnet build`, `dotnet test tests/JeebGateway.UnitTests`,
   `dotnet test tests/JeebGateway.IntegrationTests`, `bash scripts/check-stateless-gateway.sh`, `bash scripts/check-gwdbx-flag-registry.sh`.
   Open PR to `main` (title `feat(onboarding): POST/GET /v1/jeebers/me/onboarding — home base + coverage (P01)`), CI green.
G12. PREPARE deploy (do not execute): MSI native = the owner's standard gateway deploy of the merged SHA
   (`~/jeeb-native-builds/<date>/jeeb-gateway-<sha>` + systemd drop-in; no `gateway.env` change required —
   coverage ships in `appsettings.Production.json`); staging = `.github/workflows/jeeb-staging-deploy.yml`
   dispatch (protected env + confirm string), no FeatureFlags overlay needed. Hand the owner the curl proof
   commands from §7 to run after each deploy.

### Mobile — repo `jeeb-mobile`, worktree `jeeb-mobile-worktrees/ux-api-errors`

Land ONLY after G12 is live on MSI (and on staging before any store build).
Reconciled: NEVER on PR #335 (scope freeze C1) — the flip must not ride a branch that can reach a store lane before
the gateway route exists (§3(5)). Branch `fix/dm-onboarding-route` off post-merge `main`, opened only after the
combined gateway deploy (C14) is proven by §7A. PR #335 keeps the fail-safe (P10 lane 8b confirms the constant unchanged).

M1. `lib/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart`: `submitPath = '/v1/jeebers/me/onboarding'`;
   add `static const String outOfCoverageReason = 'out_of_coverage';`; replace the "NOT deployed" doc comment
   with the contract pointer (this plan / gateway PR #). Interface signature unchanged (R3: 5 `implements`
   sites incl. `lib/devtool/catalog/fixtures/dm_onboarding_screen_fixtures.dart:18,118,127` and the test double).
M2. `lib/features/jeeber_onboarding/data/dio_dm_onboarding_gateway.dart`: delete the `return;` on
   404/405/501; keep `Diag.event('dm_onboarding_submit_route_absent', {'status': status})` and then fall
   through to `throw DmOnboardingGatewayException(AppFailure.of(e))`. Discriminator:
   `failure is ConflictFailure && (problem?.typeSuffix == outOfCoverageReason || problem?.reasonCode == outOfCoverageReason)`;
   keep `_lastSegment` only if a test still needs it — otherwise delete it and its D1 comment.
   Cubit (`dm_onboarding_cubit.dart`) and screen need NO change: `submitFailed` already snacks
   `dm_onboarding_error_snack` and `outOfCoverage` already renders `dm_onboarding_out_of_coverage_note` on the step.
M3. `test/dio_dm_onboarding_gateway_test.dart`: `request.path` expectation follows the constant; rewrite the
   404/405/501 loop to `throwsA(isA<DmOnboardingGatewayException>())` and, for 404, assert the Diag line
   (`Diag.enabledOverride = true; Diag.sink = lines.add;` … `expect(lines, anyElement(contains('dm_onboarding_submit_route_absent')))`;
   `Diag.resetForTest()` in tearDown). Replace the `problems.jeeb.lb` fixtures with `https://jeeb.dev/errors/out_of_coverage`
   and add a case where `type` is generic but `reasonCode: 'out_of_coverage'` → typed exception.
   `test/features/jeeber_onboarding/dm_onboarding_gateway_test.dart` (cubit) is unaffected.
M4. `git add -A` before testing (R6). Gate: `dart analyze --fatal-infos .`, `flutter test --exclude-tags capture`
   (coverage floor 79 %), `qa/t-mob-fix-002/l10n_parity_check.sh --analyze`, `qa/t-mob-fix-002/ar_plurals_check.sh`,
   `tool/check_design_tokens.sh`; guardrail ratchets untouched (no new snack/OMDS sites). No ARB change
   (`dmOnboardingOutOfCoverage`, `dmOnboardingCoverageCheckFailed` exist EN+AR: `lib/l10n/app_en.arb:4809,6124`, `app_ar.arb:1722,2464`).
M5. Update `scratchpad/stage1/OWNER-CONFIRM.md` outcome in the PR body (route confirmed = `/v1/jeebers/me/onboarding`,
   discriminator = `…/errors/out_of_coverage`), and note in `docs/build-out/20_GAP__jeeber-onboarding.md:118`
   that the mock path is superseded (one line).

## 6. Tests summary
Gateway: `JeeberOnboardingEndpointTests` (11 cases above), `JeeberOnboardingCoverageResolverTests` (5),
existing `CapabilityCoverageGuardTests` + full unit/integration suites. Mobile: rewritten
`test/dio_dm_onboarding_gateway_test.dart` (path, 404→exception+Diag, 405/501→exception, 409 typeSuffix,
409 reasonCode, 409 other code → generic, 500 → server, Idempotency-Key cases), full `flutter test --exclude-tags capture`.

## 7. Validation on the live gateway and the real device

A. Post-deploy contract proof (curl, from this Mac over Cloudflare; run for MSI, repeat for staging with its host):
```
B=https://msi.olivium.space/gateway
A=$(curl -s -X POST $B/auth/tokens -H 'Content-Type: application/json' \
  -d '{"userId":"d1000000-0000-4000-8000-000000000002","roles":["jeeber","client"]}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["accessToken"])')
# 201 inside Lebanon
curl -s -w '\nHTTP %{http_code}\n' -X POST $B/v1/jeebers/me/onboarding -H "Authorization: Bearer $A" -H 'Content-Type: application/json' -H 'Idempotency-Key: p01-a' \
  -d '{"state":"Beirut","country":"Lebanon","street":"Hamra","address":"Bldg 1","home_base_lat":33.8938,"home_base_lng":35.5018,"home_base_label":"Hamra"}'
# 409 out_of_coverage (Nicosia)
curl -s -w '\nHTTP %{http_code}\n' -X POST $B/v1/jeebers/me/onboarding -H "Authorization: Bearer $A" -H 'Content-Type: application/json' \
  -d '{"state":"x","country":"Cyprus","street":"","address":"1","home_base_lat":35.17,"home_base_lng":33.36,"home_base_label":"Nicosia"}'
# 200 read-back shows the Hamra record; replay of Idempotency-Key p01-a returns the same 201 body
curl -s -w '\nHTTP %{http_code}\n' $B/v1/jeebers/me/onboarding -H "Authorization: Bearer $A"
# 401 without bearer; 400 with home_base_lat 95
```
Expected: 201 / 409 with `type` `https://jeeb.dev/errors/out_of_coverage` / 200 / 401 / 400.

B. Real device SM-A336B (`RZCT505K7WF`), Dev Tool alias `app.jeeb.mobile.dev` (`com.olivium.jeeb.LegacyDevToolLauncher`),
`adb install -r` only, never uninstall. Dev Tool → Server URL → `dev.base_url_override = https://msi.olivium.space/gateway`
→ Apply & Restart. Scenario Users → Super Login Plus → a fresh `devtool_client_<ts>` (non-login feature, super-login OK).
1. Delivery tab → Register (`dashboard_tab.dart:170` → `jeeber-onboarding`) → photo step: pick from gallery → Continue →
   address: fill State/Country/Street/Address → Continue → service area: pin in Beirut → Continue.
   Expect: KYC wizard opens (`/profile/kyc`); `adb logcat -s flutter | grep '\[jeeb-diag\]'` shows the API record
   `POST /v1/jeebers/me/onboarding` status 201 and NO `dm_onboarding_submit_route_absent`; curl §A GET with that user's
   token (Dev Tool shows the token / or mint by userId) returns the pinned lat/lng.
2. Re-enter the wizard; pin outside Lebanon (e.g. Damascus 33.51, 36.29 is inside the bbox — use Nicosia 35.17, 33.36
   or Haifa 32.79, 34.99) → Continue. Expect: stays on the service-area step, `dm_onboarding_out_of_coverage_note`
   present in `uiautomator dump`, no navigation, Diag shows 409.
3. Switch language to AR in-app, repeat step 2: note text = `app_ar.arb:2464`.
4. Outage: set base URL to a blackhole host, repeat step 1's Continue: `dm_onboarding_error_snack` with
   `dmOnboardingCoverageCheckFailed`, wizard stays. Restore the URL.
Evidence goes to `scratchpad/device-evidence-4/p01/` (png + uiautomator xml + logcat grep).

## 8. Risks
- Deploy-order coupling: a mobile build with M2 pointed at a gateway without the route blocks the funnel at
  service-area with a visible snack (by design, no longer silent) — so the mobile flip must not reach any
  store lane before staging has the route. Mitigation: §3(5) ordering; keep PR #335's fail-safe until G12.
- Coverage bbox is a crude country rectangle (includes bits of Syria/Israel); false positives let a
  non-Lebanon pin through, false negatives impossible inside Lebanon. Polygons later via the same options type.
- remote-user-preferences unavailable → 502 and the wizard cannot advance (cannot "resolve normally"
  any more). Acceptable: it is the same dependency saved-locations already has; mobile renders a retryable failure.
- `KycSubmitSelf` is Participant; an admin-only token gets 403 — matches KYC submit.
- Live 502s on `/v1/users/me` and `/form-builder/forms/*` (side observation) may indicate an upstream health
  issue on MSI unrelated to this route; if `:10067` is affected the 201 proof fails with 502 — check
  `GET /api/users/me/saved-locations` first (was 200 on 2026-09-05).
- gwdbx registry / stateless gate false-fail if the new section or store name is spelled differently than
  registered — run both scripts locally before pushing.

## 9. Owner decisions needed
1. Confirm the route `POST/GET /v1/jeebers/me/onboarding` under `kyc.submit.self` (vs. `profile.write.self`).
2. Confirm launch coverage = Lebanon bbox (33.05–34.70 N, 35.10–36.65 E) in `appsettings.Production.json`
   with fail-open when unconfigured (vs. fail-closed).
3. Approve the deploy order (gateway MSI → gateway staging → mobile flip) and run the owner-gated deploys.

## 10. Effort
Gateway M (controller + store + resolver + 16 tests + config/registry, ~1 day). Mobile S (2 files + 1 test file, ~2 h).
Overall **M**.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C1): mobile M1–M5 land on `fix/dm-onboarding-route` off post-merge `main`, never on PR #335.
- Reconciled (C14): the three gateway PRs (P01 route, P02 inbox ref, P03 validation) are independent files and are
  merged separately, but the owner runs ONE combined MSI deploy and ONE staging dispatch after all three are on
  `main` (owner decision OD-3 replaces this plan's decision 3). §7A curl proof runs after that single deploy.
- Reconciled (C19): §7A mints `d1000000-0000-4000-8000-000000000002`; P09 measured `GET /v1/users/me` → 502 for that
  demo account. The onboarding route never calls users/me, so the proof still works, but prefer Karim TestJeeber
  `106078a3-4758-45c1-9d31-71b503a3fce4` (roles `customer,driver`) or the fresh `devtool_client_<ts>` from §7B.
- Reconciled (C12): evidence dir is `scratchpad/device-evidence-4/p01/` (already so); the §7B session mint is a
  `session` line in the shared ledger `device-evidence-4/CREATED.jsonl` (P04 rule); onboarding creates no request.
- Reconciled (C13): §7B runs in the serial device queue after P04 Part A; restore Server URL/locale as every run does.
- Owner decisions renumbered: OD-1 (route+capability), OD-2 (bbox+fail-open), OD-3 (combined deploy order).
