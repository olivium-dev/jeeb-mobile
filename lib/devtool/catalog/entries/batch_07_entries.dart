import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../features/offers/domain/offer_submission_repository.dart';
import '../../../features/offers/presentation/offer_submission_screen.dart';
import '../../../features/onboarding/presentation/onboarding_screen.dart';
import '../../../features/order_history/application/order_history_cubit.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';
import '../../../features/order_history/presentation/order_history_screen.dart';
import '../../../features/order_summary/data/fake_order_summary_repository.dart';
import '../../../features/order_summary/domain/order_summary.dart' as order_summary;
import '../../../features/order_summary/domain/order_summary_repository.dart';
import '../../../features/order_summary/presentation/order_summary_screen.dart';
import '../../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../../features/otp_handover/domain/otp_handover_result.dart';
import '../../../features/otp_handover/presentation/otp_handover_screen.dart';
import '../../../features/wallet/data/stub_wallet_repository.dart';
import '../catalog_models.dart';

/// Batch 07 — offers, offline_mode, onboarding, order_history, order_summary,
/// otp_handover.
///
/// `offline_mode` is SKIPPED: the feature module only ships an
/// [OfflineCubit]/`OfflineBanner` pair (`lib/features/offline_mode/`) — there
/// is no `*_screen.dart` to catalog (it's an inline banner other screens
/// embed, not a navigable screen of its own).
List<CatalogEntry> get batch07Entries => const <CatalogEntry>[
      CatalogEntry(
        feature: 'offers',
        screen: 'OfferSubmissionScreen',
        states: [
          CatalogState('Composer (idle)', _offerComposerIdle),
        ],
      ),
      CatalogEntry(
        feature: 'onboarding',
        screen: 'OnboardingScreen',
        states: [
          CatalogState('Slide 1 — voice-first intro', _onboardingSlideOne),
        ],
      ),
      CatalogEntry(
        feature: 'order_history',
        screen: 'OrderHistoryScreen',
        states: [
          CatalogState('Active — populated', _orderHistoryPopulated),
          CatalogState('Completed tab — empty', _orderHistoryEmpty),
          CatalogState('Error', _orderHistoryError),
        ],
      ),
      CatalogEntry(
        feature: 'order_summary',
        screen: 'OrderSummaryScreen',
        states: [
          CatalogState('Loaded', _orderSummaryLoaded),
          CatalogState('Not found', _orderSummaryNotFound),
        ],
      ),
      CatalogEntry(
        feature: 'otp_handover',
        screen: 'OtpHandoverScreen',
        states: [
          CatalogState('Client — code displayed', _otpClientReady),
          CatalogState('Jeeber — code entry', _otpJeeberReady),
          CatalogState('Jeeber — wrong code', _otpJeeberWrongCode),
          CatalogState('Client — fetch error', _otpClientError),
          CatalogState('Success — done', _otpSuccess),
        ],
      ),
    ];

// ---------------------------------------------------------------------------
// offers
// ---------------------------------------------------------------------------

/// Never invoked in the catalog preview (the composer starts idle and no
/// interaction script submits it) — present purely to satisfy the required
/// constructor parameter without touching GetIt.
class _FakeOfferSubmissionRepository implements OfferSubmissionRepository {
  const _FakeOfferSubmissionRepository();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    return const OfferSubmissionResult(
      offerId: 'demo-offer-01',
      conversationId: 'demo-convo-01',
    );
  }
}

Widget _offerComposerIdle(BuildContext _) => const OfferSubmissionScreen(
      requestId: 'REQ-1029',
      submissionService: null,
      onWithdrawn: _noop,
      repository: _FakeOfferSubmissionRepository(),
      walletRepository: StubWalletRepository(),
    );

// ---------------------------------------------------------------------------
// onboarding
// ---------------------------------------------------------------------------

