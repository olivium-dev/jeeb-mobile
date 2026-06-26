# FAKE-FALLBACK-AUDIT — Sprint 6, Stream C

**Branch:** `sprint-6-stream-c`
**Date:** 2026-06-26
**Mission:** Reduce the guarded fake-fallback debt — screens that resolve a repo/service/gateway
via a `_resolve*()` helper which falls back to a Fake / InMemory / Stub / Empty / Noop when GetIt
is not registered.

## Method

1. Inventoried every `_resolve*()` site in `lib/features/` (51 method declarations across ~46 files).
2. For each, classified the resolution chain: explicit (test) → `sl.isRegistered<Interface>()` (DI)
   → optional `sl<Dio>()` self-construct middle-tier → Fake/Stub/InMemory/Empty fallback.
3. For each type with a Dio impl, confirmed the gateway route exists in the mock-backend route
   contract (`mock-backend/src/services/*.ts`) — the offline contract that mirrors the live gateway.
4. **No Fake/Stub/Empty/Noop class was deleted** — each remains the no-DI route-resolve test seam
   (`test/core/router/w{0..4}_routes_resolve_test.dart` reset GetIt without `configureDependencies()`).
5. No endpoint was fabricated. Where no real impl or no gateway route exists, the fake was left and
   documented as deferred.

## The fix

The cleanest correction was to register the (already-existing) real Dio impls in
`lib/core/di/injection_container.dart` so the real impl is the **canonical release default**, and the
Fake is reached **only** by the no-DI test harness. Two screens that lacked an
`sl.isRegistered<Interface>()` check (logout sheet, dm-onboarding) were updated to prefer the DI
binding before their self-construct branch.

## Results

- **Converted to real (registered as release default): 9**
- **Documented-deferred (no real impl / no gateway endpoint): 2**
- **Already real (self-construct, intentionally not singleton-registered): 1**
- **Already compliant before this stream (real impl already DI-registered): 16**

### Converted — newly registered in `injection_container.dart`

| # | Type | Screen / site | Real Dio impl | Gateway endpoint(s) | Prior state |
|---|------|---------------|---------------|---------------------|-------------|
| 1 | `CancelRequestRepository` | `cancel_request/.../cancel_request_sheet.dart` | `DioCancelRequestRepository` | `POST /v1/delivery/cancel` | **Fake was the RELEASE default** (no Dio middle-tier) |
| 2 | `OrderSummaryRepository` | `order_summary/.../order_summary_screen.dart` | `DioOrderSummaryRepository` | `GET /v1/delivery/:id`, `/v1/requests/:id`, `/users/:id`, `/v1/offers` | **Fake was the RELEASE default** |
| 3 | `AccountStatusRepository` | `account_status/.../account_status_screen.dart` | `DioAccountStatusRepository` | `GET /v1/users/me` | self-construct via `sl<Dio>()` middle-tier |
| 4 | `WaitingRepository` | `no_offer_timeout/.../no_offer_timeout_screen.dart` | `DioWaitingRepository` | `GET /v1/requests`, `/v1/offers` | self-construct via `sl<Dio>()` middle-tier |
| 5 | `DeliveryReceiptRepository` | `delivery_receipt/.../delivery_receipt_screen.dart` | `DioDeliveryReceiptRepository` | `GET /v1/delivery/:id`, `POST /v1/payments/cod_jeeb/record`, `POST /v1/delivery/status/transition` | self-construct via `sl<Dio>()` middle-tier |
| 6 | `LocationSelectRepository` | `location/.../client_location_screen.dart` | `DioLocationSelectRepository` | `GET/POST /api/users/me/saved-locations` (same BFF as the registered `DioSavedLocationRepository`) | self-construct via `sl<Dio>()` middle-tier |
| 7 | `AddressFormRepository` | `location/.../screens/address_detail_form_screen.dart` | `DioAddressFormRepository` | `GET/POST/PUT/DELETE /api/users/me/saved-locations` | self-construct via `sl<Dio>()` middle-tier |
| 8 | `DmOnboardingGateway` | `jeeber_onboarding/.../dm_onboarding_screen.dart` | `DioDmOnboardingGateway` | `POST /v1/matching/find-jeebers` | self-construct via `sl<Dio>()` middle-tier; screen updated to prefer DI |
| 9 | `AccountSessionTerminator` | `settings/.../widgets/logout_delete_confirm_sheet.dart` | `DioAccountSessionTerminator` | `POST /v1/auth/logout`, `POST /v1/devices/unregister`, `PATCH /users/:id/status` | unconditional self-construct over `resolveGatewayDio()`; screen updated to prefer DI |

