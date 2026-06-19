# 11 — Flutter Inventory (current router + shell + features)

> Phase 1 artifact. Ground truth of what the Flutter app (`jeeb-mobile`) actually
> registers and renders **today**, before blueprint-parity work. Source of truth:
> `lib/core/router/app_router.dart` (read in full), `lib/features/shell/shell_screen.dart`,
> and a scan of `lib/features/*`. Cite this file in `20_GAP_MAP.md` / `21_NAV_PLAN.md`.
> Verified 2026-06-18.

---

## 1. How routing works (router shape)

- Single top-level `GoRouter` built by `AppRouter.create(...)` (`app_router.dart`).
- `initialLocation: '/'`. `errorBuilder` renders a "Route not found: <uri>" Scaffold.
- **Redirect gates** (in order), re-evaluated via `refreshListenable` on onboarding /
  biometric-lock / session emits:
  1. **Dev chat seam** (`_devChat`, debug only) → forces `/dev-chat`.
  2. **DevSeam route pin with skipOnboarding** (debug only) → full first-run bypass + one-shot landing latch.
  3. **First-run gate** `_firstRunRedirect` (FR-P0-1 onboarding + FR-P0-3 session/JWT):
     onboarding incomplete → `/onboarding`; onboarded on `/onboarding` → `/`;
     onboarded + unauthenticated + not pre-auth → `/register`. Pre-auth routes = `{/onboarding, /register}`.
  4. **DevSeam route pin without skipOnboarding** (debug only) → honours pin's initial landing post-gate.
  5. **Biometric gate** (T-mobile-005): onboarded + `BiometricLockPhase.locked` → `/lock`; unlocked on `/lock` → `/`.
- **No `StatefulShellRoute`.** The bottom-nav shell is a single `/` route → `ShellScreen`,
  which swaps tab bodies via a local `IndexedStack` + `RoleCubit`. Tabs are NOT separate routes.

## 2. Bottom-nav shell & tab sets

`ShellScreen` (`lib/features/shell/shell_screen.dart`) is role-aware via `RoleCubit`
(`UserRole.client` / `UserRole.jeeber`). 3 tabs per role; switching role resets to index 0.
Tab bodies are wired in `lib/features/shell/tabs/`. (Debug: DevSeam `homeTab == 'unregistered'`
forces jeeber role so the Delivery-tab upsell, screen 19, renders.)

### Client tabs (`UserRole.client`)
| id | label key | body widget | delegates to (real screen) |
|----|-----------|-------------|----------------------------|
| `requests` | `navRequests` | `HomeTab` | `home_client` feed/empty-state (real) |
| `delivery` | `navDelivery` | `OrdersTab` | `OrderHistoryCubit` → `OrderHistoryScreen` (real, Dio-backed) |
| `profile` | `navProfile` | `ProfileTab` | profile list + role toggle (real) |

### Jeeber tabs (`UserRole.jeeber`)
| id | label key | body widget | delegates to (real screen) |
|----|-----------|-------------|----------------------------|
| `dashboard` | `navDashboard` | `DashboardTab` | `jeeber_home` request feed / upsell (real) |
| `earnings` | `navEarnings` | `EarningsTab` | `EarningsCubit` → `EarningsDashboardScreen` (real) |
| `profile` | `navProfile` | `ProfileTab` | profile list + role toggle (real, shared with client) |

> Note: `lib/features/shell/tabs/chat_tab.dart` exists but is NOT mounted in either
> role's tab set (chat is reached via the `/chat/:id` deep-link route, not a tab).

## 3. Registered routes (full enumeration)

Status legend:
- **real** — renders a real feature screen wired to cubit/repository/DI.
- **stub** — intentional non-crashing landing with no real behavior (inline "coming soon" Scaffold or frozen placeholder file).
- **placeholder** — Type-A discipline placeholder file (`OmdsEmptyStatePage` "coming soon"), behavior frozen pending a follow-up ticket.

