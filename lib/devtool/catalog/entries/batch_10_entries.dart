import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../features/notification_prefs/domain/notification_prefs_model.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';
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
import '../../../features/settings/domain/account_service.dart';
import '../../../features/settings/domain/profile_repository.dart';
import '../../../features/settings/domain/account_session_terminator.dart';
import '../../../features/settings/domain/user_profile.dart';
import '../../../features/settings/presentation/screens/notification_preferences_screen.dart';
import '../../../features/settings/presentation/screens/profile_edit_screen.dart';
import '../../../features/settings/presentation/screens/saved_addresses_screen.dart';
import '../../../features/settings/presentation/screens/settings_screen.dart';
import '../../../features/settings/presentation/widgets/logout_delete_confirm_sheet.dart';
import '../../../features/settlement/domain/settlement_repository.dart';
import '../../../features/settlement/domain/settlement_statement.dart';
import '../../../features/settlement/presentation/settlement_detail_screen.dart';
import '../../../features/settlement/presentation/settlement_screen.dart';
import '../../../features/tier_selection/cubit/tier_selection_cubit.dart';
import '../../../features/tier_selection/data/tier_repository.dart';
import '../../../features/tier_selection/domain/tier.dart';
import '../catalog_models.dart';
import '../tier_catalog_fixture.dart';



class _FakeRequestSubmissionService implements RequestSubmissionService {
  const _FakeRequestSubmissionService({this.failure, this.pending = false});

  final RequestSubmissionFailure? failure;

  final bool pending;

  @override
  Future<String> submit(RequestDraft draft) {
    if (pending) return Completer<String>().future;
    final f = failure;
    if (f != null) return Future<String>.error(RequestSubmissionException(f));
    return Future<String>.value('REQ-9001');
  }
}

RequestDraft _sampleRequestDraft() => const RequestDraft(
  description: 'Pick up my prescription from Pharmacie Beshara.',
  transcription: 'Please pick up my prescription and bring it home.',
  photoUrls: ['https://example.com/photo1.jpg'],
  tierId: 'express',
  tierName: 'Express',
  pickupAddress: 'Pharmacie Beshara, Hamra, Beirut',
  dropoffAddress: 'Achrafieh, Beirut',
  recipientPhone: '+96170123456',
);

Widget _requestSummaryScreen(
  RequestSubmissionService service, {
  bool drive = false,
}) {
  return BlocProvider<RequestSummaryCubit>(
    create: (_) {
      final cubit = RequestSummaryCubit(service)
        ..setDraft(_sampleRequestDraft());
      if (drive) unawaited(cubit.submit());
      return cubit;
    },
    child: const RequestSummaryScreen(),
  );
}


class _PendingTierRepository implements TierRepository {
  const _PendingTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

TierSelectionCubit _selectedTierCubit(TierId select) {
  final cubit = TierSelectionCubit(repository: const DevtoolTierRepository());
  unawaited(cubit.load().then((_) => cubit.selectTier(select)));
  return cubit;
}


const String _reviewsJeeberId = 'jeeber-042';

class _PendingReviewsRepository implements ReviewsRepository {
  const _PendingReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) {
    return Completer<ReviewsPage>().future;
  }

  @override
  Future<void> reportReview(String reviewId) => Completer<void>().future;
}

class _FailingReviewsRepository implements ReviewsRepository {
  const _FailingReviewsRepository(this.failure);

  final ReviewsFailure failure;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ReviewsRepositoryException(failure);
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

class _ColdStartReviewsRepository implements ReviewsRepository {
  const _ColdStartReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ReviewsPage(
      reviews: [
        ReviewItem(
          id: 'review-101',
          reviewerFirstName: 'Nour',
          score: 5,
          timestamp: '2026-06-30T10:00:00.000Z',
          body: 'Great first delivery!',
        ),
      ],
      page: 1,
      totalPages: 1,
      coldStart: true,
      reviewCount: 1,
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}


class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository([this._initial]);

  UserProfile? _initial;

  @override
  Future<UserProfile?> load() async => _initial;

  @override
  Future<void> save(UserProfile profile) async {
    _initial = profile;
  }

  @override
  Future<void> clear() async {
    _initial = const UserProfile.empty();
  }
}

class _FakeAccountService implements AccountService {
  const _FakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async =>
      AccountActionOutcome.success;

  @override
  Future<AccountActionOutcome> signOut() async => AccountActionOutcome.success;
}

UserProfile _sampleProfile() =>
    const UserProfile(phoneE164: '+96170123456', name: 'Maya Haddad');

SettingsCubit _settingsCubit({
  UserProfile? profile,
  bool driveDeletion = false,
}) {
  final cubit = SettingsCubit(
    profileRepository: _FakeProfileRepository(profile ?? _sampleProfile()),
    accountService: const _FakeAccountService(),
  );
  final loaded = cubit.load();
  if (driveDeletion) {
    unawaited(loaded.then((_) => cubit.requestAccountDeletion()));
  }
  return cubit;
}

class _SettingsPreview extends StatefulWidget {
  const _SettingsPreview({required this.cubit});

