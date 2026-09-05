# PLAN P02 — notifications target id (gateway gap D1)

Key: `P02-notifications-target-id` · Effort: **M** · Plan-only (no repo file changed).
Planned 2026-09-05 against gateway `origin/main@6679f6ee` (= the build running on MSI) and mobile
`ux/api-error-handling-empty-states@ecfd3cc1` (PR #335, draft).

Evidence captured for this plan lives in `plans/live/` (same scratchpad):
`karim-v1-notifications.json`, `nour-v1-notifications.json` (live `GET /v1/notifications` bodies),
`karim-upstream-raw.json`, `nour-upstream-raw.json` (raw notification-service `messages/receiver`
rows read on the MSI box), `karim.token`/`nour.token` (30-day dev tokens — delete after use).
Gateway sources were exported read-only to `plans/gw-src/` from `origin/main`.

---

## 1. Problem (what is wrong today)

Every row of `GET /v1/notifications` reaches the phone without a target id, so no inbox tap can
navigate; F8 correctly snacks `notifications_cannot_open` on all 13 taps
(`device-evidence-3/REPORT.md` §B, `57-notifications-response.txt`, FINAL-REPORT §7b).

Re-verified live on 2026-09-05 (this plan, `plans/live/*`):

| caller | rows | `ref` present | what the mobile does with them |
|---|---|---|---|
| Karim (jeeber `106078a3-…`) | 31 | 1/31 (`delivery` row `c40b2e48`, from the top-level `delivery_id` alias) | `new_request` ×11, `chat` ×10, `offer_accepted` ×5 → snack; `delivery`/`availability` → kind `unknown` → snack |
| Nour (client `34a52972-…`) | 28 | 15/28 (`delivery` 12/12, `offer` 3/9) | `chat` 0/6, `request.try_expand_tier` 0/1, `offer` 6/9 → snack; `delivery` rows have a ref but map to kind `unknown` → snack |

Two independent defects compound:

1. **Gateway read-side projection drops ids it already has** (see root cause).
2. **Mobile kind mapper does not know the wire `type` values the gateway actually emits**
   (`chat`, `delivery`, `availability`, `request.try_expand_tier`, `request.expired`), so even a
   row with a `ref` falls to `NotificationKind.unknown` → `_cannotOpen`
   (`lib/features/notifications/domain/notification_kind_mapping.dart:13-63`,
   `notifications_list_screen.dart:584`). The device inventory shows these rows labelled
   "Notification" (`device-evidence-3/27-notif-inventory.txt`).

Side defect in the same code path: `ts` is `""` for every generic-event row (only typed
`offer_accepted`/`offer` rows carry `payload.created_at`), so the relative time is blank on the phone.

## 2. Root cause (verified in code + raw data)

### 2a. The data IS stored — nothing to backfill

Raw rows from notification-service (`GET http://127.0.0.1:10026/messages/receiver/{id}` on the MSI
box, header `X-Notification-Service-Token` from `~/iter5-native/env/gateway.env`,
`plans/live/*-upstream-raw.json`): **55 of 59 rows already carry the target id**; the 4 without are
`jeeb.auto_offline` (availability), which has no target by design.

Where each producer puts the id (all on `origin/main`):

| stored `notification_type` | wire `type` the gateway emits | id location in the stored row | producer |
|---|---|---|---|
| `jeeb.new_request` | `new_request` (top-level routing `type`) | top-level **and** `payload.requestId` / `request_id` | `Notifications/NewRequestPushNotifier.cs:737-738` via `GenericEventDispatcher.BuildRecord` |
| `jeeb.chat_message` | `chat` | top-level + `payload.requestId`/`request_id`, plus `conversationId` | `Notifications/ChatMessagePushNotifier.cs:205-212` |
| `jeeb.offer_accepted` (typed) | `offer_accepted` | `payload.request_id` (+ `offer_id`, `created_at`) | `JeebNotificationRecordDtos.cs:109-138` |
| `jeeb.offer_received` (typed) | `offer` | `payload.request_id` (+ `offer_id`, `created_at`) | `JeebNotificationRecordDtos.cs:45-78` |
| `jeeb.delivery_status_updated` (generic) | `delivery` | top-level `delivery_id`/`deliveryId`/`requestId` + same in payload | `Notifications/DeliveryStatusPushNotifier.cs:300-303` |
| `jeeb.cancellation_decision` | `cancellation_decision`* | top-level `deliveryId`/`requestId`/`request_id` | `Controllers/AdminCancellationsController.cs:185-210` |
| `jeeb.request.try_expand_tier`, `jeeb.request.expired` | `request.try_expand_tier` / `request.expired` | top-level + `payload.requestId` | `Requests/DispatchingRequestExpiryNotifier.cs:99-120` |
| `jeeb.offer_lost` | `offer_lost`* | top-level `requestId`/`request_id`/`offerId` | `Notifications/OfferPushNotifier.cs:529-532` |
| `jeeb.auto_offline` | `availability` | none (by design) | `Availability/PushAutoOfflineNotifier.cs:27-29` |
| `jeeb.dispute_update` / `jeeb.support_update` / `jeeb.dispute.*` / `jeeb.support.*` | as stored | `dispute_id`, `caseId`/`case_id` (already read) | `Disputes/DisputeService.cs`, `Controllers/CaseEventCallbacksController.cs` |

\* generic rows carry no top-level `type` for these two, so the wire `type` is the `jeeb.`-stripped
`notification_type` (`NormalizeType`, `JeebNotificationsInboxController.cs:483-497`).

Why the shape is like this: notification-service `POST /notifications/events` stores
`payload = event.data`, `metadata = {event_type, data}` **and spreads the routing map at top level**
(`notification-service/main.py:1690-1710`, `**routing`). It stamps no `created_at`/`timestamp`
(only the Mongo `_id` ObjectId carries creation time). Typed routes (`POST /notifications/jeeb.*`)
store the closed `payload` only.

### 2b. The gateway projection reads the wrong keys

`src/JeebGateway/Controllers/JeebNotificationsInboxController.cs` (origin/main):

- `MapRow` (:418-428) alias list for `Ref` is `ref, targetId, target_id, deliveryId, delivery_id,
  entityId, entity_id, referenceId, reference_id, caseId, case_id` — **no `requestId`/`request_id`**.
  That is why only `delivery` rows get a ref.
- `PayloadRef` (:499-510) has cases only for `delivery_status_updated`, `dispute_resolved`,
  `settlement_paid`, `kyc_*`, dotted `dispute./support.` — **nothing for `new_request`, `chat`,
  `offer_accepted`, `request.*`, `cancellation_decision`, `offer_lost`**. Note the `delivery` wire
  type (routing `type`) never even matches the `"delivery_status_updated"` case.
- `NormalizeMappedRow` (:455-459): an `offer` row is resolved **only** through
  `IOfferRequestIndex.ResolveRequestId(offer_id)` (in-memory, re-learned after restart, capped at
  5 rows/page by `MaxOfferResolutionRowsPerPage`) although `payload.request_id` is right there —
  live result 3/9 resolved for Nour.
- `Timestamp = Str(obj, "ts","timestamp","createdAt","created_at")` then `payload.created_at`
  (:424, :451) — generic rows have neither → `ts: ""`.
- `NotificationDeepLinkResolver.Routes` (`Notifications/NotificationDeepLinkResolver.cs:26-66`) is
  keyed on `delivery_status_updated`, `offer_received`, `offer_accepted`, `kyc_*`, `request_expired`,
  `settlement_paid`, `dispute_resolved` — never on the wire types actually produced
  (`new_request`, `chat`, `delivery`, `offer`, `request.try_expand_tier`, …) → `deepLink` is always
  `jeeb://notifications`. Its templates (`jeeb://deliveries/{id}/tracking`, `jeeb://offers/{id}`,
  `jeeb://kyc/status`, `jeeb://requests/{id}`, `jeeb://wallet/settlements/{id}`) are also not in the
  mobile allow-list (`lib/core/notifications/domain/notification_deep_link.dart:13-33`).

### 2c. The mobile side

- `lib/features/notifications/data/dio_notifications_repository.dart:73-99` `_reference` reads
  `ref` first — correct, no change needed for the primary contract.
- `notification_kind_mapping.dart` maps `new_request`, `offer`, `offer_accepted`, `status`,
  `request_expired`, … but not `chat`, `delivery`, `availability`, `request.try_expand_tier`,
  `request.expired`, `cancellation_decision`.
- `NotificationKind` is switched exhaustively in exactly three places
  (`notifications_l10n.dart:22`, `widgets/notification_row.dart:183`,
  `notifications_list_screen.dart:390`) — adding members is cheap.
- Mobile route ids: `/chat/:id` is keyed by **request id** (`ChatMessagePushNotifier.cs:207`,
  `app_router.dart:1646-1648` "delivery id == request id == correlationKey"), `/jeeber/requests/:id`
  by request id, `/jeeber/deliveries/:id/active` by delivery id (== request id), `/requests/:id/offers`
  by request id. So **one id — the request id — addresses every destination**.

## 3. Decisions

- **D1 Contract:** `ref` on each `/v1/notifications` item = the request id (or the delivery id, which
  equals it) the mobile route needs — never an `offer_id`, never a `conversationId`. No new wire
  fields; `deepLink` becomes correct-or-absent-root, advisory only.
- **D2 No backfill, no migration, no notification-service change.** The fix is read-side; it applies
  to every historical row (proven above).
- **D3 Mobile stays kind+ref driven** (single source of truth, the thing P2 already fixed). Inbox
  dispatch keeps ignoring `deepLink`; consuming it is a listed follow-up.
- **D4 `offer` rows:** `payload.request_id` first, `IOfferRequestIndex` only as fallback (keeps the
  5-per-page cap semantics for the fallback path).
- **D5 `ts`:** derive from the Mongo `_id` ObjectId when no timestamp field exists.
- **D6 Default destination for `offer_accepted` inbox tap stays `chat-detail`** (current mobile
  contract, `notifications_list_screen.dart:423`). See Owner decision.

## 4. Target contract per kind

| wire `type` (unchanged) | `ref` source order | `deepLink` template (mobile grammar: `jeeb://<first-segment>/…`) | mobile kind | mobile destination |
|---|---|---|---|---|
| `new_request` | top `requestId`/`request_id` → `payload.requestId`/`request_id` | `jeeb://jeeber/requests/{ref}` | `newRequest` (exists) | `/jeeber/requests/{ref}` (jeeber) / cannot-open (client, existing role guard) |
| `chat` | top `requestId`/`request_id` → payload same (**not** `conversationId`) | `jeeb://chat/{ref}` | **`chat` (new)** | `/chat/{ref}` |
| `offer` | `payload.request_id` → top `requestId` → index(`payload.offer_id`) | `jeeb://requests/{ref}/offers` | `offer` (exists) | `/requests/{ref}/offers` |
| `offer_accepted` | `payload.request_id` → top `requestId` (never `offer_id`) | `jeeb://chat/{ref}` | `offerAccepted` (exists) | `/chat/{ref}` (jeeber) — see owner decision |
| `delivery` / `delivery_status_updated` | existing top `delivery_id`/`deliveryId` → payload `delivery_id`/`order_id` → `requestId` | `jeeb://orders/{ref}` | `status` (add alias) | `/chat/{ref}` (existing `status` contract) |
| `cancellation_decision` | top `deliveryId` → `requestId` | `jeeb://orders/{ref}` | `status` (add alias) | `/chat/{ref}` |
| `request.try_expand_tier`, `request.expired` | top/payload `requestId` | `jeeb://requests/{ref}/waiting` | `requestExpired` (add aliases) | `/requests/{ref}/waiting` |
| `offer_lost` | top `requestId`/`request_id` | (root) | `unknown` (unchanged, follow-up) | cannot-open |
| `availability` | none | (root) | **`availability` (new)** | `shell` (role home), like `kycApproved` |
| dotted `jeeb.dispute.*` / `jeeb.support.*`, `dispute_resolved`, `kyc_*`, `settlement_paid` | unchanged | unchanged (`jeeb://disputes/{id}`, `jeeb://support/tickets/{id}`, `jeeb://profile/kyc`, `jeeb://wallet`) | unchanged | unchanged |

`deepLink` for `kyc_*` changes from `jeeb://kyc/status` to `jeeb://profile/kyc` and `settlement_paid`
from `jeeb://wallet/settlements/{id}` to `jeeb://wallet` so every emitted link is in the mobile
allow-list; `NotificationDeepLinkResolverTests` pins are updated accordingly.

## 5. Fix steps

### Gateway — repo `olivium-dev/jeeb-gateway`, new branch `fix/notifications-inbox-target-ref` off `origin/main`

G0. `git -C /Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-gateway fetch origin && git worktree add
    ../jeeb-gateway-worktrees/notif-target-ref -b fix/notifications-inbox-target-ref origin/main`
    (never build from the stale checkout; the worktree dir convention already exists).

G1. `src/JeebGateway/Controllers/JeebNotificationsInboxController.cs`
    - Replace `PayloadRef(JObject? payload, string? type)` with
      `TargetRef(JObject obj, JObject? payload, string? type)` implementing the §4 order. Keep the
      existing cases (`delivery_status_updated`, `dispute_resolved`, `settlement_paid`, `kyc_*`,
      dotted) and add: `"new_request"`, `"chat"`/`"chat_message"`, `"offer_accepted"`, `"delivery"`,
      `"cancellation_decision"`, `"request.try_expand_tier"`/`"request.expired"`/`"request_expiring"`,
      `"offer_lost"` → `StrScalar(obj,"requestId","request_id") ?? StrScalar(payload,"requestId","request_id")`
      (for `delivery`/`cancellation_decision` prefer `delivery_id`/`deliveryId`/`order_id` before
      `requestId`). Explicit rule in a 2-line comment: never hoist `offer_id`/`conversationId`.
    - In `NormalizeMappedRow`, for `type == "offer"`: set
      `row.Ref = StrScalar(payload,"request_id","requestId") ?? StrScalar(obj,"requestId","request_id")`;
      only when that is null return `payload.offer_id` as the index candidate (existing path).
    - Timestamp: after the existing `row.Timestamp ??= StrScalar(payload,"created_at")` add
      `row.Timestamp ??= StrScalar(obj,"at")` and finally
      `row.Timestamp ??= ObjectIdTimestamp(Str(obj,"_id"))` — a private helper that parses the first
      8 hex chars of a 24-hex `_id` as Unix seconds → `DateTimeOffset.ToString("o")`; returns null on
      any malformed input (never throws).
    - Do NOT touch `MapRow`'s blanket alias list (a blanket `requestId` alias would also fire for
      rows whose canonical id is different) and do NOT touch `FilterJeeberBroadcasts`,
      `DeduplicateByNotificationId`, mark-read, or the capability attributes.

