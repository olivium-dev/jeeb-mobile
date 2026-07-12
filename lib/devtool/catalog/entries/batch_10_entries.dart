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
import '../../../features/settings/application/role_switch_cubit.dart';
import '../../../features/settings/application/settings_cubit.dart';
import '../../../features/settings/domain/account_service.dart';
import '../../../features/settings/domain/profile_repository.dart';
import '../../../features/settings/domain/role_switch_repository.dart';
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

// Batch 10 — request_summary, request_type, reviews, search, settings,
// settlement. `live_settings_screen.dart` is SKIPPED (see bottom of file): it
// resolves `sl<Dio>()` inside a field initializer with no constructor seam, so
// previewing it locally would either hit the live gateway or require reaching
// into GetIt registration, out of scope for an additive catalog batch.

// ─────────────────────────────────────────────────────────────────────────────
// request_summary — the accepted-request review + submit card
// (RequestSummaryScreen) and its cold-deep-link fallback
// (RequestSummaryUnavailableScreen). The cubit has no DI default (the caller
// always supplies a [RequestDraft] via `setDraft`), so every state seeds the
// draft directly; a real submit success navigates away (`context.go('/')`),
// which has no "designed" rendered state of its own — only Loaded / Submitting
// / Error are previewed.
// ─────────────────────────────────────────────────────────────────────────────

class _FakeRequestSubmissionService implements RequestSubmissionService {
  const _FakeRequestSubmissionService({this.failure, this.pending = false});

  final RequestSubmissionFailure? failure;

  /// Never resolves — keeps the screen pinned on the submitting button state.
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

// ─────────────────────────────────────────────────────────────────────────────
// request_type — tier selection (RequestTypeScreen). Both `repository` and
// `cubit` are existing constructor test seams (§5.4) — no seam addition
// needed. `TierSelectionStatus.error` is unreachable from the real cubit
// (`load()` swallows every [TierLoadException] into the offline fallback), so
// only Loading / Loaded / Selected are meaningfully designed states.
// ─────────────────────────────────────────────────────────────────────────────

/// Never resolves — keeps the screen on its centered spinner for a stable
/// "Loading" catalog state.
class _PendingTierRepository implements TierRepository {
  const _PendingTierRepository();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

/// Drives the cubit to a loaded state with [select] chosen, via the same
/// "load, then act once it resolves" trick as the `otp_handover` escalate
/// preview (batch 08) — `selectTier` is a no-op until `load()` has landed.
TierSelectionCubit _selectedTierCubit(TierId select) {
  final cubit = TierSelectionCubit(repository: const FakeTierRepository());
  unawaited(cubit.load().then((_) => cubit.selectTier(select)));
  return cubit;
}

// ─────────────────────────────────────────────────────────────────────────────
// reviews — the all-reviews list (ReviewsListScreen, JM-068). `jeeberId` +
// `repository` are existing constructor test seams (§5.4).
// ─────────────────────────────────────────────────────────────────────────────

const String _reviewsJeeberId = 'jeeber-042';

/// Never resolves — keeps the screen on the first-load skeletons (D73).
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

/// D59 cold-start posture: < 5 ratings hides the aggregate score behind the
/// "New" badge while the individual row still renders.
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

// ─────────────────────────────────────────────────────────────────────────────
// settings — SettingsScreen (`cubit` is an existing constructor test seam)
// always renders a `_LanguageSection` that reads `context.watch<LocaleCubit>()`
// unconditionally, so every preview needs a real [LocaleCubit] ancestor. That
// cubit needs a real [SharedPreferences] instance, so this mirrors the
// `_OnboardingPreview` async-seam pattern (batch 08): resolve prefs once, then
// provide the cubit. The Active-Role toggle only reads `RoleCubit` from a user
// GESTURE (`_onChanged`), never from `build`, so no `RoleCubit` ancestor is
// needed to render it statically.
// ─────────────────────────────────────────────────────────────────────────────

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

class _NoopRoleSwitchRepository implements RoleSwitchRepository {
  const _NoopRoleSwitchRepository();

