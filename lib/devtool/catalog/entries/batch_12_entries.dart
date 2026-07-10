import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../core/session/jeeber_kyc_status_gate.dart';
import '../../../features/customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../../../features/earnings/domain/earnings_repository.dart';
import '../../../features/earnings/domain/earnings_summary.dart';
import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/jeeber_home/domain/entities/availability_status.dart';
import '../../../features/jeeber_home/domain/services/availability_gateway.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../../features/kyc/presentation/widgets/kyc_capture_tile.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';
import '../../../features/photo_attachment/domain/photo_attachment.dart';
import '../../../features/rate_app/domain/app_review_launcher.dart';
import '../../../features/shell/shell_screen.dart';
import '../../../features/support/application/support_cubit.dart';
import '../../../features/support/application/support_state.dart';
import '../../../features/support/data/stub_support_repository.dart';
import '../../../features/support/domain/support_repository.dart';
import '../../../features/support/presentation/support_ticket_screen.dart';
import '../catalog_models.dart';

/// Batch 12 — photo_attachment, rate_app, shell, support (DT-04 remainder).
///
/// Every state below passes an explicit LOCAL fake/stub (no live gateway) so
/// the real screen/widget renders its DESIGNED state with NO network, per the
/// batch_00 pattern.
///
/// `shell` and `support` were DELIBERATELY SKIPPED in batch_10 (see its
/// trailing note) for lacking an injection seam. This batch adds MINIMAL,
/// ADDITIVE constructor seams to the product screens they name (all default
/// to `null` → the exact prior behaviour) so they can finally be cataloged;
/// see 'seamsAdded' in the manifest for the touched files.
///
/// `rate_app` is SKIPPED here — see the note just below the list — it has no
/// in-app UI to catalog (JM-064: the OS owns the native store-review sheet).
List<CatalogEntry> get batch12Entries => <CatalogEntry>[
      // ─────────────────────────────────────────────────────────────────────
      // photo_attachment
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'photo_attachment',
        screen: 'KycCaptureTile',
        states: [
          CatalogState('Empty — tap to capture', _photoAttachmentEmpty),
          CatalogState('Captured — thumbnail preview', _photoAttachmentCaptured),
          CatalogState('Processing (compressing)', _photoAttachmentProcessing),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // shell
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'shell',
        screen: 'ShellScreen',
        states: [
          CatalogState(
            'Client role (Requests / Delivery / Profile)',
            _shellClientRole,
          ),
          CatalogState(
            'Jeeber role (Dashboard / Earnings / Profile)',
            _shellJeeberRole,
          ),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // support
      // ─────────────────────────────────────────────────────────────────────
      const CatalogEntry(
        feature: 'support',
        screen: 'SupportTicketScreen',
        states: [
          CatalogState('Empty form', _supportEmpty),
          CatalogState(
            'Prefilled order ref (from dispute link)',
            _supportPrefilledOrder,
          ),
          CatalogState('Submitting', _supportSubmitting),
          CatalogState('Success (confirmation)', _supportSuccess),
          CatalogState('Error (network)', _supportError),
        ],
      ),
    ];

// SKIPPED (DoD #3 — no in-app UI to catalog):
//
//  * `rate_app` (JM-064): per `lib/features/rate_app/domain/app_review_launcher.dart`,
//    "There is **no** in-app rating UI and **no** network call — the OS owns
//    the sheet" (App Store `SKStoreReviewController` / Play In-App Review).
//    The feature is a single fire-and-forget `AppReviewLauncher.requestReview()`
//    call wired to the customer-profile "Rate the app" row
//    (`CustomerProfileScreen`, already cataloged under feature `customer_profile`
//    in batch_02 — see its `reviewLauncher` seam) — there is no screen state a
//    designer would review here beyond that row, which is already visible in
//    the `customer_profile` catalog entry.

// ───────────────────────────────────────────────────────────────────────────
// photo_attachment — KycCaptureTile
// ───────────────────────────────────────────────────────────────────────────
//
// `photo_attachment` (`lib/features/photo_attachment/`) is domain + data only
// (the `PhotoAttachment` model, the `PhotoPickerService` port and its
// `StubPhotoPickerService`) — it owns no presentation/ screen of its own.
// `KycCaptureTile` (kyc/presentation/widgets) is the real, reusable production
// widget that renders a [PhotoAttachment] (used by the ID-front/back/selfie
// steps in KycWizardScreen, already cataloged separately under `kyc`); it is
// the actual UI surface this feature's domain model drives, so it is the
// faithful "screen" to catalog here (same non-`Screen`-suffixed-widget
// precedent as `CancelRequestSheet`/`ProhibitedAcknowledgmentDialog` in
// earlier batches). Hosted in a plain [Scaffold] here (host-only, not a
// product change) since the tile is a small square, not a full page.

PhotoAttachment _samplePhoto() => PhotoAttachment(
      id: 'demo-photo-001',
      bytes: Uint8List.fromList(List<int>.filled(2048, 0xC0)),
      originalSizeBytes: 1 * 1024 * 1024,
      source: PhotoSource.camera,
    );

Widget _photoAttachmentTileHost(Widget tile) => Scaffold(
      body: Center(
        child: SizedBox(
          width: 220,
          height: KycCaptureTile.tileHeight,
          child: tile,
        ),
      ),
    );

Widget _photoAttachmentEmpty(BuildContext _) => _photoAttachmentTileHost(
      KycCaptureTile(
        label: 'ID front',
        photo: null,
        isProcessing: false,
        onTap: () {},
      ),
    );

Widget _photoAttachmentCaptured(BuildContext _) => _photoAttachmentTileHost(
      KycCaptureTile(
        label: 'Selfie',
        photo: _samplePhoto(),
        isProcessing: false,
        onTap: () {},
      ),
    );

Widget _photoAttachmentProcessing(BuildContext _) => _photoAttachmentTileHost(
      KycCaptureTile(
        label: 'ID back',
        photo: null,
        isProcessing: true,
        onTap: () {},
      ),
    );

// ───────────────────────────────────────────────────────────────────────────
// shell — ShellScreen
// ───────────────────────────────────────────────────────────────────────────
//
// ShellScreen composes several role-scoped tabs, each of which resolves its
// own cubit/gateway off the global `sl` (GetIt) with NO prior constructor
// override — previewing it as-is would fire the live gateway from every tab
// mounted by its `IndexedStack` (ALL tabs for the active role build
// immediately, not just the selected one). This batch adds a MINIMAL,
// ADDITIVE constructor seam per collaborator (ShellScreen → each tab,
// forwarded 1:1; every new field defaults to `null`, reproducing the exact
// prior behaviour) so both roles can be previewed locally:
//   * `shell_screen.dart` — new optional fields, forwarded to each tab.
//   * `tabs/home_tab.dart` — new `greetingRepository` field.
//   * `tabs/earnings_tab.dart` — new `repository` / `jeeberId` fields.
//   * `tabs/dashboard_tab.dart` — new `kycStatusGate` / `availabilityGateway`
//     / `requestFeedRepository` / `greetingRepository` fields (threaded to
//     the private `_JeeberHomeHost`).
// `OrdersTab` and `CustomerProfileScreen` already had a `repository` /
// `reviewLauncher` seam; only `ShellScreen` needed to forward it.
//
// `ShellScreen` reads its role from an ancestor `RoleCubit` (app-root-
// provided in the real app) — the entry supplies one directly via
// `RoleCubit(prefs: ..., initialRole: ...)`, which skips the persisted-prefs
// read entirely (no write ever happens either — `setRole` is never called),
// so this is side-effect-free against the shared `SharedPreferences` store.

CustomerProfileViewData get _clientProfileData => DevCustomerProfileFixtures.sample;

const _jeeberProfileData = CustomerProfileViewData(
  name: 'Karim Abou Chakra',
  email: 'karim.abouchakra@example.com',
  avatarUrl: 'https://i.pravatar.cc/150?img=33',
  isVerified: true,
  isJeeber: true,
  rating: 4.6,
  ratingCount: 54,
);

class _FakeCustomerProfileRepository implements CustomerProfileRepository {
  const _FakeCustomerProfileRepository(this._data);
  final CustomerProfileViewData _data;

  @override
  Future<CustomerProfileViewData> fetchProfile() async => _data;
}

class _FakeOrderRepository implements OrderRepository {
  const _FakeOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    return OrderPage(
      items: [
        OrderSummary(
          id: 'off-demo-2001',
          createdAt: DateTime(2026, 6, 20, 14, 30),
          pickupAddress: 'Hamra, Beirut',
          dropoffAddress: 'Achrafieh, Beirut',
          status: OrderRequestStatus.delivered,
          tier: OrderTier.express,
          amountMinor: 1500,
          currency: 'SAR',
        ),
      ],
      page: 1,
      hasMore: false,
    );
  }
}

class _FakeEarningsRepository implements EarningsRepository {
  const _FakeEarningsRepository();

  @override
  Future<EarningsSummary> fetchEarnings({
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    return const EarningsSummary(
      totalCashEarned: 420.0,
      feesPaid: 42.0,
      currency: 'SAR',
      deliveryCount: 18,
      memberSince: '2026-01-15',
    );
  }

  @override
  Future<String> exportEarningsPdf({
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      'devtool/demo-earnings.pdf';
}

class _FakeKycStatusGate implements JeeberKycStatusGate {
  const _FakeKycStatusGate(this.status);

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

Widget _shellClientRole(BuildContext _) => BlocProvider<RoleCubit>.value(
      value: RoleCubit(
        prefs: sl<SharedPreferences>(),
        initialRole: UserRole.client,
      ),
      child: ShellScreen(
        homeTabRepository: InMemoryClientHomeRepository.fromSnapshot(
          DevClientHomeFixtures.snapshot(),
        ),
        homeTabGreetingRepository:
            _FakeCustomerProfileRepository(_clientProfileData),
        ordersRepository: const _FakeOrderRepository(),
        profileRepository: _FakeCustomerProfileRepository(_clientProfileData),
        profileReviewLauncher: const NoopAppReviewLauncher(),
      ),
    );

Widget _shellJeeberRole(BuildContext _) => BlocProvider<RoleCubit>.value(
      value: RoleCubit(
        prefs: sl<SharedPreferences>(),
        initialRole: UserRole.jeeber,
      ),
      child: ShellScreen(
        dashboardKycStatusGate:
            const _FakeKycStatusGate(JeeberKycStatus.approved),
        dashboardAvailabilityGateway: InMemoryAvailabilityGateway(
          initial: AvailabilityStatus.initial.copyWith(
            state: AvailabilityState.online,
          ),
        ),
        dashboardRequestFeedRepository: SeededRequestFeedRepository(
          DevJeeberFeedFixtures.incoming(),
        ),
        dashboardGreetingRepository:
            const _FakeCustomerProfileRepository(_jeeberProfileData),
        earningsRepository: const _FakeEarningsRepository(),
        earningsJeeberId: 'user-jeeber-002',
        profileRepository:
            const _FakeCustomerProfileRepository(_jeeberProfileData),
        profileReviewLauncher: const NoopAppReviewLauncher(),
      ),
    );

// ───────────────────────────────────────────────────────────────────────────
// support — SupportTicketScreen
// ───────────────────────────────────────────────────────────────────────────
//
// The screen unconditionally called `GoRouterState.of(context)` to read the
// optional inbound `extra` — the Dev Tool hosts previews under a bare
// `Navigator` (no `GoRouter` ancestor), so that call threw before the screen
// could render (batch_10's skip reason). `support_ticket_screen.dart` now
// guards that read on `GoRouter.maybeOf(context)` and adds `cubit` /
// `repository` / `initialOrderRef` constructor seams (all additive, default
// `null` → identical behaviour for the real routed call site, which always
// has a `GoRouter` ancestor).

class _SeededSupportCubit extends SupportCubit {
  _SeededSupportCubit(SupportState seed)
      : super(const StubSupportRepository()) {
    emit(seed);
  }
}

Widget _supportEmpty(BuildContext _) =>
    const SupportTicketScreen(repository: StubSupportRepository());

Widget _supportPrefilledOrder(BuildContext _) => const SupportTicketScreen(
      repository: StubSupportRepository(),
      initialOrderRef: 'off-demo-1001',
    );

Widget _supportSubmitting(BuildContext _) => SupportTicketScreen(
      cubit: _SeededSupportCubit(
        const SupportState(
          phase: SupportPhase.submitting,
          category: SupportCategory.delivery,
          body: 'My delivery never arrived.',
        ),
      ),
    );

Widget _supportSuccess(BuildContext _) => SupportTicketScreen(
      cubit: _SeededSupportCubit(
        const SupportState(
          phase: SupportPhase.success,
          category: SupportCategory.delivery,
          body: 'My delivery never arrived.',
          ticketId: 'ticket-demo-9001',
        ),
      ),
    );

Widget _supportError(BuildContext _) => SupportTicketScreen(
      cubit: _SeededSupportCubit(
        const SupportState(
          phase: SupportPhase.error,
          category: SupportCategory.payment,
          body: 'Charged twice for the same delivery.',
          failure: SupportFailure.network,
        ),
      ),
    );
