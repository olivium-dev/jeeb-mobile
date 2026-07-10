import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../features/auth/social/social_auth_cubit.dart';
import '../../../features/auth/social/social_auth_error.dart';
import '../../../features/auth/social/social_auth_service.dart';
import '../../../features/auth/social/social_auth_token.dart';
import '../../../features/auth/social/social_auth_token_store.dart';
import '../../../features/auth/social/social_provider.dart';
import '../../../features/registration/application/registration_cubit.dart';
import '../../../features/registration/data/fake_otp_service.dart';
import '../../../features/registration/domain/otp_service.dart';
import '../../../features/registration/presentation/otp_verification_screen.dart';
import '../../../features/registration/presentation/registration_screen.dart';
import '../../../features/request_summary/application/request_summary_cubit.dart';
import '../../../features/request_summary/domain/request_draft.dart';
import '../../../features/request_summary/domain/request_submission_service.dart';
import '../../../features/request_summary/presentation/request_summary_screen.dart';
import '../../../features/request_summary/presentation/request_summary_unavailable_screen.dart';
import '../../../features/request_type/presentation/request_type_screen.dart';
import '../../../features/reviews/data/empty_reviews_repository.dart';
import '../../../features/reviews/data/stub_reviews_repository.dart';
import '../../../features/reviews/domain/reviews_repository.dart';
import '../../../features/reviews/presentation/reviews_list_screen.dart';
import '../../../features/settings/application/settings_cubit.dart';
import '../../../features/settings/data/in_memory_profile_repository.dart';
import '../../../features/settings/domain/account_service.dart';
import '../../../features/settings/domain/profile_repository.dart';
import '../../../features/settings/domain/user_profile.dart';
import '../../../features/settings/presentation/screens/settings_screen.dart';
import '../../../features/settlement/domain/settlement_repository.dart';
import '../../../features/settlement/domain/settlement_statement.dart';
import '../../../features/settlement/presentation/settlement_detail_screen.dart';
import '../../../features/settlement/presentation/settlement_screen.dart';
import '../../../features/tier_selection/cubit/tier_selection_cubit.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/domain/tier.dart';
import '../catalog_models.dart';

/// Batch 09 — registration, request_summary, request_type, reviews, settings,
/// settlement.
List<CatalogEntry> get batch09Entries => const <CatalogEntry>[
      CatalogEntry(
        feature: 'registration',
        screen: 'RegistrationScreen',
        states: [
          CatalogState('Phone entry', _regPhoneEntry),
          CatalogState('Phone number invalid', _regPhoneInvalid),
          CatalogState('Rate limited', _regPhoneRateLimited),
        ],
      ),
      CatalogEntry(
        feature: 'registration',
        screen: 'OtpVerificationScreen',
        states: [
          CatalogState('Code entry', _regOtpEntry),
          CatalogState('Invalid code', _regOtpInvalidCode),
          CatalogState('Locked out', _regOtpLockedOut),
        ],
      ),
      CatalogEntry(
        feature: 'request_summary',
        screen: 'RequestSummaryScreen',
        states: [
          CatalogState('Populated', _requestSummaryPopulated),
          CatalogState('Submit error', _requestSummarySubmitError),
        ],
      ),
      CatalogEntry(
        feature: 'request_summary',
        screen: 'RequestSummaryUnavailableScreen',
        states: [
          CatalogState('Unavailable', _requestSummaryUnavailable),
        ],
      ),
      CatalogEntry(
        feature: 'request_type',
        screen: 'RequestTypeScreen',
        states: [
          CatalogState('Loaded — Flash recommended', _requestTypeLoaded),
          CatalogState('Eco tier selected', _requestTypeEcoSelected),
        ],
      ),
      CatalogEntry(
        feature: 'reviews',
        screen: 'ReviewsListScreen',
        states: [
          CatalogState('Populated', _reviewsPopulated),
          CatalogState('Empty', _reviewsEmpty),
          CatalogState('Error', _reviewsError),
        ],
      ),
      CatalogEntry(
        feature: 'settings',
        screen: 'SettingsScreen',
        states: [
          CatalogState('Profile populated', _settingsProfilePopulated),
          CatalogState(
            'Delete-account pending',
            _settingsDeletionPending,
          ),
        ],
      ),
      CatalogEntry(
        feature: 'settlement',
        screen: 'SettlementScreen',
        states: [
          CatalogState('Ready — statements', _settlementReady),
          CatalogState('Empty', _settlementEmpty),
          CatalogState('Error', _settlementError),
        ],
      ),
      CatalogEntry(
        feature: 'settlement',
        screen: 'SettlementDetailScreen',
        states: [
          CatalogState('Paid breakdown', _settlementDetailPaid),
          CatalogState('Pending breakdown', _settlementDetailPending),
        ],
      ),
    ];