/// [OnboardingScreen] reads [OnboardingCubit] / [LocaleCubit] from context,
/// and both cubits need a (local, no-network) [SharedPreferences] instance.
/// `SharedPreferences.getInstance()` is async even against the mock backend,
/// so the builder resolves it once via [FutureBuilder] — no gateway, no
/// GoRouter (the screen's [OnboardingScreen.onComplete] override is passed so
/// it never needs a GoRouter ancestor).
Future<SharedPreferences>? _onboardingPrefsFuture;

Future<SharedPreferences> _onboardingPrefs() {
  return _onboardingPrefsFuture ??= _loadOnboardingPrefs();
}

Future<SharedPreferences> _loadOnboardingPrefs() async {
  // The devtool catalog is a test-shaped local seam (no gateway) — same
  // contract as a widget test using the mock SharedPreferences backend.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SharedPreferences.getInstance();
}

Widget _onboardingSlideOne(BuildContext _) => FutureBuilder<SharedPreferences>(
      future: _onboardingPrefs(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        if (prefs == null) return const SizedBox.shrink();
        return MultiBlocProvider(
          providers: [
            BlocProvider<OnboardingCubit>(
              create: (_) => OnboardingCubit(prefs: prefs),
            ),
            BlocProvider<LocaleCubit>(
              create: (_) => LocaleCubit(prefs: prefs),
            ),
          ],
          child: const OnboardingScreen(onComplete: _noop),
        );
      },
    );

void _noop() {}

// ---------------------------------------------------------------------------
// order_history
// ---------------------------------------------------------------------------

class _FakeOrderRepository implements OrderRepository {
  const _FakeOrderRepository({
    this.items = const [],
    this.failureKind,
  });

  final List<OrderSummary> items;
  final OrderRepositoryErrorKind? failureKind;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    final kind = failureKind;
    if (kind != null) throw OrderRepositoryException(kind);
    return OrderPage(items: items, page: page, hasMore: false);
  }
}

final List<OrderSummary> _demoOrders = [
  OrderSummary(
    id: 'ORD-2041',
    createdAt: DateTime(2026, 6, 30, 14, 20),
    pickupAddress: 'Spinneys, Hamra',
    dropoffAddress: 'Verdun Building 12',
    status: OrderRequestStatus.enRoute,
    tier: OrderTier.express,
    amountMinor: 4250,
    currency: 'USD',
  ),
  OrderSummary(
    id: 'ORD-2038',
    createdAt: DateTime(2026, 6, 28, 9, 5),
    pickupAddress: 'Pharmacy Al Shifa, Achrafieh',
    dropoffAddress: 'Sassine Square',
    status: OrderRequestStatus.pending,
    tier: OrderTier.flash,
    amountMinor: 1800,
    currency: 'USD',
  ),
];

Widget _orderHistoryPopulated(BuildContext _) => BlocProvider<OrderHistoryCubit>(
      create: (_) => OrderHistoryCubit(
        repository: _FakeOrderRepository(items: _demoOrders),
      ),
      child: const OrderHistoryScreen(),
    );

Widget _orderHistoryEmpty(BuildContext _) => BlocProvider<OrderHistoryCubit>(
      create: (_) => OrderHistoryCubit(
        repository: const _FakeOrderRepository(),
      ),
      child: const OrderHistoryScreen(),
    );

Widget _orderHistoryError(BuildContext _) => BlocProvider<OrderHistoryCubit>(
      create: (_) => OrderHistoryCubit(
        repository: const _FakeOrderRepository(
          failureKind: OrderRepositoryErrorKind.network,
        ),
      ),
      child: const OrderHistoryScreen(),
    );

// ---------------------------------------------------------------------------
// order_summary
// ---------------------------------------------------------------------------

Widget _orderSummaryLoaded(BuildContext _) => OrderSummaryScreen(
      deliveryId: 'demo-delivery-01',
      repository: FakeOrderSummaryRepository(
        summary: const order_summary.OrderSummary(
          deliveryId: 'demo-delivery-01',
          requestId: 'demo-delivery-01',
          conversationId: 'demo-convo-01',
          price: 42.5,
          currency: 'USD',
          jeeberName: 'Rami Fakhoury',
          tier: 'express',
          jeeberRating: 4.8,
          jeeberRatingCount: 128,
          etaMinutes: 18,
          itemSummary: 'Pharmacy pickup',
        ),
      ),
    );