G2. `src/JeebGateway/Notifications/NotificationDeepLinkResolver.cs`
    - Add routes keyed on the wire types: `new_request → jeeb://jeeber/requests/{id}`,
      `chat`/`chat_message → jeeb://chat/{id}`, `offer`/`offer_received`/`jeeb.offer_received →
      jeeb://requests/{id}/offers`, `offer_accepted`/`jeeb.offer_accepted → jeeb://chat/{id}`,
      `delivery`/`delivery_status_updated`/`jeeb.delivery_status_updated`/`cancellation_decision →
      jeeb://orders/{id}`, `request.try_expand_tier`/`request.expired`/`request_expired`/`request_expiry
      → jeeb://requests/{id}/waiting`, `kyc_* → jeeb://profile/kyc`, `settlement_paid → jeeb://wallet`.
      Remove `offer_updated` (no producer). Keep `InboxRoot` fallback when the template needs an id
      and none is present (already the behaviour).
    - Update the XML remark: templates MUST parse through the mobile `routeFromPushDeepLink`
      allow-list (`notification_deep_link.dart`), host = first path segment.

G3. Tests (`tests/JeebGateway.IntegrationTests`, project already copies `Fixtures/FM1/*.json`,
    csproj:107):
    - Add captured fixtures from this plan's raw captures, **stripped of `_dispatch`,
      `_idempotency_fingerprint`, `senderProfilePicture`, `nickname`, `media_links`** (the `_dispatch`
      sub-document embeds webhook payloads/headers — must not be committed):
      `Fixtures/FM1/captured-msi-karim-inbox-20260905-page.json` (31 rows) and
      `captured-msi-nour-inbox-20260905-page.json` (28 rows); add both to `Fixtures/FM1/README.md`
      with provenance (receivers `106078a3-…`, `34a52972-…`, read-only, 2026-09-05, MSI :10026).
    - `JeebNotificationsProjectionTests.cs`: add
      `ExtractRows_CapturedMsiInbox_EveryRowButAvailabilityHasRef` (both fixtures; assert
      `rows.Where(r => r.Type != "availability").All(r => r.Ref != null)` and spot-assert the exact
      ids: `f5cab53e… → defb1f07-efa5-4b8f-bc1a-09d6fcd1140b`, `4b241ba5… → 13b8bca2-ee0f-4acf-9db3-c364d5984a03`,
      `cab0d955… → fd91232f-8482-4a4e-ba3f-b356b24ab71b`, `788fbef4… → fd91232f-…`,
      `4061357f… → 96e5c26b-b4cf-4e53-8744-2c2f0affc4b1`), plus
      `ExtractRows_GenericRow_TimestampFallsBackToObjectId` (`_id 6a9bfb56…` → 2026-09-05T…Z) and
      `ExtractRows_ChatRow_NeverUsesConversationId`. Keep `AC17d_OfferAcceptedPayloadOfferIdIsNeverHoistedIntoChatRef`
      green (its fixture has no `request_id`, so ref stays null).
    - `JeebNotificationsDeepLinkResolutionTests.cs`: add
      `ListNotifications_PayloadRequestIdWinsWithoutIndexLookup` (offer row with `payload.request_id`
      → ref set, `index.CallCount == 0`).
    - `NotificationDeepLinkResolverTests.cs`: re-pin templates per §4; add a theory asserting every
      emitted link matches the mobile allow-list regex set (copy the 16 regexes from
      `notification_deep_link.dart:13-33` into the test as the contract).
    - Run: `dotnet build src/JeebGateway/JeebGateway.csproj -c Release` then
      `dotnet test tests/JeebGateway.IntegrationTests/JeebGateway.IntegrationTests.csproj -c Release
      --filter "FullyQualifiedName~JeebNotifications|FullyQualifiedName~NotificationDeepLink|FullyQualifiedName~F5PrivacyInbox"`
      then the full integration + unit suites (CI runs both, sharded — `ci.yml:146-175`). No new
      `jeeb.*` literal outside the resolver table (i18n/vocabulary gates).

