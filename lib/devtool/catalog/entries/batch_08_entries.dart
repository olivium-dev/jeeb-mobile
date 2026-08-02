import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/onboarding/onboarding_cubit.dart';
import '../../../features/onboarding/presentation/onboarding_screen.dart';
import '../../../features/order_history/application/order_history_cubit.dart';
import '../../../features/order_history/domain/order_repository.dart';
import '../../../features/order_history/domain/order_summary.dart';
import '../../../features/order_history/presentation/order_history_screen.dart';
import '../../../features/order_summary/data/fake_order_summary_repository.dart';
import '../../../features/order_summary/domain/order_summary.dart' as osum;
import '../../../features/order_summary/domain/order_summary_repository.dart';
import '../../../features/order_summary/presentation/order_summary_screen.dart';
import '../../../features/otp_handover/application/otp_handover_cubit.dart';
import '../../../features/otp_handover/domain/handover_code_store.dart';
import '../../../features/otp_handover/domain/otp_handover_repository.dart';
import '../../../features/otp_handover/domain/otp_handover_result.dart';
import '../../../features/otp_handover/presentation/otp_handover_screen.dart';
import '../../../features/password_security/application/password_security_cubit.dart';
import '../../../features/password_security/presentation/password_security_screen.dart';
import '../catalog_models.dart';



class _OnboardingPreview extends StatefulWidget {
  const _OnboardingPreview({required this.locale});

  final Locale locale;

  @override
  State<_OnboardingPreview> createState() => _OnboardingPreviewState();
}

class _OnboardingPreviewState extends State<_OnboardingPreview> {
  OnboardingCubit? _onboarding;
  LocaleCubit? _locale;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarding = OnboardingCubit(prefs: prefs);
    final locale = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => widget.locale,
    );
    if (!mounted) {
      await onboarding.close();
      await locale.close();
      return;
    }
    setState(() {
      _onboarding = onboarding;
      _locale = locale;
    });
  }

  @override
  void dispose() {
    _onboarding?.close();
    _locale?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = _onboarding;
    final locale = _locale;
    if (onboarding == null || locale == null) {
      return const SizedBox.shrink();
    }
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<OnboardingCubit>.value(value: onboarding),
        BlocProvider<LocaleCubit>.value(value: locale),
      ],
      child: OnboardingScreen(onComplete: () {}),
    );
  }
}


class _FakeOrderRepository implements OrderRepository {
  const _FakeOrderRepository({this.page, this.errorKind});

  final OrderPage? page;
  final OrderRepositoryErrorKind? errorKind;

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) async {
    final kind = errorKind;
    if (kind != null) {
      throw OrderRepositoryException(kind);
    }
    return this.page ?? const OrderPage(items: [], page: 1, hasMore: false);
  }
}

class _PendingOrderRepository implements OrderRepository {
  const _PendingOrderRepository();

  @override
  Future<OrderPage> fetchPage({
    required OrderHistoryTab tab,
    required int page,
    required int pageSize,
    OrderDateRange range = const OrderDateRange(),
  }) {
    return Completer<OrderPage>().future;
  }
}

OrderPage _populatedActiveOrders() => OrderPage(
      items: [
        OrderSummary(
          id: 'REQ-1042',
          createdAt: DateTime.utc(2026, 6, 20, 14, 30),
          pickupAddress: 'Hamra, Beirut',
          dropoffAddress: 'Achrafieh, Beirut',
          status: OrderRequestStatus.enRoute,
          tier: OrderTier.express,
          amountMinor: 1250,
          currency: 'USD',
        ),
        OrderSummary(
          id: 'REQ-1038',
          createdAt: DateTime.utc(2026, 6, 19, 9, 5),
          pickupAddress: 'Verdun, Beirut',
          dropoffAddress: 'Downtown, Beirut',
          status: OrderRequestStatus.matched,
          tier: OrderTier.flash,
          amountMinor: null,
          currency: 'USD',
        ),
      ],
      page: 1,
      hasMore: false,
    );

Widget _orderHistoryScreen(OrderRepository repository) {
  return BlocProvider<OrderHistoryCubit>(
    create: (_) => OrderHistoryCubit(repository: repository),
    child: const OrderHistoryScreen(),
  );
}


class _PendingOrderSummaryRepository implements OrderSummaryRepository {
  const _PendingOrderSummaryRepository();

  @override
  Future<osum.OrderSummary> fetchSummary(String deliveryId) {
    return Completer<osum.OrderSummary>().future;
  }
}

osum.OrderSummary _sampleOrderSummary() => const osum.OrderSummary(
      deliveryId: 'DEL-2044',
      requestId: 'REQ-2044',
      conversationId: 'CONV-2044',
      price: 14.5,
      currency: 'USD',
      jeeberName: 'Rami Chidiac',
      tier: 'express',
      jeeberRating: 4.8,
      jeeberRatingCount: 214,
      etaMinutes: 12,
      itemSummary: 'Pharmacy pickup',
    );

Widget _orderSummaryScreen(OrderSummaryRepository repository) {
  return OrderSummaryScreen(
    deliveryId: 'DEL-2044',
    repository: repository,
  );
}


class _FakeOtpHandoverRepository implements OtpHandoverRepository {
  const _FakeOtpHandoverRepository({
    this.fetchResult,
    this.fetchErrorKind,
    this.submitErrorKind,
  });