| path | name | screen widget | status | notes |
|------|------|---------------|--------|-------|
| `/` | `shell` | `ShellScreen` | real | role-aware bottom-nav shell (§2) |
| `/onboarding` | `onboarding` | `OnboardingScreen` | real | pre-auth |
| `/register` | `register` | `RegistrationScreen` | real | pre-auth; the ONLY auth screen (no distinct login/verify/recover/set-password/social) |
| `/lock` | `biometric-lock` | `BiometricLockScreen` | real | biometric gate target |
| `/orders/:id` | `delivery-detail` | `DeliveryDetailScreen` | real | deep_link_targets |
| `/orders/:id/cancel` | `delivery-cancel` | `CancellationScreen` | real | `?role=jeeber` flips audience |
| `/orders/:id/rate` | `rating-prompt` | `RatingPromptScreen` | placeholder | **redirects** to `/orders/:id/mutual-rate` (B-3). Builder is an unreachable frozen placeholder kept under Type-A gate (T-MOB-RATING-001) |
| `/chat/:id` | `chat-detail` | `ChatDetailScreen` | real | deep_link_targets |
| `/dev-chat` | `dev-chat` | `DevChatPreviewScreen` | stub | debug-only capture seam; unreachable in release |
| `/profile/kyc` | `kyc-status` | `KycWizardScreen` | real | E-P0 fix: real wizard (NOT the frozen `KycStatusScreen` placeholder); self-provides `KycWizardCubit` |
| `/jeeber/onboarding` | `jeeber-onboarding` | `DmOnboardingScreen` | real | `?step=address\|service-area` deep-links into a later step |
| `/profile/customer` | `customer-profile` | `CustomerProfileScreen` | real | typed `extra`; debug fixture fallback; release → `ProfileUnavailableScreen` |
| `/profile/delivery-man` | `delivery-man-profile` | `DeliveryManProfileScreen` | real | typed `extra`; debug fixture fallback; release → `ProfileUnavailableScreen` |
| `/location` | `location-picker` | `LocationPickerScreen` | real | |
| `/settings` | `settings` | `SettingsScreen` | real | |
| `/settings/profile` | `settings-profile` | `ProfileEditScreen` | real | nested under `/settings` |
| `/settings/addresses` | `settings-addresses` | `SavedLocationsScreen` | real | T-MOB-025 (replaced placeholder) |
| `/settings/notifications` | `settings-notifications` | `NotificationPreferencesScreen` | real | |
| `/voice-request` | `voice-request` | `VoiceRequestScreen` | real | `onSent` → pushes `/voice-request/transcription` with a `VoiceClip` |
| `/request-type` | `request-type` | `RequestTypeScreen` | real | tier select; Continue → `/request-summary` w/ `RequestDraft` |
| `/client-location` | `client-location` | `ClientLocationScreen` | real | add-location → `/capture-location` |
| `/capture-location` | `capture-location` | `CaptureLocationScreen` | real | |
| `/voice-request/transcription` | `transcription` | `TranscriptionScreen` | real | clip via `extra` (empty-clip fallback); confirm → `/request-summary` |
| `/jeeber/requests/:id/offer` | `jeeber-offer-submission` | `OfferSubmissionScreen` | real | T-MOB-030; POST /v1/offers; success → `/chat/:conversationId` |
| `/jeeber/requests/:id` | `jeeber-request-detail` | `JeeberRequestDetailScreen` | real | resolves from `extra` or `RequestFeedService` cache; missing → `JeeberRequestUnavailableScreen` (graceful fallback) |
| `/request-summary` | `request-summary` | `RequestSummaryScreen` | real | needs `RequestDraft` via `extra`; missing → `RequestSummaryUnavailableScreen` (graceful fallback) |
| `/orders/:id/tracking` | `live-tracking` | `LiveTrackingScreen` | real | demo repo swapped in under dev-seam `/tracking` capture |
| `/orders/:id/otp` | `otp-handover` | `OtpHandoverScreen` | real | `?mode=jeeber` flips client/jeeber |
| `/orders/:id/feedback` | `feedback` | `RatingScreen` | real | `?mode=jeeber` flips audience; `?name=` seeds ratee |
| `/orders/:id/mutual-rate` | `mutual-rating` | `MutualRatingScreen` | real | T-MOB-020 blind mutual rating; `?mode=jeeber` flips |
| `/orders/:id/escalate` | `escalate` | `EscalateScreen` | real | T-MOB-022; multipart POST /v1/deliveries/{id}/escalate |
| `/jeeber/deliveries/:id/active` | `jeeber-active-delivery` | `ActiveDeliveryJeeberScreen` | real | T-MOB-031; OTP → `/orders/:id/otp?mode=jeeber`; maps via url_launcher |
| `/jeeber/settlement` | `jeeber-settlement` | `SettlementScreen` | real | T-MOB-032; tap → `/jeeber/settlement/:id`; PDF via open_file |
| `/jeeber/settlement/:id` | `jeeber-settlement-detail` | `SettlementDetailScreen` | real | needs `SettlementStatement` via `extra`; missing → inline "Statement not found" Scaffold |
| `/wallet` | `wallet` | inline `Scaffold` "Wallet — coming soon" | stub | T-MOB-024 AC3 landing; real wallet tracked under T-MOB-035 |

