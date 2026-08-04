import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/live_tracking/domain/live_tracking_repository.dart';
import '../../../features/onboarding/presentation/onboarding_screen.dart';
import '../../../features/order_history/application/order_history_cubit.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';
import '../../../features/order_history/presentation/order_history_screen.dart';
import '../../../features/order_summary/presentation/order_summary_screen.dart';
import '../../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../../features/otp_handover/domain/handover_code_store.dart';
import '../../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../../features/otp_handover/presentation/otp_handover_screen.dart';
import '../../../features/password_security/presentation/password_security_screen.dart';
import '../catalog_models.dart';
import '../fixtures/onboarding_screen_fixtures.dart';
import '../fixtures/order_history_screen_fixtures.dart';
import '../fixtures/order_summary_screen_fixtures.dart';
import '../fixtures/otp_handover_screen_fixtures.dart';
import '../fixtures/password_security_screen_fixtures.dart';

Widget _onboardingPreview(OnboardingScreenCubitFactory create) =>
    OnboardingScreenPreviewHost(
      create: create,
      child: OnboardingScreen(onComplete: () {}),
    );

Widget _orderHistoryScreen(
  OrderRepository repository, {
  OrderHistoryTab initialTab = OrderHistoryTab.active,
}) {
  return BlocProvider<OrderHistoryCubit>(
    create: (_) => OrderHistoryCubit(repository: repository),
    child: OrderHistoryScreen(initialTab: initialTab),
  );
}

Widget _orderSummaryScreen(OrderSummaryScreenDesignedState state) {
  return OrderSummaryScreen(
    deliveryId: state.deliveryId,
    repository: state.repository,
  );
}

Widget _otpHandoverScreen({
  required bool isClient,
  required OtpHandoverRepository repository,
  HandoverCodeStore? codeStore,
  LiveTrackingRepository? deliveryInfo,
  Future<void> Function(OtpHandoverCubit cubit)? drive,
}) {
  return BlocProvider<OtpHandoverCubit>(
    create: (_) => OtpHandoverScreenPreviewFixtures.cubit(
      isClient: isClient,
      repository: repository,
      codeStore: codeStore,
      deliveryInfo: deliveryInfo,
      drive: drive,
    ),
    child: OtpHandoverScreen(
      deliveryId: OtpHandoverScreenPreviewFixtures.deliveryId,
      isClient: isClient,
    ),
  );
}

List<CatalogEntry> get batch08Entries => <CatalogEntry>[
      CatalogEntry(
        feature: 'onboarding',
        screen: 'OnboardingScreen',
        states: [
          CatalogState(
            'Slides — EN',
            (_) => _onboardingPreview(OnboardingScreenPreviewFixtures.english),
          ),
          CatalogState(
            'Slides — AR',
            (_) => _onboardingPreview(OnboardingScreenPreviewFixtures.arabic),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'order_history',
        screen: 'OrderHistoryScreen',
        states: [
          CatalogState(
            'Active — Populated',
            (_) => _orderHistoryScreen(
              OrderHistoryScreenStaticOrders(
                OrderHistoryScreenOrders.activePopulated,
              ),
            ),
          ),
          CatalogState(
            'Completed — Populated',
            (_) => _orderHistoryScreen(
              OrderHistoryScreenStaticOrders(
                OrderHistoryScreenOrders.completedPopulated,
              ),
              initialTab: OrderHistoryTab.completed,
            ),
          ),
          CatalogState(
            'Cancelled — Expired',
            (_) => _orderHistoryScreen(
              OrderHistoryScreenStaticOrders(
                OrderHistoryScreenOrders.cancelledPopulated,
              ),
              initialTab: OrderHistoryTab.cancelled,
            ),
          ),
          CatalogState(
            'Active — Empty',
            (_) => _orderHistoryScreen(
              const OrderHistoryScreenStaticOrders(
                OrderHistoryScreenOrders.none,
              ),
            ),
          ),
          CatalogState(
            'Active — Error',
            (_) => _orderHistoryScreen(
              const OrderHistoryScreenFailingOrders(
                OrderRepositoryErrorKind.server,
              ),
            ),
          ),
          CatalogState(
            'Active — Loading',
            (_) => _orderHistoryScreen(const OrderHistoryScreenStalledOrders()),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'order_summary',
        screen: 'OrderSummaryScreen',
        states: [
          CatalogState(
            'Loaded',
            (_) => _orderSummaryScreen(OrderSummaryScreenFixtures.loaded),
          ),
          CatalogState(
            'Failed — Not Found',
            (_) => _orderSummaryScreen(OrderSummaryScreenFixtures.notFound),
          ),
          CatalogState(
            'Loading',
            (_) => _orderSummaryScreen(OrderSummaryScreenFixtures.coldRead),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'otp_handover',
        screen: 'OtpHandoverScreen',
        states: [
          CatalogState(
            'Client — Code Ready',
            (_) => _otpHandoverScreen(
              isClient: true,
              repository: OtpHandoverScreenPreviewFixtures.accepting(),
              codeStore: OtpHandoverScreenPreviewFixtures.codeStore(),
            ),
          ),
          CatalogState(
            'Client — SMS Fallback',
            (_) => _otpHandoverScreen(
              isClient: true,
              repository: OtpHandoverScreenPreviewFixtures.accepting(),
            ),
          ),
          CatalogState(
            'Client — Load Error',
            (_) => _otpHandoverScreen(
              isClient: true,
              repository: OtpHandoverScreenPreviewFixtures.failingFetch(),
            ),
          ),
          CatalogState(
            'Jeeber — Code Entry',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: OtpHandoverScreenPreviewFixtures.accepting(),
            ),
          ),
          CatalogState(
            'Jeeber — Wrong Code',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: OtpHandoverScreenPreviewFixtures.rejectingSubmit(),
              drive: OtpHandoverScreenPreviewFixtures.driveWrongCode,
            ),
          ),
          CatalogState(
            'Jeeber — Escalated (Locked)',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: OtpHandoverScreenPreviewFixtures.rejectingSubmit(),
              drive: OtpHandoverScreenPreviewFixtures.driveToEscalation,
            ),
          ),
          CatalogState(
            'Jeeber — Success',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: OtpHandoverScreenPreviewFixtures.accepting(),
              drive: OtpHandoverScreenPreviewFixtures.driveSuccessfulSubmit,
            ),
          ),
          // The R13 board frame: code tiles UNDER the orange arrival banner.
          CatalogState(
            'Client — Code + Arrival Banner',
            (_) => _otpHandoverScreen(
              isClient: true,
              repository: OtpHandoverScreenPreviewFixtures.accepting(),
              codeStore: OtpHandoverScreenPreviewFixtures.codeStore('2144'),
              deliveryInfo: OtpHandoverScreenPreviewFixtures.arrivalAtDoor(),
            ),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'password_security',
        screen: 'PasswordSecurityScreen',
        states: [
          CatalogState(
            'Change Form — Idle',
            (_) => const PasswordSecurityScreen(),
          ),
          CatalogState(
            'Social-Only — Set Password Entry',
            (_) => const PasswordSecurityScreen(hasPassword: false),
          ),
          CatalogState(
            'Strength Error',
            (_) => const PasswordSecurityScreen(
              cubitFactory: passwordSecurityScreenWeakCubit,
            ),
          ),
          CatalogState(
            'Mismatch Error',
            (_) => const PasswordSecurityScreen(
              cubitFactory: passwordSecurityScreenMismatchCubit,
            ),
          ),
        ],
      ),
    ];
