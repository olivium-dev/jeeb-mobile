import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/dio_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../features/biometric_auth/data/dev_biometric_gateway.dart';
import '../../features/biometric_auth/data/shared_prefs_pin_repository.dart';
import '../../features/biometric_auth/domain/biometric_gateway.dart';
import '../../features/client_offers/data/dio_offers_repository.dart';
import '../../features/client_offers/domain/offers_repository.dart';
import '../../features/chat/domain/chat_gateway.dart';
import '../../features/chat/data/dio_chat_gateway.dart';
import '../../features/earnings/data/dio_earnings_repository.dart';
import '../../features/earnings/domain/earnings_repository.dart';
import '../../features/home_client/data/dio_client_home_repository.dart';
import '../../features/home_client/domain/client_home_repository.dart';
import '../../features/jeeber_home/data/dio_availability_gateway.dart';
import '../../features/jeeber_home/domain/services/availability_gateway.dart';
import '../../features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../../features/jeeber_request_feed/data/dio_request_feed_repository.dart';
import '../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../features/kyc/data/dio_kyc_gateway.dart';
import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/live_tracking/data/dio_live_tracking_repository.dart';
import '../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../features/notification_prefs/data/dio_notification_prefs_repository.dart';
import '../../features/notification_prefs/data/notification_prefs_store.dart';
import '../../features/notification_prefs/domain/notification_prefs_repository.dart';
import '../../features/order_history/data/dio_order_repository.dart';
import '../../features/order_history/domain/order_repository.dart';
import '../../features/otp_handover/data/dio_otp_handover_repository.dart';
import '../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../features/escalate/data/dio_escalate_repository.dart';
import '../../features/escalate/domain/escalate_repository.dart';
import '../../features/goods_cost/data/dio_goods_cost_repository.dart';
import '../../features/goods_cost/domain/goods_cost_repository.dart';
import '../../features/rating/data/dio_rating_repository.dart';
import '../../features/rating/domain/rating_repository.dart';
import '../../features/registration/data/dio_otp_service.dart';
import '../../features/registration/data/super_login_demo_user.dart';
import '../../features/registration/data/super_login_service.dart';
import '../../features/registration/domain/otp_service.dart';
import '../../features/settings/data/dio_account_service.dart';
import '../../features/settings/data/repositories/biometric_preference_repository_impl.dart';
import '../../features/settings/data/repositories/dio_role_switch_repository.dart';
import '../../features/settings/data/shared_prefs_profile_repository.dart';
import '../../features/settings/domain/account_service.dart';
import '../../features/settings/domain/profile_repository.dart';
import '../../features/settings/domain/role_switch_repository.dart';
import '../../features/tier_selection/data/tier_repository.dart';
import '../../features/voice_request/data/voice_recording_repository.dart';
import '../../features/wallet/data/dio_wallet_ledger_repository.dart';
import '../../features/wallet/data/dio_wallet_repository.dart';
import '../../features/wallet/data/dio_wallet_transaction_repository.dart';
import '../../features/wallet/domain/wallet_ledger_repository.dart';
import '../../features/wallet/domain/wallet_repository.dart';
import '../../features/wallet/domain/wallet_transaction_repository.dart';
import '../../features/notifications/data/dio_notifications_repository.dart';
import '../../features/notifications/domain/notifications_repository.dart';
import '../../features/search/data/dio_search_repository.dart';
import '../../features/search/domain/search_repository.dart';
import '../../features/support/data/dio_support_repository.dart';
import '../../features/support/domain/support_repository.dart';
import '../../features/dispute_status/data/dio_dispute_status_repository.dart';
import '../../features/dispute_status/domain/dispute_status_repository.dart';
import '../../features/reviews/data/dio_reviews_repository.dart';
import '../../features/reviews/domain/reviews_repository.dart';
// Sprint 6 Stream C — fake-fallback debt reduction: register the real Dio impls
// (which already exist + hit a real gateway/mock route) as the release default
// so the per-screen Fake/Stub/InMemory fallback is reached ONLY by the no-DI
// route-resolve test harness, never in release.
import '../../features/settings/data/dio_account_session_terminator.dart';
import '../../features/settings/domain/account_session_terminator.dart';
import '../../features/cancel_request/data/dio_cancel_request_repository.dart';
import '../../features/cancel_request/domain/cancel_request_repository.dart';
import '../../features/location/data/dio_location_select_repository.dart';
import '../../features/location/domain/location_select_repository.dart';
import '../../features/location/data/dio_address_form_repository.dart';
import '../../features/location/domain/address_form_repository.dart';
import '../../features/account_status/data/dio_account_status_repository.dart';
import '../../features/account_status/domain/account_status_repository.dart';
import '../../features/no_offer_timeout/data/dio_waiting_repository.dart';
import '../../features/no_offer_timeout/domain/waiting_repository.dart';
import '../../features/jeeber_onboarding/data/dio_dm_onboarding_gateway.dart';
import '../../features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import '../../features/order_summary/data/dio_order_summary_repository.dart';
import '../../features/order_summary/domain/order_summary_repository.dart';
import '../../features/delivery_receipt/data/dio_delivery_receipt_repository.dart';
import '../../features/delivery_receipt/domain/delivery_receipt_repository.dart';
import '../config/app_config.dart';
import '../network/dio_client.dart';
import '../session/jeeber_kyc_status_gate.dart';
import '../../features/voice_request/domain/audioplayers_voice_player.dart';
import '../../features/voice_request/domain/record_voice_recorder.dart';
import '../../features/voice_request/domain/voice_player.dart';
import '../../features/voice_request/domain/voice_recorder.dart';
import '../../features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart';
import '../../features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import '../../features/request_summary/application/compose_request_controller.dart';
import '../../features/request_summary/data/chained_recipient_phone_resolver.dart';
import '../../features/request_summary/data/dio_recipient_phone_resolver.dart';
import '../../features/request_summary/data/dio_request_submission_service.dart';
import '../../features/request_summary/data/shared_prefs_recipient_phone_resolver.dart';
import '../../features/request_summary/domain/recipient_phone_resolver.dart';
import '../../features/request_summary/domain/request_submission_service.dart';
import '../../features/cancellation/data/dio_cancellation_repository.dart';
import '../../features/cancellation/domain/cancellation_repository.dart';
import '../../features/location/data/dio_saved_location_repository.dart';
import '../../features/location/domain/saved_location_repository.dart';
import '../../features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import '../../features/jeeber_active_deliveries/data/dio_active_deliveries_repository.dart';
import '../../features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import '../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../features/background_gps/data/geolocator_geocapture_gateway.dart';
import '../../features/background_gps/domain/geocapture_gateway.dart';
import '../../features/offers/data/dio_offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/settlement/data/dio_settlement_repository.dart';
import '../../features/settlement/domain/settlement_repository.dart';
import '../network/auth_token_store.dart';
import '../network/mock_gateway_client.dart';
import '../observability/crash_reporter.dart';

