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
import '../fixtures/delivery_register_prompt_screen_fixtures.dart';
import '../fixtures/offer_kyc_gate_screen_fixtures.dart';

// ─────────────────────────────────────────────────────────────────────────────
// notification_prefs — NotificationPrefsScreen
//
// The screen has no ctor seam of its own: it reads `NotificationPrefsCubit`
// via `context.read` (its `initState` calls `.load()`), so every state below
// wraps it in a `BlocProvider` seeded with a scripted repository. The three
// states below are exactly the sealed `NotificationPrefsState` variants
// (Loading / Loaded / Error) — Loading uses a repo whose `fetch()` never
// resolves so the full-page spinner sticks for the preview.
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// notifications — NotificationsListScreen
//
// The screen already exposes a `repository` ctor seam (falls back to DI, then
// to an empty in-memory repo when GetIt is unconfigured), so each state below
// just injects a scripted `NotificationsRepository` — no BlocProvider wrapping
// needed. States mirror the 4-state machine in notifications_list_state.dart
// (initial/loading collapse into one "loading" preview; loaded splits into
// populated vs its `hasItems == false` empty variant; failed uses the typed
// network failure).
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// offer_kyc_gate — OfferKycGateScreen + DeliveryRegisterPromptScreen
//
// OfferKycGateScreen exposes a `gateway` ctor seam and self-provides its cubit.
// The canned gateways live in `../fixtures/offer_kyc_gate_screen_fixtures.dart`
// (`OfferKycGateScreenFakeGateway` / `…PendingGateway` / `…FailingGateway`),
// shared with the preview section at the bottom of the screen's own file, so
// the catalog state a designer signs off against and the canvas an engineer
// edits against are one set of fixtures rather than two copies free to drift.
// They replaced a local `FakeKycGateway(initial: …)`, which could only ever
// resolve — the LOADING and ERROR phases and the `resubmitRequested` branch of
// `_GateStatusLine` were unreachable from this entry and are now states below.
// Hosting goes through `OfferKycGateScreenPreviewHost` for the same reason the
// register prompt does: all three exits call into go_router, so without a local
// router the state paints and then throws on the first tap. `window: null`
// keeps the real device as the frame.
//
// DeliveryRegisterPromptScreen is fully static in its DATA — no cubit, no
// repository, four fixed ARB strings — but not in its ENVIRONMENT: all three of
// its exits call into go_router (`canPop`/`pop`/`go`/`goNamed`), so this entry
// hosts it through `DeliveryRegisterPromptScreenPreviewHost`, which supplies a
// local router seeded the way production seeds it (stack root, nothing to pop).
// `window: null` keeps the real device as the frame. The same host backs the
// preview section at the bottom of the screen's own file, so the catalog state a
// designer signs off against and the canvas an engineer edits against are one
// set of fixtures rather than two copies free to drift.
// ─────────────────────────────────────────────────────────────────────────────

Widget _offerKycGate(KycGateway gateway) => OfferKycGateScreenPreviewHost(
      screen: OfferKycGateScreen(gateway: gateway),
    );

Widget _deliveryRegisterPrompt() =>
    const DeliveryRegisterPromptScreenPreviewHost(
      screen: DeliveryRegisterPromptScreen(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// offers — OfferSubmissionScreen
//
// The live composer (wired into the router as `jeeber-offer-submission`;
// `lib/features/offer_submission/` is an orphaned duplicate — see SKIPPED
// below). It already takes `repository`/`walletRepository` seams for the idle
// state. To preview `submitting` and the inline validation-error state (both
// OfferFormState branches that render straight off `state`, independent of
// the BlocConsumer *listener* that drives snackbars/sheets) this batch adds a
// minimal additive `cubit` ctor param to OfferSubmissionScreen (seamsAdded) so
// a pre-driven OfferFormCubit can be hosted verbatim via BlocProvider.value.
// ─────────────────────────────────────────────────────────────────────────────

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

/// Never resolves — used so a pre-driven `submitting` mode sticks for the
/// static catalog preview instead of racing to `success`.
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

/// `submit()` validates synchronously and — with valid inputs — emits
/// `submitting` before hitting its first `await` (the never-completing repo
/// call), so the cubit's state already reflects `submitting` by the time this
/// builder returns, with no need to await anything here.
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

/// Same synchronous-completion trick: null price/eta fails client-side
/// validation and returns before any await, leaving `priceError`/`etaError`
/// set on the cubit's state.
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

// ─────────────────────────────────────────────────────────────────────────────
// offline_mode — OfflineBanner
//
// `OfflineBanner` reads `OfflineCubit` via `BlocBuilder` off context, with no
// ctor seam and no BlocProvider of its own, so each state wraps it in a
// `BlocProvider.value` over a cubit driven synchronously into the desired
// `ConnectivityStatus` before the widget is returned. Hosted inside a small
// Scaffold so the MaterialBanner has somewhere to render.
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// SKIPPED: offer_submission (lib/features/offer_submission/) — an orphaned
// duplicate of the `offers` feature's offer-submission screen/cubit. Grepping
// the whole app (router, DI, tests) for `offer_submission` turns up zero
// references to this folder's `OfferSubmissionScreen`/`OfferSubmissionCubit`
// outside itself — it is not routed, not DI-registered, and not exercised by
// any test. The live, wired screen is `features/offers/presentation/
// offer_submission_screen.dart`, cataloged above. Cataloging the dead copy
// would mislead designers into reviewing a screen nobody can ever reach.
// ─────────────────────────────────────────────────────────────────────────────

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
          // The E19 tri-state. `_GateStatusLine` has always had a branch for it
          // ("Resubmit your documents"); nothing on any dev surface reached it
          // until the fixtures moved out of this file.
          CatalogState(
            'Resubmit Requested',
            (_) => _offerKycGate(
              const OfferKycGateScreenFakeGateway(
                status: KycStatus.resubmitRequested,
              ),
            ),
          ),
          // Cold start, held open. Not a spinner: the R-F invariant means the
          // exits and the top-up note are already up and only the optional
          // status line is missing.
          CatalogState(
            'Loading',
            (_) => _offerKycGate(const OfferKycGateScreenPendingGateway()),
          ),
          // `GET /v1/kyc/status` threw. The cubit degrades to "no status line",
          // so this is byte-identical to Not Submitted — which is the point of
          // carrying it as its own state.
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