G4. Open the PR (title `fix(notifications): emit request-id ref + mobile-grammar deepLink on every
    inbox row`), body = §1/§2 evidence + the §4 table; link mobile PR #335 OWNER-CONFIRM (b).
    Merge is owner-gated.

### Mobile — repo `olivium-dev/jeeb-mobile`, follow-up branch `fix/notifications-inbox-kinds`

Reconciled (C1): PR #335 is scope-frozen. Develop this branch stacked on `ux/api-error-handling-empty-states`
(so the F8 `_dispatch` rewrite is the base), then after #335 is squash-merged run
`git rebase --onto origin/main ux/api-error-handling-empty-states fix/notifications-inbox-kinds` and open the PR against `main`.

M1. `lib/features/notifications/domain/notifications_repository.dart`: add enum members
    `NotificationKind.chat` and `NotificationKind.availability` (append before `unknown`; no
    interface/signature change, so the 11 `implements NotificationsRepository` sites are untouched —
    R3 satisfied).

M2. `lib/features/notifications/domain/notification_kind_mapping.dart`: add cases
    `'chat' | 'chat_message' | 'new_message' → chat`; `'delivery' | 'delivery_status_updated' |
    'cancellation_decision' | 'delivery_cancelled' → status`; `'availability' | 'auto_offline' →
    availability`; `'request.try_expand_tier' | 'request.expired' | 'try_expand_tier' |
    'request_expiring' → requestExpired`. (`jeeb.` prefix is already stripped at :7-9.)

