import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dev_seam/dev_seam.dart';
import '../network/auth_token_store.dart';
import '../session/account_status_gate.dart';
import '../session/session_gate.dart';
import '../session/session_state.dart';
import '../session/profile_refresh_signals.dart';
import 'app_route_observer.dart';
import 'profile_unavailable_screen.dart';
import 'root_aware_back_scope.dart';
import '../../features/account_status/presentation/account_status_screen.dart';
import '../../features/auth/presentation/set_password_screen.dart';
import '../../features/biometric_auth/application/biometric_lock_cubit.dart';
import '../../features/biometric_auth/application/biometric_lock_state.dart';
import '../../features/biometric_auth/presentation/biometric_lock_screen.dart';
import '../../features/chat/presentation/dev_chat_preview_screen.dart';
import '../../features/client_offers/presentation/client_offers_screen.dart';
import '../../features/customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../../features/customer_profile/presentation/customer_profile_screen.dart';
import '../../features/deep_link_targets/chat_detail_screen.dart';
import '../../features/delivery_man_profile/data/dev_delivery_man_profile_fixtures.dart';
import '../../features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import '../../features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import '../../features/deep_link_targets/delivery_detail_screen.dart';
import '../../features/deep_link_targets/rating_prompt_screen.dart';
import '../../features/kyc/presentation/kyc_wizard_screen.dart';
import '../../features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import '../../features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import '../../features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import '../../features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import '../../features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import '../../features/wallet/presentation/transaction_detail_screen.dart';
import '../../features/wallet/presentation/wallet_activity_list_screen.dart';
import '../../features/wallet/presentation/customer_wallet_stub_screen.dart';
import '../../features/wallet/presentation/wallet_charge_info_screen.dart';
import '../../features/wallet/presentation/wallet_hub_screen.dart';
import '../../features/dispute_status/presentation/dispute_status_screen.dart';
import '../../features/language/presentation/screens/language_settings_screen.dart';
import '../../features/notifications/presentation/notifications_list_screen.dart';
import '../../features/password_security/presentation/password_security_screen.dart';
import '../../features/reviews/presentation/reviews_list_screen.dart';
import '../../features/support/presentation/support_ticket_screen.dart';
import '../../features/escalate/application/escalate_cubit.dart';
import '../../features/escalate/domain/escalate_repository.dart';
import '../../features/escalate/presentation/escalate_screen.dart';
import '../../features/rating/application/mutual_rating_cubit.dart';
import '../../features/rating/domain/rating_repository.dart';
import '../../features/rating/presentation/mutual_rating_screen.dart';
import '../../features/rating/presentation/rating_screen.dart';
import '../../features/jeeber_home/domain/entities/feed_request.dart';
import '../../features/jeeber_home/domain/services/request_feed_service.dart';
import '../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import '../../features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../../features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import '../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../features/live_tracking/application/live_tracking_cubit.dart';
import '../../features/live_tracking/data/demo_live_tracking_repository.dart';
import '../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../features/live_tracking/presentation/live_tracking_screen.dart';
import '../../features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import '../../features/location/presentation/capture_location_screen.dart';
import '../../features/location/presentation/client_location_screen.dart';
import '../../features/location/presentation/screens/address_detail_form_screen.dart';
import '../../features/location/presentation/screens/location_picker_screen.dart';
import '../../features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import '../../features/order_summary/presentation/order_summary_screen.dart';
import '../../features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import '../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import '../../features/background_gps/application/background_gps_cubit.dart';
import '../../features/photo_attachment/domain/photo_picker_service.dart';
import '../../features/offers/domain/offer_submission_repository.dart';
import '../../features/offers/domain/offer_submission_service.dart';
import '../../features/offers/presentation/offer_submission_screen.dart';
import '../../features/settlement/domain/settlement_repository.dart';
import '../../features/settlement/domain/settlement_statement.dart';
import '../../features/settlement/presentation/settlement_detail_screen.dart';
import '../../features/settlement/presentation/settlement_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../features/otp_handover/domain/handover_code_store.dart';
import '../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../features/otp_handover/presentation/otp_handover_screen.dart';
import '../../features/registration/presentation/registration_screen.dart';
import '../../features/request_summary/application/request_summary_cubit.dart';
import '../../features/request_summary/domain/request_draft.dart';
import '../../features/request_summary/domain/request_submission_service.dart';
import '../../features/request_summary/presentation/request_summary_screen.dart';
import '../../features/request_summary/presentation/request_summary_unavailable_screen.dart';
import '../../features/profile_name/data/dio_display_name_repository.dart';
import '../../features/settings/application/settings_cubit.dart';
import '../../features/settings/data/dio_account_service.dart';
import '../../features/settings/data/shared_prefs_profile_repository.dart';
import '../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../features/cancellation/presentation/cancellation_screen.dart';
import '../../features/location/presentation/saved_locations_screen.dart';
import '../../features/settings/presentation/screens/live_settings_screen.dart';
import '../../features/request_type/presentation/request_type_screen.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/shell/tabs/earnings_tab.dart';
import '../../features/transcription/domain/voice_clip.dart';
import '../../features/transcription/presentation/transcription_screen.dart';
import '../../features/voice_request/presentation/voice_request_screen.dart';
import '../di/injection_container.dart';
import '../diagnostics/diagnostics.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../observability/session_trace/session_trace.dart';
import '../onboarding/onboarding_cubit.dart';



















