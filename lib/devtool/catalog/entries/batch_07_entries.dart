import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/notification_prefs/application/notification_prefs_cubit.dart';
import '../../../features/notification_prefs/domain/notification_prefs_model.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';
import '../../../features/notification_prefs/presentation/notification_prefs_screen.dart';
import '../../../features/notifications/domain/notifications_repository.dart';
import '../../../features/notifications/presentation/notifications_list_screen.dart';
import '../../../features/offer_kyc_gate/presentation/delivery_register_prompt_screen.dart';
import '../../../features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import '../../../features/offers/application/offer_submission_cubit.dart';
import '../../../features/offers/domain/offer_submission_repository.dart';
import '../../../features/offers/presentation/offer_submission_screen.dart';
import '../../../features/offline_mode/application/offline_cubit.dart';
import '../../../features/offline_mode/presentation/offline_banner.dart';
import '../../../features/wallet/domain/wallet_repository.dart';
import '../catalog_models.dart';


class _FakeNotificationPrefsRepository implements NotificationPrefsRepository {
  const _FakeNotificationPrefsRepository(this._prefs);

  final NotificationPrefs _prefs;

  @override
  Future<NotificationPrefs> fetch() async => _prefs;

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      _prefs.copyWith(categories: categories);
}

class _NeverLoadingNotificationPrefsRepository
    implements NotificationPrefsRepository {
  const _NeverLoadingNotificationPrefsRepository();

  @override
  Future<NotificationPrefs> fetch() => Completer<NotificationPrefs>().future;

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) =>
      Completer<NotificationPrefs>().future;
}

class _FailingNotificationPrefsRepository implements NotificationPrefsRepository {
  const _FailingNotificationPrefsRepository();

  @override
  Future<NotificationPrefs> fetch() async =>
      throw const NotificationPrefsRepositoryException(
        NotificationPrefsFailure.network,
      );

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      throw const NotificationPrefsRepositoryException(
        NotificationPrefsFailure.network,
      );
}

const NotificationPrefs _loadedPrefs = NotificationPrefs(
  categories: NotificationCategoryPrefs(
    offers: true,
    orderStatus: true,
    wallet: false,
    marketing: false,
  ),
);

Widget _notifPrefsScreen(NotificationPrefsRepository repository) {
  return BlocProvider<NotificationPrefsCubit>(
    create: (_) => NotificationPrefsCubit(repository: repository),
    child: const NotificationPrefsScreen(),
  );
}


class _FakeNotificationsRepository implements NotificationsRepository {
  const _FakeNotificationsRepository(this._items);

  final List<NotificationItem> _items;

  @override
  Future<List<NotificationItem>> fetchNotifications() async => _items;

  @override
  Future<void> markRead(String id) async {}
}

class _NeverLoadingNotificationsRepository implements NotificationsRepository {
  const _NeverLoadingNotificationsRepository();

  @override
  Future<List<NotificationItem>> fetchNotifications() =>
      Completer<List<NotificationItem>>().future;

  @override
  Future<void> markRead(String id) async {}
}

class _FailingNotificationsRepository implements NotificationsRepository {
  const _FailingNotificationsRepository();

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      throw const NotificationsRepositoryException(NotificationsFailure.network);

  @override
  Future<void> markRead(String id) async {}
}

const List<NotificationItem> _sampleNotifications = <NotificationItem>[
  NotificationItem(
    id: 'n-1',
    kind: NotificationKind.offer,
    title: 'New offer received',
    body: 'A jeeber offered to deliver your package for 12.50 USD',
    timestamp: '2026-07-05T10:00:00Z',
    read: false,
  ),
  NotificationItem(
    id: 'n-2',
    kind: NotificationKind.status,
    title: 'Order picked up',
    body: 'Your order is on its way to Verdun, Beirut',
    timestamp: '2026-07-05T09:30:00Z',
    read: true,
    ref: 'conv-1',
  ),
  NotificationItem(
    id: 'n-3',
    kind: NotificationKind.lowBalance,
    title: 'Low wallet balance',
    body: 'Top up to keep bidding on requests',
    timestamp: '2026-07-04T08:00:00Z',
    read: false,
  ),
];

Widget _notificationsScreen(NotificationsRepository repository) =>
    NotificationsListScreen(repository: repository);


Widget _offerKycGate(KycStatus status) => OfferKycGateScreen(
      gateway: FakeKycGateway(initial: KycSubmission(status: status)),
    );


class _NoopOfferRepo implements OfferSubmissionRepository {
  const _NoopOfferRepo();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      const OfferSubmissionResult(offerId: 'offer-1', conversationId: 'conv-1');
}

class _NeverCompletingOfferRepo implements OfferSubmissionRepository {
  const _NeverCompletingOfferRepo();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) =>
      Completer<OfferSubmissionResult>().future;
}

class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository(this._balance);

  final WalletBalance _balance;

  @override
  Future<WalletBalance> fetchBalance() async => _balance;
}

const WalletBalance _composerWallet = WalletBalance(
  availableBalance: 25.00,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 3.00,
  giftCredit: 10.00,
  currency: 'USD',
);

Widget _offerComposerIdle() => const OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: Object(),
      onWithdrawn: _noop,
      repository: _NoopOfferRepo(),
      walletRepository: _FakeWalletRepository(_composerWallet),
    );

Widget _offerComposerSubmitting() {
  final cubit = OfferFormCubit(repository: const _NeverCompletingOfferRepo())
    ..submit(requestId: 'req-1', priceUsd: 15.0, etaMinutes: 20);
  return OfferSubmissionScreen(
    requestId: 'req-1',
    submissionService: const Object(),
    onWithdrawn: _noop,
    walletRepository: const _FakeWalletRepository(_composerWallet),
    cubit: cubit,
  );
}

Widget _offerComposerValidationErrors() {
  final cubit = OfferFormCubit(repository: const _NoopOfferRepo())
    ..submit(requestId: 'req-1', priceUsd: null, etaMinutes: null);
  return OfferSubmissionScreen(
    requestId: 'req-1',
    submissionService: const Object(),
    onWithdrawn: _noop,
    walletRepository: const _FakeWalletRepository(_composerWallet),
    cubit: cubit,
  );
}

void _noop() {}


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
              const _NeverLoadingNotificationPrefsRepository(),
            ),
          ),
          CatalogState(
            'Loaded',
            (_) => _notifPrefsScreen(
              const _FakeNotificationPrefsRepository(_loadedPrefs),
            ),
          ),
          CatalogState(
            'Load Error',
            (_) => _notifPrefsScreen(
              const _FailingNotificationPrefsRepository(),
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
              const _NeverLoadingNotificationsRepository(),
            ),
          ),
          CatalogState(
            'Populated',
            (_) => _notificationsScreen(
              const _FakeNotificationsRepository(_sampleNotifications),
            ),
          ),
          CatalogState(
            'Empty',
            (_) => _notificationsScreen(
              const _FakeNotificationsRepository(<NotificationItem>[]),
            ),
          ),
          CatalogState(
            'Load Failed',
            (_) => _notificationsScreen(
              const _FailingNotificationsRepository(),
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
            (_) => _offerKycGate(KycStatus.notSubmitted),
          ),
          CatalogState('Pending', (_) => _offerKycGate(KycStatus.pending)),
          CatalogState('Rejected', (_) => _offerKycGate(KycStatus.rejected)),
        ],
      ),
      CatalogEntry(
        feature: 'offer_kyc_gate',
        screen: 'DeliveryRegisterPromptScreen',
        states: <CatalogState>[
          CatalogState('Default', (_) => const DeliveryRegisterPromptScreen()),
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