  final SettingsCubit cubit;

  @override
  State<_SettingsPreview> createState() => _SettingsPreviewState();
}

class _SettingsPreviewState extends State<_SettingsPreview> {
  LocaleCubit? _locale;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );
    if (!mounted) {
      await locale.close();
      return;
    }
    setState(() {
      _locale = locale;
    });
  }

  @override
  void dispose() {
    _locale?.close();
    widget.cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = _locale;
    if (locale == null) return const SizedBox.shrink();
    return BlocProvider<LocaleCubit>.value(
      value: locale,
      child: SettingsScreen(cubit: widget.cubit),
    );
  }
}

class _ProfileEditPreview extends StatefulWidget {
  const _ProfileEditPreview({this.profile});

  final UserProfile? profile;

  @override
  State<_ProfileEditPreview> createState() => _ProfileEditPreviewState();
}

class _ProfileEditPreviewState extends State<_ProfileEditPreview> {
  SettingsCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cubit = SettingsCubit(
      profileRepository: _FakeProfileRepository(
        widget.profile ?? _sampleProfile(),
      ),
      accountService: const _FakeAccountService(),
    );
    await cubit.load();
    if (!mounted) {
      await cubit.close();
      return;
    }
    setState(() => _cubit = cubit);
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) return const SizedBox.shrink();
    return BlocProvider<SettingsCubit>.value(
      value: cubit,
      child: const ProfileEditScreen(),
    );
  }
}

class _FakeNotificationPrefsRepository implements NotificationPrefsRepository {
  const _FakeNotificationPrefsRepository({this.fetchFailure});

  final NotificationPrefsFailure? fetchFailure;

  @override
  Future<NotificationPrefs> fetch() async {
    final f = fetchFailure;
    if (f != null) throw NotificationPrefsRepositoryException(f);
    return const NotificationPrefs();
  }

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async {
    return const NotificationPrefs().copyWith(categories: categories);
  }
}

class _PendingNotificationPrefsRepository
    implements NotificationPrefsRepository {
  const _PendingNotificationPrefsRepository();

  @override
  Future<NotificationPrefs> fetch() => Completer<NotificationPrefs>().future;

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) {
    return Completer<NotificationPrefs>().future;
  }
}

class _FakeAccountSessionTerminator implements AccountSessionTerminator {
  const _FakeAccountSessionTerminator();

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

Widget _logoutDeleteSheetHost(Widget sheet) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Align(alignment: Alignment.bottomCenter, child: sheet),
    ),
  );
}


class _FakeSettlementRepository implements SettlementRepository {
  const _FakeSettlementRepository({this.statements, this.fetchFailure});

  final List<SettlementStatement>? statements;
  final SettlementFailure? fetchFailure;

  @override
  Future<List<SettlementStatement>> fetchStatements() async {
    final f = fetchFailure;
    if (f != null) throw SettlementException(f);
    return statements ?? const <SettlementStatement>[];
  }

  @override
  Future<String> downloadPdf(String statementId) async {
    return '/tmp/statement-$statementId.pdf';
  }
}

class _PendingSettlementRepository implements SettlementRepository {
  const _PendingSettlementRepository();

  @override
  Future<List<SettlementStatement>> fetchStatements() {
    return Completer<List<SettlementStatement>>().future;
  }

  @override
  Future<String> downloadPdf(String statementId) => Completer<String>().future;
}

List<SettlementStatement> _sampleStatements() => const [
  SettlementStatement(
    id: 'stmt-1',
    weekLabel: 'Jun 22 – Jun 28',
    totalPayout: 184.50,
    currency: 'USD',
    status: SettlementStatus.paid,
    deliveries: [
      SettlementDeliveryLine(
        deliveryId: 'REQ-1042',
        date: '2026-06-24',
        tier: 'Express',
        fare: 20.0,
        commission: 4.0,
        net: 16.0,
        currency: 'USD',
      ),
      SettlementDeliveryLine(
        deliveryId: 'REQ-1038',
        date: '2026-06-25',
        tier: 'Flash',
        fare: 15.0,
        commission: 3.0,
        net: 12.0,
        currency: 'USD',
      ),
    ],
  ),
  SettlementStatement(
    id: 'stmt-2',
    weekLabel: 'Jun 29 – Jul 5',
    totalPayout: 96.00,
    currency: 'USD',
    status: SettlementStatus.pending,
    deliveries: [
      SettlementDeliveryLine(
        deliveryId: 'REQ-1055',
        date: '2026-07-01',
        tier: 'Standard',
        fare: 12.0,
        commission: 2.4,
        net: 9.6,
        currency: 'USD',
      ),
    ],
  ),
];


