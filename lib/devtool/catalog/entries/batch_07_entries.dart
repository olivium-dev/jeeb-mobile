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
import '../../../features/offers/domain/offer_submission_repository.dart';
import '../../../features/offline_mode/application/offline_cubit.dart';
import '../../../features/offline_mode/presentation/offline_banner.dart';
import '../catalog_models.dart';
import '../../../features/notification_prefs/application/notification_prefs_cubit.dart';
import '../fixtures/delivery_register_prompt_screen_fixtures.dart';
import '../fixtures/notification_prefs_screen_fixtures.dart';
import '../fixtures/notifications_list_screen_fixtures.dart';
import '../fixtures/offer_kyc_gate_screen_fixtures.dart';
import '../fixtures/offer_submission_screen_fixtures.dart';
import '../fixtures/middle_failure_scenarios.dart';

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

/// One rung per gateway refusal, already settled before the first frame.
Widget _offerComposerFailed(ScriptedOfferSubmissionRepository repository) =>
    catalogSubmitOffer(OfferSubmissionScreen(
      requestId: OfferSubmissionScreenPreviewFixtures.validationRequestId,
      submissionService: const Object(),
      onWithdrawn: OfferSubmissionScreenPreviewFixtures.noop,
      walletRepository: repository.failure == OfferSubmissionFailure.insufficientBalance
          ? OfferSubmissionFailureWalletRepository()
          : OfferSubmissionScreenPreviewFixtures.walletRepository,
      repository: CatalogObservedOfferRepository(repository),
    ), repository.failure!);

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
          // No collection lives on this screen, so it has no structural empty;
          // every category off is the nearest reading and the one that proves
          // the OFF track (M3-24).
          CatalogState(
            'All Off',
            (_) => _notifPrefsScreen(
              const NotificationPreferencesScreenFakeRepository(
                prefs: notificationPreferencesScreenAllOffPrefs,
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
          CatalogState(
            'Malformed body — no longer read as "everything on"',
            (_) => _notifPrefsScreen(
              NotificationPreferencesScreenThrowingRepository.malformedBody,
            ),
          ),
          CatalogState(
            'Unauthorized — safe back exit',
            (_) => _notifPrefsScreen(
              NotificationPreferencesScreenThrowingRepository.unauthorized,
            ),
          ),
          CatalogState(
            'Save failed — the toggle reverts, snack carries Retry',
            (_) => BlocProvider<NotificationPrefsCubit>(
              create: (_) => NotificationPreferencesScreenSaveFailureCubit(),
              child: const NotificationPrefsScreen(),
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
          CatalogState(
            'Degraded — showing cached (NOTIF-02)',
            (_) => _notificationsScreen(
              NotificationsListScreenPreviewFixtures.degradedInbox(),
            ),
          ),
          CatalogState(
            'Mark-read failed — the flip rolls back (NOTIF-03)',
            (_) => catalogNotificationFailure(_notificationsScreen(
              NotificationsListScreenPreviewFixtures.markReadFailure(),
            )),
          ),
          CatalogState(
            'Ref-less rows — every tap says it cannot open (NOTIF-04)',
            (_) => catalogNotificationFailure(_notificationsScreen(
              NotificationsListScreenPreviewFixtures.refLessInbox(),
            ), refLess: true),
          ),
          CatalogState(
            'Error — unauthorized (sign-in exit)',
            (_) => _notificationsScreen(
              NotificationsListScreenPreviewFixtures.unauthorizedFailure(),
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
          CatalogState(
            'Status read failed — classified, with retry',
            (_) => _offerKycGate(const OfferKycGateScreenThrowingGateway()),
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
          CatalogState(
            'Duplicate offer — withdraw and re-bid',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.duplicateRepository,
            ),
          ),
          CatalogState(
            'Fee too low — the PRICE slot',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.feeTooLowRepository,
            ),
          ),
          CatalogState(
            'ETA invalid — the ETA slot',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.etaInvalidRepository,
            ),
          ),
          CatalogState(
            'Note too long — the note slot',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.noteTooLongRepository,
            ),
          ),
          CatalogState(
            'Out of range',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.outOfRangeRepository,
            ),
          ),
          CatalogState(
            'Same-role violation',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.sameRoleRepository,
            ),
          ),
          CatalogState(
            'Request not open — terminal',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.requestNotOpenRepository,
            ),
          ),
          CatalogState(
            '402 with figures',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.insufficientRepository,
            ),
          ),
          CatalogState(
            '402 with an EMPTY body — no fabricated zero',
            (_) => _offerComposerFailed(
              OfferSubmissionScreenPreviewFixtures.insufficientUnknownRepository,
            ),
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