@visibleForTesting
class CaptureLocationRoute extends StatelessWidget {
  const CaptureLocationRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return CaptureLocationScreen(
      
      
      
      onPinned: () {
        if (context.canPop()) context.pop();
      },
    );
  }
}




























@visibleForTesting
String? normalizeChatDeepLink(Uri uri) {
  if (uri.host != 'chat') return null;
  final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
  return id.isEmpty ? null : '/chat/$id';
}













String resolveTrackingDeliveryId({
  required String? routeId,
  required String? queryDeliveryId,
}) {
  if (queryDeliveryId != null && queryDeliveryId.isNotEmpty) {
    return queryDeliveryId;
  }
  return routeId ?? '';
}
















@visibleForTesting
String? normalizeJeebSchemeDeepLink(Uri uri) {
  if (uri.scheme != 'jeeb' || uri.host.isEmpty) return null;
  final path = '/${uri.host}${uri.path}';
  return uri.hasQuery ? '$path?${uri.query}' : path;
}



























Widget buildChatDetailRouteChild(String id) =>
    ChatDetailScreen(key: ValueKey<String>(id), chatId: id);

class AppRouter {
  AppRouter._();

  
  
  
  
  
  
  
  static const Set<String> _preAuthRoutes = {
    '/onboarding',
    '/register',
    '/set-password',
  };
  static const String _lockRoute = '/lock';

  
  
  static const String _accountStatusRoute = '/account-status';

  
  static bool _isPreAuth(String loc) => _preAuthRoutes.contains(loc);

  
  
  
  
  
  static String get _devChat => kDebugMode ? DevSeam.current.chatSelector : '';

  
  
  
  
  static String get _devRoute => kDebugMode ? DevSeam.current.route : '';

  
  
  
  