M3. DROPPED — Reconciled (C4): D1/D3 make `ref` the single source of truth and P10 §10 F4 wants the fallback parser
    retired, not widened. `_reference` stays exactly as on `ecfd3cc1` (`ref` first, existing fallbacks untouched).
    Retiring the 13-key fallback is a later cleanup once the gateway change is live everywhere.

M4. `notifications_list_screen.dart` `_dispatch`: add
    `case NotificationKind.chat:` sharing the `status` branch (`ref != null → goNamed('chat-detail')`,
    else `_cannotOpen`), and `case NotificationKind.availability: context.goNamed('shell')`. Update
    the D84 header comment lines (:42-58) with the two new rows.

M5. `presentation/notifications_l10n.dart` `categoryLabel` + `widgets/notification_row.dart`
    `_iconFor`: add `chat → l10n.notificationsCategoryLabelChat`, `Icons.chat_bubble_outline`;
    `availability → l10n.notificationsCategoryLabelAvailability`, `Icons.power_settings_new_outlined`.

M6. `lib/l10n/app_en.arb` + `app_ar.arb`: add `notificationsCategoryLabelChat` ("Message" / "رسالة")
    and `notificationsCategoryLabelAvailability` ("Availability" / "حالة التوفر") with `@` metadata;
    regenerate (`flutter gen-l10n` runs on build); `tool/l10n_parity_check.sh --analyze` must stay at
    zero strict counters.

