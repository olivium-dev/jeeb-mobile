import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../features/auth/social/social_auth_cubit.dart';
import '../../../features/auth/social/social_auth_error.dart';
import '../../../features/auth/social/social_auth_service.dart';
import '../../../features/auth/social/social_auth_token.dart';
import '../../../features/auth/social/social_auth_token_store.dart';
import '../../../features/auth/social/social_provider.dart';
import '../../../features/profile_name/application/display_name_cubit.dart';
import '../../../features/profile_name/domain/display_name_repository.dart';
import '../../../features/profile_name/presentation/display_name_setup_screen.dart';
import '../../../features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import '../../../features/prohibited_acknowledgment/domain/prohibited_item.dart';
import '../../../features/prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart';
import '../../../features/prohibited_item_report/presentation/prohibited_item_report_screen.dart';
import '../../../features/rating/application/mutual_rating_cubit.dart';
import '../../../features/rating/domain/entities/rating_status.dart';
import '../../../features/rating/domain/rating_repository.dart';
import '../../../features/rating/presentation/mutual_rating_screen.dart';
import '../../../features/rating/presentation/rating_screen.dart';
import '../../../features/registration/application/registration_cubit.dart';
import '../../../features/registration/application/registration_state.dart';
import '../../../features/registration/data/fake_otp_service.dart';
import '../../../features/registration/data/super_login_demo_user.dart';
import '../../../features/registration/data/super_login_service.dart';
import '../../../features/registration/domain/otp_service.dart';
import '../../../features/registration/presentation/otp_verification_screen.dart';
import '../../../features/registration/presentation/registration_screen.dart';
import '../../../features/registration/presentation/super_login/super_login_cubit.dart';
import '../../../features/registration/presentation/super_login/super_login_picker.dart';
import '../../../features/registration/presentation/super_login/super_login_sheet.dart';
import '../catalog_models.dart';

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

class _FakeDisplayNameRepository implements DisplayNameRepository {
  const _FakeDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) async {}
}

/// Never resolves — keeps the cubit pinned on `saving` for a stable catalog
/// state (mirrors `_PendingOrderRepository` in batch 08).
class _PendingDisplayNameRepository implements DisplayNameRepository {
  const _PendingDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) => Completer<void>().future;
}

class _ThrowingDisplayNameRepository implements DisplayNameRepository {
  const _ThrowingDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) async {
    throw const DisplayNameRepositoryException(DisplayNameFailure.network);
  }
}

/// `submit` emits `saving` synchronously (before its first `await`), so
/// calling it un-awaited against a repository that never resolves leaves the
/// cubit pinned on the `saving` state by the time this returns.
DisplayNameCubit _savingDisplayNameCubit() {
  final cubit = DisplayNameCubit(repository: const _PendingDisplayNameRepository());
  cubit.submit('Ahmad Khaled');
  return cubit;
}

/// Fires the (rejected) submit and lets the cubit settle into `failure`
/// reactively once the throwing repository's future rejects — the
/// `BlocConsumer` inside the screen picks up that emission live.
DisplayNameCubit _failedDisplayNameCubit() {
  final cubit = DisplayNameCubit(repository: const _ThrowingDisplayNameRepository());
  cubit.submit('Ahmad Khaled');
  return cubit;
}