  static bool get _devSkipOnboarding =>
      kDebugMode && DevSeam.current.skipOnboarding;

  
  
  
  
  
  
  
  
  
  
  
  
  
  static ({bool hasOpinion, String? location}) _initialLandingPinRedirect(
    GoRouterState state,
    String pinLocation,
    bool Function() landed,
    void Function(bool) setLanded,
  ) {
    
    
    final pinPath = Uri.parse(pinLocation).path;
    if (state.matchedLocation == pinPath) {
      
      setLanded(true);
      return (hasOpinion: true, location: null);
    }
    
    
    
    if (!landed() && state.matchedLocation == '/') {
      return (hasOpinion: true, location: pinLocation);
    }
    return (hasOpinion: false, location: null);
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  static String? _firstRunRedirect(
    GoRouterState state,
    OnboardingCubit onboarding,
    SessionGate session,
    AccountStatusGate accountStatus,
  ) {
    final completed = onboarding.state;
    final loc = state.matchedLocation;
    final atPreAuth = _isPreAuth(loc);
    if (!completed && !atPreAuth) return '/onboarding';
    if (completed && loc == '/onboarding') return '/';
    
    
    
    if (completed && session.isUnauthenticated && !atPreAuth) {
      return '/register';
    }
    
    
    
    
    
    
    
    
    
    
    
    if (completed &&
        !session.isUnauthenticated &&
        accountStatus.isBlocked &&
        loc != _accountStatusRoute &&
        !loc.startsWith('/support') &&
        !loc.startsWith('/disputes')) {
      return _accountStatusRoute;
    }
    return null;
  }

  
  
  
  
  
  
  
  
  
  
  
  
  static LiveTrackingRepository _trackingRepository() {
    if (kDebugMode &&
        _devRoute.contains('/tracking') &&
        !DevSeam.current.hasJourneySeed) {
      return const DemoLiveTrackingRepository();
    }
    return sl<LiveTrackingRepository>();
  }

  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  @visibleForTesting
  static const Map<String, String> backFallbacks = {
    
    
    'set-password': '/',
    
    'offer-review': '/',
    'waiting-no-coverage': '/',
    'delivered-receipt': '/',
    'order-summary': '/',
    'delivery-cancel': '/',
    'chat-detail': '/',
    'kyc-status': '/',
    'jeeber-onboarding': '/',
    'customer-profile': '/',
    'delivery-man-profile': '/',
    'location-picker': '/',
    'settings': '/',
    'settings-profile': '/settings',
    'address-detail': '/settings/addresses',
    'settings-notifications': '/settings',
    'voice-request': '/',
    'request-type': '/',
    'client-location': '/',
    'capture-location': '/',
    'transcription': '/',
    
    
    
    'compose-dictation': '/',
    'compose-dictation-review': '/',
    'jeeber-request-detail': '/',
    'request-summary': '/',
    'live-tracking': '/',
    'otp-handover': '/',
    'escalate': '/',
    
    'jeeber-active-delivery': '/',
    'jeeber-settlement': '/',
    'jeeber-settlement-detail': '/jeeber/settlement',
    'onboarding-funding': '/',
    'offer-kyc-gate': '/',
    'delivery-register-prompt': '/',
    'kyc-rejected': '/',
    'jeeber-pending-offers': '/',
    'wallet': '/',
    'customer-wallet': '/',
    'wallet-charge-info': '/wallet',
    'earnings': '/',
    
    'wallet-activity': '/wallet',
    'transaction-detail': '/wallet/activity',
    
    'notifications': '/',
    'support-ticket': '/',
    'dispute-status': '/',
    'reviews-list': '/',
    'reviews-list-by-id': '/',
    'language-settings': '/settings',
    'password-security': '/settings',
  };

  
  
  
  
  
  static List<RouteBase> _wrapRootAware(List<RouteBase> routes) {
    return <RouteBase>[
      for (final route in routes)
        if (route is GoRoute) _wrapGoRoute(route) else route,
    ];
  }

  static GoRoute _wrapGoRoute(GoRoute route) {
    final fallback = backFallbacks[route.name];
    final builder = route.builder;
    final GoRouterWidgetBuilder? wrapped = (fallback != null && builder != null)
        ? (context, state) => RootAwareBackScope(
              fallbackLocation: fallback,
              child: builder(context, state),
            )
        : builder;
    return GoRoute(
      path: route.path,
      name: route.name,
      builder: wrapped,
      redirect: route.redirect,
      routes: _wrapRootAware(route.routes),
    );
  }

  static GoRouter create({
    required OnboardingCubit onboarding,
    required BiometricLockCubit biometricLock,
    
    
    
    
    
    SessionGate session = const AlwaysAuthenticatedSessionGate(),
    
    
    
    
    
    
    AccountStatusGate accountStatus = const AlwaysActiveAccountStatusGate(),
  }) {
    
    
    
    
    var devSeamLanded = false;
    
    
    
    
    final Cubit<SessionState>? sessionCubit = session is Cubit<SessionState>
        ? session as Cubit<SessionState>
        : null;
    
    
    
    final BlocBase<Object?>? accountStatusBloc =
        accountStatus is BlocBase<Object?>
        ? accountStatus as BlocBase<Object?>
        : null;
    return GoRouter(
      initialLocation: '/',
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      observers: [
        DiagNavObserver(),
        newAppRouteObserver(),
        if (kObsCompiledIn) ObsNavObserver(),
      ],
      refreshListenable: _MergedRefreshListenable([
        _CubitRefreshListenable<bool>(onboarding),
        _CubitRefreshListenable<BiometricLockState>(biometricLock),
        if (sessionCubit != null)
          _CubitRefreshListenable<SessionState>(sessionCubit),
        if (accountStatusBloc != null)
          _BlocRefreshListenable(accountStatusBloc),
      ]),
      redirect: (context, state) {
        
        
        
        
        final chatDeepLink = normalizeChatDeepLink(state.uri) ??
            normalizeJeebSchemeDeepLink(state.uri);
        if (chatDeepLink != null && state.matchedLocation != chatDeepLink) {
          return chatDeepLink;
        }

        
        
        
        
        
        if (_devChat.isNotEmpty) {
          final pin = _initialLandingPinRedirect(
            state,
            '/dev-chat',
            () => devSeamLanded,
            (v) => devSeamLanded = v,
          );
          
          
          return pin.hasOpinion ? pin.location : null;
        }

        
        
        
        
        
        
        
        
        
        
        
        
        if (_devRoute.isNotEmpty && _devSkipOnboarding) {
          final pin = _initialLandingPinRedirect(
            state,
            _devRoute,
            () => devSeamLanded,
            (v) => devSeamLanded = v,
          );
          
          return pin.hasOpinion ? pin.location : null;
        }

        
        
        
        final firstRun = _firstRunRedirect(
          state,
          onboarding,
          session,
          accountStatus,
        );
        if (firstRun != null) return firstRun;

        
        
        
        
        if (_devRoute.isNotEmpty && !_devSkipOnboarding) {
          final pin = _initialLandingPinRedirect(
            state,
            _devRoute,
            () => devSeamLanded,
            (v) => devSeamLanded = v,
          );
          if (pin.hasOpinion) return pin.location;
        }

        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        
        final completed = onboarding.state;
        final loc = state.matchedLocation;
        final lockPhase = biometricLock.state.phase;
        if (completed &&
            !session.isUnauthenticated &&
            lockPhase == BiometricLockPhase.locked &&
            loc != _lockRoute) {
          return _lockRoute;
        }
        if (lockPhase != BiometricLockPhase.locked && loc == _lockRoute) {
          return '/';
        }
        return null;
      },
      
      
      
      
      
      routes: _wrapRootAware([
        GoRoute(
          path: '/',
          name: 'shell',
          builder: (context, state) => const ShellScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegistrationScreen(),
        ),
        GoRoute(
          path: _lockRoute,
          name: 'biometric-lock',
          
          
          builder: (context, state) => const BiometricLockScreen(),
        ),
        
        
        
        
        
        
        
        GoRoute(
          path: '/set-password',
          name: 'set-password',
          
          
          
          
          
          
          
          builder: (context, state) {
            final query = state.uri.queryParameters;
            final extra = state.extra;
            final extraMap = extra is Map<String, String>
                ? extra
                : const <String, String>{};
            final email = query['email'] ?? extraMap['email'] ?? '';
            final resetToken = query['resetToken'] ?? extraMap['resetToken'];
            return SetPasswordScreen(
              email: email,
              resetToken: resetToken,
            );
          },
        ),
        
        
        
        GoRoute(
          path: _accountStatusRoute,
          name: 'account-status',
          builder: (context, state) => const AccountStatusScreen(),
        ),
        
        
        
        
        
        
        
        
        
        
        
        GoRoute(
          path: '/requests/:id/offers',
          name: 'offer-review',
          builder: (context, state) =>
              ClientOffersScreen(requestId: state.pathParameters['id'] ?? ''),
        ),
        
        
        
        
        
        
        
        GoRoute(
          path: '/requests/:id/waiting',
          name: 'waiting-no-coverage',
          builder: (context, state) =>
              NoOfferTimeoutScreen(requestId: state.pathParameters['id'] ?? ''),
        ),
        
        
        
        
        
        
        GoRoute(
          path: '/orders/:id/receipt',
          name: 'delivered-receipt',
          builder: (context, state) => DeliveryReceiptScreen(
            deliveryId: state.pathParameters['id'] ?? '',
          ),
        ),
        
        
        
        
        
        GoRoute(
          path: '/orders/:id/summary',
          name: 'order-summary',
          builder: (context, state) =>
              OrderSummaryScreen(deliveryId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/orders/:id',
          name: 'delivery-detail',
          builder: (context, state) => DeliveryDetailScreen(
            deliveryId: state.pathParameters['id'] ?? '',
          ),
        ),
        GoRoute(
          path: '/orders/:id/cancel',
          name: 'delivery-cancel',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final isJeeber = state.uri.queryParameters['role'] == 'jeeber';
            return CancellationScreen(deliveryId: id, isJeeber: isJeeber);
          },
        ),
        GoRoute(
          path: '/orders/:id/rate',
          name: 'rating-prompt',
          
          
          
          
          
          
          
          
          redirect: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            if (id.isEmpty) return null;
            final query = state.uri.query;
            final suffix = query.isEmpty ? '' : '?$query';
            return '/orders/$id/mutual-rate$suffix';
          },
          builder: (context, state) =>
              RatingPromptScreen(deliveryId: state.pathParameters['id'] ?? ''),
        ),
        GoRoute(
          path: '/chat/:id',
          name: 'chat-detail',
          builder: (context, state) =>
              buildChatDetailRouteChild(state.pathParameters['id'] ?? ''),
        ),
        
        
        GoRoute(
          path: '/dev-chat',
          name: 'dev-chat',
          builder: (context, state) => DevChatPreviewScreen(selector: _devChat),
        ),
        GoRoute(
          path: '/profile/kyc',
          name: 'kyc-status',
          
          
          
          
          
          builder: (context, state) => const KycWizardScreen(),
        ),
        
        
        
        
        GoRoute(
          path: '/jeeber/onboarding',
          name: 'jeeber-onboarding',
          builder: (context, state) => DmOnboardingScreen(
            initialStep: DmOnboardingStep.fromSlug(
              state.uri.queryParameters['step'],
            ),
            onCompleted: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
        ),
        GoRoute(
          path: '/profile/customer',
          name: 'customer-profile',
          
          
          
          
          builder: (context, state) {
            final extra = state.extra;
            if (extra is CustomerProfileViewData) {
              return CustomerProfileScreen(data: extra);
            }
            if (kDebugMode) {
              return const CustomerProfileScreen(
                data: DevCustomerProfileFixtures.sample,
              );
            }
            return const ProfileUnavailableScreen();
          },
        ),
        GoRoute(
          path: '/profile/delivery-man',
          name: 'delivery-man-profile',
          
          
          
          builder: (context, state) {
            final extra = state.extra;
            if (extra is DeliveryManProfileViewData) {
              return DeliveryManProfileScreen(data: extra);
            }
            if (kDebugMode) {
              return const DeliveryManProfileScreen(
                data: DevDeliveryManProfileFixtures.sample,
              );
            }
            return const ProfileUnavailableScreen();
          },
        ),
        GoRoute(
          path: '/location',
          name: 'location-picker',
          builder: (context, state) => const LocationPickerScreen(),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const LiveSettingsScreen(),
          routes: [
            GoRoute(
              path: 'profile',
              name: 'settings-profile',
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              
              builder: (context, state) => BlocProvider<SettingsCubit>(
                create: (_) => SettingsCubit(
                  profileRepository: SharedPrefsProfileRepository(
                    prefs: sl<SharedPreferences>(),
                  ),
                  accountService:
                      DioAccountService(sl<Dio>(), AuthTokenStore()),
                  displayNameRepository: DioDisplayNameRepository(sl<Dio>()),
                  refreshSignals: sl.isRegistered<ProfileRefreshSignals>()
                      ? sl<ProfileRefreshSignals>()
                      : null,
                )..load(),
                child: const ProfileEditScreen(),
              ),
            ),
            GoRoute(
              path: 'addresses',
              name: 'settings-addresses',
              
              builder: (context, state) => const SavedLocationsScreen(),
              routes: [
                
                
                
                
                
                GoRoute(
                  path: 'edit',
                  name: 'address-detail',
                  builder: (context, state) => AddressDetailFormScreen(
                    addressId: state.uri.queryParameters['id'],
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'notifications',
              name: 'settings-notifications',
              builder: (context, state) =>
                  const NotificationPreferencesScreen(),
            ),
            
            
            
            
            
            GoRoute(
              path: 'diagnostics',
              name: 'settings-diagnostics',
              builder: (context, state) => const DiagnosticsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/voice-request',
          name: 'voice-request',
          
          
          
          
          
          
          
          
          
          builder: (context, state) => VoiceRequestScreen(
            
            
            
            onSent: (clipId, transcript,
                    {String? localAudioPath,
                    Duration duration = Duration.zero}) =>
                context.push(
              '/voice-request/transcription',
              extra: VoiceClip(
                audioPath: clipId,
                durationMs: duration.inMilliseconds,
                transcript: transcript,
                localAudioPath: localAudioPath,
              ),
            ),
          ),
        ),
        
        
        
        
        
        
        GoRoute(
          path: '/request-type',
          name: 'request-type',
          builder: (context, state) => RequestTypeScreen(
            onChangeLocation: () => context.push('/client-location'),
            
            
            
            
            
            
            onTierSelected: (tier) => context.push(
              '/request-summary',
              extra: RequestDraft(
                description: '',
                tierId: tier.id.name,
                tierName: tier.id.name,
              ),
            ),
            
            
            
            
            
            
            onContinue: (draft) =>
                context.push('/request-summary', extra: draft),
          ),
        ),
        GoRoute(
          path: '/client-location',
          name: 'client-location',
          
          
          
          
          
          
          builder: (context, state) => const ClientLocationScreen(),
        ),
        GoRoute(
          path: '/capture-location',
          name: 'capture-location',
          builder: (context, state) => const CaptureLocationRoute(),
        ),
        GoRoute(
          path: '/voice-request/transcription',
          name: 'transcription',
          
          
          
          
          
          
          
          
          
          
          builder: (context, state) {
            final extra = state.extra;
            final clip = extra is VoiceClip
                ? extra
                : const VoiceClip(audioPath: '', durationMs: 0);
            return TranscriptionScreen(
              clip: clip,
              onConfirm: (text, audioPath) => context.push(
                '/request-summary',
                extra: RequestDraft(
                  description: text,
                  transcription: text,
                  audioUrl: audioPath.isEmpty ? null : audioPath,
                ),
              ),
              onReRecord: () {
                if (context.canPop()) context.pop();
              },
            );
          },
        ),
        
        
        
        
        
        
        
        
        GoRoute(
          path: '/compose-dictation',
          name: 'compose-dictation',
          builder: (context, state) => VoiceRequestScreen(
            onSent: (clipId, transcript,
                {String? localAudioPath,
                Duration duration = Duration.zero}) async {
              
              
              final clip = await context.push<VoiceClip>(
                '/compose-dictation/review',
                extra: VoiceClip(
                  audioPath: clipId,
                  durationMs: duration.inMilliseconds,
                  transcript: transcript,
                  localAudioPath: localAudioPath,
                ),
              );
              
              
              if (clip != null && context.mounted && context.canPop()) {
                context.pop(clip);
              }
            },
          ),
        ),
        GoRoute(
          path: '/compose-dictation/review',
          name: 'compose-dictation-review',
          builder: (context, state) {
            final extra = state.extra;
            final clip = extra is VoiceClip
                ? extra
                : const VoiceClip(audioPath: '', durationMs: 0);
            return TranscriptionScreen(
              clip: clip,
              onConfirm: (text, audioPath) => context.pop(
                VoiceClip(
                  audioPath: audioPath,
                  durationMs: clip.durationMs,
                  transcript: text,
                ),
              ),
              onReRecord: () {
                if (context.canPop()) context.pop();
              },
            );
          },
        ),
        GoRoute(
          path: '/jeeber/requests/:id/offer',
          name: 'jeeber-offer-submission',
          
          
          builder: (context, state) {
            final requestId = state.pathParameters['id'] ?? '';
            
            
            
            
            return RootAwareBackScope(
              fallbackLocation: '/',
              child: OfferSubmissionScreen(
                requestId: requestId,
                submissionService: sl<OfferSubmissionService>(),
                repository: sl<OfferSubmissionRepository>(),
                onWithdrawn: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
                onSubmitted: (conversationId) {
                  context.go('/chat/$conversationId');
                },
                onRequestGone: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
            );
          },
        ),
        GoRoute(
          path: '/jeeber/requests/:id',
          name: 'jeeber-request-detail',
          
          
          
          
          
          
          
          
          
          
          
          
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            final extra = state.extra;
            final cached = extra is FeedRequest
                ? extra
                : (sl.isRegistered<RequestFeedService>()
                    ? sl<RequestFeedService>().findById(id)
                    : null);
            void back() {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            }

            return JeeberRequestDetailLoader(
              requestId: id,
              initial: cached,
              fetch: () => _recoverFeedRequestById(id),
              
              
              
              
              fetchAcceptedDeliveryId: () => _probeAcceptedDeliveryId(id),
              onAcceptedRedirect: (deliveryId) => context.pushReplacementNamed(
                'jeeber-active-delivery',
                pathParameters: {'id': deliveryId},
              ),
              reportService: sl<ProhibitedItemReportService>(),
              onDeclined: (_) => back(),
              onBack: back,
            );
          },
        ),
        GoRoute(
          path: '/request-summary',
          name: 'request-summary',
          
          
          
          
          
          builder: (context, state) {
            final extra = state.extra;
            if (extra is! RequestDraft) {
              return const RequestSummaryUnavailableScreen();
            }
            return BlocProvider<RequestSummaryCubit>(
              create: (_) =>
                  RequestSummaryCubit(sl<RequestSubmissionService>())
                    ..setDraft(extra),
              child: const RequestSummaryScreen(),
            );
          },
        ),
        GoRoute(
          path: '/orders/:id/tracking',
          name: 'live-tracking',
          builder: (context, state) {
            
            
            
            
            
            
            
            
            final deliveryId = resolveTrackingDeliveryId(
              routeId: state.pathParameters['id'],
              queryDeliveryId: state.uri.queryParameters['deliveryId'],
            );
            return BlocProvider<LiveTrackingCubit>(
              create: (_) => LiveTrackingCubit(
                repository: _trackingRepository(),
                deliveryId: deliveryId,
                
                
                
                
                
                
                
                
                
                
                
                refreshSignals: resolvePushRefreshStream(
                  topics: const {RefreshTopic.order},
                ),
                
                
                
                handoverCodeStore: sl.isRegistered<HandoverCodeStore>()
                    ? sl<HandoverCodeStore>()
                    : null,
                
                
                
                
                
                positionChannel: resolveCourierPositionChannel(),
              ),
              
              
              
              
              
              
              
              
              
              
              child: LiveTrackingScreen(
                deliveryId: deliveryId,
                useLiveMap: true,
              ),
            );
          },
        ),
        GoRoute(
          path: '/orders/:id/otp',
          name: 'otp-handover',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            final isClient = state.uri.queryParameters['mode'] != 'jeeber';
            return BlocProvider<OtpHandoverCubit>(
              create: (_) => OtpHandoverCubit(
                repository: sl<OtpHandoverRepository>(),
                deliveryId: deliveryId,
                isClient: isClient,
                
                
                
                codeStore: sl.isRegistered<HandoverCodeStore>()
                    ? sl<HandoverCodeStore>()
                    : null,
              ),
              child: OtpHandoverScreen(
                deliveryId: deliveryId,
                isClient: isClient,
              ),
            );
          },
        ),
        
        
        
        
        GoRoute(
          path: '/orders/:id/feedback',
          name: 'feedback',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            final isClient = state.uri.queryParameters['mode'] != 'jeeber';
            return RatingScreen(
              deliveryId: deliveryId,
              isClient: isClient,
              rateeName: state.uri.queryParameters['name'] ?? '',
            );
          },
        ),
        
        
        
        GoRoute(
          path: '/orders/:id/mutual-rate',
          name: 'mutual-rating',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            final isClient = state.uri.queryParameters['mode'] != 'jeeber';
            return BlocProvider<MutualRatingCubit>(
              create: (_) => MutualRatingCubit(
                repository: sl<RatingRepository>(),
                deliveryId: deliveryId,
                isClient: isClient,
              ),
              child: const MutualRatingScreen(),
            );
          },
        ),
        
        
        GoRoute(
          path: '/orders/:id/escalate',
          name: 'escalate',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            return BlocProvider<EscalateCubit>(
              create: (_) => EscalateCubit(
                repository: sl<EscalateRepository>(),
                deliveryId: deliveryId,
              ),
              child: const EscalateScreen(),
            );
          },
        ),
        
        
        GoRoute(
          path: '/jeeber/deliveries/:id/active',
          name: 'jeeber-active-delivery',
          builder: (context, state) {
            final deliveryId = state.pathParameters['id'] ?? '';
            return ActiveDeliveryJeeberScreen(
              deliveryId: deliveryId,
              repository: sl<ActiveDeliveryRepository>(),
              
              
              photoPicker: sl<PhotoPickerService>(),
              
              
              
              
              gpsUploader: sl<BackgroundGpsCubit>(),
              
              
              
              
              
              
              onOpenChat: () => context.pushNamed(
                'chat-detail',
                pathParameters: {'id': deliveryId},
              ),
              onOpenOtp: () {
                context.go('/orders/$deliveryId/otp?mode=jeeber');
              },
              
              
              
              
              
              
              
              onMarkedDelivered: () {
                context.go('/orders/$deliveryId/mutual-rate?mode=jeeber');
              },
              
              mapsUrlBuilder: (url) => launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              ),
            );
          },
        ),

        
        GoRoute(
          path: '/jeeber/settlement',
          name: 'jeeber-settlement',
          builder: (context, state) => SettlementScreen(
            repository: sl<SettlementRepository>(),
            onTapStatement: (statement) {
              context.push(
                '/jeeber/settlement/${statement.id}',
                extra: statement,
              );
            },
            
            onOpenPdf: (path) => OpenFile.open(path),
          ),
        ),

        
        GoRoute(
          path: '/jeeber/settlement/:id',
          name: 'jeeber-settlement-detail',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is SettlementStatement) {
              return SettlementDetailScreen(statement: extra);
            }
            return const Scaffold(
              body: Center(child: Text('Statement not found')),
            );
          },
        ),

        
        
        
        
        
        
        
        
        

        
        
        GoRoute(
          path: '/jeeber/onboarding/funding',
          name: 'onboarding-funding',
          builder: (context, state) => const OnboardingFundingScreen(),
        ),
        
        
        GoRoute(
          path: '/jeeber/offer-gate',
          name: 'offer-kyc-gate',
          builder: (context, state) => const OfferKycGateScreen(),
        ),
        
        
        
        
        GoRoute(
          path: '/jeeber/register-prompt',
          name: 'delivery-register-prompt',
          builder: (context, state) => const DeliveryRegisterPromptScreen(),
        ),
        
        GoRoute(
          path: '/kyc/rejected',
          name: 'kyc-rejected',
          builder: (context, state) => const KycRejectedScreen(),
        ),
        
        
        
        
        GoRoute(
          path: '/jeeber/pending-offers',
          name: 'jeeber-pending-offers',
          builder: (context, state) => const JeeberPendingOffersScreen(),
        ),
        
        
        
        
        
        
        GoRoute(
          path: '/wallet',
          name: 'wallet',
          builder: (context, state) => const WalletHubScreen(),
        ),
        
        
        
        
        GoRoute(
          path: '/wallet/customer',
          name: 'customer-wallet',
          builder: (context, state) => const CustomerWalletStubScreen(),
        ),
        
        
        GoRoute(
          path: '/wallet/charge-info',
          name: 'wallet-charge-info',
          builder: (context, state) => const WalletChargeInfoScreen(),
        ),
        
        
        
        
        
        
        
        GoRoute(
          path: '/earnings',
          name: 'earnings',
          builder: (context, state) => const EarningsTab(),
        ),

        
        
        
        
        

        
        
        
        GoRoute(
          path: '/wallet/activity',
          name: 'wallet-activity',
          builder: (context, state) => const WalletActivityListScreen(),
        ),
        
        
        
        
        GoRoute(
          path: '/wallet/transactions/:id',
          name: 'transaction-detail',
          builder: (context, state) => TransactionDetailScreen(
            transactionId: state.pathParameters['id'] ?? '',
          ),
        ),

        
        
        
        
        
        
        
        
        

        
        
        
        GoRoute(
          path: '/notifications',
          name: 'notifications',
          builder: (context, state) => const NotificationsListScreen(),
        ),
        
        
        
        GoRoute(
          path: '/support',
          name: 'support-ticket',
          builder: (context, state) => const SupportTicketScreen(),
        ),
        
        
        GoRoute(
          path: '/disputes/:id',
          name: 'dispute-status',
          builder: (context, state) =>
              DisputeStatusScreen(disputeId: state.pathParameters['id'] ?? ''),
        ),
        
        
        
        GoRoute(
          path: '/profile/delivery-man/reviews',
          name: 'reviews-list',
          builder: (context, state) => ReviewsListScreen(
            jeeberId: state.uri.queryParameters['jeeberId'],
          ),
        ),
        
        
        
        GoRoute(
          path: '/profile/delivery-man/:jeeberId/reviews',
          name: 'reviews-list-by-id',
          builder: (context, state) => ReviewsListScreen(
            jeeberId:
                state.pathParameters['jeeberId'] ??
                state.uri.queryParameters['jeeberId'],
          ),
        ),
        
        
        
        
        
        GoRoute(
          path: '/settings/language',
          name: 'language-settings',
          builder: (context, state) => const LanguageSettingsScreen(),
        ),
        
        
        GoRoute(
          path: '/settings/password',
          name: 'password-security',
          builder: (context, state) => const PasswordSecurityScreen(),
        ),
      ]),
      errorBuilder: (context, state) =>
          Scaffold(body: Center(child: Text('Route not found: ${state.uri}'))),
    );
  }
}



