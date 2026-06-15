import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../../features/rating/data/dio_rating_repository.dart';
import '../../features/rating/domain/rating_repository.dart';
import '../../features/registration/data/dio_otp_service.dart';
import '../../features/registration/data/super_login_demo_user.dart';
import '../../features/registration/data/super_login_service.dart';
import '../../features/registration/domain/otp_service.dart';
import '../../features/settings/data/repositories/dio_role_switch_repository.dart';
import '../../features/settings/domain/role_switch_repository.dart';
import '../../features/tier_selection/data/tier_repository.dart';
import '../../features/voice_request/data/voice_recording_repository.dart';
import '../../features/voice_request/domain/audioplayers_voice_player.dart';
import '../../features/voice_request/domain/record_voice_recorder.dart';
import '../../features/voice_request/domain/voice_player.dart';
import '../../features/voice_request/domain/voice_recorder.dart';
import '../../features/prohibited_acknowledgment/data/prohibited_acknowledgment_repository_impl.dart';
import '../../features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import '../../features/request_summary/data/dio_request_submission_service.dart';
import '../../features/request_summary/domain/request_submission_service.dart';
import '../../features/cancellation/data/dio_cancellation_repository.dart';
import '../../features/cancellation/domain/cancellation_repository.dart';
import '../../features/location/data/dio_saved_location_repository.dart';
import '../../features/location/domain/saved_location_repository.dart';
import '../../features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import '../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../features/offers/data/dio_offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/settlement/data/dio_settlement_repository.dart';
import '../../features/settlement/domain/settlement_repository.dart';
import '../network/auth_token_store.dart';
import '../network/mock_gateway_client.dart';
import '../observability/crash_reporter.dart';

final sl = GetIt.instance;

void configureDependencies({
  required SharedPreferences sharedPreferences,
  required CrashReporter crashReporter,
}) {
  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  sl.registerSingleton<CrashReporter>(crashReporter);

  sl.registerLazySingleton<Dio>(() => MockGatewayClient.createDio());
  sl.registerLazySingleton<AuthTokenStore>(() => AuthTokenStore());

  sl.registerLazySingleton<OtpService>(
    () => DioOtpService(sl<Dio>(), sl<AuthTokenStore>()),
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

  // T-MOB-015: DioOffersRepository provides the real gateway path.
  // FakeOffersRepository is only acceptable as a test seam via constructor.
  sl.registerLazySingleton<OffersRepository>(
    () => DioOffersRepository(sl<Dio>()),
  );

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

  // Availability toggle — Jeeber online/offline state via geolocation-service.
  sl.registerLazySingleton<AvailabilityGateway>(
    () => DioAvailabilityGateway(sl<Dio>()),
  );

  // Remote notification prefs — syncs with gateway notification-service.
  sl.registerLazySingleton<NotificationPrefsRepository>(
    () => DioNotificationPrefsRepository(sl<Dio>()),
  );

  // T-MOB-028: Role-switch repository — POST /v1/users/me/role/switch.
  sl.registerLazySingleton<RoleSwitchRepository>(
    () => DioRoleSwitchRepository(sl<Dio>()),
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
  sl.registerLazySingleton<RequestSubmissionService>(
    () => DioRequestSubmissionService(sl<Dio>()),
  );

  // T-MOB-031: Active delivery (Jeeber) — GET /v1/deliveries/{id} +
  // POST /v1/deliveries/{id}/transition.
  sl.registerLazySingleton<ActiveDeliveryRepository>(
    () => DioActiveDeliveryRepository(sl<Dio>()),
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
}