**Total: 35 registered `GoRoute`s** (32 top-level + 3 nested under `/settings`).

## 4. Stubs / placeholders / frozen files

### Live stubs reachable in a build
- **`/wallet`** — inline `Scaffold` `Text('Wallet — coming soon')`. Real wallet = T-MOB-035.
- **`/dev-chat`** (`DevChatPreviewScreen`) — debug capture seam, unreachable in release.
- **`/jeeber/settlement/:id`** missing-`extra` branch — inline "Statement not found" Scaffold (fallback only; happy path is real).

### Frozen placeholder files (Type-A discipline gate; not the rendered happy path)
- **`RatingPromptScreen`** (`lib/features/deep_link_targets/rating_prompt_screen.dart`) — `OmdsEmptyStatePage` "Rating Prompt coming soon". The `/orders/:id/rate` route **redirects past it** to `/orders/:id/mutual-rate`; builder is an unreachable fallback. Frozen pending T-MOB-RATING-001.
- **`KycStatusScreen`** (`lib/features/deep_link_targets/kyc_status_screen.dart`) — `OmdsEmptyStatePage` "KYC Status coming soon". **NOT routed** — `/profile/kyc` now renders the real `KycWizardScreen` (E-P0 fix). File retained under Type-A gate; effectively dead.

### Graceful fallback screens (real screens exist; these guard missing payloads)
- `ProfileUnavailableScreen` (`lib/core/router/profile_unavailable_screen.dart`) — release fallback for `/profile/customer` + `/profile/delivery-man` when typed `extra` is absent (avoids rendering PII fixtures in release).
- `RequestSummaryUnavailableScreen` — `/request-summary` without a `RequestDraft`.
- `JeeberRequestUnavailableScreen` — `/jeeber/requests/:id` when the request can't be resolved (closed/cancelled/expired).

## 5. Notable routing facts for gap analysis

- **Tabs are not routes.** Client = Requests/Delivery/Profile; Jeeber = Dashboard/Earnings/Profile, all hosted inside `/` via `ShellScreen` + `RoleCubit`. Deep-link / `goNamed` targets must be top-level routes.
- **Auth is one screen.** Only `/register`. No distinct login / sign-up / verify-OTP / recover / set-password / social-auth / biometric-login routes (vs the blueprint's 8 auth screens). `/lock` is the biometric *unlock* gate, not a login screen.
- **No notifications-list route.** `/settings/notifications` is preferences, not a notification inbox.
- **`/orders/:id/rate` is a redirect** to mutual-rate; the `rating-prompt` placeholder is unreachable.
- **Removed:** legacy `/tier-selection` (dead duplicate of `/request-type`); `TierSelectionScreen` kept only for its widget tests.
- **Chat tab widget** (`tabs/chat_tab.dart`) exists but is unmounted.
- Several feature folders under `lib/features/*` have no dedicated route yet (e.g. `client_offers`, `delivery_status`, `dispute`, `goods_cost`, `masked_call`, `mixed_direction`, `no_offer_timeout`, `offline_mode`, `prohibited_acknowledgment`, `prohibited_item_report`, `client_unreachable`, `delivery_receipt`, `notification_prefs`) — surfaced inline/as widgets or pending wiring. To be reconciled against the blueprint in `20_GAP_MAP.md`.