  @override
  Future<RoleSwitchResult> switchRole(String role) async =>
      RoleSwitchResult.success;
}

UserProfile _sampleProfile() => const UserProfile(
      phoneE164: '+96170123456',
      name: 'Maya Haddad',
    );

/// Builds + hydrates a [SettingsCubit] from the fakes above. `load()` is
/// fire-and-forget here (mirrors `_orderHistoryScreen`, batch 08): the
/// in-memory repository resolves within a microtask so the list settles to
/// its loaded content immediately after first paint. When [driveDeletion] is
/// set, `requestAccountDeletion()` is chained onto the SAME load future so the
/// deletion-pending row is reachable without a live gesture.
SettingsCubit _settingsCubit({UserProfile? profile, bool driveDeletion = false}) {
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

/// Async-seam host for [SettingsScreen] (see file-header note): resolves a
/// real [SharedPreferences] instance, builds the [LocaleCubit] it needs, and
/// optionally a [RoleSwitchCubit] when [withRoleToggle] is set.
class _SettingsPreview extends StatefulWidget {
  const _SettingsPreview({required this.cubit, this.withRoleToggle = false});

  final SettingsCubit cubit;
  final bool withRoleToggle;

  @override
  State<_SettingsPreview> createState() => _SettingsPreviewState();
}

class _SettingsPreviewState extends State<_SettingsPreview> {
  LocaleCubit? _locale;
  RoleSwitchCubit? _roleSwitch;

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
    final roleSwitch = widget.withRoleToggle
        ? RoleSwitchCubit(
            repository: const _NoopRoleSwitchRepository(),
            initialRole: 'client',
          )
        : null;
    if (!mounted) {
      await locale.close();
      await roleSwitch?.close();
      return;
    }
    setState(() {
      _locale = locale;
      _roleSwitch = roleSwitch;
    });
  }

  @override
  void dispose() {
    _locale?.close();
    _roleSwitch?.close();
    widget.cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = _locale;
    if (locale == null) return const SizedBox.shrink();
    return BlocProvider<LocaleCubit>.value(
      value: locale,
      child: SettingsScreen(
        cubit: widget.cubit,
        roleSwitchCubit: _roleSwitch,
        availableRoles:
            widget.withRoleToggle ? const ['client', 'jeeber'] : const [],
      ),
    );
  }
}

/// Async-seam host for [ProfileEditScreen] (no `cubit` ctor param of its own —
/// it reads `SettingsCubit` from context). Awaits the fake profile load to
/// completion BEFORE first build so the name field's `initState`-seeded
/// [TextEditingController] starts from the loaded name, not the empty default
/// (mirrors real usage: the settings list is already loaded before a user
/// navigates into profile-edit).
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
      profileRepository:
          _FakeProfileRepository(widget.profile ?? _sampleProfile()),
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

/// Never resolves — keeps the screen on its centered loading state.
class _PendingNotificationPrefsRepository implements NotificationPrefsRepository {
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

/// Bottom-sheet preview host (mirrors `_sheetHost` in batch 02):
/// [LogoutDeleteConfirmSheet] is a sheet, not a route — it renders a bare
/// column, not a `Scaffold`. Pinning it to the bottom of a plain `Scaffold`
/// mirrors how `showModalBottomSheet` actually presents it without depending
/// on a live `Navigator`/modal route.
Widget _logoutDeleteSheetHost(Widget sheet) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Align(alignment: Alignment.bottomCenter, child: sheet),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// settlement — the weekly statements list (SettlementScreen, `repository` is
// an existing constructor test seam) and the per-statement breakdown
// (SettlementDetailScreen, a plain `statement` value — no repository at all).
// ─────────────────────────────────────────────────────────────────────────────

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

/// Never resolves — keeps the screen on its centered loading state.
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

// ─────────────────────────────────────────────────────────────────────────────
// Catalog entries
// ─────────────────────────────────────────────────────────────────────────────

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
            (_) => const RequestTypeScreen(
              repository: _PendingTierRepository(),
            ),
          ),
          CatalogState(
            'Loaded — Flash preselected',
            (_) => const RequestTypeScreen(
              repository: FakeTierRepository(),
            ),
          ),
          CatalogState(
            'Selected — Eco',
            (_) => RequestTypeScreen(cubit: _selectedTierCubit(TierId.eco)),
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
          CatalogState(
            'Loaded — Role Toggle',
            (_) => _SettingsPreview(
              cubit: _settingsCubit(),
              withRoleToggle: true,
            ),
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
        states: [
          CatalogState('Placeholder', (_) => const SavedAddressesScreen()),
        ],
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
            (_) => const SettlementScreen(
              repository: _PendingSettlementRepository(),
            ),
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
            (_) => const SettlementScreen(
              repository: _FakeSettlementRepository(),
            ),
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

      // live_settings_screen.dart — SKIPPED. `LiveSettingsScreen` resolves
      // `sl<Dio>().get('/v1/users/me')` inside a `late Future` FIELD
      // INITIALIZER (before `build`, before any constructor seam could
      // intervene) and has no constructor param of its own — the generic,
      // seamed `SettingsScreen` it wraps is already cataloged above. Adding a
      // seam here would mean threading a fake `Dio`/response through a
      // field-initializer future, which is a bigger surgery than "minimal
      // additive" for a live-gateway host with no unique designed state beyond
      // what `SettingsScreen` already renders.
    ];
