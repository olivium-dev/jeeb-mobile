# 12 — Mock Backend Inventory

> Phase 1 artifact. Authoritative scan of `jeeb-mock-backend/src/server.ts` +
> `jeeb-mock-backend/src/services/*`. Verified 2026-06-18 against the committed source.
> Purpose: enumerate every mounted service, its mount prefix, and the endpoints the
> **mobile app** (`jeeb-mobile`) would consume — so the gap map (`20_GAP_MAP.md`) and
> backlog (`30_BACKLOG.md`) can wire screens to real contracts.

## How to read this

- **Mount prefix** = the `app.use('<prefix>', router)` value in `server.ts`. The mock is
  service-prefixed (NOT a single gateway). Mobile reaches it via the rewrite map in
  `jeeb-mobile/lib/core/network/mock_gateway_client.dart` (`useMockPrefixes = true`),
  which prepends the service prefix to the gateway-style path the app emits.
- **Full path** = `<mount prefix>` + the in-router route. e.g. offer submit =
  `POST /offer-service/v1/offers`.
- 23 service files exist; `server.ts` mounts **22 routers across 21 distinct prefixes**
  (`/user-management` is shared by `user-management.ts` + `kyc-admin-service.ts`;
  `cms-admin-service.ts` mounts at `/gateway`, `cms-dashboard-service.ts` at `/cms-admin`).
  The boot banner says "19 services" — stale; the real count is higher.
- Every service also exposes `GET /healthz`, `GET /readyz` (some add `GET /metrics`).
  These are operational, not consumed by app screens — omitted from the per-service tables.

## Mount table (server.ts)

| Mount prefix | Router file | Mobile-facing? | Notes |
|---|---|---|---|
| `/auth-service` | auth-service.ts | YES | OTP login/verify/refresh/logout. `/auth/login` is admin email/pw (CMS only). |
| `/user-management` | user-management.ts | YES | me / user / role-switch / saved-locations / KYC link. |
| `/wallet-service` | wallet-service.ts | YES (jeeber) | earnings (read/export/sync). `/v1/admin/*` = CMS only. |
| `/chat-service` | chat-service.ts | YES | Jeeb conversations + messages (the core chat). |
| `/ban-service` | ban-service.ts | YES (read) | moderation check + prohibited-items list. `/v1/admin/*` = CMS. |
| `/compliment-service` | compliment-service.ts | YES | disputes (create/list/get/patch). Misnamed file = disputes. |
| `/contract-signing-service` | contract-signing-service.ts | YES (jeeber) | ToS template fetch + sign (onboarding). |
| `/delivery-service` | delivery-service.ts | YES | deliveries + tiers + **/v1/requests** + **/api/requests**. `/v1/admin/*` = CMS. |
| `/feedback-service` | feedback-service.ts | partial | only `GET /v1/feedback/jeeb/groups`. |
| `/form-builder-service` | form-builder-service.ts | YES (jeeber) | KYC form template fetch + submit. |
| `/geolocation-service` | geolocation-service.ts | YES | geo ping / route / availability (online toggle, online-jeebers). |
| `/matching` | matching.ts | YES (system) | find-jeebers + broadcast (request fan-out). |
| `/notification-service` | notification-service.ts | YES | list / mark-read / preferences. `send` + templates are system/CMS. |
| `/offer-service` | offer-service.ts | YES | submit / list / edit / withdraw / **accept (saga)**. |
| `/push-notification` | push-notification.ts | YES | device register/unregister (FCM token). |
| `/realtime-comunication-service` | realtime-comunication-service.ts | YES | WS upgrade at `/socket/websocket` (Phoenix). REST broadcast = system. |
| `/score-taking-service` | score-taking-service.ts | YES | rating submit + status (post-delivery). |
| `/unified-payment-gateway` | unified-payment-gateway.ts | YES (jeeber) | COD settlement record + cancellation fee. batches = CMS/system. |
| `/voice-transcription-service` | voice-transcription-service.ts | YES (client) | `POST /v1/transcribe` (voice request → text). |
| `/gateway` | cms-admin-service.ts | NO | CMS authoring plane (admin JWT, `cms:write`). Not mobile. |
| `/cms-admin` | cms-dashboard-service.ts | NO | CMS dashboard summary. Not mobile. |
| `/user-management` (2nd) | kyc-admin-service.ts | NO | Admin KYC review queue (`/admin/kyc`). Not mobile. |