class _CubitRefreshListenable<T> extends ChangeNotifier {
  _CubitRefreshListenable(Cubit<T> cubit) {
    _subscription = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<T> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}





class _BlocRefreshListenable extends ChangeNotifier {
  _BlocRefreshListenable(BlocBase<Object?> bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}



class _MergedRefreshListenable extends ChangeNotifier {
  _MergedRefreshListenable(this._children) {
    for (final child in _children) {
      child.addListener(notifyListeners);
    }
  }

  final List<Listenable> _children;

  @override
  void dispose() {
    for (final child in _children) {
      child.removeListener(notifyListeners);
      if (child is ChangeNotifier) child.dispose();
    }
    super.dispose();
  }
}













Future<FeedRequest?> _recoverFeedRequestById(String id) async {
  if (id.isEmpty || !sl.isRegistered<RequestFeedRepository>()) return null;
  final requests = await sl<RequestFeedRepository>().refresh();
  for (final request in requests) {
    if (request.id == id) {
      return FeedRequest(
        id: request.id,
        shortLabel: request.pickup.label,
        
        
        description: request.itemsSummary,
      );
    }
  }
  return null;
}












Future<String?> _probeAcceptedDeliveryId(String id) async {
  if (id.isEmpty || !sl.isRegistered<ActiveDeliveryRepository>()) return null;
  try {
    final delivery = await sl<ActiveDeliveryRepository>().fetchDelivery(id);
    if (delivery.status == JeeberDeliveryStatus.done) return null;
    return delivery.id.isNotEmpty ? delivery.id : id;
  } catch (_) {
    return null;
  }
}