void _noop() {}

// ---------------------------------------------------------------------------
// registration
// ---------------------------------------------------------------------------

/// Debug-only OTP service used across the phone-rate-limited state below —
/// always reports the send as rate-limited (no network).
class _RateLimitedOtpService implements OtpService {
  const _RateLimitedOtpService();

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async =>
      OtpSendOutcome.rateLimited;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async =>
      OtpVerifyOutcome.verified;
}

/// Local, no-network social sign-in stand-in — never actually invoked in the
/// catalog preview (no interaction script taps the social buttons); present
/// purely so [RegistrationScreen] doesn't fall back to its production
/// [SocialAuthCubit] default (which wires a real Dio client + native SDKs).
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

Widget _regPhoneEntry(BuildContext _) => RegistrationScreen(
      cubit: RegistrationCubit(otpService: const FakeOtpService()),
      socialAuthCubit: _fakeSocialAuthCubit(),
      onVerified: _noop,
    );

Widget _regPhoneInvalid(BuildContext _) {
  final cubit = RegistrationCubit(otpService: const FakeOtpService())
    ..phoneChanged('123')
    ..sendCode();
  return RegistrationScreen(
    cubit: cubit,
    socialAuthCubit: _fakeSocialAuthCubit(),
    onVerified: _noop,
  );
}

Widget _regPhoneRateLimited(BuildContext _) {
  final cubit = RegistrationCubit(otpService: const _RateLimitedOtpService())
    ..phoneChanged('71234567')
    ..sendCode();
  return RegistrationScreen(
    cubit: cubit,
    socialAuthCubit: _fakeSocialAuthCubit(),
    onVerified: _noop,
  );
}

Widget _regOtpEntry(BuildContext _) {
  final cubit = RegistrationCubit(otpService: const FakeOtpService())
    ..phoneChanged('71234567');
  return BlocProvider<RegistrationCubit>.value(
    value: cubit,
    child: const OtpVerificationScreen(onVerified: _noop),
  );
}

Widget _regOtpInvalidCode(BuildContext _) {
  final cubit = RegistrationCubit(otpService: const FakeOtpService())
    ..phoneChanged('71234567')
    ..verifyCode('000000');
  return BlocProvider<RegistrationCubit>.value(
    value: cubit,
    child: const OtpVerificationScreen(onVerified: _noop),
  );
}

/// Fires three consecutive wrong codes (the default policy's `maxAttempts`)
/// so the cubit transitions to the lockout banner. Sequenced with real
/// `await`s (not fire-and-forget cascades) because [RegistrationCubit
/// .verifyCode] guards re-entry while a previous call is still in flight.
Future<void> _lockOutOtp(RegistrationCubit cubit) async {
  for (var i = 0; i < 3; i++) {
    await cubit.verifyCode('000000');
  }
}

Widget _regOtpLockedOut(BuildContext _) {
  final cubit = RegistrationCubit(otpService: const FakeOtpService())
    ..phoneChanged('71234567');
  _lockOutOtp(cubit);
  return BlocProvider<RegistrationCubit>.value(
    value: cubit,
    child: const OtpVerificationScreen(onVerified: _noop),
  );
}

