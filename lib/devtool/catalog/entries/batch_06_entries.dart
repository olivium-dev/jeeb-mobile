import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/no_offer_timeout/data/fake_waiting_repository.dart';
import '../../../features/no_offer_timeout/domain/waiting_repository.dart';
import '../../../features/no_offer_timeout/domain/waiting_request.dart';
import '../../../features/no_offer_timeout/presentation/no_offer_timeout_screen.dart';
import '../../../features/notification_prefs/application/notification_prefs_cubit.dart';
import '../../../features/notification_prefs/domain/notification_prefs_model.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';
import '../../../features/notification_prefs/presentation/notification_prefs_screen.dart';
import '../../../features/notifications/domain/notifications_repository.dart';
import '../../../features/notifications/data/empty_notifications_repository.dart';
import '../../../features/notifications/presentation/notifications_list_screen.dart';
import '../../../features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import '../../../features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import '../../../features/offer_submission/presentation/offer_submission_screen.dart';
import '../catalog_models.dart';

/// Batch 06 — mixed_direction, no_offer_timeout, notification_prefs,
/// notifications, offer_kyc_gate, offer_submission.
///
/// `mixed_direction` is SKIPPED: it has no `*_screen.dart` — its only
/// presentation artifact is `MixedDirectionText`, a text-direction-detecting
/// `Text` wrapper widget, not a screen (see manifest `skipped`).
List<CatalogEntry> get batch06Entries => <CatalogEntry>[
      // ── no_offer_timeout ──────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'no_offer_timeout',
        screen: 'NoOfferTimeoutScreen',
        states: [
          CatalogState('Broadcasting (notified)', _waitingBroadcasting),
          CatalogState('No coverage (0 notified)', _waitingNoCoverage),
          CatalogState('Offers arrived', _waitingOffersArrived),
          CatalogState('Error', _waitingError),
        ],
      ),

      // ── notification_prefs ───────────────────────────────────────────────
      const CatalogEntry(
        feature: 'notification_prefs',
        screen: 'NotificationPrefsScreen',
        states: [
          CatalogState('Loaded (defaults)', _notificationPrefsLoaded),
          CatalogState(
            'Loaded (marketing on, wallet off)',
            _notificationPrefsCustomized,
          ),
          CatalogState('Load error', _notificationPrefsError),
        ],
      ),

      // ── notifications ─────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'notifications',
        screen: 'NotificationsListScreen',
        states: [
          CatalogState('Loaded (mixed inbox)', _notificationsLoaded),
          CatalogState('Empty inbox', _notificationsEmpty),
          CatalogState('Error', _notificationsError),
        ],
      ),

      // ── offer_kyc_gate ────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'offer_kyc_gate',
        screen: 'OfferKycGateScreen',
        states: [
          CatalogState('Pending status line', _offerKycGatePending),
          CatalogState('Rejected status line', _offerKycGateRejected),
        ],
      ),
      CatalogEntry(
        feature: 'offer_kyc_gate',
        screen: 'DeliveryRegisterPromptScreen',
        states: [
          CatalogState(
            'Register prompt',
            (_) => const DeliveryRegisterPromptScreen(),
          ),
        ],
      ),

      // ── offer_submission ─────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'offer_submission',
        screen: 'OfferSubmissionScreen',
        states: [
          CatalogState('Empty form', _offerSubmissionEmpty),
        ],
      ),
    ];

// ─────────────────────────── no_offer_timeout ────────────────────────────

Widget _waitingBroadcasting(BuildContext _) => NoOfferTimeoutScreen(
      requestId: 'demo-request-001',
      repository: FakeWaitingRepository(
        seed: WaitingRequest(
          requestId: 'demo-request-001',
          phase: WaitingRequestPhase.broadcasting,
          notifiedCount: 6,
          offerCount: 0,
          broadcastExpiresAt: DateTime.now().add(const Duration(minutes: 4)),
          displayId: 'ORD-501001',
          tier: 'express',
          title: 'Grocery run',
        ),
      ),
    );

Widget _waitingNoCoverage(BuildContext _) => NoOfferTimeoutScreen(
      requestId: 'demo-request-002',
      repository: FakeWaitingRepository(
        seed: WaitingRequest(
          requestId: 'demo-request-002',
          phase: WaitingRequestPhase.broadcasting,
          notifiedCount: 0,
          offerCount: 0,
          broadcastExpiresAt: DateTime.now().add(const Duration(minutes: 2)),
          displayId: 'ORD-501002',
          tier: 'standard',
          title: 'Document pickup',
        ),
      ),
    );