Admin/dev: `GET /__mock/health`, `GET /__mock/state`, `POST /__mock/reset`,
`POST /__mock/breaker/voice-open|voice-close` (toggles 503 on transcription).

---

## Mobile gateway rewrite map (the consumption contract)

The app emits gateway-style paths; `mock_gateway_client.dart` rewrites the prefix. Key
entries (app path → mock path):

```
/auth/otp        → /auth-service/auth/otp
/auth/social     → /auth-service/auth/social   (NO mock route exists — gap)
/auth/refresh    → /auth-service/auth/refresh
/users           → /user-management/users
/v1/chat/jeeb    → /chat-service/v1/chat/jeeb
/v1/offers       → /offer-service/v1/offers
/v1/delivery     → /delivery-service/v1/delivery
/v1/tiers        → /delivery-service/v1/tiers
/v1/requests     → /delivery-service/v1/requests
/api/requests    → /delivery-service/api/requests
/v1/matching     → /matching/v1/matching
/v1/availability → /geolocation-service/v1/availability
/v1/notifications→ /notification-service/v1/notifications
/v1/ratings/jeeb → /score-taking-service/v1/ratings/jeeb
/v1/feedback/jeeb→ /feedback-service/v1/feedback/jeeb
/v1/templates    → /form-builder-service/v1/templates
/v1/contracts    → /contract-signing-service/v1/templates
/v1/moderation/jeeb → /ban-service/v1/moderation/jeeb
/v1/disputes     → /compliment-service/v1/disputes
/v1/payments/cod_jeeb → /unified-payment-gateway/v1/payments/cod_jeeb
/v1/jeeb/earnings→ /wallet-service/v1/jeeb/earnings
/v1/transcribe   → /voice-transcription-service/v1/transcribe
/v1/devices      → /push-notification/v1/devices
/channels/jeeb-chat → /realtime-comunication-service/channels/jeeb-chat
```

### KNOWN GAPS (call out for backenders / foundation — per CTO brief §4)

1. **Auth path mismatch (BLOCKER).** Mock auth routes live at `/auth-service/auth/otp/...`
   but the rewrite key is `/auth/otp`. The app's auth repo sends `/v1/auth/otp/...` per
   the gateway OpenAPI; that prefix is NOT in the rewrite map → auth never reaches `:4010`.
   FIX: add `/v1/auth/otp`, `/v1/auth/refresh`, `/v1/auth/logout` rewrite entries pointing
   at `/auth-service/auth/...` (the mock has no `/v1` segment on auth), OR rename mock auth
   routes to `/auth-service/v1/auth/...`. Either side must change. (CTO brief §4.)
2. **`/auth/social` has no mock route.** Rewrite maps it but `auth-service.ts` defines no
   social-login handler. Social-login screens cannot be exercised against the mock.
3. **No login-with-password for clients.** `/auth/login` is dev-only admin email/pw
   (`admin@jeeb.local`). Client/jeeber auth is OTP-only (code is always `1234`).
4. **`/v1/contracts` → `/v1/templates` collision.** Both contract-signing AND form-builder
   expose `/v1/templates/:id`. The rewrite disambiguates by prefix (`/v1/contracts` vs
   `/v1/templates`), so contract templates are reachable only via the `/v1/contracts` app
   path. Template IDs differ (`jeeb_tos_v1` vs `jeeb_jeeber_v1`) so no data collision.
5. **`/v1/deliveries` and `/api/deliveries` rewrite targets have no mock routes.** Mock
   delivery routes are singular `/v1/delivery/...`; the plural list lives under
   `/v1/requests`. Any app call to `/v1/deliveries` 404s.
6. **Wallet "coming soon" stub.** App `/wallet` route is a stub; the real earnings data is
   already in `wallet-service` (`GET /v1/jeeb/earnings`). Wiring exists, screen does not.

---

## Per-service endpoints (mobile-consumed)