All 9 endpoints verified present in `mock-backend/src/services/*.ts` route definitions.

### Already real — intentionally NOT registered

| Type | Screen | Why left as-is |
|------|--------|----------------|
| `SubmittedOffersRepository` | `jeeber_pending_offers/.../jeeber_pending_offers_screen.dart` | Parametrized by a **per-screen `jeeberId`**, so it cannot be a fixed singleton. The screen already self-constructs the real `DioSubmittedOffersRepository(dio, jeeberId)` whenever `sl<Dio>()` is registered (always true in release). The `_EmptySubmittedOffersRepository` fallback fires only in the no-DI route-resolve harness. **Not a fake-as-release-default bug.** |

### Documented-deferred — NO real impl or NO gateway endpoint (fake LEFT, do NOT fabricate)

| Type | Screen(s) | has-real-endpoint? | Why deferred |
|------|-----------|--------------------|--------------|
| `PhotoPickerService` | `kyc/.../kyc_wizard_screen.dart`, `jeeber_onboarding/.../dm_onboarding_screen.dart` (`_resolvePicker`) | N/A — device capability, not a gateway call | Only `StubPhotoPickerService` exists; a real `image_picker`-backed adapter has **not been written** (T-mobile-040 follow-up — see `photo_attachment/domain/photo_picker_service.dart` doc). The `image_picker: ^1.1.2` dep is present but no real `PhotoPickerService` impl. Writing it is feature work, not an audit/DI change. **Stub left as default; documented.** |
| `AppReviewLauncher` | `customer_profile/.../customer_profile_screen.dart` (`_resolveReviewLauncher`) | N/A — OS in-app-review, not a gateway call | `InAppReviewLauncher` exists but its body is itself a **no-op** because the `in_app_review` package is absent from `pubspec.lock` (see `INTEGRATOR-SWAP(JM-064)` in `rate_app/data/in_app_review_launcher.dart`). It is functionally identical to the `NoopAppReviewLauncher` fallback today, so registering it would be cosmetic. **Deferred to JM-064 dep landing; documented.** |

### Already compliant before this stream (verified, no change needed)

Real Dio impl already registered in `injection_container.dart`; the screen's Fake/Stub/Empty is
already the test-only fallback: `OffersRepository`, `OrderRepository`, `AuthRepository`,
`RoleSwitchRepository`, `ClientHomeRepository`, `ActiveDeliveriesRepository`, `TierRepository`,
`KycGateway`, `SavedLocationRepository`, `GoodsCostRepository`, `SearchRepository`,
`WalletLedgerRepository`, `WalletTransactionRepository`, `NotificationsRepository`,
`DisputeStatusRepository`, `ReviewsRepository`. (`chat_detail` self-constructs the real
`DioChatGateway` / `DioOrderBroadcastService` with no fake fallback.)

## Verification

- `dart analyze` on all touched dirs: clean (the 6 remaining `info` lints are pre-existing
  `unintended_html_in_doc_comment` / `use_null_aware` in files NOT touched by this stream).
- `flutter test test/core/di test/core/router`: **83 passing** (the no-DI route-resolve harness —
  the fake fallback path — still green).
- Affected feature tests (`account_status`, `cancel_request`, `delivery_receipt`,
  `jeeber_pending_offers`, `location`, `no_offer_timeout`, `order_summary`, `settings`,
  `dm_onboarding`, `saved_locations`, `cancellation`): **95 passing**.
- Full suite (`flutter test`): **1698 passing, 0 failing**.

## Files changed

- `lib/core/di/injection_container.dart` — +9 registrations (+ imports).
- `lib/features/settings/presentation/widgets/logout_delete_confirm_sheet.dart` — prefer DI terminator.
- `lib/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart` — prefer DI gateway.
- `FAKE-FALLBACK-AUDIT.md` — this file.
