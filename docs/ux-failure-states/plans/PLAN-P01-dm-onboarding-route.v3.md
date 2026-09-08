# PLAN P01-dm-onboarding-route v3 — the Rahma pattern applied to jeeb: builder DEFINES the form, mobile BUILDS it from the template, gateway STORES the answers in user preferences

Status: PLAN ONLY (no implementation or deployment performed). Author: Fable 5.1 principal, 2026-09-06; corrected in the 2026-09-06 review-fix wave. Supersedes v2 after the owner
clarified OD-1 verbatim: **"for builder is for building the form, you receive the data from the mobile as a gateway
and you store it in the user preferences (check rahma project for example)."**

Three clauses, three obligations: (1) the form-builder service DEFINES the onboarding form → a template must be
REGISTERED on it (v2 §9 "no new template" is withdrawn); (2) the mobile app BUILDS/renders the form from that template
(jeeb's hand-built wizard becomes template-driven); (3) the gateway receives the answers and writes them into
remote-user-preferences, exactly the way `rahmah-gateway` does. Repos touched: `olivium-dev/form-builder-service`
(template DATA + one generic loader fix), `olivium-dev/jeeb-gateway`, `olivium-dev/jeeb-mobile`. Never a new repo;
new branches only. Deploys stay owner-gated — this plan PREPARES them (OD-3 combined deploy).

Rahma sources (read-only clones, HEAD of each default branch on 2026-09-06):
`scratchpad/rahma/rahmah-gateway` (`1cc9596`, `master`), `scratchpad/rahma/rahmah-fe` (`03890f1`, `master`, in-repo lib
`libraries/fanus_form_builder`), `scratchpad/rahma/ofc-form-builder` (`7c2bc3b`, `main`; published lineage of fanus, not the last published revision),
`scratchpad/rahma/rahmah-admin-panel` (`873f4bb`). Rahma's form-builder-service IS the same fleet service jeeb runs
(`form-builder-service` `origin/main` `801ef01`; `flavors/form_builder_template/{male,female}.json` are Rahma's flavors,
`app/main.py:35-39`). Rahma's reverse proxy: `/Users/oudaykhaled/server-rahmah/server-rahma-config/nginx/nginx.conf:272-291`.

---

## 0. The Rahma pattern (verified in code)

| Step | Rahma does | Where |
|---|---|---|
| R1 **Template registered on the builder** | Two template files registered by env `TEMPLATE_JSON_FILES=form_builder_template.json,partner_form_builder.json`; flat shape `{ "screen-2": [components…], "screen-3": […] }` — each top-level key is one wizard SCREEN; a component = `componentID`, `componentName` (UI kind: Header, Label, Text Input, Date Input, Single Selection, Slider…), `attributes[]` (label/placeholder as `%label::screen-2.Text Input.label` i18n keys resolved by the service from `assets/lang/{en,ar}.json`), `output.type`, `validations[]` | `rahmah-gateway/form_builder_template.json:1-120` (source cloned by the builder deployment from the gateway repo; `deploy-to-fds1.yml:37,45,203`), `form-builder-service/app/config.py:14-23` (comma-split env), `app/localization.py:1-60`, `app/template_endpoints.py:106-184` (`male`/`female` flavor merge) |
| R2 **Mobile fetches the template and builds the wizard from it** | After gender pick the app opens `FormBuilderWrapper(provider: FormBuilderProvider(getScreensEndpoint: '/formbuilder/templates/male' or 'female', submitScreenEndpoint: 'formbuilder/forms/{screen}', …))`; `getScreens()` = `GET <baseUrl>/formbuilder/templates/{flavor}` (nginx → form-builder-service :10032, NOT through the C# gateway) → `Map<screenKey, List<ScreenItem>>`; `FormBuilderScreen` walks the map, renders each component by `componentID` (kind plus instance, not `componentName`), validates client-side from `validations` | `rahmah-fe/lib/core/utils/api_constant.dart:36-40`, `lib/features/user_setup/presentation/screens/gender_selection_screen.dart:262-293`, `libraries/fanus_form_builder/lib/data/provider/form_builder_provider.dart:23-24,210-224`, `lib/presentation/screens/form_builder_screen.dart:78-106,2068-2109,2421-2422`, `screens_helper.dart:158-181,357-386` |
| R3 **Per-screen submit goes to the GATEWAY, not to the builder** | On Continue, `_submitScreenData` switches on the screen key and calls a typed provider method → gateway `api/RemoteUserPreferences/preferences/{key}` (`nickname`, `firstName`, `liveIn`, `dateOfBirth`, `about_me`…), `nested-preferences/{basics\|lifeStyle}` for multi-field screens, `data/{movies_preferences…}` for sets, `api/Matching/*/upsert` for matching-owned fields. Only screens with no typed handler fall to the generic `submitScreen` → `formbuilder/forms/{screen}` (builder's own PG) — the exception, not the rule | `form_builder_screen.dart:655-760` (switch), `:1722` (generic default), `form_builder_provider.dart:27-100` (endpoint table), `:227-270` (generic submitScreen), `:389-403` (nickname) |
| R4 **Gateway handler = thin me-scoped write into remote-user-preferences** | `RemoteUserPreferencesController` `[Route("api/[controller]")]`, `[Authorize]` on each action (not on the class), userId from the token (`ClaimTypes.Sid` → `sid` → `sub`), NO template validation, NO idempotency, NO versioning: `POST preferences/nickname` → `Data_SetSinglePreferenceAsync(userId, "nickname", value)`; `POST nested-preferences/basics` → `Data_SetNestedPreferenceAsync(userId, "basics", nested)` (+ side-effect to matching); generic `POST/PUT preferences/{prefKey}` also exposed behind authorization. `liveIn` writes the preference then calls matching (`:650-677`); invalid numeric input can therefore fail after persistence. Values are STRINGS (`PreferenceValue.Value`), groups are `Dictionary<string,string>` (`NestedPreferenceInput.Value`); keys are bare (`nickname`, `liveIn`), one preference per field, a nested dict per multi-field screen. Registration/social login seed `isOnboarded="false"`; the observed Skip action sends an empty POST to `preferences/isOnboarded`, whose gateway handler writes `"true"`; login GETs the marker to decide whether to show the wizard | `rahmah-gateway/Controllers/RemoteUserPreferencesController.cs:17-46,67-240,543-570,607-645,650-677,1385-1443`; `Services/ServiceRemoteUserPreferences.cs:1675-1687,1727-1770` (nested/single DTOs); `Controllers/UserController.cs:52-53,188-191,398-399`; `rahmah-fe/lib/core/utils/api_constant.dart:153-154`, `features/login/data/remote/service/login_service.dart:29`, `features/verification/data/remote/service/verification_service.dart:30` |
| R5 **Read-back** | `GET api/User/data` → `UserData.GetUserDataWithIdsByUserIdAsync` → `Data_GetPreferencesAsync(userId)` (all keys) + `Data_GetAllItemsAsync(userId,"profile_photos")` plus nested reads for basics/lifeStyle/socialMedia → `RemoteUserPreferencesWithIds` (localized `IdValue` fields) inside `UserCompleteDataResponse.RemoteUserPrefs`. No admin/CMS view of preferences exists (`rahmah-admin-panel/src` has zero preference API usage) | `Controllers/UserController.cs:848-882`, `Services/UserDataService.cs:940-1000`, `DTOs/Response/UserCompleteDataResponse.cs:116,146,174-180`, `UserDataService.cs:1080,1138,1253` |

Two Rahma facts that shape jeeb's design:
- **F1 — `GET /templates/{name}` only serves the PRIMARY template file.** `template_endpoints.py:20-21,44` loads
  `generated_<first file of TEMPLATE_JSON_FILES>` only; `get_all_templates` (`:58-105`) localizes the primary only. The
  second Rahma file (`partner_form_builder.json`) is therefore served by a BESPOKE route
  `GET /templates/partner-form-builder/generated` (`app/main.py:212-216`). `POST /forms/*` and the PG tables, by
  contrast, are built from ALL files (`app/endpoints.py:19-30`, `app/main.py:106-123`, `app/database.py:initialize_db`).
  A second jeeb template would hit exactly this gap (§2, D-FB2).
- **F2 — Package reuse is possible, but not selected for this form.** `FormBuilderWrapper(provider:)` and
  `FormBuilderProvider(baseUrl, getScreensEndpoint, submitScreenEndpoint, …)` are configurable (`wrapper.dart:9-22`,
  `form_builder_provider.dart:9-18,27-100`); non-Rahma keys reach generic submit. The actual adaptation costs are the
  closed `componentID` render vocabulary (`form_builder_screen.dart:2068-2099,2421-2422`), `componentID-index` storage
  keys (`:2107-2109`) and injected Rahma review screen (`:78-106`). Keep the small jeeb renderer so schema field IDs
  remain stable; do not claim endpoint configuration is impossible. Last published package state was
  `PROF-592-salehly-widgets` at `216f36f` (1.0.6-beta.1), not the inspected main revision.

## 1. Piece-by-piece: mirror where jeeb has the piece, deviate only where it does not

| Rahma piece | jeeb has it? | v3 does | Why |
|---|---|---|---|
| R1 template file registered via `TEMPLATE_JSON_FILES` | YES, same service; MSI native `jeeb-form-builder.service` runs `TEMPLATE_JSON_FILES='generated_jeeb_jeeber_v1.json'` (env `/home/ec2-user/iter5-native/env/form-builder-service.env`, written by `iter5_native_run.sh:101-104`), live `GET :10070/templates` = `['jeeb_jeeber_v1']`; staging swarm `add_env TEMPLATE_JSON_FILES jeeb_kyc_form_builder.json` (`form-builder-service/.github/workflows/jeeb-staging-deploy.yml:197`) | **MIRROR**: register `jeeb_jeeber_onboarding_v1` (§2) | Owner clause 1; Rahma registers templates |
| R1 template SHAPE: flat `{key: [components]}`, `componentName` = UI kind, labels = i18n keys | YES — MSI's `generated_jeeb_jeeber_v1.json` is flat (labels = `kyc.jeeb.v1.<field>.label` keys); staging's `jeeb_kyc_form_builder.json` is step-based (`componentName` = UI kind, labels = `{en,ar}` dicts) — the two live KYC registrations disagree on vocabulary, invisible today because the KYC wizard is hand-built | **MIRROR the flat shape, DEVIATE in vocabulary**: `componentName` = jeeb UI kind, `componentID` = stable field id, `attributes.label` = i18n KEY; steps encoded as `attributes.step` (§2.2) | Flat survives `normalize_template_document` untouched; the step-based shape is flattened by the service so step boundaries would be lost |
| R2 mobile fetches the template through the reverse proxy | jeeb's gateway ALREADY fronts the builder: `GET /form-builder/templates/{t}` → `{ name, document:[components] }` (`FormBuilderController.cs:72-83`, live 200 for `jeeb_jeeber_v1` on 2026-09-06), `Accept-Language` forwarded | **MIRROR via the gateway route** (jeeb's proxy IS the gateway) | Same mechanism, jeeb's ingress |
| R2 renderer (`fanus_form_builder`) | NO (F2); jeeb's KYC fetches `/v1/kyc/jeeb/form-schema` into `KycFormSchema` but renders a hand-built wizard (`lib/features/kyc/presentation/**` never reads `formSchema`) | **DEVIATE (reuse weighed in F2)**: minimal template-driven renderer for the onboarding wizard reusing the existing step widgets (§5 Mobile) | Owner clause 2 |
| R3 submit goes to the gateway, keyed by template/screen | Mobile already posts one body to a template-named route (PR #335 branch `dm_onboarding_gateway.dart:64-67`, `dio_dm_onboarding_gateway.dart:19-45`) | **MIRROR**: `POST /form-builder/templates/{templateName}/submit` (v2 route, kept) with the body keyed by `componentID` | Same idea, one route instead of Rahma's ~40 typed ones (jeeb's form has 6 components) |
| R4 gateway = thin write into remote-user-preferences, me-scoped, nested dict for a multi-field screen | YES: same Rust upstream (`:10067`), same NSwag client methods (`Data_SetNestedPreferenceAsync`, `Data_GetNestedPreferenceAsync`, `Data_SetSinglePreferenceAsync`) `Services/Generated/ServiceRemoteUserPreferencesClient.cs:730-870,1136-1270`; generic surface `UserPreferencesController` `nested-preferences/{pref_key}` GET/POST (`:277,294`) | **MIRROR the `basics` idiom**: answers = ONE nested preference `jeeb.form.jeeb_jeeber_onboarding_v1` (`Dictionary<string,string>`), marker = single preference `jeeb.form.jeeb_jeeber_onboarding_v1.submitted_at` (Rahma's `isOnboarded` analogue) | Rahma stores a multi-field screen as a nested dict (`basics`, `lifeStyle`); jeeb adds only the `jeeb.` namespace (GR2, `jeeb.notification_prefs` precedent) |
| R4 no gateway validation | jeeb has a hard convention: RFC 7807 `400` with `field` (`KycSubmissionBffController.FieldProblem` `:684-695`) | **DEVIATE (jeeb convention)**: validate against the TEMPLATE SCHEMA fetched from the builder (`required_fields`, `type`), not against rules retyped in gateway code | "builder defines the form" — one source of rules; Rahma validates client-side from the same template |
| R4 no idempotency / no versioning | jeeb uses `Idempotency-Key` per controller (`KycSubmissionBffController.ResolveIdempotencyKey` `:697-707`), no gateway-wide replay middleware for this path | **MIRROR Rahma**: upsert semantics make replay safe; header accepted, ignored, documented. Version = the template name (`_v1`), as `jeeb_jeeber_v1` | Nothing to store; stateless gateway roster unchanged |
| Coverage bbox 409 | Rahma has none; OD-2 = `nobbox` | **KEEP v2 §3(4)**: mechanism ships dormant (`Boundaries: []` everywhere) | Owner-decided (OD-2) |
| R5 read-back + `isOnboarded` gate | jeeb has the generic surface live (`GET /api/UserPreferences/nested-preferences/{key}` → 404 until written; `GET /api/UserPreferences/preferences` → `{}`) | **MIRROR**: `GET /form-builder/templates/{t}/submission` (typed read-back) + the generic nested surface as the "it is in the user preferences" proof; the marker key doubles as the resume/skip flag | Same role, simpler shape than Rahma's `RemoteUserPreferencesWithIds`: stored strings and re-parsed objects, with two upstream reads instead of Rahma's five |
| Admin/CMS view | Rahma: none; `GET api/User/data` is me-scoped and its admin panel has no preference usage | Follow-up requires a new admin-authorized gateway read plus CMS UI | New scope, not a mirror |

## 2. The template question — YES, register one (supersedes v2 "no new template")

### 2.1 Decision
Rahma registers its wizard as a template file and the mobile builds every screen from it (R1–R2). jeeb must do the
same for the DM onboarding form: **`jeeb_jeeber_onboarding_v1`**, a new flat-shape data file
`jeeb_onboarding_form_builder.json` committed to `form-builder-service` (the KYC precedent: `jeeb_kyc_form_builder.json`
lives there "purely as generic data", `jeeb-gateway/product/form-builder/README.md:16-22`), with the jeeb-owned SOURCE
flavor under `jeeb-gateway/product/form-builder/flavors/jeeb_jeeber_onboarding_v1/default.json` (Golden Rule 2, same
README). Template name stays distinct from `jeeb_jeeber_v1` (the KYC template) for the reasons in v2 §3(1).

**Repository of record:** Rahma keeps template data and localization assets in its gateway repo; the builder fetches them at deploy time (`deploy-to-fds1.yml:37,45,140-155,203`). Jeeb deliberately keeps the tracked template data in form-builder-service and the product-owned source flavor in jeeb-gateway: its current deploy paths have no gateway-template clone step. The live MSI `generated_jeeb_jeeber_v1.json` is not tracked in any reviewed repo; preserve the working-directory copy and ask the owner where to version it before later operational cleanup.

### 2.2 The template (flat shape, generic vocabulary)
```json
{ "jeeb_jeeber_onboarding_v1": [
  { "componentID": "portrait_object_ref", "componentName": "Image Upload",
    "attributes": { "step": "photo", "stepOrder": 1, "label": "onboarding.jeeb.v1.portrait_object_ref.label",
                    "maxSizeMb": 8, "acceptedTypes": ["image/jpeg","image/png"] },
    "output": { "type": "string", "format": "object_storage_url" }, "validations": [] },
  { "componentID": "state",   "componentName": "Text Input",
    "attributes": { "step": "address", "stepOrder": 2, "label": "onboarding.jeeb.v1.state.label",
                    "placeholder": "onboarding.jeeb.v1.state.placeholder", "maxLength": 256 },
    "output": { "type": "string" }, "validations": [ { "rule": "required" }, { "rule": "maxLength", "value": 256 } ] },
  { "componentID": "country", "componentName": "Text Input", "attributes": { "step": "address", "stepOrder": 2, "label": "onboarding.jeeb.v1.country.label", "placeholder": "onboarding.jeeb.v1.country.placeholder", "maxLength": 256 }, "output": { "type": "string" }, "validations": [ { "rule": "required" }, { "rule": "maxLength", "value": 256 } ] },
  { "componentID": "street",  "componentName": "Text Input", "attributes": { "step": "address", "stepOrder": 2, "label": "onboarding.jeeb.v1.street.label",  "placeholder": "onboarding.jeeb.v1.street.placeholder",  "maxLength": 256 }, "output": { "type": "string" }, "validations": [ { "rule": "maxLength", "value": 256 } ] },
  { "componentID": "address", "componentName": "Text Input", "attributes": { "step": "address", "stepOrder": 2, "label": "onboarding.jeeb.v1.address.label", "placeholder": "onboarding.jeeb.v1.address.placeholder", "maxLength": 256 }, "output": { "type": "string" }, "validations": [ { "rule": "required" }, { "rule": "maxLength", "value": 256 } ] },
  { "componentID": "home_base", "componentName": "Location Picker",
    "attributes": { "step": "service_area", "stepOrder": 3, "label": "onboarding.jeeb.v1.home_base.label" },
    "output": { "type": "object" }, "validations": [ { "rule": "required" } ] }
] }
```
- `componentID` = the submit body key and the preference sub-key (Rahma: `componentID` keys the generic submit, `endpoints.py:69-79`).
- `componentName` = UI kind for the new jeeb renderer: a deliberate deviation from Rahma's `componentID` dispatch. `Text Input` exists in `components_config.json`; `Image Upload` is the KYC precedent
  (`jeeb_kyc_form_builder.json` step `id_back`, not in `components_config` — the service reads only
  `componentID/componentName/output/validations`, `app/models.py:55-100`, so new kinds need NO service code);
  `Location Picker` is a new GENERIC kind (output `object`, `type_mapping` `app/models.py:9-19` supports `object`).
- `attributes.step` / `stepOrder` are opaque to the service (it never reads `attributes`) and let the renderer regroup
  the flat list into wizard steps — the flat shape's screen keys are what Rahma uses for this; a single key is used
  here so the gateway reads ONE template by name (F1) and the builder creates ONE PG table
  (`jeeb_jeeber_onboarding_v1_submissions`, unused, harmless — `app/database.py:70-95`).
- Labels are i18n KEYS (MSI KYC precedent `kyc.jeeb.v1.*`; AC7 gate); copy lives in the app ARBs (§5 M4).
- The builder's own schema for it (`GET /form-builder/templates/jeeb_jeeber_onboarding_v1/schema`, live shape verified
  on `jeeb_jeeber_v1`): `{ template_name, components:[{ name:"Text Input", type:"string", required:true, componentID:"state" }…], required_fields:["state","country","address","home_base"] }`
  (`app/template_endpoints.py:186-258`) — this is what the gateway validates against (§4.1).

### 2.3 Registration = data + one non-breaking loader fix (D-FB2) + env
- **D-FB1** `form-builder-service` branch `feat/jeeb-onboarding-template`: add `jeeb_onboarding_form_builder.json`
  (above). `scripts/check-generic-vocabulary.sh:24-26` excludes ONLY `jeeb_kyc_form_builder.json`; change that single
  exclude to the glob `':(exclude)jeeb_*_form_builder.json'` (same line, same `# vocab-allow:` marker, budget
  `scripts/check-generic-vocabulary.sh=2` unchanged) — the KYC precedent generalized, no new escape.
- **D-FB2** (generic, ~15 lines, `app/template_endpoints.py`): `get_template_by_name` and `get_template_schema` fall
  back to the OTHER files of `get_template_files()` (each normalized separately via `normalize_template_document`,
  reading `generated_<file>` and localizing with per-file temporary names and a (file, language) cache) when the name
  is absent from the primary. Do not copy the partner route's shared temporary filename. `get_all_templates` and
  the `male`/`female` path stay untouched: successful primary requests retain their results and colliding keys retain
  primary precedence; names only in secondary files change from 404 to 200. This is a lookup chain, not a merge. Unit test in `tests/` with two temp files. Without D-FB2 the second
  file is registered for `POST /forms/*` but `GET /templates/{name}` returns 404 (F1) — the gateway would 502.
  Interim if D-FB2 must wait: on MSI only, add the `jeeb_jeeber_onboarding_v1` key into the flat PRIMARY
  `generated_jeeb_jeeber_v1.json` (multi-key flat file, no code change) — not possible on staging (its primary is
  the single-template step-based document).
- **D-FB3** staging: `jeeb-staging-deploy.yml:197` → `add_env TEMPLATE_JSON_FILES jeeb_kyc_form_builder.json,jeeb_onboarding_form_builder.json`
  (comma list per `app/config.py:19-23`). Same PR.
- **D-FB4** MSI (owner-gated; prepare only). The recorded unit runs from
  `WorkingDirectory=/home/ec2-user/iter5-services/form-builder-service`, a plain directory, not the separate
  `iter5-native/releases/` tree. Filling a new release directory and merely restarting would still run old code.
  Before any deploy, check `systemctl cat jeeb-form-builder.service` and the running process CWD; stop if they differ
  from this recorded topology. Preserve a dated copy and the untracked `generated_jeeb_jeeber_v1.json` in the actual
  working directory; do not overwrite or delete any `generated_*.json` while placing the merged code and new template.
  If the owner instead chooses a release-directory deployment, explicitly change and verify the unit's WorkingDirectory
  and carry both template files there; that is a separate reviewed operational change, not an implied restart.
  Edit `/home/ec2-user/iter5-native/env/form-builder-service.env` and `iter5_native_run.sh:103` together to register
  `generated_jeeb_jeeber_v1.json,jeeb_onboarding_form_builder.json`; preserve the existing venv/ExecStart contract.
  After the owner restarts the service, prove its running CWD/code SHA and read the onboarding template (6 components),
  onboarding schema (4 required fields), and existing KYC schema (11 required fields). Use the actual service CWD as
  the file source: the historical release directory points its generated KYC file into that live working directory.
  This remains part of the separately authorized OD-3 combined deployment; no deployment is performed by this plan.
- **D-FB5** `jeeb-gateway`: source flavor `product/form-builder/flavors/jeeb_jeeber_onboarding_v1/default.json`
  (fields[] with `id`, `type`, `i18n_label_key`, `validations` — the `jeeb_jeeber_v1/national_id.json` shape) and
  extend `product/form-builder/qa/i18n-key-check.sh` `KEY_RE` to `^(kyc|onboarding)\.jeeb\.v1\.[a-z_]+\.(label|placeholder|helper|error\.…)$`
  (the script walks `flavors/*jeeb_*/*.json`, so the new dir is picked up automatically). ARB keys in
  `product/form-builder/l10n/intl_{en,ar}.arb` for `onboarding.jeeb.v1.*` (mobile copies exist already, §5 M4).

## 3. Decision summary

1. Template `jeeb_jeeber_onboarding_v1` registered on form-builder-service (§2). Mobile renders from it; gateway validates against its schema.
2. Route: `POST /form-builder/templates/{templateName}/submit` (upsert) + `GET /form-builder/templates/{templateName}/submission`
   on a new `FormSubmissionsBffController` `[Route("form-builder")]` (coexists with `FormBuilderController`, distinct templates), me-scoped (`UserIdentity.TryGetUserId`, `Users/UserIdentity.cs:20`).
3. Capability: `ProfileWriteSelf` / `ProfileReadSelf` (§B any-authenticated, `CapabilityRolePolicy.cs:65-66`) — v2 unchanged.
4. Persistence (the Rahma `basics` idiom): nested preference `jeeb.form.<templateName>` = `{componentID: valueAsString}`
   via `Data_SetNestedPreferenceAsync`; marker `jeeb.form.<templateName>.submitted_at` via `Data_SetSinglePreferenceAsync`.
   No gateway DB, no InMemory owner, `check-stateless-gateway.sh` needs no roster row.
5. Validation: `required_fields` + `type` from `IFormBuilderServiceClient.SchemaAsync(templateName)` (flag
   `UseUpstream:FormBuilder` is `true` in Production, `appsettings.Production.json:34`); lat/lng range + coverage in
   gateway code. Do not cite ADR-005: it is absent from gateway main (ADR-0006 records the numbering gap).
6. Coverage: v2 §3(4) verbatim, dormant (OD-2).
7. Idempotency: header accepted and ignored (upsert); no replay store.
8. Mobile: template fetch → render → submit; compiled-in fallback template until the deploy lands; 404/405/501
   fail-safe removed only in the post-deploy flip PR (v2 §3(6)-(7) ordering unchanged; PR #335 untouched).

## 4. Contract

### 4.1 `POST /form-builder/templates/{templateName}/submit`
Headers: `Authorization: Bearer <jeeb-clients token>`, `Content-Type: application/json`, optional `Idempotency-Key` (ignored; upsert).
Body = `{componentID: value}` for the template's output components (what the renderer collected):
```json
{ "portrait_object_ref": "cdn/objects/portrait-1",
  "state": "Beirut", "country": "Lebanon", "street": "Hamra", "address": "Bldg 1",
  "home_base": { "lat": 33.8938, "lng": 35.5018, "label": "Hamra" } }
```
Flow: template known to the gateway allow-list `{ jeeb_jeeber_onboarding_v1 }` (else 404 `https://jeeb.dev/errors/not-found`) →
identity (401) → `SchemaAsync(templateName, Accept-Language, ct)` (flag off → 503 `https://jeeb.dev/errors/upstream-disabled`;
upstream 404 → 404 not-found "template not registered"; upstream down → 502 `https://jeeb.dev/errors/upstream-unavailable`) →
validate: body must be a JSON object (else 400 `invalid-request`); every `required_fields` id present and non-blank;
each present key must be a schema `componentID` (unknown → 400 `validation`, `field`); `type` string→JSON string ≤ `maxLength`
(the gateway reads `validations[].rule=="maxLength"` from `GET /templates/{t}` — or hard 256 when absent), `object`→JSON object;
`home_base.lat` ∈ [-90,90], `.lng` ∈ [-180,180], finite, `.label` ≤ 256 (gateway rule). First violation wins:
`{ "type": "https://jeeb.dev/errors/validation", "title": "Invalid submission field", "status": 400, "detail": "…", "field": "state" }`
(`FieldProblem` idiom) → coverage (v2 §4.1, dormant; 409 `https://jeeb.dev/errors/out_of_coverage` + `reasonCode`) →
store → **201**:
```json
{ "templateName": "jeeb_jeeber_onboarding_v1", "userId": "106078a3-…",
  "data": { "portrait_object_ref": "cdn/objects/portrait-1", "state": "Beirut", "country": "Lebanon", "street": "Hamra",
            "address": "Bldg 1", "home_base": { "lat": 33.8938, "lng": 35.5018, "label": "Hamra" } },
  "coverage": { "checked": false, "zoneKey": null }, "submittedAt": "2026-09-06T07:00:00Z" }
```
No `submissionId` (Rahma has none; the record is the user's preferences, one per user per template). Store failures:
502 `https://jeeb.dev/errors/dependency-unavailable`, 504 `https://jeeb.dev/errors/upstream-timeout` (`SavedLocationsController.cs:134-148` idiom).

### 4.2 `GET /form-builder/templates/{templateName}/submission`
200 with the §4.1 body (rebuilt from the two preference keys; string values that are JSON objects are re-parsed for
`object`-typed components); 404 `not-found` when the nested key is absent (upstream `ApiException` 404 → null);
404 unknown template; 502/504 as above.

### 4.3 Stored preferences (what "it is in the user preferences" means)
- Nested `jeeb.form.jeeb_jeeber_onboarding_v1` (`NestedPreferenceInput.Value : Dictionary<string,string>` — strings only, Rahma's shape):
  `{ "portrait_object_ref": "cdn/objects/portrait-1", "state": "Beirut", "country": "Lebanon", "street": "Hamra", "address": "Bldg 1",
     "home_base": "{\"lat\":33.8938,\"lng\":35.5018,\"label\":\"Hamra\"}" }` — non-string outputs are JSON text
  (Rahma stores `liveIn` as `"3"`; same idea).
- Single `jeeb.form.jeeb_jeeber_onboarding_v1.submitted_at` = `"2026-09-06T07:00:00Z"` (Rahma's `isOnboarded` analogue;
  absent = not onboarded). Coverage outcome, when a zone is configured, goes to `jeeb.form.jeeb_jeeber_onboarding_v1.zone_key`.
- Readable today through the generic surface: `GET /api/UserPreferences/nested-preferences/jeeb.form.jeeb_jeeber_onboarding_v1`
  (`UserPreferencesController.cs:277`) and `GET /api/UserPreferences/preferences/jeeb.form.jeeb_jeeber_onboarding_v1.submitted_at` (`:358`).

### 4.4 `GET /form-builder/templates/jeeb_jeeber_onboarding_v1` (exists, `FormBuilderController.cs:72-83`)
`{ "name": "jeeb_jeeber_onboarding_v1", "document": [ …§2.2 components, labels localized only if `%label::`-style; ours are keys and pass through… ] }`.
Mobile sends `Accept-Language` (forwarded, `:185-189`). No gateway change.

## 5. Fix steps (ordered)

### form-builder-service — branch `feat/jeeb-onboarding-template` off `origin/main` (`801ef01`)
FB1. `jeeb_onboarding_form_builder.json` (§2.2). FB2. `app/template_endpoints.py` lookup fallback (D-FB2) + `tests/test_template_lookup_fallback.py`.
FB3. `scripts/check-generic-vocabulary.sh:26` exclude glob (D-FB1). FB4. `.github/workflows/jeeb-staging-deploy.yml:197` env list (D-FB3).
FB5. The review found the vocabulary gate already red on pristine `801ef01` (three workflow-name literals in
`scripts/audit-fail-closed-deployments.py:9,11,13`), its workflow disabled, and no CI workflow running pytest. Compare
vocabulary output against a separate pristine checkout: require zero added findings, without stashing anyone's work.
Run pytest locally with the supported Python 3.11 dependencies and run the active fail-closed audit; record baseline
failures honestly. Fixing/re-enabling the existing gate is a separate owner choice. Then local run `TEMPLATE_JSON_FILES=jeeb_kyc_form_builder.json,jeeb_onboarding_form_builder.json python -m app.main`
and `curl :8000/templates/jeeb_jeeber_onboarding_v1/schema` → 6 components / 4 required. PR title
`feat(templates): register jeeb_jeeber_onboarding_v1 (data) + serve non-primary templates by name`. PREPARE D-FB4 (hand the owner the exact commands).

### jeeb-gateway — branch `feat/form-submissions-preferences` off `origin/main` (`6679f6ee`; local clone is 515 commits stale → worktree, v2 C14)
G1. `src/JeebGateway/FormSubmissions/FormSubmissionRecord.cs`: `Answers : IReadOnlyDictionary<string,string>`, `SubmittedAt`, `ZoneKey?`; response DTO `FormSubmissionResponse` (§4.1, camelCase) + `CoverageDto`.
G2. `IFormSubmissionStore`: `GetAsync(userId, templateName, ct)` → record?; `SetAsync(userId, templateName, record, ct)`.
G3. `RemoteUserPreferencesFormSubmissionStore.cs` — the `RemoteUserPreferencesNotificationPreferencesStore` idiom
    (`IServiceScopeFactory`, lazily scoped `ServiceRemoteUserPreferencesClient`, read budget 1500 ms / write 2000 ms,
    `NotificationPreferences/RemoteUserPreferencesNotificationPreferencesStore.cs:27-158`), keys `jeeb.form.{t}` (nested) and
    `jeeb.form.{t}.submitted_at` (single). Never log answers.
    ```csharp
    // Rahma "basics" idiom: one nested dict per form, then the isOnboarded-style marker.
    await client.Data_SetNestedPreferenceAsync(userId, key, new NestedPreferenceInput { Value = answers }, budget.Token);
    await client.Data_SetSinglePreferenceAsync(userId, key + ".submitted_at", new PreferenceValue { Value = submittedAt }, budget.Token);
    ```
G4. `FormSubmissions/FormTemplateRegistry.cs` (allow-list `{ "jeeb_jeeber_onboarding_v1" }`) and
    `FormSubmissions/TemplateSchemaValidator.cs`: input = `FormSchemaDocument.Schema` (`components[]`, `required_fields[]`)
    + `FormTemplateDocument.Document` (for `maxLength`) + body `JsonElement`; output `(field, detail)?`; `object` values
    serialized with `JsonSerializerDefaults.Web` for storage. `HomeBaseRules.Validate(JsonElement)` for lat/lng/label.
G5. Coverage options/resolver — v2 G5 verbatim (dormant, OD-2).
G6. `Controllers/FormSubmissionsBffController.cs` — flow of §4.1/4.2; injects `IFormBuilderServiceClient`,
    `IOptionsMonitor<UpstreamFeatureFlags>` (`FormBuilder` flag, `Services/UpstreamFeatureFlags.cs:182`), `IFormSubmissionStore`,
    `IJeeberOnboardingCoverageResolver`. `[RequireCapability]` on both actions. Comments ≤ 2 lines.
G7. `Program.cs` after `AddSavedLocations()` (~`:1734`): options + resolver + `AddSingleton<IFormSubmissionStore, RemoteUserPreferencesFormSubmissionStore>()`.
G8. `scripts/gwdbx-flag-registry.txt` rows for `JeeberOnboarding:Coverage:Boundaries` / `FailOpenWhenUnconfigured` (`setting -`).
G9. `appsettings.json` + `appsettings.Production.json`: `"JeeberOnboarding": { "Coverage": { "Boundaries": [], "FailOpenWhenUnconfigured": true } }`.
G10. Optional in the same PR (live defect seen in v2 §0): `FormBuilderServiceClient.ListTemplatesAsync` binds a
     `List<FormTemplateSummary>` while the upstream emits `{ "<name>": [...] }` → bind `Dictionary<string, JsonElement>` and
     project names. Not on the mobile path; include only if the wire test change is trivial.
G11. `product/form-builder/flavors/jeeb_jeeber_onboarding_v1/default.json`, `qa/i18n-key-check.sh` `KEY_RE`, l10n ARBs (D-FB5).
G12. Tests — `tests/JeebGateway.IntegrationTests/FormSubmissions/FormSubmissionsEndpointTests.cs` (`WebApplicationFactory<Program>`,
     `X-User-Id` + `X-User-Roles` headers as `SavedLocationsEndpointTests.cs:26-32`; `RemoveAll<IFormSubmissionStore>()` +
     dictionary fake; `RemoveAll<IFormBuilderServiceClient>()` + `FakeFormBuilder` returning the §2.2 schema — the
     `Kyc/KycSubmissionWiringEndpointTests.cs:115-150` pattern; `UseSetting("FeatureFlags:UseUpstream:FormBuilder","true")`):
     401 no identity; 201 `driver`/`customer`/`admin`; 404 unknown template (allow-list) and 404 when the fake schema throws
     `HttpRequestException(NotFound)`; 503 flag off; 502 fake schema throws; 400 missing `state` (`field=="state"`);
     400 unknown key `vehicle_number`; 400 `home_base.lat` 95; 400 non-object body; 400 `state` > 256; replay same body → 201 same record;
     GET 404 before / 200 after; 409 + 201 inside box with `UseSetting("JeeberOnboarding:Coverage:Boundaries:0:…")`;
     502/504 store exceptions. Unit: `TemplateSchemaValidatorTests` (each rule), `HomeBaseRulesTests`, coverage resolver (v2). Run `CapabilityCoverageGuardTests`.
G13. `bash scripts/export-openapi.sh` + compat check (additive paths pass); commit `artifacts/openapi/jeeb-gateway.v1.json` if only the two paths changed.
G14. Gate: `dotnet restore --locked-mode`, build, both test projects, `bash scripts/check-stateless-gateway.sh`, `bash scripts/check-gwdbx-flag-registry.sh`,
     `bash product/form-builder/qa/i18n-key-check.sh`. PR `feat(form-builder): onboarding template submit/read persisted in user preferences (P01 v3)`.
G15. PREPARE the OD-3 combined deploy: MSI native gateway + form-builder-service (D-FB4) in one window; one staging dispatch of both services.

### jeeb-mobile — branch `fix/dm-onboarding-route` off post-merge `main` (never on PR #335)
Land ONLY after G15 is live on MSI and staging (deploy-order coupling, v2 §3(7)).
M1. `lib/features/jeeber_onboarding/domain/dm_onboarding_template.dart` (new): `DmOnboardingTemplate { name, steps }`,
    `DmOnboardingTemplateStep { id, order, components }`, `DmOnboardingComponent { id, kind, labelKey, placeholderKey, required, maxLength }`,
    `kind ∈ {imageUpload, textInput, locationPicker, unknown}` from `componentName`; `fromDocument(List<dynamic>)` groups by
    `attributes.step` sorted by `stepOrder`; `static final builtIn = …` (the §2.2 template compiled in — the fail-safe).
M2. `domain/dm_onboarding_template_gateway.dart` + `data/dio_dm_onboarding_template_gateway.dart`:
    `GET /form-builder/templates/jeeb_jeeber_onboarding_v1` with `Accept-Language`; parse `document`; ANY failure (404 before the
    deploy, 503 flag off, network) → `builtIn` + `Diag.event('dm_onboarding_template_fallback', {'status': …})`; success →
    `Diag.event('dm_onboarding_template_source', {'source': 'remote', 'components': n})`. This is the "fail-safe until deployed" for the render half.
M3. `application/dm_onboarding_cubit.dart` / `dm_onboarding_state.dart`: `loadTemplate()` on creation; state gains `template`,
    `stepIndex`, `answers: Map<String,String>` (replaces the four fixed string fields + setters → `setAnswer(id, value)`);
    `photo` and `homeBase` stay typed; `next()`/`back()` walk `template.steps`; `canContinue` = every `required` component
    of the current step answered (client-side validation from the template, as Rahma `form_builder_screen.dart:603-643` and `libraries/fanus_form_builder/lib/presentation/screens/screens_helper.dart:158-181,357-386`).
    `_draft()` builds `DmOnboardingSubmission(answers: {...answers, 'home_base': {lat,lng,label}, if portrait 'portrait_object_ref': ref})`.
M4. Presentation: `dm_onboarding_screen.dart` renders `template.steps[stepIndex]` through a `DmOnboardingStepRenderer`:
    `imageUpload` → existing `DmOnboardingPhotoStep`; `textInput` list → `DmOnboardingAddressStep` fed by
    `List<DmAddressFieldSpec>` built from the components (`dm_onboarding_address_step.dart:47-77` already takes specs);
    `locationPicker` → `DmOnboardingServiceAreaStep`. Label/placeholder keys resolve through a
    `DmOnboardingLabels.resolve(l10n, key)` table mapping `onboarding.jeeb.v1.state.label` → `l10n.dmOnboardingAddressStateLabel`
    etc. (all EN+AR keys exist: `lib/l10n/app_en.arb:3287-3350`); unknown key → last segment, humanized. No ARB change.
M5. `domain/dm_onboarding_gateway.dart`: `submitPath = '/form-builder/templates/jeeb_jeeber_onboarding_v1/submit'`;
    `DmOnboardingSubmission.toJson()` = `answers` (§4.1 body). `data/dio_dm_onboarding_gateway.dart`: delete the 404/405/501
    `return` (keep the Diag line, then throw), 409 discriminator `typeSuffix == 'out_of_coverage' || reasonCode == 'out_of_coverage'`
    (`lib/core/network/gateway_problem.dart:72-86`), drop `_reasonOf/_lastSegment`. 5 `implements` sites incl.
    `lib/devtool/catalog/fixtures/dm_onboarding_screen_fixtures.dart` follow the new DTO.
M6. Optional mock parity: `lib/core/network/mock_gateway_client.dart:84` prefix map + `jeeb-mock-backend/src/services/form-builder-service.ts:9`
    template registry — only if mock mode is still exercised (verify at implementation).
M7. Tests: `test/dio_dm_onboarding_gateway_test.dart` (path, body keyed by componentID incl. nested `home_base`, 404 → exception + Diag,
    405/501 → exception, 409 typeSuffix / reasonCode, 500); `test/dm_onboarding_template_test.dart` (parse §2.2 document → 3 steps in
    order, required flags, unknown kind tolerated, fallback on 404/503/timeout with Diag); `test/dm_onboarding_cubit_test.dart`
    (template load → steps, `canContinue` gating, `_draft` shape); `test/dm_onboarding_screen_test.dart` + midnight goldens
    re-baselined for the renderer (`git add -A` first, R6). Gate: `dart analyze --fatal-infos .`, `flutter test --exclude-tags capture`
    (79 % floor), `qa/t-mob-fix-002/l10n_parity_check.sh --analyze`, `qa/t-mob-fix-002/ar_plurals_check.sh`, `tool/check_design_tokens.sh`.
    PR body records OD-1 v3 and updates `docs/build-out/20_GAP__jeeber-onboarding.md:118` (mock path superseded).

## 6. Tests summary
form-builder-service: lookup-fallback unit test + local template smoke. Gateway: `FormSubmissionsEndpointTests` (~20 cases),
`TemplateSchemaValidatorTests`, `HomeBaseRulesTests`, coverage resolver tests, `CapabilityCoverageGuardTests`, wire test for
G10 if taken, shell gates. Mobile: template parse/fallback, gateway, cubit, screen/golden suites; full `flutter test --exclude-tags capture`.

## 7. Validation on the live gateway and the real device

A. Post-deploy contract proof (this Mac over Cloudflare; MSI first, then staging host). Karim `106078a3-…` or a fresh `devtool_client_<ts>`:
```
B=https://msi.olivium.space/gateway; T=jeeb_jeeber_onboarding_v1
A=$(curl -s -X POST $B/auth/tokens -H 'Content-Type: application/json' \
  -d '{"userId":"106078a3-4758-45c1-9d31-71b503a3fce4","roles":["jeeber","client"]}' | python3 -c 'import json,sys;print(json.load(sys.stdin)["accessToken"])')
# 200 — the template the mobile builds from (6 components, 3 steps)
curl -s $B/form-builder/templates/$T -H "Authorization: Bearer $A" -H 'Accept-Language: ar' | python3 -c 'import json,sys;d=json.load(sys.stdin)["document"];print(len(d),[c["attributes"]["step"] for c in d])'
# 201, coverage.checked=false (OD-2)
curl -s -w '\nHTTP %{http_code}\n' -X POST $B/form-builder/templates/$T/submit -H "Authorization: Bearer $A" -H 'Content-Type: application/json' \
  -d '{"state":"Beirut","country":"Lebanon","street":"Hamra","address":"Bldg 1","home_base":{"lat":33.8938,"lng":35.5018,"label":"Hamra"}}'
# 200 typed read-back
curl -s -w '\nHTTP %{http_code}\n' $B/form-builder/templates/$T/submission -H "Authorization: Bearer $A"
# 200 — the SAME answers through the generic user-preferences surface = "stored in the user preferences"
curl -s -w '\nHTTP %{http_code}\n' $B/api/UserPreferences/nested-preferences/jeeb.form.$T -H "Authorization: Bearer $A"
curl -s -w '\nHTTP %{http_code}\n' $B/api/UserPreferences/preferences/jeeb.form.$T.submitted_at -H "Authorization: Bearer $A"
# 400 field=state (missing); 400 field=vehicle_number (unknown); 404 unknown template; 401 no bearer
curl -s -w '\nHTTP %{http_code}\n' -X POST $B/form-builder/templates/$T/submit -H "Authorization: Bearer $A" -H 'Content-Type: application/json' -d '{"country":"Lebanon","address":"x","home_base":{"lat":1,"lng":1,"label":""}}'
```
Expected: 200 / 201 / 200 / 200 / 200 / 400 / 400 / 404 / 401. Sanity first: `GET $B/api/users/me/saved-locations` 200 (RUP up) and
`GET $B/form-builder/templates/jeeb_jeeber_v1/schema` 200 (KYC template untouched by the registration).

B. Real device SM-A336B (`RZCT505K7WF`), `adb install -r` only, never uninstall; Dev Tool → Server URL →
`dev.base_url_override = https://msi.olivium.space/gateway` → Apply & Restart (check `/data/local/tmp/jeeb-dev-seam.json` first —
stale-token trap); Scenario Users → Super Login Plus → fresh `devtool_client_<ts>` (non-login feature, A17). Serial after P04 Part A;
evidence → `scratchpad/device-evidence-4/p01/`, `session` line in `device-evidence-4/CREATED.jsonl`.
1. Delivery tab → Register → `adb logcat -s flutter | grep '\[jeeb-diag\]'` shows `GET /form-builder/templates/jeeb_jeeber_onboarding_v1` 200
   and `dm_onboarding_template_source source=remote components=6` — the wizard on screen is BUILT from the template
   (switch the phone to Arabic: the request carries `Accept-Language: ar`, labels render AR from the app ARBs).
2. Photo (gallery) → Continue → State/Country/Street/Address → Continue (Continue disabled until `state`, `country`, `address` filled — template `required`) →
   pin anywhere → Continue: `POST …/submit` 201, no `dm_onboarding_submit_route_absent`; KYC wizard opens (`/profile/kyc`); §7A read-back
   with that user's token shows the pinned `home_base`.
3. Re-enter, change the address, Continue: read-back shows the NEW answers and a NEW `submitted_at` (upsert).
4. Fallback proof: Dev Tool → base URL to a blackhole host → Register: wizard still renders (Diag `dm_onboarding_template_fallback`), Continue on
   service-area → `dmOnboardingCoverageCheckFailed` snack, wizard stays. Restore URL + locale.
5. Out-of-coverage: not reproducible live under OD-2 (catalog fixture `DmOnboardingScreenOutOfCoverageGateway` remains the UI proof).

## 8. Risks
- **Shared-service touch (new vs v2).** D-FB2 changes `form-builder-service` code used by Rahma/FDS1/Salhley; it is a lookup FALLBACK
  only (primary first, `get_all_templates` and flavors untouched), with tests for unchanged successful lookups and new secondary lookups.
  Rahma's recorded deployed SHAs are `f1e9d9f` / `1b6b4c8`, not current main: a future owner redeploy carries the intervening drift too.
  Do not equate source compatibility with proof against a different deployed version.
- **Registration is an ops change per environment** (restart of `jeeb-form-builder.service` on MSI by `ouday`; staging dispatch);
  `TEMPLATE_JSON_FILES` on MSI is ALSO hardcoded in `iter5_native_run.sh:103` — both must change or a rerun reverts it.
  The actual MSI working directory must retain `generated_jeeb_jeeber_v1.json` (not in git); a new release dir alone is not the deploy target.
- **Two live KYC template vocabularies** (MSI flat `componentName=field id` vs staging step-based `componentName=UI kind`): the
  onboarding template pins jeeb's chosen vocabulary (`componentName` UI kind + `componentID` field id), not Rahma's dispatch vocabulary on both; unaffected KYC stays as is.
- Deploy-order coupling: the render half is safe in any order (fallback template); the submit half keeps v2's rule — flip only after
  staging + MSI have the route AND the template.
- Nested-preference values are strings only (Rust `NestedPreferenceInput`): `home_base` is JSON text inside the dict; the typed
  read-back re-parses it. Consumers using the generic surface see the string.
- `attributes.step` is a convention the service does not enforce; a template without it renders as one step (renderer default) — tested.
- `GET /form-builder/templates` (list) stays broken (500) unless G10 is taken; mobile does not call it.
- Cloudflare replaces 502 bodies with text/plain (v2 §0); `AppFailure.of` classifies by status.
- Mobile effort is larger than v2 (renderer + state refactor + golden re-baseline): the fixed-enum wizard becomes template-driven.

## 9. Dependencies
- Shared gateway files with P15: proposed integration order is P01 gateway first, then P15 G0. The second lander reconciles `Program.cs`, both appsettings files, flag-registry entries and exported OpenAPI, then reruns those gates. A changed owner ordering must be recorded in both plans.
- OD-3 `combined`: ONE MSI deploy window covering gateway + form-builder-service (+ env/restart), ONE staging dispatch of both; §7A after it;
  mobile flip + §7B after staging also has route + template.
- OD-2 `nobbox`: G9 empty boundaries everywhere; 409 dormant.
- OD-0 `widen`: irrelevant — the flip stays off #335 for deploy-order reasons.
- PR #330 invariants untouched (no `auth_interceptor.dart` edit); comments ≤ 2 lines; `git add -A` before mobile tests (R6).
- C19 demo-account caveat, C12/C13 evidence and device-queue rules carried from v1/v2.

## 10. Effort
form-builder-service **S** (data file + ~15-line fallback + test + 2 one-liners, ~½ day). Gateway **M** (controller + store + schema
validator + coverage + ~25 tests + config/registry, ~1–1.5 days). Mobile **M** (template model/gateway + cubit/state refactor +
step renderer + tests/goldens, ~2–3 days). Ops: two env edits + one service restart per environment, owner-gated. Overall **M–L**.

## 11. Owner-gated execution and newly surfaced decisions
All choices are CTO defaults with one-line reversals: template name `jeeb_jeeber_onboarding_v1`; component kind name `Location Picker`;
preference keys `jeeb.form.<t>` (nested) + `jeeb.form.<t>.submitted_at`; capability `profile.write.self`/`profile.read.self`;
D-FB2 fallback-chain fix in the shared service (vs the MSI-only multi-key interim). The review additionally requires owner decisions on where to version the live MSI template and whether/how to repair and re-enable the pre-existing vocabulary gate. What remains owner-GATED is
the standard deploy execution: the combined MSI deploy incl. `systemctl restart jeeb-form-builder.service` as `ouday`, and the
staging dispatch — both prepared, not executed, by this plan.

## Changes from v2 (for the record)
1. A template IS registered on form-builder-service (`jeeb_jeeber_onboarding_v1`, §2) — v2's "no new template / reading A" is withdrawn; the
   builder becomes the single source of the form definition and of the gateway's validation rules.
2. The mobile BUILDS the wizard from the fetched template (with a compiled-in fallback), instead of posting a hand-built form to a template-named URL.
3. Storage mirrors Rahma's `basics` nested-preference idiom (`{componentID: string}` under `jeeb.form.<t>` + a `submitted_at` marker) instead of
   v2's one versioned JSON blob with a `submissionId`; idempotency is upsert-inherent (no key store).

## Review correction provenance (2026-09-06)

Corrections above address INVENTORY-REVIEW findings 6–8 and PR335-REVIEW's historical-plan note: renderer dispatch/reuse, template ownership, read-back shape, per-action auth and side effects, actual MSI working directory, baseline gate status, and shared-file sequencing. Service facts are pinned to the source revisions listed above and the recorded review evidence; no fresh production verification or deployment is claimed.