// ---------------------------------------------------------------------------
// request_summary
// ---------------------------------------------------------------------------

const RequestDraft _sampleRequestDraft = RequestDraft(
  description:
      'Deliver a sealed envelope of signed contracts to the downtown branch.',
  transcription: 'Please deliver this envelope to the downtown branch by 5pm.',
  photoUrls: ['https://example.com/demo-photo-1.jpg'],
  tierId: 'flash',
  tierName: 'Flash',
  pickupAddress: 'Hamra, Beirut',
  dropoffAddress: 'Downtown, Beirut',
);

class _FakeRequestSubmissionService implements RequestSubmissionService {
  const _FakeRequestSubmissionService();

  @override
  Future<String> submit(RequestDraft draft) async => 'req-demo-001';
}

class _FailingRequestSubmissionService implements RequestSubmissionService {
  const _FailingRequestSubmissionService();

  @override
  Future<String> submit(RequestDraft draft) async {
    throw const RequestSubmissionException(RequestSubmissionFailure.server);
  }
}

Widget _requestSummaryPopulated(BuildContext _) =>
    BlocProvider<RequestSummaryCubit>(
      create: (_) => RequestSummaryCubit(const _FakeRequestSubmissionService())
        ..setDraft(_sampleRequestDraft),
      child: const RequestSummaryScreen(),
    );

Widget _requestSummarySubmitError(BuildContext _) {
  final cubit =
      RequestSummaryCubit(const _FailingRequestSubmissionService())
        ..setDraft(_sampleRequestDraft)
        ..submit();
  return BlocProvider<RequestSummaryCubit>.value(
    value: cubit,
    child: const RequestSummaryScreen(),
  );
}

Widget _requestSummaryUnavailable(BuildContext _) =>
    const RequestSummaryUnavailableScreen();

// ---------------------------------------------------------------------------
// request_type
// ---------------------------------------------------------------------------

Widget _requestTypeLoaded(BuildContext _) => RequestTypeScreen(
      cubit: TierSelectionCubit(repository: const FakeTierRepository())
        ..load(),
    );

Widget _requestTypeEcoSelected(BuildContext _) {
  final cubit = TierSelectionCubit(repository: const FakeTierRepository());
  cubit.load().then((_) => cubit.selectTier(TierId.eco));
  return RequestTypeScreen(cubit: cubit);
}

// ---------------------------------------------------------------------------
// reviews
// ---------------------------------------------------------------------------