  final OtpFetchResult? fetchResult;
  final OtpHandoverErrorKind? fetchErrorKind;
  final OtpHandoverErrorKind? submitErrorKind;

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async {
    final kind = fetchErrorKind;
    if (kind != null) {
      throw OtpHandoverException(kind);
    }
    return fetchResult ?? const OtpFetchResult(smsTriggered: true);
  }

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async {
    final kind = submitErrorKind;
    if (kind != null) {
      throw OtpHandoverException(kind);
    }
    return const OtpHandoverResult(success: true);
  }
}

class _InMemoryHandoverCodeStore implements HandoverCodeStore {
  _InMemoryHandoverCodeStore([this._code]);

  String? _code;

  @override
  Future<void> save({required String deliveryId, required String code}) async {
    _code = code;
  }

  @override
  Future<String?> read({required String deliveryId}) async => _code;

  @override
  Future<void> clear({required String deliveryId}) async {
    _code = null;
  }
}

Future<void> _driveEscalate(OtpHandoverCubit cubit) async {
  for (var i = 0; i < 3; i++) {
    await cubit.submitOtp('0000');
  }
}

Widget _otpHandoverScreen({
  required bool isClient,
  required OtpHandoverRepository repository,
  HandoverCodeStore? codeStore,
  void Function(OtpHandoverCubit cubit)? drive,
}) {
  const deliveryId = 'DEL-3091';
  return BlocProvider<OtpHandoverCubit>(
    create: (_) {
      final cubit = OtpHandoverCubit(
        repository: repository,
        deliveryId: deliveryId,
        isClient: isClient,
        codeStore: codeStore,
      );
      drive?.call(cubit);
      return cubit;
    },
    child: OtpHandoverScreen(deliveryId: deliveryId, isClient: isClient),
  );
}


PasswordSecurityCubit _weakPasswordCubit() => PasswordSecurityCubit()
  ..submit(current: 'OldPass1', newPassword: 'weak', confirm: 'weak');

PasswordSecurityCubit _mismatchPasswordCubit() => PasswordSecurityCubit()
  ..submit(
    current: 'OldPass1',
    newPassword: 'NewPass123',
    confirm: 'Mismatch123',
  );


List<CatalogEntry> get batch08Entries => <CatalogEntry>[
      CatalogEntry(
        feature: 'onboarding',
        screen: 'OnboardingScreen',
        states: [
          CatalogState(
            'Slides — EN',
            (_) => const _OnboardingPreview(locale: Locale('en')),
          ),
          CatalogState(
            'Slides — AR',
            (_) => const _OnboardingPreview(locale: Locale('ar')),
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
              _FakeOrderRepository(page: _populatedActiveOrders()),
            ),
          ),
          CatalogState(
            'Active — Empty',
            (_) => _orderHistoryScreen(
              const _FakeOrderRepository(
                page: OrderPage(items: [], page: 1, hasMore: false),
              ),
            ),
          ),
          CatalogState(
            'Active — Error',
            (_) => _orderHistoryScreen(
              const _FakeOrderRepository(
                errorKind: OrderRepositoryErrorKind.server,
              ),
            ),
          ),
          CatalogState(
            'Active — Loading',
            (_) => _orderHistoryScreen(const _PendingOrderRepository()),
          ),
        ],
      ),
      CatalogEntry(
        feature: 'order_summary',
        screen: 'OrderSummaryScreen',
        states: [
          CatalogState(
            'Loaded',
            (_) => _orderSummaryScreen(
              FakeOrderSummaryRepository(summary: _sampleOrderSummary()),
            ),
          ),
          CatalogState(
            'Failed — Not Found',
            (_) => _orderSummaryScreen(
              FakeOrderSummaryRepository(failure: OrderSummaryFailure.notFound),
            ),
          ),
          CatalogState(
            'Loading',
            (_) => _orderSummaryScreen(const _PendingOrderSummaryRepository()),
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
              repository: const _FakeOtpHandoverRepository(),
              codeStore: _InMemoryHandoverCodeStore('4821'),
            ),
          ),
          CatalogState(
            'Client — SMS Fallback',
            (_) => _otpHandoverScreen(
              isClient: true,
              repository: const _FakeOtpHandoverRepository(
                fetchResult: OtpFetchResult(smsTriggered: true),
              ),
            ),
          ),
          CatalogState(
            'Client — Load Error',
            (_) => _otpHandoverScreen(
              isClient: true,
              repository: const _FakeOtpHandoverRepository(
                fetchErrorKind: OtpHandoverErrorKind.network,
              ),
            ),
          ),
          CatalogState(
            'Jeeber — Code Entry',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: const _FakeOtpHandoverRepository(),
            ),
          ),
          CatalogState(
            'Jeeber — Wrong Code',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: const _FakeOtpHandoverRepository(
                submitErrorKind: OtpHandoverErrorKind.invalidOtp,
              ),
              drive: (cubit) => cubit.submitOtp('0000'),
            ),
          ),
          CatalogState(
            'Jeeber — Escalated (Locked)',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: const _FakeOtpHandoverRepository(
                submitErrorKind: OtpHandoverErrorKind.invalidOtp,
              ),
              drive: (cubit) => unawaited(_driveEscalate(cubit)),
            ),
          ),
          CatalogState(
            'Jeeber — Success',
            (_) => _otpHandoverScreen(
              isClient: false,
              repository: const _FakeOtpHandoverRepository(),
              drive: (cubit) => cubit.submitOtp('1234'),
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
            (_) => const PasswordSecurityScreen(cubitFactory: _weakPasswordCubit),
          ),
          CatalogState(
            'Mismatch Error',
            (_) => const PasswordSecurityScreen(cubitFactory: _mismatchPasswordCubit),
          ),
        ],
      ),

    ];
