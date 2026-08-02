import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/onboarding/presentation/onboarding_screen.dart';
import '../../../features/order_history/application/order_history_cubit.dart';
import '../../../features/order_history/domain/order_repository.dart';
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

// Batch 08 — onboarding, order_history, order_summary, otp_handover,
// password_security. `photo_attachment` is SKIPPED (see bottom of file): it is
// a pure domain/data module (PhotoAttachment value object + PhotoPickerService
// + PhotoCompressor) with no screen of its own — it is only consumed by the
// `kyc` and `settings` (profile photo) features, both out of scope here.

// ─────────────────────────────────────────────────────────────────────────────
// onboarding — the three-slide first-launch carousel.
//
// The cubits and the seating moved to
// `../fixtures/onboarding_screen_fixtures.dart`, shared verbatim with the
// preview section at the bottom of `onboarding_screen.dart`, so the designer's
// browser and the engineer's canvas cannot show two different "Slides — AR".
// Same two states, same labels; what changed is underneath:
//
//   * the prefs are in-memory, so tapping Skip no longer persists
//     `app.onboarding.completed` into the real app (suppressing the real
//     walkthrough forever) and tapping العربية no longer changes the app's
//     language on the next cold start;
//   * construction is synchronous, so the `SharedPreferences.getInstance()`
//     seam this entry used to carry — and the blank `SizedBox.shrink()` first
//     frame it produced — is gone;
//   * the locale each state pins is now honoured. Over the device's real prefs
//     `_resolveInitial` read the persisted key BEFORE `deviceLocaleProvider`,
//     so on any device where a language had ever been chosen both states
//     rendered the same chip.
//
// `onComplete` is still a no-op so Get Started / Skip never attempt a
// `goNamed('register')` outside a Router.
// ─────────────────────────────────────────────────────────────────────────────

Widget _onboardingPreview(OnboardingScreenCubitFactory create) =>
    OnboardingScreenPreviewHost(
      create: create,
      child: OnboardingScreen(onComplete: () {}),
    );

// ─────────────────────────────────────────────────────────────────────────────
// order_history — the tabbed Active/Completed/Cancelled order list. Local
// [OrderRepository] fakes drive the populated / empty / error / loading
// designed states; the screen's own `initState` calls `initialLoad()`, so no
// extra driving is needed beyond wiring the cubit.
//
// The three fakes and the populated cast that used to live here now live in
// `../fixtures/order_history_screen_fixtures.dart`, shared with the JEEB
// PREVIEWS section at the bottom of `order_history_screen.dart`. Same rows,
// same four states, same labels — one copy, so the designer's catalog and the
// engineer's canvas cannot drift apart.
// ─────────────────────────────────────────────────────────────────────────────

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
//
// The fake repository and the sample summary that used to live here now live in
// `../fixtures/order_summary_screen_fixtures.dart`, shared verbatim with the
// JEEB PREVIEWS section at the bottom of `order_summary_screen.dart`. Same
// values, same three states, same labels — one copy, so the designer's catalog
// and the engineer's canvas cannot drift apart.
// ─────────────────────────────────────────────────────────────────────────────

Widget _orderSummaryScreen(OrderSummaryScreenDesignedState state) {
  return OrderSummaryScreen(
    deliveryId: state.deliveryId,
    repository: state.repository,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// otp_handover — client code display + Jeeber code entry (T-MOB-018). A local
// [OtpHandoverRepository] + [HandoverCodeStore] fake drives every designed
// mode; the wrong-code / escalate / success states use the SAME "drive the
// cubit once in `create:`" trick the production `OrderSummaryScreen` already
// uses (its `cubitFactory` calls `cubit.load()` before returning).
//
// The fakes, the delivery id and the drives moved to
// `../fixtures/otp_handover_screen_fixtures.dart`, shared verbatim with the JEEB
// PREVIEWS section at the bottom of `otp_handover_screen.dart`. Same seven
// states, same labels, same behaviour — one copy, so the designer's in-app
// browser and the engineer's canvas cannot drift into showing two different
// "Jeeber — Wrong Code".
// ─────────────────────────────────────────────────────────────────────────────

Widget _otpHandoverScreen({
  required bool isClient,
  required OtpHandoverRepository repository,
  HandoverCodeStore? codeStore,
  Future<void> Function(OtpHandoverCubit cubit)? drive,
}) {
  return BlocProvider<OtpHandoverCubit>(
    create: (_) => OtpHandoverScreenPreviewFixtures.cubit(
      isClient: isClient,
      repository: repository,
      codeStore: codeStore,
      drive: drive,
    ),
    child: OtpHandoverScreen(
      deliveryId: OtpHandoverScreenPreviewFixtures.deliveryId,
      isClient: isClient,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// password_security — change-password form (JM-061). No repository at all
// (B-33: local validation only) — `PasswordSecurityCubit.submit` is
// synchronous, so pre-seeding an error state is just calling it once before
// the cubit is returned from `cubitFactory`.
//
// The two seeded cubits moved to
// `../fixtures/password_security_screen_fixtures.dart`, shared verbatim with
// the preview section at the bottom of `password_security_screen.dart`, so the
// designer's browser and the engineer's canvas cannot show two different
// "Mismatch Error". Same states, same labels, same strings fed to `submit` —
// `_weakPasswordCubit` is now `passwordSecurityScreenWeakCubit` and
// `_mismatchPasswordCubit` is `passwordSecurityScreenMismatchCubit`.
// ─────────────────────────────────────────────────────────────────────────────

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

      // photo_attachment — SKIPPED. Pure domain/data module (PhotoAttachment,
      // PhotoPickerService/StubPhotoPickerService, PhotoCompressor); it has no
      // presentation/ screen of its own. Its only UI consumers are
      // `kyc` (KycCaptureTile) and `settings` (profile photo edit), both
      // out of scope for this batch — cataloging it here would mean either
      // inventing a screen that doesn't exist or reaching into another
      // feature's screen, which this batch does not own.
    ];
