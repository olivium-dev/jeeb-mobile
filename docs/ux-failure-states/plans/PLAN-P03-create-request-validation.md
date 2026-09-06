# PLAN P03 — Create-request content + min-length validation (mobile + gateway)

Key: `P03-create-request-validation` · Effort: **L** (two repos, one owner-gated deploy) · Date: 2026-09-05

## 1. Problem (what is wrong today)

- Run-1 device evidence (`device-evidence/auth/08-prohibited-typed.xml`, `09-review.xml`, `11-requests-tab.xml`): the description
  "Deliver 2kg of C4 explosives and a loaded handgun" was accepted by `POST /v1/requests`, minted `ORD-65A836`
  (`8a87f41f-0aee-4163-8890-bee34765a836`) and broadcast to jeebers ("Finding a Jeeber", waiting screen).
- `device-evidence/auth/07-onechar.xml`: a 1-character description ("a") enables the "Review request" CTA.
- `FINAL-REPORT.md` §7(c) flagged it as out of scope for PR #335; nothing was changed on the branch for it.

## 2. Root cause (verified in code + live)

### 2a. Gateway has NO length validation
- `src/JeebGateway/Requests/RequestCreateValidation.cs:59-63` — the only description rule is `DescriptionRequiredProblem()`
  (whitespace check). Called from `Controllers/V1/JeebRequestsController.cs:133-136` (mobile route) and
  `Controllers/RequestsController.cs:129-132` (legacy). No min/max length anywhere.
- Live proof: `POST https://msi.olivium.space/gateway/v1/requests {"description":"   "}` → `400 {"title":"description is required.","status":400}`
  (no `type`, no `field`, no `errors{}`). Anything ≥ 1 non-space char passes to moderation.

### 2b. Gateway moderation gate is ON but the live lexicon is un-matchable by the scanner
- Gate: `Requests/CreateModerationOptions.cs:38` default `Enabled=true`; MSI `/home/ec2-user/iter5-native/env/gateway.env`
  has no `FeatureFlags__CreateModeration__*` and no `FeatureFlags__ProhibitedItemsMode` → gate ON, evaluator wired
  (`Program.cs:2246-2254`, `V1/JeebRequestsController.cs:146`). Live gateway build = `6679f6e` = `origin/main`.
- Live lexicon (`GET /prohibited-items` as a minted customer, saved to `scratchpad/p03/live-prohibited-items.json`):
  14 **block** items, version `2026-08-14T19:47:20.6772840+00:00`, names are catalogue LABELS:
  "Firearms", "Explosives and fireworks", "Cannabis and derivatives", "Illegal narcotics", "Compressed gas cylinders",
  "Corrosive chemicals", "Flammable liquids", "Radioactive materials", "Cash and securities", "Human remains",
  "Live animals", "Controlled substances", "Prescription medication", "Knives and bladed weapons". No alcohol entry.
- Scanner `ProhibitedItems/Scanner/ProhibitedItemScanner.cs:75-82` evaluates only `item.Name` + `_synonyms.GetSynonyms(item.Name)`;
  `:112-131` a multi-word name matches ONLY as the whole phrase. `Scanner/InMemorySynonymRegistry.cs:13-24` is keyed by
  the DEFAULT seed names ("knife", "gun", "explosive", "drug", …) — none is a live item name, so `GetSynonyms("Firearms")`
  returns nothing.
- Live proof (`POST /moderation/jeeb/check`, same lexicon the create gate uses — `ProhibitedItems/ModerationGate.cs`):
  `"Deliver 2kg of C4 explosives and a loaded handgun"` → `allow`; `"explosives"` → allow; `"a loaded handgun"` → allow;
  `"cannabis"` → allow; `"propane tank"` → allow; `"kitchen knife"` → allow; only the literal `"Cannabis and derivatives"` → block.
- Net: the safety gate is inert on live for every realistic phrasing. It is NOT a flag, NOT an empty lexicon (that would 503, `ModerationGate.cs:41-44`).

