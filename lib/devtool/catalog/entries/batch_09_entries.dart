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
import '../../../features/registration/application/registration_state.dart';
import '../../../features/registration/data/super_login_demo_user.dart';
import '../../../features/registration/domain/otp_service.dart';
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
import '../fixtures/prohibited_acknowledgment_dialog_fixtures.dart';
import '../fixtures/prohibited_item_report_screen_fixtures.dart';
import '../fixtures/middle_failure_scenarios.dart';
import '../fixtures/rating_screen_fixtures.dart';
import '../fixtures/registration_screen_fixtures.dart';

// Batch 09: profile_name, prohibited_acknowledgment, prohibited_item_report,

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

  // rate_app — SKIPPED (no UI to catalog).
];

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
    CatalogState(
      'Save refused — unauthorized (UX-39)',
      (_) => _displayNameSetupUnauthorizedPreview(),
    ),
  ],
);

Widget _displayNameSetupUnauthorizedPreview() {
  final cubit = DisplayNameSetupScreenPreviewFixtures.unauthorizedRejecting();
  return DisplayNameSetupScreenPreviewDriver(
    cubit: cubit,
    child: DisplayNameSetupScreen(onDone: () {}, cubit: cubit),
  );
}

const List<ProhibitedItem> _sampleProhibitedItems = [
  ProhibitedItem(id: 'p1', name: 'Firearms & Ammunition', category: 'Weapons'),
  ProhibitedItem(id: 'p2', name: 'Live Animals', category: 'Animals'),
  ProhibitedItem(
    id: 'p3',
    name: 'Unsealed Alcohol',
    category: 'Beverages',
    severity: ProhibitedItemSeverity.warn,
  ),
];

class _FakeProhibitedAckRepository
    implements ProhibitedAcknowledgmentRepository {
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

class _PendingProhibitedAckRepository
    implements ProhibitedAcknowledgmentRepository {
  const _PendingProhibitedAckRepository();

  @override
  Future<List<ProhibitedItem>> fetchItems() =>
      Completer<List<ProhibitedItem>>().future;

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}

class _ProhibitedAckDialogHost extends StatefulWidget {
  const _ProhibitedAckDialogHost({required this.repository});

  final ProhibitedAcknowledgmentRepository repository;

  @override
  State<_ProhibitedAckDialogHost> createState() =>
      _ProhibitedAckDialogHostState();
}

class _ProhibitedAckDialogHostState extends State<_ProhibitedAckDialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showProhibitedAcknowledgmentDialog(
        context,
        repository: widget.repository,
      );
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
    CatalogState(
      'Error — Acknowledge Failed (server)',
      (_) => ProhibitedAckDialogHost(
        repository: AckFailingProhibitedAckRepository(),
        matches: const <String>['knife'],
        attemptAcknowledgment: true,
      ),
    ),
  ],
);

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
    CatalogState(
      'Photo attached (the CTA is wired now)',
      (_) => catalogAttachPhoto(ProhibitedItemReportScreen(
        requestId: ProhibitedItemReportScreenPreviewFixtures.requestId,
        initialDescription:
            ProhibitedItemReportScreenPreviewFixtures.filled.description,
        photoPicker:
            ProhibitedItemReportScreenPreviewFixtures.attachingPicker(),
      )),
    ),
    CatalogState(
      'Photo permission denied',
      (_) => catalogAttachPhoto(ProhibitedItemReportScreen(
        requestId: ProhibitedItemReportScreenPreviewFixtures.requestId,
        initialDescription:
            ProhibitedItemReportScreenPreviewFixtures.filled.description,
        photoPicker:
            ProhibitedItemReportScreenPreviewFixtures.permissionDeniedPicker(),
      )),
    ),
    CatalogState(
      'Photo unavailable',
      (_) => catalogAttachPhoto(ProhibitedItemReportScreen(
        requestId: ProhibitedItemReportScreenPreviewFixtures.requestId,
        initialDescription:
            ProhibitedItemReportScreenPreviewFixtures.filled.description,
        photoPicker:
            ProhibitedItemReportScreenPreviewFixtures.unavailablePicker(),
      )),
    ),
  ],
);