### auth-service — `/auth-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/auth-service/auth/otp/request` | requestOtp — send OTP to phone (mock code = `1234`, 300s). |
| POST | `/auth-service/auth/otp/verify` | verifyOtp — verify code, find-or-create user, set `jeeb_rt` HttpOnly cookie, return access/refresh tokens + user. |
| POST | `/auth-service/auth/refresh` | refreshTokens — rotate tokens via cookie OR body refreshToken. |
| POST | `/auth-service/auth/logout` | revokeRefreshToken — clears `jeeb_rt`, 204. |
| POST | `/auth-service/auth/login` | loginWithPassword — **admin/CMS only** (email/pw). Not for app clients/jeebers. |

### user-management — `/user-management`
| Method | Path | Purpose |
|---|---|---|
| GET | `/user-management/users/me` | getMe — current user (defaults to `user-client-001`). |
| GET | `/user-management/users/:userId` | getUser — public profile. |
| POST | `/user-management/users/:userId/role/switch` | switchRole — flip activeRole (client↔jeeber); 403 if not in availableRoles. Powers Profile-tab role switch. |
| PATCH | `/user-management/users/:userId/available-roles` | updateAvailableRoles — add/remove a role (become-a-jeeber). |
| POST | `/user-management/users/:userId/kyc-link` | linkKycSubmission — attach KYC submission to user. |
| GET | `/user-management/users/:userId/kyc` | getKycSubmission — KYC status (pending/approved/rejected). |
| GET | `/user-management/users/:userId/saved-locations` | listSavedLocations — saved addresses. |
| POST | `/user-management/users/:userId/saved-locations` | createSavedLocation — add address (max 10). |

### wallet-service — `/wallet-service`
| Method | Path | Purpose |
|---|---|---|
| GET | `/wallet-service/v1/jeeb/earnings?jeeberId=` | getEarnings — jeeber earnings total + items (ETag cached). Powers Earnings tab. |
| GET | `/wallet-service/v1/jeeb/earnings/export?jeeberId=` | exportEarnings — PDF export URL. |
| POST | `/wallet-service/v1/jeeb/earnings/sync` | syncEarningsFromSettlement — system; idempotent on deliveryId. |

### chat-service — `/chat-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/chat-service/v1/chat/jeeb/conversations` | createJeebConversation — opens broadcasting-phase thread for a request. |
| GET | `/chat-service/v1/chat/jeeb/conversations/by-request/:requestId` | getConversationByRequest — resolve thread from a request. |
| GET | `/chat-service/v1/chat/jeeb/conversations/:conversationId` | getJeebConversation — conversation + phase + participants. |
| PATCH | `/chat-service/v1/chat/jeeb/conversations/:conversationId/membership` | patchMembership — add/remove participant, flip_phase. |
| GET | `/chat-service/v1/chat/jeeb/conversations/:conversationId/messages?since=` | listMessages — message poll (403 if not a member). |
| POST | `/chat-service/v1/chat/jeeb/conversations/:conversationId/messages` | postMessage — send (text/voice/audio/image/location/offer_card/...). |
| GET | `/chat-service/v1/chat/jeeb/conversations/:conversationId/snapshot` | snapshotForDispute — HTML snapshot URL for dispute evidence. |

### offer-service — `/offer-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/offer-service/v1/offers` | submitOffer — jeeber's single private offer (409 on duplicate request+jeeber). |
| GET | `/offer-service/v1/offers?requestId=&jeeberId=` | listOffers — offers for a request (client review) or by jeeber. |
| PATCH | `/offer-service/v1/offers/:offerId` | editOffer — amend amount (max 2 edits; 410 if no longer editable). |
| DELETE | `/offer-service/v1/offers/:offerId` | withdrawOffer — 204 (410 if finalized). |
| POST | `/offer-service/v1/offers/:offerId/accept` | acceptOffer — **saga**: accept, supersede losers, flip convo to `accepted`, promote winner, append `offer_accepted` msg; returns handoverCode + conversationId. |