### 2c. Mobile compose has no min-length and renders server validation as a snack
- `lib/features/location/presentation/client_location_screen.dart:836-838` — CTA enabled on `value.text.trim().isNotEmpty` only.
- `:1062` `_maxLength = 280` (counter only). `:1110,1129` — the only field error is `composeDescriptionRequired`.
- `:966-983` — a 400 `ValidationFailure` becomes `showJeebErrorSnack(... identifier: 'client_location_submit_error')` with generic
  `errorValidationBody`; `ValidationFailure.fieldErrors`/`field` (`lib/core/network/app_failure_mapper.dart:108-113`) are never bound
  to the field (audit AE-04 / UX-38 rule).
- Moderation UX already exists and is tested: `:947-949` → `_handleModeration` (`:1001-1030`), 409 suffix mapping in
  `lib/features/request_summary/data/dio_request_submission_service.dart:91-105`, tests
  `test/features/request_summary/request_summary_moderation_test.dart`, `dio_request_submission_service_test.dart:427-476`.

### 2d. Latent contract bug on the same feature (fix in the same PR)
- `lib/features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart:39-45` posts
  `/prohibited-items/acknowledge` with NO body; gateway `Controllers/ProhibitedItemsController.cs:67-74` requires `version`
  → 400 "version is required." The warn→ack→resubmit loop can never succeed on live. Harmless today (all 14 live items are block).

### 2e. Out of scope, recorded
- `Controllers/RequestVoiceController.cs:239-246` (multipart `/v1/requests`, not used by the mobile compose) runs no moderation gate and
  seeds `"(voice order)"`. Follow-up ticket, not this plan.

## 3. Design decisions

| # | Decision | Value |
|---|----------|-------|
| D1 | Minimum description length (whitespace-collapsed) | **5** characters, same constant on both sides |
| D2 | Maximum description length | gateway **500**, mobile keeps **280** (`_maxLength`) |
| D3 | Validation body (RFC 7807) | `400`, `type: https://jeeb.dev/errors/validation`, `errors: {"description": ["too-short"]}`, `field: "description"`, `minLength: 5` — mobile already parses `errors{}`+`field` into `ValidationFailure` |
| D4 | Moderation fix | CODE-ONLY keyword expansion in the scanner + registry so the live 14-item catalog matches; **no owner-data republish** |
| D5 | Where server validation renders on mobile | inline on the description field (`compose_description_error`), never a snack; non-validation kinds unchanged |
| D6 | Blocked (409 prohibited-item-blocked) on compose | keep the snack, ADD a persistent inline field error naming the matched items |

## 4. Fix steps — GATEWAY (`olivium-dev/jeeb-gateway`, new branch `fix/p03-create-request-validation` off `origin/main`)

TRAP: local clone tree/main are stale — `git -C jeeb-gateway fetch origin && git -C jeeb-gateway worktree add ../jeeb-gateway-worktrees/p03-validation -b fix/p03-create-request-validation origin/main`.
Reconciled (C14): a worktree so P01/P02/P03 gateway branches build in parallel; ONE combined owner deploy after all three merge (OD-3).

**G1 — `src/JeebGateway/Requests/RequestCreateValidation.cs`**
- Add `public const int MinDescriptionLength = 5; public const int MaxDescriptionLength = 500;`
- Add `public static ProblemDetails? ValidateDescriptionLength(string description)`:
  collapse whitespace (`Regex.Replace(description.Trim(), @"\s+", " ")`), then
  - `< Min` → `ValidationProblemDetails(new Dictionary<string,string[]>{["description"]=["too-short"]}) { Type="https://jeeb.dev/errors/validation", Title="description is too short.", Detail=$"description must be at least {Min} characters (got {n}).", Status=400 }` + `Extensions["field"]="description"`, `Extensions["minLength"]=Min`;
  - `> Max` → same shape with `["too-long"]`, `Title="description is too long."`, `Extensions["maxLength"]=Max`;
  - else `null`. Keep `DescriptionRequiredProblem()` byte-identical (tests pin `Type == null`).