final sl = GetIt.instance;

/// Resolves the ONE configured gateway [Dio] for call sites that build a
/// repository/service outside [configureDependencies] (e.g. a screen's
/// no-DI test fallback, or `app.dart`'s push registrar).
///
/// DI-FIRST: when [configureDependencies] has run (production, Maestro, the
/// app) this returns the registered singleton — the AppConfig-driven
/// [DioClient] (or the [MockGatewayClient] when `--dart-define=USE_MOCK_GATEWAY=
/// true`) with the bearer-attach + 401-refresh interceptors. Every caller then
/// shares the SAME client, so a logged-in session's token is attached uniformly.
///
/// FALLBACK: when GetIt is NOT configured (the `w0_routes_resolve_test.dart`
/// route table mounts screens without `configureDependencies()`), it mirrors
/// the exact same AppConfig selection the DI registration uses — it never
/// hardcodes a base URL and never bypasses [AppConfig].
Dio resolveGatewayDio() {
  if (sl.isRegistered<Dio>()) return sl<Dio>();
  return AppConfig.useMockGateway
      ? MockGatewayClient.createDio()
      : DioClient.createDio(
          AppConfig.gatewayBaseUrl,
          tokenStore:
              sl.isRegistered<AuthTokenStore>() ? sl<AuthTokenStore>() : null,
        );
}