M7. Tests (all assert by semantics identifier, pump EN + AR — R6):
    - `test/features/notifications/notification_kind_mapping_test.dart` (new): the §4 wire values →
      kinds, including the `jeeb.`-prefixed spellings.
    - `dio_notifications_wire_projection_test.dart`: Reconciled (C5) — TWO commits. Commit 1 (no gateway
      dependency) uses a hand-authored fixture built from `plans/live/karim-v1-notifications.json` with the §4
      `ref`/`deepLink` values filled in per row, so kinds/ts/ref assertions run before any deploy. Commit 2 (after the
      combined deploy, C14) replaces it with the **captured** post-fix fixture
      `fixtures/fm1/captured-msi-karim-v1-notifications-20260905.json` (take it AFTER the gateway
      deploy with `curl -H "Authorization: Bearer $(cat plans/live/karim.token)"
      https://msi.olivium.space/gateway/v1/notifications` and note provenance in
      `fixtures/fm1/README.md`); assert every non-availability item has `ref`, kinds are not
      `unknown`, and `timestamp` is non-empty.
    - `notifications_dead_tap_test.dart`: extend the ref-less loop with `chat`; add
      `an addressed chat row routes to chat-detail` (`chat_root_<ref>` stub appears, no
      `notifications_cannot_open`) and `an availability row routes to shell` (`shell_root`).
    - `notifications_list_screen_test.dart`/`notifications_list_midnight_test.dart`: one row each for
      the two new kinds (label + icon render, EN/AR).
    - Catalog: add one `chat` and one `availability` `NotificationItem` to
      `lib/devtool/catalog/fixtures/notifications_list_screen_fixtures.dart` (never delete entries;
      `preview_structure_test` floor unaffected — no new widget).