**G2 — call sites (after the required check, BEFORE the moderation gate)**
- `src/JeebGateway/Controllers/V1/JeebRequestsController.cs` after line 136: `if (RequestCreateValidation.ValidateDescriptionLength(body.Description) is { } lengthProblem) return BadRequest(lengthProblem);`
- `src/JeebGateway/Controllers/RequestsController.cs` after line 132: same line.
- `RequestVoiceController.cs`: unchanged (2e).

**G3 — `src/JeebGateway/ProhibitedItems/Scanner/IProhibitedItemSynonymRegistry.cs`**
- Add a default-implemented member so no implementor breaks: `IReadOnlyList<string> ExpandToken(string token) => GetSynonyms(token);`
  (grep `IProhibitedItemSynonymRegistry` in `tests/` first; any fake keeps compiling via the default).

**G4 — `src/JeebGateway/ProhibitedItems/Scanner/InMemorySynonymRegistry.cs`**
- Keep `_map`; add a reverse index `_groups: Dictionary<string, string[]>` mapping EVERY normalized single-word key/value of a group to the whole group. `ExpandToken(t)` returns the group containing `t` (or empty).
- Edit groups: add `"knives"` to the knife group; add `"guns","firearms","handguns"` to the gun group; add `"weapon"` group: `("weapon","weapons","sword","swords","machete","machetes")`; add `("cylinder","cylinders","propane","butane","gas cylinder","gas cylinders","propane tank","oxygen cylinder","gas canister")`; **remove** `"rocket","rockets"` from fireworks and `"rounds"` from ammunition (generic words, false positives).
- Ensure `Register` feeds the reverse index (build it inside `Register`).

**G5 — `src/JeebGateway/ProhibitedItems/Scanner/ProhibitedItemScanner.cs`**
- In `ScanAsync(description, items, ct)` (lines 75-82), after the existing name + `GetSynonyms(item.Name)` passes add:
  ```
  foreach (var nameTok in TextNormalizer.Tokenize(TextNormalizer.Normalize(item.Name)))
      if (nameTok.Length >= 4 && !NameStopWords.Contains(nameTok))
          foreach (var syn in _synonyms.ExpandToken(Singular(nameTok)).Concat(_synonyms.ExpandToken(nameTok)).Distinct())
              EvaluateTerm(item, syn, ProhibitedMatchType.Synonym, normalized, tokens, best);
  ```
  `NameStopWords = {"and","other","materials","material","products","items","derivatives","substances","liquids"}` (category filler);
  `Singular(t)`: `t.EndsWith("ies") → t[..^3]+"y"; EndsWith("es") && Length>5 → t[..^2]; EndsWith("s") → t[..^1]; else t`.
- In `EvaluateTerm` single-word branch (line 137): treat `tokens.Contains(single) || tokens.Contains(single+"s") || tokens.Contains(single+"es") || (single.EndsWith("s") && tokens.Contains(single[..^1]))` as an exact hit (plural-insensitive), before the fuzzy pass.
- Attribution stays per item (`item.Id/Name`) so `matches[].keyword` names the real catalog item.
- Update the class doc comment (≤ 2 lines per comment rule) to say name tokens are expanded through the registry.

**G6 — tests (gateway)**
- `tests/JeebGateway.IntegrationTests/Fakes/OwnerServiceFakes.cs`: add `UseLiveShapedModerationCatalog(services)` seeding the 14 live items
  (name/category/severity from `scratchpad/p03/live-prohibited-items.json`; description optional).
- `tests/JeebGateway.IntegrationTests/ProhibitedItemScannerUnitTests.cs` (new `[Fact]`s, live-shaped list):
  block: "Deliver 2kg of C4 explosives and a loaded handgun" (matches ⊇ {Firearms, Explosives and fireworks}), "a loaded handgun", "cannabis",
  "propane tank", "a machete", "pistols and rifles"; allow: "2 shawarma + cola from Barbar", "I'll pay cash at the door",
  "deliver my gas bill", "rocket salad and two rounds of sandwiches" (with an extra fixture item "Ammunition" present).