List<CatalogEntry> get batch10Entries => <CatalogEntry>[
  CatalogEntry(
    feature: 'request_summary',
    screen: 'RequestSummaryScreen',
    states: [
      CatalogState(
        'Loaded',
        (_) => _requestSummaryScreen(const _FakeRequestSubmissionService()),
      ),
      CatalogState(
        'Submitting',
        (_) => _requestSummaryScreen(
          const _FakeRequestSubmissionService(pending: true),
          drive: true,
        ),
      ),
      CatalogState(
        'Error — Network',
        (_) => _requestSummaryScreen(
          const _FakeRequestSubmissionService(
            failure: RequestSubmissionFailure.network,
          ),
          drive: true,
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'request_summary',
    screen: 'RequestSummaryUnavailableScreen',
    states: [
      CatalogState(
        'Unavailable',
        (_) => const RequestSummaryUnavailableScreen(),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'request_type',
    screen: 'RequestTypeScreen',
    states: [
      CatalogState(
        'Loading',
        (_) => const RequestTypeScreen(repository: _PendingTierRepository()),
      ),
      CatalogState(
        'Loaded — no selection',
        (_) => const RequestTypeScreen(repository: DevtoolTierRepository()),
      ),
      CatalogState(
        'Selected — Standard',
        (_) => RequestTypeScreen(cubit: _selectedTierCubit(TierId.standard)),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'reviews',
    screen: 'ReviewsListScreen',
    states: [
      CatalogState(
        'Loading',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: _PendingReviewsRepository(),
        ),
      ),
      CatalogState(
        'Populated',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: StubReviewsRepository(),
        ),
      ),
      CatalogState(
        'Cold-start — New Jeeber',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: _ColdStartReviewsRepository(),
        ),
      ),
      CatalogState(
        'Empty',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: EmptyReviewsRepository(),
        ),
      ),
      CatalogState(
        'Error — Network',
        (_) => const ReviewsListScreen(
          jeeberId: _reviewsJeeberId,
          repository: _FailingReviewsRepository(ReviewsFailure.network),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'SettingsScreen',
    states: [
      CatalogState(
        'Loaded — Profile',
        (_) => _SettingsPreview(cubit: _settingsCubit()),
      ),
      CatalogState(
        'Loaded — Deletion Pending',
        (_) => _SettingsPreview(cubit: _settingsCubit(driveDeletion: true)),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'ProfileEditScreen',
    states: [
      CatalogState('Loaded', (_) => const _ProfileEditPreview()),
      CatalogState(
        'Empty — No Name Yet',
        (_) => const _ProfileEditPreview(
          profile: UserProfile(phoneE164: '+96170123456'),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'NotificationPreferencesScreen',
    states: [
      CatalogState(
        'Loading',
        (_) => const NotificationPreferencesScreen(
          repository: _PendingNotificationPrefsRepository(),
        ),
      ),
      CatalogState(
        'Loaded',
        (_) => const NotificationPreferencesScreen(
          repository: _FakeNotificationPrefsRepository(),
        ),
      ),
      CatalogState(
        'Error',
        (_) => const NotificationPreferencesScreen(
          repository: _FakeNotificationPrefsRepository(
            fetchFailure: NotificationPrefsFailure.network,
          ),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'SavedAddressesScreen',
    states: [CatalogState('Placeholder', (_) => const SavedAddressesScreen())],
  ),
  CatalogEntry(
    feature: 'settings',
    screen: 'LogoutDeleteConfirmSheet',
    states: [
      CatalogState(
        'Sign Out',
        (_) => _logoutDeleteSheetHost(
          const LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.logout,
            terminator: _FakeAccountSessionTerminator(),
          ),
        ),
      ),
      CatalogState(
        'Delete Account',
        (_) => _logoutDeleteSheetHost(
          const LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.delete,
            terminator: _FakeAccountSessionTerminator(),
          ),
        ),
      ),
      CatalogState(
        'Both',
        (_) => _logoutDeleteSheetHost(
          const LogoutDeleteConfirmSheet(
            mode: LogoutDeleteMode.both,
            terminator: _FakeAccountSessionTerminator(),
          ),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settlement',
    screen: 'SettlementScreen',
    states: [
      CatalogState(
        'Loading',
        (_) =>
            const SettlementScreen(repository: _PendingSettlementRepository()),
      ),
      CatalogState(
        'Ready — Mixed',
        (_) => SettlementScreen(
          repository: _FakeSettlementRepository(
            statements: _sampleStatements(),
          ),
        ),
      ),
      CatalogState(
        'Empty',
        (_) => const SettlementScreen(repository: _FakeSettlementRepository()),
      ),
      CatalogState(
        'Error',
        (_) => const SettlementScreen(
          repository: _FakeSettlementRepository(
            fetchFailure: SettlementFailure.network,
          ),
        ),
      ),
    ],
  ),
  CatalogEntry(
    feature: 'settlement',
    screen: 'SettlementDetailScreen',
    states: [
      CatalogState(
        'Paid',
        (_) => SettlementDetailScreen(statement: _sampleStatements()[0]),
      ),
      CatalogState(
        'Pending',
        (_) => SettlementDetailScreen(statement: _sampleStatements()[1]),
      ),
    ],
  ),

];
