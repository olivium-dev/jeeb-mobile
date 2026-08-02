import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../features/profile_name/presentation/display_name_setup_screen.dart';
import '../../../features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import '../../../features/prohibited_acknowledgment/domain/prohibited_item.dart';
import '../../../features/prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart';
import '../../../features/prohibited_item_report/presentation/prohibited_item_report_screen.dart';
import '../../../features/rating/application/mutual_rating_cubit.dart';
import '../../../features/rating/presentation/mutual_rating_screen.dart';
import '../../../features/rating/presentation/rating_screen.dart';
import '../../../features/registration/application/registration_cubit.dart';
import '../../../features/registration/data/super_login_demo_user.dart';
import '../../../features/registration/data/super_login_service.dart';
import '../../../features/registration/presentation/otp_verification_screen.dart';
import '../../../features/registration/presentation/registration_screen.dart';
import '../../../features/registration/presentation/super_login/super_login_cubit.dart';
import '../../../features/registration/presentation/super_login/super_login_picker.dart';
import '../../../features/registration/presentation/super_login/super_login_sheet.dart';
import '../catalog_models.dart';
import '../fixtures/display_name_setup_screen_fixtures.dart';
import '../fixtures/mutual_rating_screen_fixtures.dart';
import '../fixtures/otp_verification_screen_fixtures.dart';
import '../fixtures/prohibited_item_report_screen_fixtures.dart';
import '../fixtures/rating_screen_fixtures.dart';
import '../fixtures/registration_screen_fixtures.dart';

// Batch 09 — profile_name, prohibited_acknowledgment, prohibited_item_report,
// rate_app, rating, registration (DT-04 screen-catalog rework, rebased
// worktree). `rate_app` is SKIPPED (see bottom of file): JM-064 raises the
// native OS store-review sheet with NO in-app UI of its own — there is no
// screen to catalog.
//
// Every builder renders the REAL screen/dialog/sheet with an explicit LOCAL
// fake repository/service — never the DI-resolved production one, since the
// Dev Tool shares the app's real GetIt graph (`Bootstrap.minimal`, see
// `devtool_shell.dart`) and would otherwise hit the live gateway. The Dev
// Tool's root (`DevToolApp`) is a plain `MaterialApp` (no `GoRouter`), so
// every driven state below deliberately stops short of any transition that
// would call `context.go(...)` (which has no Router to resolve against here).

List<CatalogEntry> get batch09Entries => <CatalogEntry>[
      _displayNameSetupScreenEntry,
      _prohibitedAcknowledgmentDialogEntry,
      _prohibitedItemReportScreenEntry,
      _mutualRatingScreenEntry,
      _ratingScreenEntry,
      _registrationScreenEntry,
      _otpVerificationScreenEntry,
      _superLoginSheetEntry,
      _superLoginPickerEntry,

      // rate_app — SKIPPED. `AppReviewLauncher`/`InAppReviewLauncher` (JM-064)
      // is a pure side-channel port that raises the platform's native
      // store-review sheet (`SKStoreReviewController` / Play In-App Review).
      // There is NO in-app rating UI and no screen under
      // `lib/features/rate_app/presentation/` (the directory doesn't even
      // exist — only `domain/` + `data/`) — cataloging it would mean either
      // inventing a screen that doesn't exist or reaching into the
      // `customer_profile` feature's "Rate the app" row, which is out of
      // scope for this batch.
    ];

// ─────────────────────────────────────────────────────────────────────────────
// profile_name — the post-OTP display-name onboarding step. The screen
// already carries `repository`/`refreshSignals` seams for the idle designed
// state; a minimal additive `cubit` seam (this batch, default null, no
// existing call site touched) lets the catalog pre-drive the saving/failure
// states, which the screen has no other way to reach from outside (the
// production `build()` always constructs its own cubit from
// `repository`/`refreshSignals`).
// ─────────────────────────────────────────────────────────────────────────────