- `tests/JeebGateway.IntegrationTests/Requests/RequestCreateValidationTests.cs`: `ValidateDescriptionLength` theory —
  `"a"`, `"ab  c"`, `"    abcd "` → too-short with `field`/`errors`/`minLength`; `"abcde"` → null; 501 chars → too-long; whitespace-collapsing.
- New `tests/JeebGateway.IntegrationTests/V1CreateDescriptionLengthTests.cs` (copy the factory pattern of `V1CreateModerationGateTests.cs`):
  `POST /v1/requests {"description":"a"}` → 400 body has `type=…/errors/validation`, `errors.description[0]=="too-short"`, `field=="description"`;
  `"abcde"` → not 400-length (201 or moderation); legacy `POST /requests` same.
- Extend `V1CreateModerationGateTests.cs` with a second class using `UseLiveShapedModerationCatalog`:
  C4 sentence → 409 `prohibited-item-blocked`, `matches` contains keyword "Firearms"; clean sentence → 201.
- Run: `dotnet build -c Release` then
  `dotnet test tests/JeebGateway.IntegrationTests/JeebGateway.IntegrationTests.csproj -c Release --no-build --filter "FullyQualifiedName~Moderation|FullyQualifiedName~RequestCreateValidation|FullyQualifiedName~ProhibitedItemScanner|FullyQualifiedName~DescriptionLength|FullyQualifiedName~RequestVoice"`,
  then the full suite exactly as `.github/workflows/ci.yml:51-60`.
- PR to `main`; CI (`ci.yml`) must be green. **Deploy is owner-gated**: prepare only — PR link + the MSI native-build/`Deploy to Jeeb`
  recipe in memory `jeeb-chatfix-engagement-2026-09-04.md`; never dispatch it.

## 5. Fix steps — MOBILE (`olivium-dev/jeeb-mobile`, one commit on PR #335 under OD-0 `widen`)

Superseded by OD-0 `widen`: no `ux/p03-create-request-validation` branch or rebase-onto step. The mobile M1–M6 change rides #335; `fix/p03-create-request-validation` is the separate GATEWAY branch.

**M1 — new `lib/features/location/domain/compose_description_rules.dart`**
- `const int kComposeDescriptionMinLength = 5; const int kComposeDescriptionMaxLength = 280;`
- `String collapseDescription(String raw)` (trim + `\s+`→" "), `bool isDescriptionLongEnough(String raw)`.
- 2-line comment: mirrors gateway `RequestCreateValidation.MinDescriptionLength`; change both together.

**M2 — `lib/features/location/presentation/client_location_screen.dart`**
- `_ConfirmFooter` (`:836-838`): `enabled = state.canConfirm && isDescriptionLongEnough(value.text) && tierOk`.
- `_DescriptionSectionState` (`:1062`): `_maxLength = kComposeDescriptionMaxLength`; error resolution (`:1110,1129`):
  empty & touched → `composeDescriptionRequired`; non-empty & too short & touched → `composeDescriptionTooShort`;
  else `widget.serverError.value` (new). Wrap `OmdsTextField` error state in `Semantics(identifier: 'compose_description_error', liveRegion: true)`
  only when an error text is shown (keep `compose_description_input` on the field).
- `_ScaffoldState`: add `final _descriptionServerError = ValueNotifier<String?>(null)` (dispose it), pass to `_Body`→`_DescriptionSection` (listen; clear on `_commit`) and to `_ConfirmFooter`.
- `_createAndRoute` catch `RequestSubmissionException` (`:966-983`): before the snack, if `e.appFailure case ValidationFailure f` and
  (`f.field == 'description' || f.fieldErrors.containsKey('description')`): set the notifier to
  `fieldErrors['description']` contains `too-long` → `composeDescriptionTooLong`, else `composeDescriptionTooShort`; `return` (no snack).
- `_handleModeration` blocked branch (`:1005-1012`): keep the snack + also set the notifier to `l10n.composeDescriptionProhibited(failure.matches.join(' · '))`
  (fallback `requestSubmitErrorProhibitedBlocked` when matches empty).