Widget _waitingOffersArrived(BuildContext _) => NoOfferTimeoutScreen(
      requestId: 'demo-request-003',
      repository: FakeWaitingRepository(
        seed: WaitingRequest(
          requestId: 'demo-request-003',
          phase: WaitingRequestPhase.offersArrived,
          notifiedCount: 5,
          offerCount: 3,
          broadcastExpiresAt: DateTime.now().add(const Duration(minutes: 1)),
          displayId: 'ORD-501003',
          tier: 'express',
          title: 'Furniture delivery',
        ),
      ),
    );

Widget _waitingError(BuildContext _) => NoOfferTimeoutScreen(
      requestId: 'demo-request-004',
      repository: FakeWaitingRepository(
        failure: const WaitingException(WaitingFailure.network),
      ),
    );

// ────────────────────────── notification_prefs ───────────────────────────

class _FakeNotificationPrefsRepository implements NotificationPrefsRepository {
  const _FakeNotificationPrefsRepository({
    this.prefs = const NotificationPrefs(),
    this.failing = false,
  });

  final NotificationPrefs prefs;
  final bool failing;

  @override
  Future<NotificationPrefs> fetch() async {
    if (failing) {
      throw const NotificationPrefsRepositoryException(
        NotificationPrefsFailure.network,
      );
    }
    return prefs;
  }

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      prefs.copyWith(categories: categories);
}

Widget _notificationPrefsLoaded(BuildContext _) =>
    BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(
        repository: const _FakeNotificationPrefsRepository(),
      )..load(),
      child: const NotificationPrefsScreen(),
    );

Widget _notificationPrefsCustomized(BuildContext _) =>
    BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(
        repository: const _FakeNotificationPrefsRepository(
          prefs: NotificationPrefs(
            categories: NotificationCategoryPrefs(
              offers: true,
              orderStatus: true,
              wallet: false,
              marketing: true,
            ),
          ),
        ),
      )..load(),
      child: const NotificationPrefsScreen(),
    );

Widget _notificationPrefsError(BuildContext _) =>
    BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(
        repository: const _FakeNotificationPrefsRepository(failing: true),
      )..load(),
      child: const NotificationPrefsScreen(),
    );

// ─────────────────────────────  notifications  ───────────────────────────

class _FakeNotificationsRepository implements NotificationsRepository {
  const _FakeNotificationsRepository({
    this.items = const <NotificationItem>[],
    this.failing = false,
  });

  final List<NotificationItem> items;
  final bool failing;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    if (failing) {
      throw const NotificationsRepositoryException(
        NotificationsFailure.network,
      );
    }
    return items;
  }

  @override
  Future<void> markRead(String id) async {}
}

Widget _notificationsLoaded(BuildContext _) => NotificationsListScreen(
      repository: _FakeNotificationsRepository(
        items: [
          NotificationItem(
            id: 'n-1',
            kind: NotificationKind.offer,
            title: 'New offer received',
            body: 'A Jeeber offered LBP 45,000 for your grocery run.',
            timestamp:
                DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
            read: false,
          ),
          NotificationItem(
            id: 'n-2',
            kind: NotificationKind.lowBalance,
            title: 'Low wallet balance',
            body: 'Your wallet balance is running low.',
            timestamp:
                DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
            read: false,
          ),
          NotificationItem(
            id: 'n-3',
            kind: NotificationKind.kycApproved,
            title: 'KYC approved',
            body: 'You are now approved to send offers.',
            timestamp:
                DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
            read: true,
          ),
        ],
      ),
    );

Widget _notificationsEmpty(BuildContext _) => const NotificationsListScreen(
      repository: EmptyNotificationsRepository(),
    );

Widget _notificationsError(BuildContext _) => const NotificationsListScreen(
      repository: _FakeNotificationsRepository(failing: true),
    );

// ────────────────────────────  offer_kyc_gate  ────────────────────────────

Widget _offerKycGatePending(BuildContext _) => OfferKycGateScreen(
      gateway: FakeKycGateway(decision: KycStatus.pending),
    );

Widget _offerKycGateRejected(BuildContext _) => OfferKycGateScreen(
      gateway: FakeKycGateway(
        decision: KycStatus.rejected,
        rejectionReason: KycRejectionReason.idUnreadable,
      ),
    );

// ───────────────────────────  offer_submission  ──────────────────────────

Widget _offerSubmissionEmpty(BuildContext _) =>
    const OfferSubmissionScreen(requestId: 'demo-request-005');