M8. Gates on the worktree: `dart analyze --fatal-infos .`, `flutter test --exclude-tags capture`
    (baseline 10539 pass / 0 fail, coverage ≥ 79%), `tool/l10n_parity_check.sh --analyze`,
    `tool/ar_plurals_check.sh`, `tool/check_design_tokens.sh`, guardrail ratchets. `git add` new
    files before running tests (mb1 residual-receipts trap). Do not touch PR #330 network files.

## 6. Validation (real device, real UI)

Preconditions: gateway PR merged **and deployed to MSI by the owner** (§7); mobile commit built as
`flutter build apk --flavor dev --debug` from the worktree (copy the two gitignored
`google-services.json` + `MAPS_API_KEY` as in run 3); `adb -s RZCT505K7WF install -r …` (never
uninstall); Dev Tool → Server URL = `https://msi.olivium.space/gateway` → Apply & Restart; check
`/data/local/tmp/jeeb-dev-seam.json` is absent first (stale-token trap).

Gateway-side proof first (no device): `curl -s -H "Authorization: Bearer $(cat plans/live/karim.token)"
https://msi.olivium.space/gateway/v1/notifications | jq '.items[] | {type, ref, deepLink, ts}'` →
every non-`availability` item has `ref` (a UUID) and a non-root `deepLink`; every item has a
non-empty `ts`. Save as `device-evidence-4/00-gateway-v1-notifications-post.json`; repeat for Nour.