Widget _mutualRatingScreen(
  MutualRatingCubit Function() cubit, {
  String rateeName = '',
}) {
  return BlocProvider<MutualRatingCubit>(
    create: (_) => cubit(),
    child: MutualRatingScreen(rateeName: rateeName),
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
    // The board frame: named counterpart, 4 stars, two tags lit.
    CatalogState(
      'Rate — Board Frame',
      (_) =>
          _mutualRatingScreen(mutualRatingScreenBoardCubit, rateeName: 'Karim'),
    ),
    CatalogState(
      'Rate — Jeeber Rates Client',
      (_) => _mutualRatingScreen(
        () => mutualRatingScreenFreshCubit(isClient: false),
      ),
    ),
    CatalogState(
      'Submitting — In Flight',
      (_) => _mutualRatingScreen(mutualRatingScreenSubmittingCubit),
    ),
    CatalogState(
      'Error — Submit Failed',
      (_) => _mutualRatingScreen(mutualRatingScreenErrorCubit),
    ),
    CatalogState(
      'Error — Submit Failed (network), the sheet stays open',
      (_) => _mutualRatingScreen(mutualRatingScreenSubmitFailedNetworkCubit),
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
    // The lit frame: amber stars + halo, verdict word, selected chips and the
    // enabled orange CTA — none of it reachable from a state with 0 stars.
    CatalogState(
      'Feedback — Stars Picked',
      (_) => const RatingScreen(
        deliveryId: ratingScreenDeliveryId,
        rateeName: ratingScreenRatedRatee,
        repository: RatingScreenFakeRepository(),
        initialStars: 4,
        initialTags: <String>['punctuality', 'courtesy'],
      ),
    ),
    CatalogState(
      'Feedback — No Name On File',
      (_) => const RatingScreen(
        deliveryId: ratingScreenDeliveryId,
        repository: RatingScreenFakeRepository(),
      ),
    ),
  ],
);

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
    // R7 deleted the Verify pill, so the in-flight verify now speaks from the
    // meta row — it needs its own capture to be reviewable at all.
    CatalogState(
      'Code Entry — Verifying',
      (_) => _otpVerificationScreen(otpVerificationScreenVerifyingCubit),
    ),
    CatalogState(
      'Locked Out',
      (_) => _otpVerificationScreen(otpVerificationScreenLockedOutCubit),
    ),
    CatalogState(
      'OTP — rate limited (server window 45s)',
      (_) => _otpVerificationScreen(
        () => _otpServiceCubit(
          const RegistrationScreenRateLimitedOtpService(),
          resend: true,
        ),
      ),
    ),
    CatalogState(
      'OTP — service unavailable (503, never the network line)',
      (_) => _otpVerificationScreen(
        () => _otpServiceCubit(
          const RegistrationScreenServiceUnavailableOtpService(),
        ),
      ),
    ),
    CatalogState(
      'OTP — verified with no tokens (F5)',
      (_) => _otpVerificationScreen(
        () => _otpServiceCubit(const RegistrationScreenNoTokensOtpService()),
      ),
    ),
  ],
);

/// Parks the cubit on the OTP step over a scripted service, then submits a
/// code so the service's own outcome is what the meta row reports.
RegistrationCubit _otpServiceCubit(OtpService service, {bool resend = false}) {
  final RegistrationCubit cubit = RegistrationScreenSeededCubit(
    otpService: service,
    seed: const RegistrationState(
      step: RegistrationStep.otp,
      phoneInput: otpVerificationScreenPhoneInput,
    ),
  );
  // Retry-After rides the RESEND result; verify-only has no server window.
  // Driving verifyCode under the "server 45s" label staged the wrong scenario.
  unawaited(resend ? cubit.resendCode() : cubit.verifyCode('1234'));
  return cubit;
}

class _FakeSuperLoginService implements SuperLoginService {
  const _FakeSuperLoginService();

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async => const SuperLoginFailure(SuperLoginError.invalidCredentials);
}

class _PendingSuperLoginService implements SuperLoginService {
  const _PendingSuperLoginService();

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) => Completer<SuperLoginResult>().future;
}

// Without an injected cubit the sheet resolves `sl<SuperLoginService>()`, which
// is unregistered outside a booted app and throws in the capture harness.
SuperLoginCubit _idleSuperLoginCubit() => SuperLoginCubit(
  service: const _FakeSuperLoginService(),
  tokenStore: AuthTokenStore(),
);

// submit emits submitting synchronously before first await — never-resolving service pins loading state.
SuperLoginCubit _submittingSuperLoginCubit() {
  final cubit = SuperLoginCubit(
    service: const _PendingSuperLoginService(),
    tokenStore: AuthTokenStore(),
  );
  cubit.submit(userId: 'nour.demo', passcode: '000000');
  return cubit;
}

// Empty credentials trigger submit's guard, emit error synchronously.
SuperLoginCubit _erroredSuperLoginCubit() {
  final cubit = SuperLoginCubit(
    service: const _FakeSuperLoginService(),
    tokenStore: AuthTokenStore(),
  );
  cubit.submit(userId: '', passcode: '');
  return cubit;
}

class _SuperLoginSheetHost extends StatefulWidget {
  const _SuperLoginSheetHost({
    this.cubit,
    this.initialUserId,
    this.initialPasscode,
  });

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
      'Idle — Empty',
      (_) => _SuperLoginSheetHost(cubit: _idleSuperLoginCubit()),
    ),
    CatalogState(
      'Prefilled — Ready to Submit',
      (_) => _SuperLoginSheetHost(
        cubit: _idleSuperLoginCubit(),
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

class _PendingSuperLoginDemoUserService implements SuperLoginDemoUserService {
  const _PendingSuperLoginDemoUserService();

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() =>
      Completer<List<SuperLoginDemoUser>>().future;
}

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
