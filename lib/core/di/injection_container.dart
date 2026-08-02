import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
// P5: Android platform must flip useAndroidPhotoPicker; guarded by `is` check.
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/dio_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/background_gps/application/background_gps_cubit.dart';
import '../../features/background_gps/data/geolocator_geocapture_gateway.dart';
import '../../features/background_gps/data/http_location_uploader.dart';
import '../../features/background_gps/domain/location_permission.dart';
import '../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../features/biometric_auth/data/dev_biometric_gateway.dart';
import '../../features/biometric_auth/data/local_auth_biometric_gateway.dart';
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
import '../config/app_config.dart';
import '../notifications/application/offer_lifecycle_signals.dart';
import '../notifications/application/push_refresh_signals.dart';

export '../notifications/application/push_refresh_signals.dart'
    show RefreshTopic;
import '../session/profile_refresh_signals.dart';
import '../../features/jeeber_home/data/dio_availability_gateway.dart';
import '../../features/jeeber_home/domain/services/availability_gateway.dart';
import '../../features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../../features/jeeber_request_feed/data/dio_request_feed_repository.dart';
import '../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../features/kyc/data/dio_cdn_asset_gateway.dart';
import '../../features/kyc/data/dio_kyc_gateway.dart';
import '../../features/kyc/domain/cdn_asset_gateway.dart';
import '../../features/kyc/domain/kyc_gateway.dart';
import '../../features/photo_attachment/data/image_picker_photo_picker_service.dart';
import '../../features/photo_attachment/domain/photo_picker_service.dart';
import '../../features/live_tracking/data/dio_live_tracking_repository.dart';
import '../../features/live_tracking/data/realtime_courier_position_channel.dart';
import '../../features/live_tracking/domain/courier_position_channel.dart';
import '../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../features/language/data/dio_language_preference_repository.dart';
import '../../features/notification_prefs/data/dio_notification_prefs_repository.dart';
import '../../features/notification_prefs/data/notification_prefs_store.dart';
import '../locale/language_preference_repository.dart';
import '../../features/notification_prefs/domain/notification_prefs_repository.dart';
import '../../features/order_history/data/dio_order_repository.dart';
import '../../features/order_history/domain/order_repository.dart';
import '../../features/otp_handover/data/dio_otp_handover_repository.dart';
import '../../features/otp_handover/data/shared_prefs_handover_code_store.dart';
import '../../features/otp_handover/domain/handover_code_store.dart';
import '../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../features/escalate/data/dio_escalate_repository.dart';
import '../../features/escalate/domain/escalate_repository.dart';
import '../../features/rate_app/data/in_app_review_launcher.dart';
import '../../features/rate_app/domain/app_review_launcher.dart';
import '../../features/rating/data/dio_rating_repository.dart';
import '../../features/rating/domain/rating_repository.dart';
import '../../features/registration/data/dio_otp_service.dart';
import '../../features/registration/data/super_login_demo_user.dart';
import '../../features/registration/data/super_login_service.dart';
import '../../features/registration/domain/otp_service.dart';
import '../../features/settings/data/repositories/biometric_preference_repository_impl.dart';
import '../../features/settings/data/repositories/dio_role_switch_repository.dart';
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
import '../../features/notifications/data/local_merging_notifications_repository.dart';
import '../../features/notifications/domain/notifications_repository.dart';
import '../notifications/data/shared_prefs_local_push_inbox.dart';
import '../notifications/domain/local_push_inbox.dart';
import '../../features/support/data/dio_support_repository.dart';
import '../../features/support/domain/support_repository.dart';
import '../../features/dispute_status/data/dio_dispute_status_repository.dart';
import '../../features/dispute_status/domain/dispute_status_repository.dart';
import '../../features/reviews/data/dio_reviews_repository.dart';
import '../../features/reviews/domain/reviews_repository.dart';
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
import '../../features/settings/data/shared_prefs_profile_repository.dart';
import '../../features/cancel_request/data/dio_cancel_request_repository.dart';
import '../../features/cancel_request/domain/cancel_request_repository.dart';
import '../../features/cancellation/data/dio_cancellation_repository.dart';
import '../../features/cancellation/domain/cancellation_repository.dart';
import '../../features/location/data/dio_saved_location_repository.dart';
import '../../features/location/data/geolocator_current_location_resolver.dart';
import '../../features/location/domain/current_location_resolver.dart';
import '../../features/location/domain/saved_location_repository.dart';
import '../../features/active_delivery_jeeber/data/dio_active_delivery_repository.dart';
import '../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../features/order_summary/data/dio_order_summary_repository.dart';
import '../../features/order_summary/domain/order_summary_repository.dart';
import '../../features/offers/data/dio_offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/settlement/data/dio_settlement_repository.dart';
import '../../features/settlement/domain/settlement_repository.dart';
import '../config/dev_base_url.dart';
import '../lifecycle/app_lifecycle_gate.dart';
import '../network/auth_token_store.dart';
import '../network/mock_gateway_client.dart';
import '../network/single_flight_get.dart';
import '../observability/crash_reporter.dart';

