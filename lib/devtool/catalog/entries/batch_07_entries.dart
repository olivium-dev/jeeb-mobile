import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';
import '../../../features/notification_prefs/presentation/notification_prefs_screen.dart';
import '../../../features/notifications/domain/notifications_repository.dart';
import '../../../features/notifications/presentation/notifications_list_screen.dart';
import '../../../features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import '../../../features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import '../../../features/offers/presentation/offer_submission_screen.dart';
import '../../../features/offline_mode/application/offline_cubit.dart';
import '../../../features/offline_mode/presentation/offline_banner.dart';
import '../catalog_models.dart';
import '../fixtures/delivery_register_prompt_screen_fixtures.dart';
import '../fixtures/notification_prefs_screen_fixtures.dart';
import '../fixtures/notifications_list_screen_fixtures.dart';
import '../fixtures/offer_kyc_gate_screen_fixtures.dart';
import '../fixtures/offer_submission_screen_fixtures.dart';

Widget _notifPrefsScreen(NotificationPrefsRepository repository) =>
    notificationPrefsScreenSeeded(
      repository: repository,
      child: const NotificationPrefsScreen(),
    );

Widget _notificationsScreen(NotificationsRepository repository) =>
    NotificationsListScreen(repository: repository);

Widget _offerKycGate(KycGateway gateway) => OfferKycGateScreenPreviewHost(
      screen: OfferKycGateScreen(gateway: gateway),
    );

Widget _deliveryRegisterPrompt() =>
    const DeliveryRegisterPromptScreenPreviewHost(
      screen: DeliveryRegisterPromptScreen(),
    );

Widget _offerComposerIdle() => const OfferSubmissionScreen(
      requestId: OfferSubmissionScreenPreviewFixtures.requestId,
      submissionService: Object(),
      onWithdrawn: OfferSubmissionScreenPreviewFixtures.noop,
      repository: OfferSubmissionScreenPreviewFixtures.idleRepository,
      walletRepository: OfferSubmissionScreenPreviewFixtures.walletRepository,
    );

Widget _offerComposerSubmitting() => OfferSubmissionScreen(
      requestId: OfferSubmissionScreenPreviewFixtures.submittingRequestId,
      submissionService: const Object(),
      onWithdrawn: OfferSubmissionScreenPreviewFixtures.noop,
      walletRepository: OfferSubmissionScreenPreviewFixtures.walletRepository,
      cubit: OfferSubmissionScreenPreviewFixtures.submittingCubit(),
    );

Widget _offerComposerValidationErrors() => OfferSubmissionScreen(
      requestId: OfferSubmissionScreenPreviewFixtures.validationRequestId,
      submissionService: const Object(),
      onWithdrawn: OfferSubmissionScreenPreviewFixtures.noop,
      walletRepository: OfferSubmissionScreenPreviewFixtures.walletRepository,
      cubit: OfferSubmissionScreenPreviewFixtures.validationErrorCubit(),
    );

Widget _offlineBannerDemo({required bool offline}) {
  final cubit = OfflineCubit();
  if (offline) cubit.setOffline();
  return BlocProvider<OfflineCubit>.value(
    value: cubit,
    child: const Scaffold(
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [OfflineBanner()],
      ),
    ),
  );
}

List<CatalogEntry> get batch07Entries => <CatalogEntry>[
      CatalogEntry(
        feature: 'notification_prefs',
        screen: 'NotificationPrefsScreen',
        states: <CatalogState>[
          CatalogState(
            'Loading',
            (_) => _notifPrefsScreen(
              const NotificationPreferencesScreenPendingRepository(),
            ),
          ),
          CatalogState(
            'Loaded',
            (_) => _notifPrefsScreen(
              const NotificationPreferencesScreenFakeRepository(
                prefs: notificationPrefsScreenCatalogPrefs,
              ),
            ),
          ),
          CatalogState(
            'Load Error',
            (_) => _notifPrefsScreen(
              const NotificationPreferencesScreenFakeRepository(
                fetchFailure: NotificationPrefsFailure.network,
                saveFailure: NotificationPrefsFailure.network,
              ),
            ),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'notifications',
        screen: 'NotificationsListScreen',
        states: <CatalogState>[
          CatalogState(
            'Loading',
            (_) => _notificationsScreen(
              NotificationsListScreenPreviewFixtures.stalledLoad(),
            ),
          ),
          CatalogState(
            'Populated',
            (_) => _notificationsScreen(
              NotificationsListScreenPreviewFixtures.populated(),
            ),
          ),
          CatalogState(
            'Empty',
            (_) => _notificationsScreen(
              NotificationsListScreenPreviewFixtures.emptyInbox(),
            ),
          ),
          CatalogState(
            'Load Failed',
            (_) => _notificationsScreen(
              NotificationsListScreenPreviewFixtures.networkFailure(),
            ),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'offer_kyc_gate',
        screen: 'OfferKycGateScreen',
        states: <CatalogState>[
          CatalogState(
            'Not Submitted',
            (_) => _offerKycGate(const OfferKycGateScreenFakeGateway()),
          ),
          CatalogState(
            'Pending',
            (_) => _offerKycGate(
              const OfferKycGateScreenFakeGateway(status: KycStatus.pending),
            ),
          ),
          CatalogState(
            'Rejected',
            (_) => _offerKycGate(
              const OfferKycGateScreenFakeGateway(status: KycStatus.rejected),
            ),
          ),
          CatalogState(
            'Resubmit Requested',
            (_) => _offerKycGate(
              const OfferKycGateScreenFakeGateway(
                status: KycStatus.resubmitRequested,
              ),
            ),
          ),
          CatalogState(
            'Loading',
            (_) => _offerKycGate(const OfferKycGateScreenPendingGateway()),
          ),
          CatalogState(
            'Status Read Failed',
            (_) => _offerKycGate(const OfferKycGateScreenFailingGateway()),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'offer_kyc_gate',
        screen: 'DeliveryRegisterPromptScreen',
        states: <CatalogState>[
          CatalogState('Default', (_) => _deliveryRegisterPrompt()),
        ],
      ),
      CatalogEntry(
        feature: 'offers',
        screen: 'OfferSubmissionScreen',
        states: <CatalogState>[
          CatalogState('Idle / Empty', (_) => _offerComposerIdle()),
          CatalogState('Submitting', (_) => _offerComposerSubmitting()),
          CatalogState(
            'Validation Errors',
            (_) => _offerComposerValidationErrors(),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'offline_mode',
        screen: 'OfflineBanner',
        states: <CatalogState>[
          CatalogState(
            'Offline (Banner Visible)',
            (_) => _offlineBannerDemo(offline: true),
          ),
          CatalogState(
            'Online (Banner Hidden)',
            (_) => _offlineBannerDemo(offline: false),
          ),
        ],
      ),
    ];