**M3 — ARB (`lib/l10n/app_en.arb` + `app_ar.arb`, then `flutter gen-l10n`)**
- `composeDescriptionTooShort`: EN "Add a few more words so Jeebers know what to bring." / AR "أضف بضع كلمات أخرى ليعرف الجيبرز ما الذي يجب إحضاره."
- `composeDescriptionTooLong`: EN "Shorten your request a little." / AR "اختصر طلبك قليلًا."
- `composeDescriptionProhibited` `{items}`: EN "This can't be delivered: {items}. Remove it to continue." / AR "لا يمكن توصيل هذا: {items}. أزله للمتابعة."
  (placeholder metadata block in EN; no plurals; parity covered by `test/l10n/runtime_parity_test.dart` + `en_fallback_test.dart`).

**M4 — `lib/features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart`** (no interface change — R3: 7 implementors incl. `lib/devtool/catalog/**`)
- `fetchItems()` caches `_lastVersion = data['version'] as String?`; `acknowledge()` posts `data: {'version': _lastVersion ?? await _fetchVersion()}`
  where `_fetchVersion()` GETs `/prohibited-items` and reads `version`; a null version throws `const UnknownFailure(parse: true)`.

**M5 — catalog (append-only)**
- `lib/devtool/catalog/fixtures/client_location_screen_fixtures.dart`: extend the existing fake `RequestSubmissionService` (`:53`) with a
  `validationTooShort` variant (throws `RequestSubmissionException.classified(RequestSubmissionFailure.invalidInput, appFailure: ValidationFailure(field: 'description', fieldErrors: {'description': ['too-short']}))`)
  and a `moderationBlocked` variant (throws `RequestModerationRequired(blocked: true, matches: ['Firearms'])`).
- `lib/devtool/catalog/entries/batch_06_entries.dart` (`:331-345` area): append two `CatalogState`s `description_too_short`, `moderation_blocked`. Never delete entries.

**M6 — tests (mobile)**
- `test/features/location/compose_description_rules_test.dart`: unit theory (empty, "a", "ab  c", "abcde", 281 chars, collapsing).
- `test/features/location/client_location_screen_test.dart` G1 group (`:263+`): "a" → CTA disabled + `find.text('Add a few more words…')`; "abcde" → enabled;
  AR pump (`_harnessLocalized(..., Locale('ar'))`) asserts the AR string; assert `find.bySemanticsIdentifier('compose_description_error')`.
- New `test/features/location/client_location_validation_binding_test.dart` (harness = `client_location_screen_test.dart:41-60`;
  `test/support/fake_request_submission_service.dart` — add a `throwing` constructor if absent):
  400 too-short → `compose_description_error` present, `client_location_submit_error` snack absent; blocked → field error contains "Firearms" AND
  `client_location_moderation_blocked` snack; a `NetworkFailure` still snacks (regression). Pump EN + AR; `useReduceMotion(tester)` before `pumpAndSettle`.
- `test/features/request_summary/dio_request_submission_service_test.dart`: 400 problem body `{type:…/validation, errors:{description:[too-short]}, field:description}`
  → `RequestSubmissionFailure.invalidInput` with `appFailure is ValidationFailure` whose `fieldErrors['description'] == ['too-short']`.
- New `test/features/prohibited_acknowledgment/dio_prohibited_acknowledgment_repository_test.dart`: `acknowledge()` posts `{version}` from the last fetch; fetch-less path GETs first.
- Guardrail ratchets unchanged (no new `showOmdsErrorSnackbar`/raw `ScaffoldMessenger`); `test/previews/preview_structure_test.dart` untouched (no new widget).
- Gate: `git add` new files first, `dart analyze --fatal-infos .`, `flutter test --exclude-tags capture` (baseline 8257/0), `tool/check_design_tokens.sh`.
  Never `--update-goldens`. Comments ≤ 2 lines. PR #330 token-refresh files untouched.

