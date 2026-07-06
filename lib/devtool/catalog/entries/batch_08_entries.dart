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

// Batch 08 — onboarding, order_history, order_summary, otp_handover,
// password_security. `photo_attachment` is SKIPPED (see bottom of file): it is
// a pure domain/data module (PhotoAttachment value object + PhotoPickerService
// + PhotoCompressor) with no screen of its own — it is only consumed by the
// `kyc` and `settings` (profile photo) features, both out of scope here.

// ─────────────────────────────────────────────────────────────────────────────
// onboarding — the three-slide first-launch carousel. OnboardingCubit and
// LocaleCubit both need a real SharedPreferences instance, so this preview
// mirrors the legacy `dev_tools/catalog/groups/auth_first_run_screens.dart`
// async-seam pattern: build the cubits once `SharedPreferences.getInstance()`
// resolves, then provide them. `onComplete` is a no-op so Get Started / Skip
// never attempt a `goNamed('register')` outside a Router.
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// order_history — the tabbed Active/Completed/Cancelled order list. Local
// [OrderRepository] fakes drive the populated / empty / error / loading
// designed states; the screen's own `initState` calls `initialLoad()`, so no
// extra driving is needed beyond wiring the cubit.
// ─────────────────────────────────────────────────────────────────────────────

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

/// Never resolves — keeps the screen pinned on its first-page spinner so
/// "Loading" is a stable, capturable catalog state.
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
          // No usable amount surfaced yet — renders the em-dash, never $0.00.
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

// ─────────────────────────────────────────────────────────────────────────────
// order_summary — the standalone accepted-order summary screen. It already
// carries a `repository` constructor seam (production leaves it null and
// resolves from GetIt), so the catalog just passes a local fake directly —
// no additive seam needed.
// ─────────────────────────────────────────────────────────────────────────────

/// Never resolves — keeps the screen on its centered spinner for a stable
/// "Loading" catalog state.
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

// ─────────────────────────────────────────────────────────────────────────────
// otp_handover — client code display + Jeeber code entry (T-MOB-018). A local
// [OtpHandoverRepository] + [HandoverCodeStore] fake drives every designed
// mode; the wrong-code / escalate / success states use the SAME "drive the
// cubit once in `create:`" trick the production `OrderSummaryScreen` already
// uses (its `cubitFactory` calls `cubit.load()` before returning).
// ─────────────────────────────────────────────────────────────────────────────

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

/// In-memory [HandoverCodeStore] test seam — seeded with [_code] (or empty),
/// mutated in place by the cubit's save/clear calls.
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

/// Drives three sequential wrong-code submits (each awaited so the cubit's
/// re-entry guard sees `ready` again before the next call) to reach the
/// AC4 escalate state.
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

// ─────────────────────────────────────────────────────────────────────────────
// password_security — change-password form (JM-061). No repository at all
// (B-33: local validation only) — `PasswordSecurityCubit.submit` is
// synchronous, so pre-seeding an error state is just calling it once before
// the cubit is returned from `cubitFactory`.
// ─────────────────────────────────────────────────────────────────────────────

PasswordSecurityCubit _weakPasswordCubit() => PasswordSecurityCubit()
  ..submit(current: 'OldPass1', newPassword: 'weak', confirm: 'weak');

PasswordSecurityCubit _mismatchPasswordCubit() => PasswordSecurityCubit()
  ..submit(
    current: 'OldPass1',
    newPassword: 'NewPass123',
    confirm: 'Mismatch123',
  );

// ─────────────────────────────────────────────────────────────────────────────
// Catalog entries
// ─────────────────────────────────────────────────────────────────────────────

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

      // photo_attachment — SKIPPED. Pure domain/data module (PhotoAttachment,
      // PhotoPickerService/StubPhotoPickerService, PhotoCompressor); it has no
      // presentation/ screen of its own. Its only UI consumers are
      // `kyc` (KycCaptureTile) and `settings` (profile photo edit), both
      // out of scope for this batch — cataloging it here would mean either
      // inventing a screen that doesn't exist or reaching into another
      // feature's screen, which this batch does not own.
    ];