// The fakes and the driven cubits moved to
// `../fixtures/display_name_setup_screen_fixtures.dart`, shared verbatim with
// the JEEB PREVIEWS section at the bottom of `display_name_setup_screen.dart`,
// so the catalog state a designer signs off and the canvas state an engineer
// edits cannot drift apart. Same three states, same labels, same rendering.
//
// One thing DID change with the extraction: the failure state used to call
// `submit()` on the cubit before the screen was built and rely on the rejected
// future landing after the mount. That holds inside a synchronous `build()`
// (here) and not under `WidgetTester.pumpWidget`, where the error snackbar
// silently never appeared. `DisplayNameSetupScreenPreviewDriver` fires the
// submit from a post-frame callback instead, so the `saving → failure`
// transition the screen's listener needs is deterministic on both surfaces.

/// The failure state: the screen over a cubit whose PUT is fired one frame
/// after mount and rejects.
Widget _displayNameSetupFailurePreview() {
  final cubit = DisplayNameSetupScreenPreviewFixtures.rejecting();
  return DisplayNameSetupScreenPreviewDriver(
    cubit: cubit,
    child: DisplayNameSetupScreen(onDone: () {}, cubit: cubit),
  );
}

final CatalogEntry _displayNameSetupScreenEntry = CatalogEntry(
  feature: 'profile_name',
  screen: 'DisplayNameSetupScreen',
  states: [
    CatalogState(
      'Idle — Empty',
      (_) => DisplayNameSetupScreen(
        onDone: () {},
        repository: DisplayNameSetupScreenPreviewFixtures.accepting,
      ),
    ),
    CatalogState(
      'Saving',
      (_) => DisplayNameSetupScreen(
        onDone: () {},
        cubit: DisplayNameSetupScreenPreviewFixtures.saving(),
      ),
    ),
    CatalogState(
      'Error — Save Failed',
      (_) => _displayNameSetupFailurePreview(),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// prohibited_acknowledgment — the one-time prohibited-items dialog (T-MOB-021).
// The only public entry point is the `showProhibitedAcknowledgmentDialog`
// function (the dialog widget itself is private), so a small host raises it
// via `showDialog` on the first frame — same "drive on mount" idiom the
// registration OTP screen already uses for its debug seam
// (`_maybeAutoSubmitSeamCode`).
// ─────────────────────────────────────────────────────────────────────────────

const List<ProhibitedItem> _sampleProhibitedItems = [
  ProhibitedItem(
    id: 'p1',
    name: 'Firearms & Ammunition',
    category: 'Weapons',
  ),
  ProhibitedItem(
    id: 'p2',
    name: 'Live Animals',
    category: 'Animals',
  ),
  ProhibitedItem(
    id: 'p3',
    name: 'Unsealed Alcohol',
    category: 'Beverages',
    severity: ProhibitedItemSeverity.warn,
  ),
];

class _FakeProhibitedAckRepository implements ProhibitedAcknowledgmentRepository {
  const _FakeProhibitedAckRepository({this.throwOnFetch = false});

  final bool throwOnFetch;

  @override
  Future<List<ProhibitedItem>> fetchItems() async {
    if (throwOnFetch) throw Exception('mock fetch failure');
    return _sampleProhibitedItems;
  }

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}

/// Never resolves — keeps the dialog on its loading spinner for a stable
/// catalog state.
class _PendingProhibitedAckRepository implements ProhibitedAcknowledgmentRepository {
  const _PendingProhibitedAckRepository();

  @override
  Future<List<ProhibitedItem>> fetchItems() => Completer<List<ProhibitedItem>>().future;

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}

/// Raises [showProhibitedAcknowledgmentDialog] on the first frame against a
/// local [repository] — the dialog is the actual designed state; this host is
/// just the minimal Scaffold underneath it (matching `showDialog`'s real
/// barrier presentation).
class _ProhibitedAckDialogHost extends StatefulWidget {
  const _ProhibitedAckDialogHost({required this.repository});

  final ProhibitedAcknowledgmentRepository repository;

  @override
  State<_ProhibitedAckDialogHost> createState() => _ProhibitedAckDialogHostState();
}

class _ProhibitedAckDialogHostState extends State<_ProhibitedAckDialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showProhibitedAcknowledgmentDialog(context, repository: widget.repository);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
  }
}

final CatalogEntry _prohibitedAcknowledgmentDialogEntry = CatalogEntry(
  feature: 'prohibited_acknowledgment',
  screen: 'ProhibitedAcknowledgmentDialog',
  states: [
    CatalogState(
      'Loading',
      (_) => const _ProhibitedAckDialogHost(
        repository: _PendingProhibitedAckRepository(),
      ),
    ),
    CatalogState(
      'Loaded — Mixed Severities',
      (_) => const _ProhibitedAckDialogHost(
        repository: _FakeProhibitedAckRepository(),
      ),
    ),
    CatalogState(
      'Error — Load Failed',
      (_) => const _ProhibitedAckDialogHost(
        repository: _FakeProhibitedAckRepository(throwOnFetch: true),
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// prohibited_item_report — the free-form "report a prohibited item" form. No
// repository/network of any kind (submit is a local `Navigator.pop(true)`).
// The description field only ever seeds empty in production; the additive
// `initialDescription` seam (this batch) lets the catalog preview the
// CTA-enabled designed state too.
//
// The two designed states below now come from
// `../fixtures/prohibited_item_report_screen_fixtures.dart`, shared verbatim
// with the preview section at the bottom of the screen's own source, so the
// states a designer signs off here and the states an engineer sees in the
// canvas cannot drift apart. Labels and count are unchanged.
// ─────────────────────────────────────────────────────────────────────────────

final CatalogEntry _prohibitedItemReportScreenEntry = CatalogEntry(
  feature: 'prohibited_item_report',
  screen: 'ProhibitedItemReportScreen',
  states: [
    CatalogState(
      'Empty — Report CTA Disabled',
      (_) => ProhibitedItemReportScreen(
        requestId: ProhibitedItemReportScreenPreviewFixtures.requestId,
        initialDescription:
            ProhibitedItemReportScreenPreviewFixtures.empty.description,
      ),
    ),
    CatalogState(
      'Filled — Ready to Report',
      (_) => ProhibitedItemReportScreen(
        requestId: ProhibitedItemReportScreenPreviewFixtures.requestId,
        initialDescription:
            ProhibitedItemReportScreenPreviewFixtures.filled.description,
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// rating — two screens: the canonical mandatory terminal [MutualRatingScreen]
// (JM-034, `/orders/:id/mutual-rate`) and the legacy `/feedback`
// [RatingScreen]. Both are mandatory (no skip/dismiss) and route home
// (`context.go('/')`) on a successful submit — the Dev Tool's root has no
// `GoRouter`, so every driven state below deliberately stays short of that
// transition (inputting / error only, never `submitted`).
// ─────────────────────────────────────────────────────────────────────────────

// Each rating screen owns its own extracted fixture file, shared verbatim with
// the preview section at the bottom of that screen's source, so the states a
// designer signs off here and the states an engineer sees in the canvas cannot
// drift apart:
//
//   * `../fixtures/rating_screen_fixtures.dart` — the legacy `/feedback`
//     `RatingScreen`, which takes a `repository:` seam directly.
//   * `../fixtures/mutual_rating_screen_fixtures.dart` — the mandatory
//     terminal, whose only axis is the cubit handed to it.
//
// Both stand on the same `RatingRepository` contract; they are kept separate
// because the two screens seed through different seams and neither should be
// able to move the other's designed states.

/// [MutualRatingScreen] is driven by its own fixture set,
/// `../fixtures/mutual_rating_screen_fixtures.dart`, shared verbatim with the
/// preview section at the bottom of
/// `lib/features/rating/presentation/mutual_rating_screen.dart`. Each state
/// names a cubit factory there; the screen itself is constructed here, because
/// the cubit is the only axis this screen has.
///
/// The errored state used to be reached by firing an UN-AWAITED `submit()`
/// against a repository bound to reject and letting the cubit settle into
/// `MutualRatingPhase.error` a microtask later. It is now SEEDED into that
/// phase, so the state is on screen from the first frame and does not depend on
/// when the surface happens to sample it. What renders is unchanged.
Widget _mutualRatingScreen(MutualRatingCubit Function() cubit) {
  return BlocProvider<MutualRatingCubit>(
    create: (_) => cubit(),
    child: const MutualRatingScreen(),
  );
}

final CatalogEntry _mutualRatingScreenEntry = CatalogEntry(
  feature: 'rating',
  screen: 'MutualRatingScreen',
  states: [
    CatalogState(
      'Rate — Client Rates Jeeber',
      (_) => _mutualRatingScreen(mutualRatingScreenFreshCubit),
    ),
    CatalogState(
      'Rate — Jeeber Rates Client',
      (_) => _mutualRatingScreen(
        () => mutualRatingScreenFreshCubit(isClient: false),
      ),
    ),
    CatalogState(
      'Error — Submit Failed',
      (_) => _mutualRatingScreen(mutualRatingScreenErrorCubit),
    ),
  ],
);

final CatalogEntry _ratingScreenEntry = CatalogEntry(
  feature: 'rating',
  screen: 'RatingScreen',
  states: [
    CatalogState(
      'Feedback — Client Rates Jeeber',
      (_) => const RatingScreen(
        deliveryId: ratingScreenDeliveryId,
        isClient: true,
        rateeName: ratingScreenJeeberRatee,
        repository: RatingScreenFakeRepository(),
      ),
    ),
    CatalogState(
      'Feedback — Jeeber Rates Client',
      (_) => const RatingScreen(
        deliveryId: ratingScreenDeliveryId,
        isClient: false,
        rateeName: ratingScreenClientRatee,
        repository: RatingScreenFakeRepository(),
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// registration — phone+OTP sign-up (T-mobile-002 / JM-009). `RegistrationScreen`
// already carries `cubit`/`socialAuthCubit`/`onVerified` test seams (built for
// exactly this kind of router-free preview) — no source edits needed.
// `OtpVerificationScreen` has no such seam of its own, but it only ever reads
// its `RegistrationCubit` from context, so `OtpVerificationScreenSeededCubit`
// (in `../fixtures/otp_verification_screen_fixtures.dart` — a dev-only
// subclass, no production seam) synchronously emits the designed step via the
// inherited (protected-to-subclasses) `emit`, which lets every OTP-step state
// render pre-settled instead of only reachable through the async
// `sendCode`/`verifyCode` round-trip. Those fixtures are shared with the
// widget-preview section in the screen's own source file.
// ─────────────────────────────────────────────────────────────────────────────

/// The three designed states below used to be seeded by four private fixtures
/// declared in this file (`_FakeSocialAuthService`, `_FakeSocialAuthTokenStore`,
/// `_fakeSocialAuthCubit`, `_PendingOtpService`) plus three inline phone-number
/// literals. They now come from
/// `lib/devtool/catalog/fixtures/registration_screen_fixtures.dart`, shared
/// verbatim with the preview section at the bottom of
/// `lib/features/registration/presentation/registration_screen.dart`, so the
/// catalog and the canvas cannot drift into two different notions of "the
/// sending state". Nothing about these states changed — same fakes, same
/// numbers, same seeding technique.
Widget _registrationScreen(RegistrationCubit cubit) {
  return RegistrationScreen(
    cubit: cubit,
    socialAuthCubit: registrationScreenFakeSocialAuthCubit(),
    onVerified: () {},
  );
}

final CatalogEntry _registrationScreenEntry = CatalogEntry(
  feature: 'registration',
  screen: 'RegistrationScreen',
  states: [
    CatalogState(
      'Phone Entry — Idle',
      (_) => _registrationScreen(registrationScreenIdleCubit()),
    ),
    CatalogState(
      'Phone Entry — Invalid Number',
      (_) => _registrationScreen(registrationScreenInvalidNumberCubit()),
    ),
    CatalogState(
      'Phone Entry — Sending Code',
      (_) => _registrationScreen(registrationScreenSendingCubit()),
    ),
  ],
);

/// The three designed states below used to be seeded by a private
/// `_SeededRegistrationCubit` declared in this file. They now come from
/// `lib/devtool/catalog/fixtures/otp_verification_screen_fixtures.dart`, shared
/// verbatim with the preview section at the bottom of
/// `lib/features/registration/presentation/otp_verification_screen.dart`, so
/// the catalog and the canvas cannot drift into two different notions of "the
/// wrong-code state". The seeding technique is unchanged — a dev-only
/// `RegistrationCubit` subclass that emits the designed state at construction,
/// no production seam — and so is every number these three states render.
Widget _otpVerificationScreen(RegistrationCubit Function() createCubit) {
  return BlocProvider<RegistrationCubit>(
    create: (_) => createCubit(),
    child: OtpVerificationScreen(onVerified: () {}),
  );
}

final CatalogEntry _otpVerificationScreenEntry = CatalogEntry(
  feature: 'registration',
  screen: 'OtpVerificationScreen',
  states: [
    CatalogState(
      'Code Entry — Ready',
      (_) => _otpVerificationScreen(otpVerificationScreenCountingDownCubit),
    ),
    CatalogState(
      'Code Entry — Wrong Code',
      (_) => _otpVerificationScreen(otpVerificationScreenWrongCodeCubit),
    ),
    CatalogState(
      'Locked Out',
      (_) => _otpVerificationScreen(otpVerificationScreenLockedOutCubit),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// registration/super_login — debug-only credential sheet (FR-P0-4) + demo-user
// picker. Both public entry points already accept an injectable
// cubit/service (`showSuperLoginSheet(cubit:)`, `showSuperLoginPicker(service:)`),
// so no source edits are needed — only a small host raises them via
// `showDialog`-equivalent (`showModalBottomSheet`) on the first frame, mirroring
// the prohibited-acknowledgment dialog host above.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeSuperLoginService implements SuperLoginService {
  const _FakeSuperLoginService();

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async =>
      const SuperLoginFailure(SuperLoginError.invalidCredentials);
}

/// Never resolves — keeps the sheet's submit CTA on its loading spinner.
class _PendingSuperLoginService implements SuperLoginService {
  const _PendingSuperLoginService();

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) =>
      Completer<SuperLoginResult>().future;
}

/// `submit` emits `submitting` synchronously (before its first `await`) once
/// past its empty-field guard, so pairing it with a never-resolving service
/// pins the sheet on its loading state.
SuperLoginCubit _submittingSuperLoginCubit() {
  final cubit = SuperLoginCubit(
    service: const _PendingSuperLoginService(),
    tokenStore: AuthTokenStore(),
  );
  cubit.submit(userId: 'nour.demo', passcode: '000000');
  return cubit;
}

/// Empty credentials hit `submit`'s own client-side guard, which emits
/// `error` synchronously with no service round-trip at all.
SuperLoginCubit _erroredSuperLoginCubit() {
  final cubit = SuperLoginCubit(
    service: const _FakeSuperLoginService(),
    tokenStore: AuthTokenStore(),
  );
  cubit.submit(userId: '', passcode: '');
  return cubit;
}

/// Raises [showSuperLoginSheet] on the first frame — the sheet is the actual
/// designed state; this host is just the minimal Scaffold underneath it.
class _SuperLoginSheetHost extends StatefulWidget {
  const _SuperLoginSheetHost({this.cubit, this.initialUserId, this.initialPasscode});

  final SuperLoginCubit? cubit;
  final String? initialUserId;
  final String? initialPasscode;

  @override
  State<_SuperLoginSheetHost> createState() => _SuperLoginSheetHostState();
}

class _SuperLoginSheetHostState extends State<_SuperLoginSheetHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSuperLoginSheet(
        context,
        cubit: widget.cubit,
        initialUserId: widget.initialUserId,
        initialPasscode: widget.initialPasscode,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
  }
}

final CatalogEntry _superLoginSheetEntry = CatalogEntry(
  feature: 'registration',
  screen: 'SuperLoginSheet',
  states: [
    CatalogState(
      // The sheet's own production defaults already render empty fields —
      // no fake service/cubit needed for this state.
      'Idle — Empty',
      (_) => const _SuperLoginSheetHost(),
    ),
    CatalogState(
      // Mirrors the "Super user login plus" picker hand-off (picked user's
      // id + the dev SuperAdmin passcode arrive pre-filled, submit-ready).
      'Prefilled — Ready to Submit',
      (_) => const _SuperLoginSheetHost(
        initialUserId: 'nour.demo',
        initialPasscode: 'super-admin-dev-passcode',
      ),
    ),
    CatalogState(
      'Submitting',
      (_) => _SuperLoginSheetHost(cubit: _submittingSuperLoginCubit()),
    ),
    CatalogState(
      'Error — Invalid Credentials',
      (_) => _SuperLoginSheetHost(cubit: _erroredSuperLoginCubit()),
    ),
  ],
);

class _FakeSuperLoginDemoUserService implements SuperLoginDemoUserService {
  const _FakeSuperLoginDemoUserService({this.throwOnFetch = false});

  final bool throwOnFetch;

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async {
    if (throwOnFetch) {
      throw const SuperLoginDemoUserException(SuperLoginDemoUserError.network);
    }
    return const [
      SuperLoginDemoUser(
        userId: 'u-1001',
        name: 'Nour Demo',
        role: 'customer',
        availableRoles: ['customer'],
      ),
      SuperLoginDemoUser(
        userId: 'u-1002',
        name: 'Rami Chidiac',
        role: 'driver',
        availableRoles: ['customer', 'driver'],
      ),
      SuperLoginDemoUser(
        userId: 'u-1003',
        name: 'Layla Haddad',
        role: 'customer',
        availableRoles: ['customer'],
      ),
    ];
  }
}

/// Never resolves — keeps the picker on its loading spinner.
class _PendingSuperLoginDemoUserService implements SuperLoginDemoUserService {
  const _PendingSuperLoginDemoUserService();

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() => Completer<List<SuperLoginDemoUser>>().future;
}

/// Raises [showSuperLoginPicker] on the first frame against a local
/// [service].
class _SuperLoginPickerHost extends StatefulWidget {
  const _SuperLoginPickerHost({required this.service});

  final SuperLoginDemoUserService service;

  @override
  State<_SuperLoginPickerHost> createState() => _SuperLoginPickerHostState();
}

class _SuperLoginPickerHostState extends State<_SuperLoginPickerHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSuperLoginPicker(context, service: widget.service);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
  }
}

final CatalogEntry _superLoginPickerEntry = CatalogEntry(
  feature: 'registration',
  screen: 'SuperLoginPicker',
  states: [
    CatalogState(
      'Loading',
      (_) => const _SuperLoginPickerHost(
        service: _PendingSuperLoginDemoUserService(),
      ),
    ),
    CatalogState(
      'Loaded — Roster',
      (_) => const _SuperLoginPickerHost(
        service: _FakeSuperLoginDemoUserService(),
      ),
    ),
    CatalogState(
      'Error — Load Failed',
      (_) => const _SuperLoginPickerHost(
        service: _FakeSuperLoginDemoUserService(throwOnFetch: true),
      ),
    ),
  ],
);