Device scenarios (Karim via Dev Tool → Super Login Plus → "Karim TestJeeber"; Nour for the client
half); dump `uiautomator` + screenshot per step, verify by identifier:

| # | row | expected landing | assert present | assert absent |
|---|---|---|---|---|
| V1 | `new_request` for a live pending request — Reconciled (C7): `defb1f07…` is cancelled by P04 Part A before this run; create a fresh client request through the real UI, `tool/device_validation_cleanup.sh record request <id> de520a28-… ` into `device-evidence-4/CREATED.jsonl`, and `sweep` at the end | jeeber request detail | `jeeber_request_detail_description` (or `_loading_state` then `_description`) | `notifications_cannot_open`, `jeeber_home_root` |
| V2 | `new_request` for a request already taken/expired (e.g. `87b60885…`) | request detail's own graceful state | `jeeber_request_detail_error` or the taken/expired copy | `notifications_cannot_open` |
| V3 | `chat` ("Hello", `4b241ba5…`) | chat thread of request `13b8bca2…` | `chat_detail_message_list` | `notifications_cannot_open` |
| V4 | `offer_accepted` (`cab0d955…`) | chat thread of `fd91232f…` (D6 default) | `chat_detail_message_list` | `notifications_cannot_open` |
| V5 | `availability` (`403003cd…`) | jeeber home | `jeeber_home_root` | `notifications_cannot_open` |
| V6 | `delivery` (`c40b2e48…`, cancelled) | chat thread of `40c32e41…` | `chat_detail_message_list` | snack |
| V7 | BACK from V1/V3 returns to the inbox | `notifications_root` | | |
| V8 (client, Nour) | `offer` (`788fbef4…`) | offer review list | `offer_review_list_root` | snack |
| V9 (client) | `chat` (`a0fd7391…`) | chat thread `352d03a1…` | `chat_detail_message_list` | snack |
| V10 (client) | `new_request` row must not exist (F5 filter) and a leaked one would still snack | — | `notifications_cannot_open` if tapped | `jeeber_*` |
| V11 | relative time non-blank on generic rows | `notif_row_*` text contains "ago"/"h"/"d" | | |
| V12 | AR locale: V3 + V5 repeated | same identifiers | | |

Also capture `adb logcat | grep '\[http←\] 200 GET /v1/notifications'` once to show `ref` per item
on the phone's own wire. Write `device-evidence-4/REPORT.md` with the table, evidence file names,
gateway SHA (`curl …/gateway/health/ready` + drop-in `WorkingDirectory`), mobile SHA, device state
restored (Karim offline, override left at MSI, no uninstall). Cancel the probe request(s) created
for V1 afterwards or note their auto-expiry.

## 7. Deploy preparation (owner-gated — plan only, never execute)

- **MSI (dev, where the phones point):** on-box recipe from `_chatfix-2026-09-03/M1-msi-recon.md`
  §"Gateway": `ssh msi-ec2-cloudflare`; new dated sync `~/jeeb-native-sync/20260906-notifref`;
  `git checkout -f <merged sha>`; `dotnet publish … -c Release -r linux-x64 --no-self-contained -o
  ~/jeeb-native-builds/20260906/jeeb-gateway-<sha7>`; write `.deployed-sha`; root: `cp -a` the
  drop-in `/etc/systemd/system/jeeb-gateway.service.d/90-jeeb-staging-20260828.conf` to
  `.pre-20260906`, `sed` the `WorkingDirectory` from `20260904/jeeb-gateway-6679f6e` to the new dir,
  `daemon-reload`, `systemctl restart jeeb-gateway`, verify `/health/ready` still 27 checks with the
  same 4 pre-existing credential `Degraded` rows (they are unrelated). Rollback = restore the
  `.pre-20260906` drop-in + restart. `gateway.env` needs no new key (no config added).