final sl = GetIt.instance;

Dio resolveGatewayDio() {
  if (sl.isRegistered<Dio>()) return sl<Dio>();
  return MockGatewayClient.createDio();
}

Stream<void>? resolvePushRefreshStream({Set<RefreshTopic>? topics}) {
  if (!sl.isRegistered<PushRefreshSignals>()) return null;
  final bus = sl<PushRefreshSignals>();
  return topics == null ? bus.stream : bus.streamFor(topics);
}

CourierPositionChannel? resolveCourierPositionChannel() {
  if (!AppConfig.realtimeCourierPositionEnabled) return null;
  if (!sl.isRegistered<CourierPositionChannel>()) return null;
  return sl<CourierPositionChannel>();
}

void configureDependencies({
  required SharedPreferences sharedPreferences,
  required CrashReporter crashReporter,
}) {
  AppLifecycleGate.install(WidgetsBindingAppLifecycleGate());

  sl.registerSingleton<SharedPreferences>(sharedPreferences);
  sl.registerSingleton<CrashReporter>(crashReporter);

  sl.registerLazySingleton<Dio>(
    () => MockGatewayClient.createDio(
      baseUrl: DevBaseUrl.read(sl<SharedPreferences>()),
      // b02 P0: rate limit window trailing edge — screen holds pre-429 snapshot
      onRateLimitWindowClosed: () {
        if (!sl.isRegistered<PushRefreshSignals>()) return;
        sl<PushRefreshSignals>().signalStatusChange();
      },
    ),
  );

  sl.registerLazySingleton<SingleFlightGet>(() => SingleFlightGet(sl<Dio>()));

  sl.registerLazySingleton<AuthTokenStore>(() => AuthTokenStore());

  sl.registerLazySingleton<PushRefreshSignals>(() => PushRefreshSignals());

  sl.registerLazySingleton<ProfileRefreshSignals>(
    () => ProfileRefreshSignals(),
  );

  sl.registerLazySingleton<OfferLifecycleSignals>(
    () => OfferLifecycleSignals(),
  );

  sl.registerLazySingleton<AppReviewLauncher>(
    () => const InAppReviewLauncher(),
  );

  // BUG-7: persist phone-OTP number to settings.profile.v1.
  sl.registerLazySingleton<OtpService>(
    () => DioOtpService(
      sl<Dio>(),
      sl<AuthTokenStore>(),
      profileRepository: SharedPrefsProfileRepository(
        prefs: sl<SharedPreferences>(),
      ),
    ),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => DioAuthRepository(sl<Dio>(), sl<AuthTokenStore>()),
  );

  // DEBUG: hardcodes authenticate()=true; RELEASE: OS biometric with fallback; tree-shaken in release.
  sl.registerLazySingleton<BiometricGateway>(
    () => kDebugMode
        ? const DevBiometricGateway()
        : LocalAuthBiometricGateway(),
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

  sl.registerLazySingleton<SuperLoginService>(
    () => DefaultSuperLoginService(dio: sl<Dio>()),
  );

  sl.registerLazySingleton<SuperLoginDemoUserService>(
    () => DefaultSuperLoginDemoUserService(dio: sl<Dio>()),
  );

  sl.registerLazySingleton<OrderRepository>(
    () => DioOrderRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<ClientHomeRepository>(
    () => DioClientHomeRepository(sl<Dio>(), coalescer: sl<SingleFlightGet>()),
  );

  sl.registerLazySingleton<EarningsRepository>(
    () => DioEarningsRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<OtpHandoverRepository>(
    () => DioOtpHandoverRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<HandoverCodeStore>(
    () => SharedPrefsHandoverCodeStore(prefs: sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<LiveTrackingRepository>(
    () => DioLiveTrackingRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<CourierPositionChannel>(
    () => RealtimeCourierPositionChannel(sl<Dio>()),
  );

  sl.registerLazySingleton<NotificationPrefsStore>(
    () => NotificationPrefsStore(sl<SharedPreferences>()),
  );

  sl.registerLazySingleton<LanguagePreferenceRepository>(
    () => DioLanguagePreferenceRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<TierRepository>(() => DioTierRepository(sl<Dio>()));

  sl.registerLazySingleton<OffersRepository>(
    () => DioOffersRepository(
      sl<Dio>(),
      handoverCodeStore: sl<HandoverCodeStore>(),
      coalescer: sl<SingleFlightGet>(),
    ),
  );

  sl.registerFactory<ChatGateway>(
    () => DioChatGateway(
      dio: sl<Dio>(),
      currentUserId: 'faketoken',
      handoverCodeStore: sl<HandoverCodeStore>(),
    ),
  );

  sl.registerLazySingleton<RequestFeedRepository>(
    () => DioRequestFeedRepository(dio: sl<Dio>()),
  );

  sl.registerLazySingleton<ProhibitedItemReportService>(
    () => const ProhibitedItemReportService(),
  );

  sl.registerLazySingleton<CdnAssetGateway>(
    () => DioCdnAssetGateway(sl<Dio>()),
  );
  sl.registerLazySingleton<KycGateway>(
    () => DioKycGateway(sl<Dio>(), sl<CdnAssetGateway>()),
  );

  sl.registerLazySingleton<PhotoPickerService>(
    () => ImagePickerPhotoPickerService(),
  );

  final imagePickerPlatform = ImagePickerPlatform.instance;
  if (imagePickerPlatform is ImagePickerAndroid) {
    imagePickerPlatform.useAndroidPhotoPicker = true;
  }

  sl.registerLazySingleton<RatingRepository>(
    () => DioRatingRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<EscalateRepository>(
    () => DioEscalateRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<AvailabilityGateway>(
    () => DioAvailabilityGateway(
      sl<Dio>(),
      tokenStore: sl<AuthTokenStore>(),
      locationFix: () async {
        final gateway = GeolocatorGeocaptureGateway();
        var permission = await gateway.currentPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.notDetermined) {
          permission = await gateway.requestAlwaysPermission();
        }
        if (permission == LocationPermission.denied) {
          throw StateError('location-permission-denied');
        }
        return gateway.currentFix();
      },
    ),
  );

  sl.registerLazySingleton<NotificationPrefsRepository>(
    () => DioNotificationPrefsRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<RoleSwitchRepository>(
    () => DioRoleSwitchRepository(sl<Dio>(), sl<AuthTokenStore>()),
  );

  sl.registerLazySingleton<SavedLocationRepository>(
    () => DioSavedLocationRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<CurrentLocationResolver>(
    GeolocatorCurrentLocationResolver.new,
  );

  sl.registerLazySingleton<CancellationRepository>(
    () => DioCancellationRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<CancelRequestRepository>(
    () => DioCancelRequestRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<ProhibitedAcknowledgmentRepository>(
    () => DioProhibitedAcknowledgmentRepository(
      dio: sl<Dio>(),
      prefs: sl<SharedPreferences>(),
    ),
  );

  sl.registerLazySingleton<OfferSubmissionRepository>(
    () => DioOfferSubmissionRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<OfferSubmissionService>(
    () => const OfferSubmissionService(),
  );

  // BUG-7: ChainedRecipientPhoneResolver tries SharedPrefs phone then gateway.
  sl.registerLazySingleton<RecipientPhoneResolver>(
    () => ChainedRecipientPhoneResolver(<RecipientPhoneResolver>[
      SharedPrefsRecipientPhoneResolver(
        profileRepository: SharedPrefsProfileRepository(
          prefs: sl<SharedPreferences>(),
        ),
      ),
      DioRecipientPhoneResolver(sl<Dio>()),
    ]),
  );

  sl.registerLazySingleton<RequestSubmissionService>(
    () => DioRequestSubmissionService(sl<Dio>(), sl<RecipientPhoneResolver>()),
  );

  // BUG-6: ComposeRequestController was not registered (dead code), so create fell through.
  sl.registerLazySingleton<ComposeRequestController>(
    () => ComposeRequestController(sl<RequestSubmissionService>()),
  );

  sl.registerLazySingleton<ActiveDeliveryRepository>(
    () => DioActiveDeliveryRepository(
      sl<Dio>(),
      cdnAssetGateway: sl<CdnAssetGateway>(),
    ),
  );

  // JEBV4-269 P1: was registerFactory (screen-scoped). On route pop, cubit closed → GPS uploader
  sl.registerLazySingleton<BackgroundGpsCubit>(
    () => BackgroundGpsCubit(
      gateway: GeolocatorGeocaptureGateway(),
      uploader: HttpLocationUploader(dio: sl<Dio>()),
    ),
  );

  sl.registerLazySingleton<OrderSummaryRepository>(
    () => DioOrderSummaryRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<SettlementRepository>(
    () => DioSettlementRepository(sl<Dio>()),
  );

  sl.registerFactory<VoiceRecorder>(() => RecordVoiceRecorder());
  sl.registerFactory<VoicePlayer>(() => AudioPlayersVoicePlayer());

  sl.registerLazySingleton<VoiceRecordingRepository>(
    () => HttpVoiceRecordingRepository(dio: sl<Dio>()),
  );

  sl.registerLazySingleton<WalletRepository>(
    () => DioWalletRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<JeeberKycStatusGate>(
    () => LiveJeeberKycStatusGate(sl<KycGateway>()),
  );

  sl.registerLazySingleton<WalletLedgerRepository>(
    () => DioWalletLedgerRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<WalletTransactionRepository>(
    () => DioWalletTransactionRepository(sl<Dio>()),
  );

  // G3: on-device durable push store lets background isolate surface new_request badge + row.
  sl.registerLazySingleton<LocalPushInbox>(
    () => SharedPrefsLocalPushInbox(prefs: sl<SharedPreferences>()),
  );

  // G3: LocalMergingNotificationsRepository so background push shows durable merged row.
  sl.registerLazySingleton<NotificationsRepository>(
    () => LocalMergingNotificationsRepository(
      remote: DioNotificationsRepository(
        dio: sl<Dio>(),
        tokenStore: sl<AuthTokenStore>(),
      ),
      localInbox: sl<LocalPushInbox>(),
    ),
  );

  sl.registerLazySingleton<SupportRepository>(
    () => DioSupportRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<DisputeStatusRepository>(
    () => DioDisputeStatusRepository(sl<Dio>()),
  );

  sl.registerLazySingleton<ReviewsRepository>(
    () => DioReviewsRepository(sl<Dio>()),
  );
}