void configureDependencies({
  required SharedPreferences sharedPreferences,
  required CrashReporter crashReporter,
}) {
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  sl.registerSingleton<CrashReporter>(crashReporter);

  sl.registerLazySingleton<AuthTokenStore>(() => AuthTokenStore());

  // Sprint 1 Stream A: the DI default is now the REAL gateway Dio client
  // (DioClient → AppConfig.gatewayBaseUrl), with bearer-attach + single-shot
  // 401-refresh interceptors and a DEBUG-only PII log gate. The local Express
  // mock (MockGatewayClient, service-prefix rewrite, :4010) is retained intact
  // and selected only when an explicit `--dart-define=USE_MOCK_GATEWAY=true`
  // build sets [AppConfig.useMockGateway]. Production/device/CI builds (no
  // define) default to the real impl.
  sl.registerLazySingleton<Dio>(
    () => AppConfig.useMockGateway
        ? MockGatewayClient.createDio()
        : DioClient.createDio(
            AppConfig.gatewayBaseUrl,
            tokenStore: sl<AuthTokenStore>(),
          ),
  );

  sl.registerLazySingleton<OtpService>(
    () => DioOtpService(sl<Dio>(), sl<AuthTokenStore>()),
  );

  // W0-INT (JM-007/020/021/022, CTO-D1 email-first auth funnel). Real Dio-backed
  // auth repo: login + recovery-request/verify + set-password. Posts the
  // VERIFIED /v1/auth/* gateway paths (42_GUARDRAILS_MOCK "W-1 FLOOR CLOSED" —
  // B1/B3 are GREEN, so these routes are NOT absent: no INTEGRATOR-STUB marker).
  // Persists the JWT pair (incl. user.userId for splash routing, JM-006) via
  // AuthTokenStore. The W0 screens resolve this from DI, with a constructor
  // override for tests.
  sl.registerLazySingleton<AuthRepository>(
    () => DioAuthRepository(sl<Dio>(), sl<AuthTokenStore>()),
  );

  // W0-INT (JM-005): BiometricLockCubit + its deps, registered as a FACTORY so
  // each `/lock` entry owns a fresh cubit (it queries the platform biometric /
  // local PIN, a per-entry resource). app.dart still constructs its own
  // instance for the router's refreshListenable; this registration lets the
  // JM-005 screen + JM-006 splash resolve a real cubit from DI. The cubit's
  // real evaluate()/authenticate() behaviour is the JM-005 engineer's to fill
  // in (the type + wiring is real now).
  // RC-3 (JM-005, demo-critical): the production [UnavailableBiometricGateway]
  // always returns `false` from authenticate(), so on the emulator (no enrolled
  // biometric) the `/lock` screen can never release → the shell is never
  // reached. In DEBUG only we wire [DevBiometricGateway] whose authenticate()
  // resolves `true`, so tapping `biometric_unlock_authenticate_cta` succeeds and
  // [BiometricLockCubit] transitions `locked → unlocked` → router releases to
  // `shell_tab_requests`. isAvailable() stays false on both, so the lock is
  // still HELD on entry via the seam-seeded PIN (`hasPin → canChallenge`).
  // RELEASE behaviour is unchanged (kDebugMode is a const false → the dev path
  // is tree-shaken out).
  sl.registerLazySingleton<BiometricGateway>(
    () => kDebugMode
        ? const DevBiometricGateway()
        : const UnavailableBiometricGateway(),
  );
  sl.registerFactory<SharedPrefsPinRepository>(
    () => SharedPrefsPinRepository(prefs: sl<SharedPreferences>()),
  );
  sl.registerFactory<BiometricPreferenceRepositoryImpl>(
    () => BiometricPreferenceRepositoryImpl(prefs: sl<SharedPreferences>()),
  );
  sl.registerFactory<BiometricLockCubit>(
    () => BiometricLockCubit(
      preference: sl<BiometricPreferenceRepositoryImpl>(),
      gateway: sl<BiometricGateway>(),
      pinRepository: sl<SharedPrefsPinRepository>(),
    ),
  );

  // FR-P0-4: super-login service POSTs the dev passcode to the gateway and
  // returns a real, server-minted session (no client-side mock-jwt mint).
  sl.registerLazySingleton<SuperLoginService>(
    () => DefaultSuperLoginService(dio: sl<Dio>()),
  );

  // "Super user login plus": fetches the predefined demo-user roster the picker
  // lists (debug-only). Same Dio client as every other gateway data source.
  sl.registerLazySingleton<SuperLoginDemoUserService>(
    () => DefaultSuperLoginDemoUserService(dio: sl<Dio>()),
  );

  sl.registerLazySingleton<OrderRepository>(
    () => DioOrderRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<ClientHomeRepository>(
    () => DioClientHomeRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<EarningsRepository>(
    () => DioEarningsRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<OtpHandoverRepository>(
    () => DioOtpHandoverRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<LiveTrackingRepository>(
    () => DioLiveTrackingRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<NotificationPrefsStore>(
    () => NotificationPrefsStore(sl<SharedPreferences>()),
  );

  // T-MOB-010: DioTierRepository replaces FakeTierRepository as the DI default.
  // The screen still accepts a constructor-injected repo for widget tests.
  sl.registerLazySingleton<TierRepository>(
    () => DioTierRepository(sl<Dio>()),
  );

  // T-MOB-015 / W1-INT (JM-028 offer-review): DioOffersRepository provides the
  // real gateway path (GET /v1/offers?requestId=, POST /v1/offers/:id/accept →
  // rewritten to /offer-service/v1/... on :4010, 42_GUARDRAILS_MOCK §1.2). The
  // orphaned `/requests/:id/offers` route (W1-INT) resolves ClientOffersScreen,
  // which self-provides ClientOffersCubit over THIS registration.
  // FakeOffersRepository is only acceptable as a test seam via constructor.
  sl.registerLazySingleton<OffersRepository>(
    () => DioOffersRepository(sl<Dio>()),
  );

  // ── WAVE 1 (S2) integrator note — core customer journey (50_EXECUTION_PLAN
  //    §"WAVE 1 (1) S2"). The delivery-service / offer-service / chat-service
  //    surfaces the W1 screens read already route through `sl<Dio>()` =
  //    MockGatewayClient.createDio() (B0/B1 GREEN, base URL :4010), so they are
  //    bound to REAL Dio today — no stub needed:
  //      • offer-review  → OffersRepository (above)            [JM-028]
  //      • tracking      → LiveTrackingRepository (below)       [JM-032]
  //      • chat          → ChatGateway / DioChatGateway (below) [JM-025]
  //      • delivery/req  → ClientHomeRepository, OrderRepository,
  //                        CancellationRepository, ActiveDeliveryRepository
  //      • tiers (T1)    → TierRepository (above; the 5-tier DATA fix is a
  //                        backender mock change, not an app DI change)
  //    The waiting/matching (JM-026), delivered-receipt (JM-033), order-summary
  //    (JM-031) and customer-profile/getMe (JM-035) repositories do NOT exist
  //    as types yet — each per-screen engineer defines its `domain/<X>Repository`
  //    + `data/Dio<X>Repository` (clean-arch: the domain contract is theirs to
  //    author) and registers it HERE in its JM diff (e.g.
  //    `sl.registerLazySingleton<WaitingRepository>(() =>
  //    DioWaitingRepository(sl<Dio>()));`). The integrator does not pre-invent
  //    those types (40_GUARDRAILS_ARCH §6 / DO-NOT: never invent a contract).

  // T-MOB-001: Register all previously missing repos in DI.
  // No screen may self-construct these outside DI in release builds.

  // Chat gateway — conversation-scoped; DI provides the factory default.
  // The factory is registered as a type alias so screens can resolve it;
  // note that DioChatGateway requires a currentUserId which is async — screens
  // that need a per-conversation instance should call DioChatGateway directly
  // with their own resolved userId (see chat_detail_screen.dart).
  sl.registerFactory<ChatGateway>(
    () => DioChatGateway(
      dio: sl<Dio>(),
      currentUserId: 'faketoken',
    ),
  );

  // Jeeber request feed — polling-backed until WS support is wired.
  sl.registerLazySingleton<RequestFeedRepository>(
    () => DioRequestFeedRepository(dio: sl<Dio>()),
  );

  // T-MOB-FIX-001: ProhibitedItemReportService — resolved by app_router when
  // building the jeeber-request-detail route. Without this registration the
  // route builder's `sl<ProhibitedItemReportService>()` throws a GetIt "not
  // registered" Bad state and red-screens the Jeeber leg (active delivery →
  // OTP → mutual rating all unreachable). It is a pure/local, stateless
  // service today, so it is a const lazy singleton — same shape as the sibling
  // OfferSubmissionService that the adjacent jeeber-offer-submission route
  // resolves. When the real prohibited-item flagging RPC lands it swaps to a
  // Dio-backed impl here (mirroring the Dio* repositories above) without
  // touching the route or screen.
  sl.registerLazySingleton<ProhibitedItemReportService>(
    () => const ProhibitedItemReportService(),
  );

  // KYC — submit + status from auth-service via gateway.
  sl.registerLazySingleton<KycGateway>(
    () => DioKycGateway(sl<Dio>()),
  );

  // Rating — post-delivery star rating via score-taking-service.
  sl.registerLazySingleton<RatingRepository>(
    () => DioRatingRepository(sl<Dio>()),
  );

  // T-MOB-022: Escalate — dispute submission via delivery-service.
  sl.registerLazySingleton<EscalateRepository>(
    () => DioEscalateRepository(sl<Dio>()),
  );

  // Sprint 2 Stream G (goods-cost): the Jeeber's goods-cost declaration —
  // GET /v1/delivery/:id (currency label) + POST /v1/delivery/:id/goods-cost.
  // GoodsCostScreen self-resolves this binding (sl.isRegistered<
  // GoodsCostRepository>()); with this explicit registration it no longer
  // falls through to the defensive `DioGoodsCostRepository(sl<Dio>())` /
  // FakeGoodsCostRepository branches. The GoodsCostCubit is provided by the
  // screen's own BlocProvider (mirroring RequestSummaryCubit), so it is not
  // registered here. FakeGoodsCostRepository stays the widget-test seam via the
  // screen's `repository` constructor override.
  sl.registerLazySingleton<GoodsCostRepository>(
    () => DioGoodsCostRepository(sl<Dio>()),
  );

  // Availability toggle — Jeeber online/offline state via geolocation-service.
  sl.registerLazySingleton<AvailabilityGateway>(
    () => DioAvailabilityGateway(sl<Dio>()),
  );

  // Remote notification prefs — syncs with gateway notification-service.
  sl.registerLazySingleton<NotificationPrefsRepository>(
    () => DioNotificationPrefsRepository(sl<Dio>()),
  );

  // T-mobile-031 (Sprint 2 Stream F): real settings seams. The settings screen
  // previously self-constructed InMemoryProfileRepository + FakeAccountService
  // inline (DI bypassed), so release builds never touched persistence or the
  // gateway. Those fakes now live under test/ only; production resolves these:
  //   • ProfileRepository → SharedPrefsProfileRepository — the documented
  //     production impl (profile is an on-device cache; the live gateway does
  //     not surface a profile read/write contract, so this is NOT a Dio repo).
  //   • AccountService → DioAccountService — real POST /v1/auth/logout +
  //     PATCH /users/{id}/status, mapping transport failures to networkError
  //     so the settings UI can render the error banner.
  sl.registerLazySingleton<ProfileRepository>(
    () => SharedPrefsProfileRepository(prefs: sl<SharedPreferences>()),
  );
  sl.registerLazySingleton<AccountService>(
    () => DioAccountService(sl<Dio>(), sl<AuthTokenStore>()),
  );

  // T-MOB-028: Role-switch repository — POST /v1/users/me/role/switch.
  // D-ROLE-TOGGLE: adopts the re-minted token pair from the 200 body via
  // AuthTokenStore so jeeber routes stop 403-ing after an in-app toggle.
  sl.registerLazySingleton<RoleSwitchRepository>(
    () => DioRoleSwitchRepository(sl<Dio>(), sl<AuthTokenStore>()),
  );

  // T-MOB-012: Saved locations — GET/POST /v1/users/me/saved-locations.
  sl.registerLazySingleton<SavedLocationRepository>(
    () => DioSavedLocationRepository(sl<Dio>()),
  );

  // T-MOB-024: Cancellation flow — POST /v1/deliveries/{id}/cancel.
  sl.registerLazySingleton<CancellationRepository>(
    () => DioCancellationRepository(sl<Dio>()),
  );

  // T-MOB-021: Prohibited items acknowledgment — GET /prohibited-items +
  // POST /prohibited-items/acknowledge + SharedPreferences local flag.
  sl.registerLazySingleton<ProhibitedAcknowledgmentRepository>(
    () => DioProhibitedAcknowledgmentRepository(
      dio: sl<Dio>(),
      prefs: sl<SharedPreferences>(),
    ),
  );

  // T-MOB-030: Offer submission — POST /v1/offers.
  sl.registerLazySingleton<OfferSubmissionRepository>(
    () => DioOfferSubmissionRepository(sl<Dio>()),
  );

  // T-MOB-030: OfferSubmissionService — domain service wrapping the repo;
  // resolved by app_router when building the jeeber-offer-submission route.
  sl.registerLazySingleton<OfferSubmissionService>(
    () => const OfferSubmissionService(),
  );

  // T-MOB-REQSUBMIT: real request-create RPC — POST /requests → 201 {id}.
  // Resolved by app_router when building the /request-summary route so the
  // RequestSummaryCubit submits over Dio instead of the prior stub.
  //
  // T-BE-019 / JEB-55 (+ iter6 OTP-phone v2): the create body carries a
  // `recipientPhone` so the gateway request-store row has a non-null
  // RecipientPhone and the at-door handover OTP (`POST /deliveries/{id}/otp/
  // verify {code:"1234"}`) can dispatch/validate instead of returning 400
  // recipient-phone-missing.
  //
  // ROOT-CAUSE FIX (v2): the #67 default source — `GET /v1/users/me` `phone` —
  // does NOT exist in the LIVE gateway `UsersMeResponse` contract, so that lone
  // resolver always returned null and the OTP kept 400-ing. We now resolve the
  // DEFAULT phone from a CHAIN, first non-null wins:
  //   1. SharedPrefsRecipientPhoneResolver — the LOCALLY-persisted registration
  //      profile phone (`UserProfile.phoneE164`), which the live `/me` does not
  //      surface. This is the reliable on-device default for phone-OTP users.
  //   2. DioRecipientPhoneResolver — the gateway `GET /v1/users/me` `phone`,
  //      kept as a best-effort fallback for a future gateway that adds it.
  // The explicit compose-form recipient phone (RequestDraft.recipientPhone)
  // still wins over BOTH defaults inside the submission service. Best-effort:
  // if every source misses, the field is omitted and the create is never
  // blocked.
  sl.registerLazySingleton<RecipientPhoneResolver>(
    () => ChainedRecipientPhoneResolver(<RecipientPhoneResolver>[
      SharedPrefsRecipientPhoneResolver(),
      DioRecipientPhoneResolver(sl<Dio>()),
    ]),
  );
  sl.registerLazySingleton<RequestSubmissionService>(
    () => DioRequestSubmissionService(
      sl<Dio>(),
      phoneResolver: sl<RecipientPhoneResolver>(),
    ),
  );

  // iter6 B11: shared compose controller — carries the chosen tier from the
  // request-type step to the location-confirm step and performs the actual
  // POST /requests there (so the create flow mints a REAL request id instead of
  // handing off the placeholder 'new' to order-chat). Singleton so both steps,
  // which own separate cubits with no common widget-tree ancestor, share it.
  sl.registerLazySingleton<ComposeRequestController>(
    () => ComposeRequestController(sl<RequestSubmissionService>()),
  );

  // T-MOB-031: Active delivery (Jeeber) — GET /v1/deliveries/{id} +
  // POST /v1/deliveries/{id}/transition.
  sl.registerLazySingleton<ActiveDeliveryRepository>(
    () => DioActiveDeliveryRepository(sl<Dio>()),
  );

  // iter6 real-flow blocker fix: the jeeber's ACCEPTED/active deliveries list —
  // GET /v1/deliveries?role=jeeber (gateway JeebOrdersListController). Powers
  // the dashboard active-deliveries banner so a jeeber whose offer was accepted
  // can reach the order's chat + drive the delivery.
  sl.registerLazySingleton<ActiveDeliveriesRepository>(
    () => DioActiveDeliveriesRepository(sl<Dio>()),
  );

  // T-MOB-032: Settlement statements — GET /v1/wallet/jeeb/earnings/statements.
  sl.registerLazySingleton<SettlementRepository>(
    () => DioSettlementRepository(sl<Dio>()),
  );

  // T-MOB-011: Real voice recorder + player behind the VoiceRecorder /
  // VoicePlayer ports. Registered as FACTORIES (not singletons) because each
  // recording session owns an open mic / audio-session resource — a fresh
  // instance per VoiceRecordingScreen avoids leaking a half-open recorder
  // across screen entries. FakeVoiceRecorder / FakeVoicePlayer remain the
  // unit-test seam via the cubit constructor, so they are NOT registered here.
  sl.registerFactory<VoiceRecorder>(() => RecordVoiceRecorder());
  sl.registerFactory<VoicePlayer>(() => AudioPlayersVoicePlayer());

  // T-MOB-011: Voice upload repository — POST /v1/voice/transcribe (gateway
  // proxies voice-transcription-service). Registered so the screen resolves
  // it from DI in release builds instead of self-constructing.
  sl.registerLazySingleton<VoiceRecordingRepository>(
    () => HttpVoiceRecordingRepository(dio: sl<Dio>()),
  );

  // ── WAVE 2 / 2.5 (S2) integrator registrations ───────────────────────────

  // LIVE(JM-053/046): the wallet balance/affordability/reserved-now/gift
  // endpoint (`GET /v1/jeeb/wallet`) has landed (gateway PR #196), so this binds
  // the REAL Dio repo. The wallet UI shell (WalletHubScreen, JM-053) + every
  // "+ Top up" CTA that routes through it resolve this against `/v1/jeeb/wallet`.
  // The in-memory StubWalletRepository remains as the integrator fallback and
  // honors the same [WalletRepository] contract.
  sl.registerLazySingleton<WalletRepository>(
    () => DioWalletRepository(sl<Dio>()),
  );

  // JM-036: the DELIVERY-tab KYC gate source (register-prompt vs feed) + the
  // offer gate (JM-044). The DELIVERY tab body reads `sl<JeeberKycStatusGate>()`
  // .isApproved. SeamJeeberKycStatusGate is debug-aware (reads
  // `jeeb.seam.kyc_status` so Maestro drives the branch) and production-safe
  // (reports approved in release until the JM-036 engineer swaps in the real
  // getMe/kyc-backed gate — GET /user-management/users/:userId/kyc, U1; it
  // depends on the JeeberKycStatusGate interface, not this impl, so the swap is
  // a one-line DI change with no tab-body edit).
  sl.registerLazySingleton<JeeberKycStatusGate>(
    () => const SeamJeeberKycStatusGate(),
  );

  // ── WAVE 3 (S2) integrator registrations — wallet ledger + transaction ─────

  // JM-055 wallet-activity-list: the typed paginated ledger. W2m
  // (`GET /v1/jeeb/wallet/ledger`) is LIVE on :4010 (42_GUARDRAILS_MOCK "W2 mock
  // closeout"), so this binds the REAL Dio repo (NOT a stub). Reached through
  // the `/v1/jeeb/wallet` rewrite key (W3-INT, mock_gateway_client.dart). The
  // JM-055 engineer's WalletActivityListScreen resolves this from DI.
  sl.registerLazySingleton<WalletLedgerRepository>(
    () => DioWalletLedgerRepository(sl<Dio>()),
  );

  // LIVE(JM-056): the wallet transaction-by-id endpoint
  // (`GET /v1/jeeb/wallet/ledger/:id`) has landed (gateway PR #196), so this
  // binds the REAL Dio repo. The transaction-detail screen
  // (TransactionDetailScreen, JM-056) + the inbound `wallet_activity_row_<id>`
  // edge (JM-055) resolve this against `/v1/jeeb/wallet/ledger/:id`. The
  // in-memory StubWalletTransactionRepository remains as the integrator fallback
  // and honors the same [WalletTransactionRepository] contract.
  sl.registerLazySingleton<WalletTransactionRepository>(
    () => DioWalletTransactionRepository(sl<Dio>()),
  );

  // ── WAVE 4 (S2) integrator registrations — notifications/support/dispute/
  //    reviews (50_EXECUTION_PLAN §"WAVE 4 (1) S2"). ────────────────────────

  // JM-057 notifications-list: the notification-service inbox (list + mark-read)
  // is LIVE on :4010 (42_GUARDRAILS_MOCK §4 mock-ready), so this binds the REAL
  // Dio repo. The inbox is scoped to the AUTHENTICATED user via the bearer token
  // (the gateway derives the owner from the JWT `sub` and ignores any `?userId=`
  // param, §6B-confirmed) — so NO client-side userId is passed. (Was previously
  // hardcoded to the mock fixture id `user-client-001`, a §6B FAIL.) The header
  // bell now routes here (`goNamed('notifications')`, shell guard removed).
  sl.registerLazySingleton<NotificationsRepository>(
    () => DioNotificationsRepository(dio: sl<Dio>()),
  );

  // Sprint-5 Stream C search: the gateway free-text search BFF
  // (GET /v1/search?q=). The route is not live yet, so the Dio repo maps a 404
  // to SearchFailure.unavailable → the results screen renders an honest
  // "search isn't available yet" empty state (no dead-end). Same code path
  // returns real hits once the BFF lands.
  sl.registerLazySingleton<SearchRepository>(
    () => DioSearchRepository(dio: sl<Dio>()),
  );

  // LIVE(JM-063): the support-ticket service (S1) has landed — the gateway now
  // exposes the support routes (`POST /v1/support/tickets`, `GET .../{id}`,
  // `GET .../tickets`, `GET .../categories`) backed by jeeb-state-service
  // (gateway PR #200), and the `/v1/support` rewrite key is now declared
  // (mock_gateway_client.dart), so this binds the REAL Dio repo. The support
  // form (SupportTicketScreen, JM-063) + every inbound edge (account-status /
  // dispute-status / kyc-rejected → support, D76) resolve this against
  // `/v1/support/tickets`. Gateway #200 reconciles the DTO drift (tolerates the
  // mobile `orderRef` field + the `delivery`/`kycAppeal` category enum), so no
  // screen/DTO change is needed. The in-memory StubSupportRepository remains as
  // the integrator fallback and honors the same [SupportRepository] contract.
  sl.registerLazySingleton<SupportRepository>(
    () => DioSupportRepository(sl<Dio>()),
  );

  // JM-065 dispute-status: the compliment-service dispute endpoints
  // (`GET /v1/disputes/:disputeId`) are LIVE on :4010 (42_GUARDRAILS_MOCK §4
  // mock-ready; the `/v1/disputes` rewrite key already exists), so this binds
  // the REAL Dio repo. The JM-065 engineer's DisputeStatusScreen resolves this.
  sl.registerLazySingleton<DisputeStatusRepository>(
    () => DioDisputeStatusRepository(sl<Dio>()),
  );

  // LIVE(JM-068): R1m (the per-jeeber reviews source) has landed, so this binds
  // the REAL Dio repo. The reviews list (ReviewsListScreen, JM-068) + the inbound
  // `profile_view_all_reviews` edge (JM-067) resolve this against `/v1/...`.
  // The in-memory StubReviewsRepository remains as the integrator fallback and
  // honors the same [ReviewsRepository] contract.
  sl.registerLazySingleton<ReviewsRepository>(
    () => DioReviewsRepository(sl<Dio>()),
  );

  // T-MOB-012 / T-MOB-017 (feat/maps): device GPS behind the GeocaptureGateway
  // port. GeolocatorGeocaptureGateway wraps the `geolocator` plugin; the cubit,
  // map picker, and capture screen never import the plugin directly.
  // Registered as the concrete type too so the GoogleMap "centre on me"
  // button can call currentFix() (not on the port, which streams).
  // FakeGeocaptureGateway remains the unit-test seam via constructor.
  sl.registerLazySingleton<GeolocatorGeocaptureGateway>(
    () => GeolocatorGeocaptureGateway(),
  );
  sl.registerLazySingleton<GeocaptureGateway>(
    () => sl<GeolocatorGeocaptureGateway>(),
  );

  // ── SPRINT 6 STREAM C — fake-fallback debt reduction ──────────────────────
  // Each repo/service/gateway below already had a real Dio impl AND a real
  // gateway/mock route, but was NOT registered in DI — so its screen's
  // `_resolve*()` either (a) made the Fake the RELEASE default (cancel-request,
  // order-summary) or (b) self-constructed the Dio impl per-screen via an
  // `sl<Dio>()` middle-tier (account-status, waiting, delivery-receipt,
  // location-select, address-form, dm-onboarding, account-session-terminator).
  // Registering them HERE makes the real impl the canonical release default and
  // demotes the Fake/Stub/InMemory to its intended role: the no-DI
  // route-resolve test-harness fallback only. No Fake/Stub class is deleted.
  // (SubmittedOffersRepository is intentionally NOT registered — it is
  // parametrized by a per-screen jeeberId and already self-constructs the real
  // Dio impl; see FAKE-FALLBACK-AUDIT.md.)

  // cancel-request → POST /v1/delivery/cancel. (Was: FakeCancelRequestRepository
  // as the release default — no Dio middle-tier in the sheet.)
  sl.registerLazySingleton<CancelRequestRepository>(
    () => DioCancelRequestRepository(sl<Dio>()),
  );

  // order-summary → GET /v1/delivery/:id + /v1/requests/:id + /users/:id +
  // /v1/offers. (Was: FakeOrderSummaryRepository as the release default.)
  sl.registerLazySingleton<OrderSummaryRepository>(
    () => DioOrderSummaryRepository(sl<Dio>()),
  );

  // account-status → GET /v1/users/me.
  sl.registerLazySingleton<AccountStatusRepository>(
    () => DioAccountStatusRepository(sl<Dio>()),
  );

  // no-offer-timeout / waiting → GET /v1/requests + /v1/offers.
  sl.registerLazySingleton<WaitingRepository>(
    () => DioWaitingRepository(sl<Dio>()),
  );

  // delivery-receipt → GET /v1/delivery/:id + POST /v1/payments/cod_jeeb/record
  // + POST /v1/delivery/status/transition.
  sl.registerLazySingleton<DeliveryReceiptRepository>(
    () => DioDeliveryReceiptRepository(sl<Dio>()),
  );

  // location-select + address-form → the `me`-scoped Saved-Locations BFF
  // (/api/users/me/saved-locations) — the SAME path as the already-registered
  // DioSavedLocationRepository, so the route is proven-live.
  sl.registerLazySingleton<LocationSelectRepository>(
    () => DioLocationSelectRepository(sl<Dio>()),
  );
  sl.registerLazySingleton<AddressFormRepository>(
    () => DioAddressFormRepository(sl<Dio>()),
  );

  // jeeber dm-onboarding service-area probe → POST /v1/matching/find-jeebers.
  sl.registerLazySingleton<DmOnboardingGateway>(
    () => DioDmOnboardingGateway(sl<Dio>()),
  );

  // account-session-terminator (logout + delete) → POST /v1/auth/logout +
  // POST /v1/devices/unregister + PATCH /users/:id/status. Needs the keystore
  // too (token attach + clear on logout).
  sl.registerLazySingleton<AccountSessionTerminator>(
    () => DioAccountSessionTerminator(sl<Dio>(), sl<AuthTokenStore>()),
  );
}