Widget _orderSummaryNotFound(BuildContext _) => OrderSummaryScreen(
      deliveryId: 'demo-delivery-02',
      repository: FakeOrderSummaryRepository(
        failure: OrderSummaryFailure.notFound,
      ),
    );

// ---------------------------------------------------------------------------
// otp_handover
// ---------------------------------------------------------------------------

class _FakeOtpHandoverRepository implements OtpHandoverRepository {
  const _FakeOtpHandoverRepository({
    this.code = '4821',
    this.fetchFailure,
    this.submitFailure,
  });

  final String code;
  final OtpHandoverErrorKind? fetchFailure;
  final OtpHandoverErrorKind? submitFailure;

  @override
  Future<String> fetchHandoverCode({required String deliveryId}) async {
    final failure = fetchFailure;
    if (failure != null) throw OtpHandoverException(failure);
    return code;
  }

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async {
    final failure = submitFailure;
    if (failure != null) throw OtpHandoverException(failure);
    return const OtpHandoverResult(success: true);
  }
}

Widget _otpClientReady(BuildContext _) => BlocProvider<OtpHandoverCubit>(
      create: (_) => OtpHandoverCubit(
        repository: const _FakeOtpHandoverRepository(code: '4821'),
        deliveryId: 'demo-delivery-01',
        isClient: true,
      ),
      child: const OtpHandoverScreen(
        deliveryId: 'demo-delivery-01',
        isClient: true,
      ),
    );

Widget _otpJeeberReady(BuildContext _) => BlocProvider<OtpHandoverCubit>(
      create: (_) => OtpHandoverCubit(
        repository: const _FakeOtpHandoverRepository(),
        deliveryId: 'demo-delivery-01',
        isClient: false,
      ),
      child: const OtpHandoverScreen(
        deliveryId: 'demo-delivery-01',
        isClient: false,
      ),
    );

/// Kicks off one failed jeeber submit (local fake, not network) so the
/// designed "wrong code" variant (shake + attempt hint + red instruction) is
/// visible without any interaction script.
Widget _otpJeeberWrongCode(BuildContext _) => BlocProvider<OtpHandoverCubit>(
      create: (_) {
        final cubit = OtpHandoverCubit(
          repository: const _FakeOtpHandoverRepository(
            submitFailure: OtpHandoverErrorKind.invalidOtp,
          ),
          deliveryId: 'demo-delivery-01',
          isClient: false,
        );
        cubit.submitOtp('0000');
        return cubit;
      },
      child: const OtpHandoverScreen(
        deliveryId: 'demo-delivery-01',
        isClient: false,
      ),
    );

Widget _otpClientError(BuildContext _) => BlocProvider<OtpHandoverCubit>(
      create: (_) => OtpHandoverCubit(
        repository: const _FakeOtpHandoverRepository(
          fetchFailure: OtpHandoverErrorKind.network,
        ),
        deliveryId: 'demo-delivery-01',
        isClient: true,
      ),
      child: const OtpHandoverScreen(
        deliveryId: 'demo-delivery-01',
        isClient: true,
      ),
    );

/// Kicks off one successful jeeber submit (local fake) so the celebratory
/// "done" designed state renders without an interaction script.
Widget _otpSuccess(BuildContext _) => BlocProvider<OtpHandoverCubit>(
      create: (_) {
        final cubit = OtpHandoverCubit(
          repository: const _FakeOtpHandoverRepository(),
          deliveryId: 'demo-delivery-01',
          isClient: false,
        );
        cubit.submitOtp('4821');
        return cubit;
      },
      child: const OtpHandoverScreen(
        deliveryId: 'demo-delivery-01',
        isClient: false,
      ),
    );
