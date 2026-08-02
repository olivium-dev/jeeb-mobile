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

    ];


class _FakeDisplayNameRepository implements DisplayNameRepository {
  const _FakeDisplayNameRepository();

  @override
  Future<void> submitDisplayName(String name) async {}
}

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

DisplayNameCubit _savingDisplayNameCubit() {
  final cubit = DisplayNameCubit(repository: const _PendingDisplayNameRepository());
  cubit.submit('Ahmad Khaled');
  return cubit;
}

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
      'Phone Entry — Invalid Number',
      (_) => _registrationScreen(
        RegistrationCubit(otpService: const FakeOtpService())
          ..sendCode(renderedPhone: '123'),
      ),
    ),
    CatalogState(
      'Phone Entry — Sending Code',
      (_) => _registrationScreen(
        RegistrationCubit(otpService: const _PendingOtpService())
          ..sendCode(renderedPhone: '71234567'),
      ),
    ),
  ],
);

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


class _FakeSuperLoginService implements SuperLoginService {
  const _FakeSuperLoginService();

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async =>
      const SuperLoginFailure(SuperLoginError.invalidCredentials);
}

class _PendingSuperLoginService implements SuperLoginService {
  const _PendingSuperLoginService();

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) =>
      Completer<SuperLoginResult>().future;
}

SuperLoginCubit _submittingSuperLoginCubit() {
  final cubit = SuperLoginCubit(
    service: const _PendingSuperLoginService(),
    tokenStore: AuthTokenStore(),
  );
  cubit.submit(userId: 'nour.demo', passcode: '000000');
  return cubit;
}

SuperLoginCubit _erroredSuperLoginCubit() {
  final cubit = SuperLoginCubit(
    service: const _FakeSuperLoginService(),
    tokenStore: AuthTokenStore(),
  );
  cubit.submit(userId: '', passcode: '');
  return cubit;
}

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
      'Idle — Empty',
      (_) => const _SuperLoginSheetHost(),
    ),
    CatalogState(
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

class _PendingSuperLoginDemoUserService implements SuperLoginDemoUserService {
  const _PendingSuperLoginDemoUserService();

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() => Completer<List<SuperLoginDemoUser>>().future;
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