- **Staging (.20):** owner dispatches `jeeb-staging-deploy.yml` (`deployment_mode=normal`) after
  merge; nothing in this change touches flags or secrets.
- No notification-service deploy. No mobile store build needed for the proof (dev flavour on the
  A33); Play-internal/TestFlight only once PR #335 is un-drafted and merged.

## 8. Risks

- Wrong-id hoist: a blanket alias would let an `offer_id` or `conversationId` become `ref` and send
  the user to a non-existent chat/request. Mitigated by per-type resolution + the two negative tests
  (AC17d, `ChatRow_NeverUsesConversationId`).
- `delivery` rows on the **client** route to `chat-detail` (existing `status` contract) rather than
  the order summary; acceptable now, may deserve `/orders/:id` later (follow-up).
- `offer_accepted` destination diverges between inbox (`/chat/{id}`) and push profile
  (`/jeeber/deliveries/{request_id}/active`) — owner decision below.
- ObjectId-derived `ts` is creation time in UTC to the second — fine for relative time; do not use
  it for ordering (upstream sorts by `_id` already).
- Old builds of the app (pre-M2) keep snacking on `chat`/`delivery`/`availability` rows even after
  the gateway deploy — expected, both halves are needed.
- `IOfferRequestIndex` fallback keeps the 5-row cap; with `payload.request_id` present on every
  typed offer row the cap is no longer reached in practice.
- Gateway CI vocabulary/i18n gates reject new `jeeb.*` literals outside sanctioned tables — keep the
  new keys in the resolver dictionary and the controller `switch`, both already hosting such literals.

## 9. Dependencies

- Gateway PR merge + MSI deploy (owner) before device validation.
- Mobile commit lands on the still-draft PR #335 branch; if #335 is split, this commit must follow
  the F8 `_dispatch` rewrite (`ecfd3cc1`).
- Owner decision D6 (below) only changes one `goNamed` target in M4; everything else is fixed.

## 10. Owner decision

Confirm the inbox tap destination for `offer_accepted` rows: **keep `chat-detail` (plan default,
matches today's mobile contract)** or switch to `/jeeber/deliveries/{ref}/active` to match the
notification-service push profile (`jeeb://jeeber/deliveries/{request_id}/active`). Everything else
in this plan is a verified defect fix with no product choice.

## 11. Cleanup

Delete `plans/live/karim.token` and `plans/live/nour.token` (30-day dev tokens minted under
`SuperLogin:OpenMode`) once the proof is captured; the raw upstream captures are safe to keep only
after stripping `_dispatch` as in G3.

## Reconciled (2026-09-05 conflict review — see plans/CONFLICT-REVIEW.md)

- Reconciled (C1): mobile M1–M2, M4–M8 ship as follow-up branch `fix/notifications-inbox-kinds` (stacked now,
  retargeted to `main` after the #335 squash). M3 dropped (C4). M7 split into two commits (C5); commit 1 has no
  deploy dependency and can merge before the gateway change is live (kind additions are backward-compatible:
  `availability` → shell, `chat`/`delivery` rows without `ref` keep snacking).
- Reconciled (C10): M6 ARB keys land in the serialized l10n order (P13 → P05 → P06 → P07 → P02 → P03 → P12-B); resolve
  `app_localizations.dart` by hand, then run the parity scripts.
- Reconciled (C14): gateway PR is one of three (P01/P02/P03); one combined owner deploy (OD-3); §7 recipe unchanged.
- Reconciled (C7/C12): V1 creates a ledgered request; evidence dir `scratchpad/device-evidence-4/p02/REPORT.md`
  (not the root REPORT.md); Karim's notifications inbox will show the P04-cancelled request's `new_request` row
  `f5cab53e` → tapping it after the deploy must land on the request detail's *cancelled/expired* graceful state (V2).
- Reconciled (C6): P09 D-P09-1 / P12 ChatTab ruling is unrelated to inbox `chat` kind — `/chat/<built-in function id>` stays the target.
- Owner decision renumbered: OD-4 (`offer_accepted` inbox destination).