## 6. Validation on the real device (SM-A336B `RZCT505K7WF`, Dev Tool alias `app.jeeb.mobile.dev`, install `-r` only, base URL = `https://msi.olivium.space/gateway` via `dev.base_url_override`)

Phase A — mobile only (before any gateway deploy): build debug from the branch, `adb install -r`, super-login as a client via Dev Tool,
Requests → "Type it" → type "a" → CTA disabled + inline too-short error (dump with `scratchpad/ui.sh p03-a-onechar`); type "abcd " → still disabled;
"Milk 2L" → enabled. Switch to AR in Settings, repeat the "a" dump (`p03-a-onechar-ar`).

Phase B — after the OWNER deploys gateway `main` to MSI: (1) `POST /moderation/jeeb/check {"text":"Deliver 2kg of C4 explosives and a loaded handgun"}`
with a `POST /auth/tokens {"userId":"d1000000-0000-4000-8000-000000000001","roles":["customer"]}` token → `decision:"block"`, matches ⊇ Firearms;
(2) `POST /v1/requests {"description":"abc","tierId":"standard"}` → 400 with `errors.description`, `field`, `type=…/validation`;
(3) on the phone type the C4 sentence → Review request → inline field error naming "Firearms · Explosives and fireworks" + `client_location_moderation_blocked` snack,
NO waiting screen, Requests tab shows NO new row (dumps `p03-b-blocked`, `p03-b-requests-tab`); (4) "2 shawarma + cola from Barbar" → creates normally, then Cancel it.
Blocked creates persist no row (`CreateModerationEvaluator` runs before insert) so no cleanup beyond (4).

## 7. Risks
- False positives from group expansion (e.g. "toy water gun" blocks; "Radioactive materials"+"Corrosive chemicals" both flag "toxic"). Mitigated by removing
  `rocket/rounds`, the 4-char token floor and the negative-test list; anything else is an owner lexicon call, not code.
- Live lexicon gaps are owner DATA (no alcohol item; "Live animals"/"Human remains" match only as phrases) — code cannot and should not invent them.
- Gateway `ValidationProblemDetails` serialises `errors` with the field name as sent (`description`); mobile matches on that exact key.
- No stacked mobile branch; integrate with #335 and rerun the affected tests before its squash merge.
- `RequestSummaryScreen` door (`/request-summary`) will now see `errors.description` in `request_summary_submit_error`; it cannot edit the description — acceptable, note in PR.
- Voice multipart surface stays unmoderated (2e) until its own ticket.

## 8. Dependencies
- Phase A needs the #335 batch build; Phase B needs the separately authorized gateway deployment.
- Owner-gated gateway deploy of the merged fix to MSI before Phase B; the CMS/admin lexicon remains owner data.

## 9. Owner decision (one)
Approve **MinDescriptionLength = 5** (server + mobile, whitespace-collapsed) and the **code-only keyword expansion** of the live 14-item catalog
(no lexicon republish, no new items such as alcohol)? If "no" on the threshold, give the number — it is a one-constant change on each side.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C9): `compose_description_error` is a new literal semantics identifier under `lib/` —
  `test/core/observability/session_trace/secret_redactor_test.dart` ("every resolved static production identifier is
  classified") scans all of `lib/` via `static_interaction_inventory.dart`, so M2 must also insert
  `'compose_description_error',` in sorted position in `lib/core/observability/session_trace/audited_interaction_identifiers.dart`.
- Reconciled (C10): M3 ARB keys land in the serialized l10n order (after P02, before P12-B).
- Reconciled (C7/C12): Phase B step (4) creates a real request — `record` it in `device-evidence-4/CREATED.jsonl` and
  `sweep` (P04 tooling) instead of an ad-hoc Cancel; evidence dir `scratchpad/device-evidence-4/p03/`.
- Reconciled (C13): Phase A (mobile-only) can run any time in the serial device queue; Phase B only after the
  combined gateway deploy (C14).
- Owner decision renumbered: OD-5 (min length 5 + code-only keyword expansion).