final CatalogEntry _displayNameSetupScreenEntry = CatalogEntry(
  feature: 'profile_name',
  screen: 'DisplayNameSetupScreen',
  states: [
    CatalogState(
      'Idle — Empty',
      (_) => DisplayNameSetupScreen(
        onDone: () {},
        repository: const _FakeDisplayNameRepository(),
      ),
    ),
    CatalogState(
      'Saving',
      (_) => DisplayNameSetupScreen(
        onDone: () {},
        cubit: _savingDisplayNameCubit(),
      ),
    ),
    CatalogState(
      'Error — Save Failed',
      (_) => DisplayNameSetupScreen(
        onDone: () {},
        cubit: _failedDisplayNameCubit(),
      ),
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
// ─────────────────────────────────────────────────────────────────────────────

final CatalogEntry _prohibitedItemReportScreenEntry = CatalogEntry(
  feature: 'prohibited_item_report',
  screen: 'ProhibitedItemReportScreen',
  states: [
    CatalogState(
      'Empty — Report CTA Disabled',
      (_) => const ProhibitedItemReportScreen(requestId: 'REQ-7742'),
    ),
    CatalogState(
      'Filled — Ready to Report',
      (_) => const ProhibitedItemReportScreen(
        requestId: 'REQ-7742',
        initialDescription:
            'Client asked me to carry an unsealed bottle of liquor.',
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

class _FakeRatingRepository implements RatingRepository {
  const _FakeRatingRepository({this.throwOnSubmit = false});

  final bool throwOnSubmit;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    if (throwOnSubmit) {
      throw const RatingRepositoryException(RatingFailure.network);
    }
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: RatingRevealState.pendingMine,
    );
  }
}

/// Sets a star count (sync) then fires (un-awaited) a submit that is bound to
/// reject — the cubit settles into `MutualRatingPhase.error` reactively,
/// which renders `_ErrorView` (no navigation, safe under a router-less host).
MutualRatingCubit _erroredMutualRatingCubit() {
  final cubit = MutualRatingCubit(
    repository: const _FakeRatingRepository(throwOnSubmit: true),
    deliveryId: 'DEL-4021',
    isClient: true,
  );
  cubit.setStars(4);
  cubit.submit();
  return cubit;
}

Widget _mutualRatingScreen({
  required bool isClient,
  MutualRatingCubit? cubit,
}) {
  return BlocProvider<MutualRatingCubit>(
    create: (_) =>
        cubit ??
        MutualRatingCubit(
          repository: const _FakeRatingRepository(),
          deliveryId: 'DEL-4021',
          isClient: isClient,
        ),
    child: const MutualRatingScreen(),
  );
}

final CatalogEntry _mutualRatingScreenEntry = CatalogEntry(
  feature: 'rating',
  screen: 'MutualRatingScreen',
  states: [
    CatalogState(
      'Rate — Client Rates Jeeber',
      (_) => _mutualRatingScreen(isClient: true),
    ),
    CatalogState(
      'Rate — Jeeber Rates Client',
      (_) => _mutualRatingScreen(isClient: false),
    ),
    CatalogState(
      'Error — Submit Failed',
      (_) => _mutualRatingScreen(
        isClient: true,
        cubit: _erroredMutualRatingCubit(),
      ),
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
        deliveryId: 'DEL-3390',
        isClient: true,
        rateeName: 'Rami Chidiac',
        repository: _FakeRatingRepository(),
      ),
    ),
    CatalogState(
      'Feedback — Jeeber Rates Client',
      (_) => const RatingScreen(
        deliveryId: 'DEL-3390',
        isClient: false,
        rateeName: 'Layla Haddad',
        repository: _FakeRatingRepository(),
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// registration — phone+OTP sign-up (T-mobile-002 / JM-009). `RegistrationScreen`
// already carries `cubit`/`socialAuthCubit`/`onVerified` test seams (built for
// exactly this kind of router-free preview) — no source edits needed.
// `OtpVerificationScreen` has no such seam of its own, but it only ever reads
// its `RegistrationCubit` from context, so a private `_SeededRegistrationCubit`
// subclass (this file only — no production seam) synchronously emits the
// designed step via the inherited (protected-to-subclasses) `emit`, which lets
// every OTP-step state render pre-settled instead of only reachable through
// the async `sendCode`/`verifyCode` round-trip.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeSocialAuthService implements SocialAuthService {
  const _FakeSocialAuthService();

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async =>
      const SocialAuthFailure(SocialAuthError.cancelled);

  @override
  Future<void> signOut() async {}
}

class _FakeSocialAuthTokenStore implements SocialAuthTokenStore {
  const _FakeSocialAuthTokenStore();

  @override
  Future<void> save(SocialAuthSession session) async {}

  @override
  Future<SocialAuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

SocialAuthCubit _fakeSocialAuthCubit() => SocialAuthCubit(
      service: const _FakeSocialAuthService(),
      tokenStore: const _FakeSocialAuthTokenStore(),
    );

/// Never resolves — keeps `RegistrationCubit.sendCode`/`verifyCode` pinned
/// in-flight for a stable "Sending…" catalog state.
class _PendingOtpService implements OtpService {
  const _PendingOtpService();

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) => Completer<OtpSendOutcome>().future;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) =>
      Completer<OtpVerifyOutcome>().future;
}

Widget _registrationScreen(RegistrationCubit cubit) {
  return RegistrationScreen(
    cubit: cubit,
    socialAuthCubit: _fakeSocialAuthCubit(),
    onVerified: () {},
  );
}

final CatalogEntry _registrationScreenEntry = CatalogEntry(
  feature: 'registration',
  screen: 'RegistrationScreen',
  states: [
    CatalogState(
      'Phone Entry — Idle',
      (_) => _registrationScreen(
        RegistrationCubit(otpService: const FakeOtpService(latency: Duration.zero)),
      ),
    ),
    CatalogState(
      // `sendCode` validates and emits `phoneError` synchronously (before any
      // `await`) when the number doesn't parse, so this settles instantly.
      'Phone Entry — Invalid Number',
      (_) => _registrationScreen(
        RegistrationCubit(otpService: const FakeOtpService())
          ..sendCode(renderedPhone: '123'),
      ),
    ),
    CatalogState(
      // `sendCode` emits `isSendingCode: true` synchronously before its first
      // `await`; pairing it with a never-resolving service pins the CTA on
      // its loading spinner.
      'Phone Entry — Sending Code',
      (_) => _registrationScreen(
        RegistrationCubit(otpService: const _PendingOtpService())
          ..sendCode(renderedPhone: '71234567'),
      ),
    ),
  ],
);

/// Catalog-only subclass: lets the preview seed [RegistrationState.step]
/// directly (via the inherited, subclass-visible `emit`) instead of only
/// reaching the OTP step through the async `sendCode` round-trip. No
/// production file is touched — this class lives in the catalog batch only.
class _SeededRegistrationCubit extends RegistrationCubit {
  _SeededRegistrationCubit({required super.otpService});

  void seedOtpReady() {
    emit(state.copyWith(
      step: RegistrationStep.otp,
      phoneInput: '71234567',
      resendSecondsRemaining: 60,
    ));
  }

  void seedWrongCode() {
    emit(state.copyWith(
      step: RegistrationStep.otp,
      phoneInput: '71234567',
      resendSecondsRemaining: 0,
      failedAttempts: 1,
      otpError: RegistrationOtpError.invalid,
    ));
  }

  void seedLockedOut() {
    emit(state.copyWith(
      step: RegistrationStep.lockedOut,
      phoneInput: '71234567',
      failedAttempts: 3,
      lockoutSecondsRemaining: 45,
    ));
  }
}

Widget _otpVerificationScreen(void Function(_SeededRegistrationCubit cubit) seed) {
  final cubit = _SeededRegistrationCubit(otpService: const FakeOtpService());
  seed(cubit);
  return BlocProvider<RegistrationCubit>.value(
    value: cubit,
    child: OtpVerificationScreen(onVerified: () {}),
  );
}

final CatalogEntry _otpVerificationScreenEntry = CatalogEntry(
  feature: 'registration',
  screen: 'OtpVerificationScreen',
  states: [
    CatalogState(
      'Code Entry — Ready',
      (_) => _otpVerificationScreen((c) => c.seedOtpReady()),
    ),
    CatalogState(
      'Code Entry — Wrong Code',
      (_) => _otpVerificationScreen((c) => c.seedWrongCode()),
    ),
    CatalogState(
      'Locked Out',
      (_) => _otpVerificationScreen((c) => c.seedLockedOut()),
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