### delivery-service — `/delivery-service` (also hosts requests)
| Method | Path | Purpose |
|---|---|---|
| GET | `/delivery-service/v1/tiers` | listTiers — flash/express/standard. |
| GET | `/delivery-service/v1/requests?status=pending\|offers-received\|active\|delivered\|cancelled` | listRequests — client Requests tab (decorated with offersCount, offerAvatars, conversationId). |
| GET | `/delivery-service/api/requests` | listRequests — legacy alias used by OrderHistoryScreen. |
| GET | `/delivery-service/v1/requests/:requestId` | getRequest — single request (chat header). |
| GET | `/delivery-service/v1/delivery/active?tier=` | listActiveDeliveries — jeeber Dashboard / active-delivery (decorated with jeeberName, progressStep, conversationId). |
| GET | `/delivery-service/v1/delivery/:deliveryId` | getDelivery — delivery detail / tracking. |
| POST | `/delivery-service/v1/delivery/status/transition` | transitionStatus — SM-1 state machine (Ordered→Picked→InTransit→AtDoor→Done; 422 on illegal). |
| POST | `/delivery-service/v1/delivery/cancel` | cancelDelivery — cancel within SM-1 rules. |

### matching — `/matching`
| Method | Path | Purpose |
|---|---|---|
| POST | `/matching/v1/matching/find-jeebers` | findJeebers — nearby online jeebers by tier radius (flash 3km / express 7km / standard 15km). |
| POST | `/matching/v1/matching/broadcast` | broadcastRequest — fan request out to matched jeebers (202). |

### geolocation-service — `/geolocation-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/geolocation-service/v1/jeeb/geo/ping` | ingestPing — live GPS (throttled 1/250ms → 429). Jeeber live-tracking. |
| GET | `/geolocation-service/v1/jeeb/geo/route/:deliveryId` | getRoute — encoded polyline + distance/duration (tracking map). |
| POST | `/geolocation-service/v1/availability` | setAvailability — jeeber online/offline toggle (Dashboard). |
| GET | `/geolocation-service/v1/availability/online-jeebers?geohash5=` | listOnlineJeebers — online jeebers in a cell. |
| GET | `/geolocation-service/v1/availability/:userId` | getAvailability — a jeeber's current online state. |

### notification-service — `/notification-service`
| Method | Path | Purpose |
|---|---|---|
| GET | `/notification-service/v1/notifications?userId=` | listNotifications — notifications-list screen (currently absent in app, per brief §4). |
| PATCH | `/notification-service/v1/notifications/:id/read` | markRead — 204. |
| GET | `/notification-service/v1/notifications/preferences` | getPreferences — push/sms/email + per-topic prefs. |
| PUT | `/notification-service/v1/notifications/preferences` | updatePreferences — save notification settings. |
| POST | `/notification-service/v1/notifications/send` | sendNotification — **system/CMS** (fan-out). |

### score-taking-service — `/score-taking-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/score-taking-service/v1/ratings/jeeb/submit` | submitRating — post-delivery rating (idempotent deliveryId+raterId; 403 if not party). |
| GET | `/score-taking-service/v1/ratings/jeeb/:deliveryId/status` | getRatingStatus — double-blind reveal state (pending_self/pending_counter/revealed). |

### compliment-service (disputes) — `/compliment-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/compliment-service/v1/disputes` | createDispute — open a dispute (escalate flow). |
| GET | `/compliment-service/v1/disputes?status=&userId=` | listDisputes — user's disputes (dispute-status screen, per brief §4). |
| GET | `/compliment-service/v1/disputes/:disputeId` | getDispute — dispute detail. |
| PATCH | `/compliment-service/v1/disputes/:disputeId` | updateDispute — status/resolution/refund/note. |

### unified-payment-gateway — `/unified-payment-gateway`
| Method | Path | Purpose |
|---|---|---|
| POST | `/unified-payment-gateway/v1/payments/cod_jeeb/record` | recordCashSettlement — COD collected at delivery (idempotent on deliveryId). Settlement flow. |
| POST | `/unified-payment-gateway/v1/payments/cod_jeeb/fee` | recordCancellationFee — 10% / cancellation fee from wallet. |
| POST | `/unified-payment-gateway/v1/payments/cod_jeeb/refund` | recordRefund — dispute-driven refund. |
| GET | `/unified-payment-gateway/v1/payments/cod_jeeb/batches?status=&weekOf=` | listBatches — weekly payout batches (jeeber may view; settlement = CMS). |