class _FailingReviewsRepository implements ReviewsRepository {
  const _FailingReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw const ReviewsRepositoryException(ReviewsFailure.network);
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

Widget _reviewsPopulated(BuildContext _) => const ReviewsListScreen(
      jeeberId: 'user-jeeber-002',
      repository: StubReviewsRepository(),
    );

Widget _reviewsEmpty(BuildContext _) => const ReviewsListScreen(
      jeeberId: 'user-jeeber-002',
      repository: EmptyReviewsRepository(),
    );

Widget _reviewsError(BuildContext _) => const ReviewsListScreen(
      jeeberId: 'user-jeeber-002',
      repository: _FailingReviewsRepository(),
    );

// ---------------------------------------------------------------------------
// settings
// ---------------------------------------------------------------------------

const UserProfile _demoSettingsProfile = UserProfile(
  phoneE164: '+96170123456',
  name: 'Maya Haddad',
);

/// Seeds an [InMemoryProfileRepository] with [profile] so [SettingsCubit
/// .load] resolves to real, populated content instead of the empty default —
/// `save` has no internal `await`, so this completes synchronously before the
/// cubit's own `load()` call reads it back.
ProfileRepository _seededProfileRepository(UserProfile profile) {
  final repo = InMemoryProfileRepository();
  repo.save(profile);
  return repo;
}

/// [SettingsScreen]'s Language section reads a [LocaleCubit] from context
/// (`context.watch`, not an optional read), which needs a local (no-network)
/// [SharedPreferences] instance — mirrors the onboarding catalog entry
/// (`batch_07_entries.dart`).
Future<SharedPreferences>? _settingsPrefsFuture;

Future<SharedPreferences> _settingsPrefs() =>
    _settingsPrefsFuture ??= _loadSettingsPrefs();

Future<SharedPreferences> _loadSettingsPrefs() async {
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  return SharedPreferences.getInstance();
}

Widget _settingsWithCubit(SettingsCubit cubit) => FutureBuilder<SharedPreferences>(
      future: _settingsPrefs(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        if (prefs == null) return const SizedBox.shrink();
        return BlocProvider<LocaleCubit>(
          create: (_) => LocaleCubit(prefs: prefs),
          child: SettingsScreen(cubit: cubit),
        );
      },
    );

Widget _settingsProfilePopulated(BuildContext _) => _settingsWithCubit(
      SettingsCubit(
        profileRepository: _seededProfileRepository(_demoSettingsProfile),
        accountService: const FakeAccountService(),
      )..load(),
    );

Widget _settingsDeletionPending(BuildContext _) => _settingsWithCubit(
      SettingsCubit(
        profileRepository: _seededProfileRepository(_demoSettingsProfile),
        accountService: const FakeAccountService(),
      )
        ..load()
        ..requestAccountDeletion(),
    );

// ---------------------------------------------------------------------------
// settlement
// ---------------------------------------------------------------------------

const SettlementStatement _paidStatement = SettlementStatement(
  id: 'stmt-01',
  weekLabel: 'Jun 23 – Jun 29',
  totalPayout: 245.50,
  currency: 'USD',
  status: SettlementStatus.paid,
  deliveries: [
    SettlementDeliveryLine(
      deliveryId: 'd1',
      date: 'Jun 24',
      tier: 'Flash',
      fare: 40,
      commission: 6,
      net: 34,
      currency: 'USD',
    ),
    SettlementDeliveryLine(
      deliveryId: 'd2',
      date: 'Jun 26',
      tier: 'Standard',
      fare: 30,
      commission: 4.5,
      net: 25.5,
      currency: 'USD',
    ),
  ],
);

const SettlementStatement _pendingStatement = SettlementStatement(
  id: 'stmt-02',
  weekLabel: 'Jun 30 – Jul 6',
  totalPayout: 132.75,
  currency: 'USD',
  status: SettlementStatus.pending,
  deliveries: [],
);

const List<SettlementStatement> _sampleStatements = [
  _paidStatement,
  _pendingStatement,
];

class _FakeSettlementRepository implements SettlementRepository {
  const _FakeSettlementRepository({
    this.statements = const [],
    this.failWith,
  });

  final List<SettlementStatement> statements;
  final SettlementFailure? failWith;

  @override
  Future<List<SettlementStatement>> fetchStatements() async {
    final failure = failWith;
    if (failure != null) throw SettlementException(failure);
    return statements;
  }

  @override
  Future<String> downloadPdf(String statementId) async =>
      '/tmp/demo-statement.pdf';
}

Widget _settlementReady(BuildContext _) => const SettlementScreen(
      repository: _FakeSettlementRepository(statements: _sampleStatements),
    );

Widget _settlementEmpty(BuildContext _) => const SettlementScreen(
      repository: _FakeSettlementRepository(),
    );

Widget _settlementError(BuildContext _) => const SettlementScreen(
      repository:
          _FakeSettlementRepository(failWith: SettlementFailure.network),
    );

Widget _settlementDetailPaid(BuildContext _) =>
    const SettlementDetailScreen(statement: _paidStatement);

Widget _settlementDetailPending(BuildContext _) =>
    const SettlementDetailScreen(statement: _pendingStatement);