### contract-signing-service — `/contract-signing-service`
| Method | Path | Purpose |
|---|---|---|
| GET | `/contract-signing-service/v1/templates/:templateId` | getTemplate — ToS doc + signed URL (`jeeb_tos_v1`). Jeeber onboarding. |
| POST | `/contract-signing-service/v1/templates/:templateId/sign` | signTemplate — submit signature blob → signed PDF URL. |

### form-builder-service — `/form-builder-service`
| Method | Path | Purpose |
|---|---|---|
| GET | `/form-builder-service/v1/templates/:templateId` | getTemplate — KYC form JSON schema (`jeeb_jeeber_v1`). Jeeber KYC. |
| POST | `/form-builder-service/v1/templates/:templateId/submit` | submitForm — submit KYC data → submissionId. |

### ban-service (moderation) — `/ban-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/ban-service/v1/moderation/jeeb/check` | checkText — moderate request/message text (soft_warn / hard_block). |
| GET | `/ban-service/v1/moderation/jeeb/prohibited-items` | listProhibitedItems — active prohibited-items list (request compose helper). |

### voice-transcription-service — `/voice-transcription-service`
| Method | Path | Purpose |
|---|---|---|
| POST | `/voice-transcription-service/v1/transcribe` | transcribe — multipart audio (≤5MiB) → Arabic text. Voice-request screen. 503 when breaker open, 413/415 on bad upload. |

### push-notification — `/push-notification`
| Method | Path | Purpose |
|---|---|---|
| POST | `/push-notification/v1/devices/register` | registerDevice — store FCM token (app boot / login). 204. |
| POST | `/push-notification/v1/devices/unregister` | unregisterDevice — remove token (logout). 204. |

### feedback-service — `/feedback-service`
| Method | Path | Purpose |
|---|---|---|
| GET | `/feedback-service/v1/feedback/jeeb/groups` | listJeebGroups — feedback groups (thin; seeded data only). |

### realtime-comunication-service — `/realtime-comunication-service`
| Method | Path | Purpose |
|---|---|---|
| WS | `/realtime-comunication-service/socket/websocket` | Phoenix WS upgrade — `phx_join` topics `jeeb:chat:<convId>` (new_msg) + `geo:delivery:<id>` (gps_update). Live chat + live tracking. Note: app's `webSocketUrl` points at port **3056** (separate shim), not 4010. |
| POST | `/realtime-comunication-service/channels/jeeb-chat/:conversationId/broadcast` | broadcastChatEvent — **system** push to WS subscribers. |
| POST | `/realtime-comunication-service/channels/geo-delivery/:deliveryId/broadcast` | broadcastGeoEvent — **system** GPS push to WS subscribers. |

---

## Admin-only services (NOT mobile — listed for completeness)

- **cms-admin-service.ts** @ `/gateway` — CMS authoring plane (admin JWT, `cms:write`).
- **cms-dashboard-service.ts** @ `/cms-admin` — `GET /cms-admin/v1/dashboard/summary` (KPI tiles).
- **kyc-admin-service.ts** @ `/user-management/admin/kyc` — admin KYC review queue
  (`GET /admin/kyc`, `GET/PATCH /admin/kyc/:submissionId`).
- Admin surfaces inside otherwise-mobile services: `wallet-service /v1/admin/earnings*`,
  `delivery-service /v1/admin/orders*`, `user-management /admin/users*`,
  `ban-service /v1/admin/moderation/*`. These are CMS, not consumed by `jeeb-mobile`.

## Conventions observed (apply when extending the mock)

- Errors are RFC-7807 problem+json via `ProblemError(status, code, detail, ..., extras)`.
- Mutating POSTs that must be safe to retry use the `idempotency` middleware
  (Idempotency-Key header) — submit offer/message, transcribe, settlements, ratings.
- `(req as any).userId` comes from the `authStub` middleware; default identity is
  `user-client-001` when no token is sent.
- Seeded fixtures load on boot (`config.seed`); reset via `POST /__mock/reset`.
- Default seeded user IDs surface in handlers: `user-client-001`, `user-admin-004`.
