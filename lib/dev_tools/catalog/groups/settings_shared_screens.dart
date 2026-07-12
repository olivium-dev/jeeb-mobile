import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/diagnostics/diagnostics_screen.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';
import 'package:jeeb_mobile/features/dispute_status/presentation/dispute_status_screen.dart';
import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';
import 'package:jeeb_mobile/features/location/data/fake_address_form_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/screens/address_detail_form_screen.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/notification_prefs/presentation/notification_prefs_screen.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/notifications/presentation/notifications_list_screen.dart';
import 'package:jeeb_mobile/features/password_security/presentation/password_security_screen.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/live_settings_screen.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/profile_edit_screen.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';

import '../dev_screen_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Settings & Shared" catalog group.
//
// Every entry is ported 1:1 from the matching integration_test/screens/<file>,
// one DevScreenState per `testWidgets` case (screenshot suffix → state id,
// locale → state locale, the pumped widget → the builder body). All fakes /
// fixtures below are copied inline from those tests and privatised — nothing is
// imported from test/ or integration_test/.
//
// Builder rules honoured: navigation callbacks are safe no-ops, no runaway
// timers, and the screens are LIVE (form controls stay interactive). Screens
// that need a Router ancestor (RootAwareBackScope / GoRouterState.of) rely on
// the Router the dev preview host provides, so they are returned directly.
// ─────────────────────────────────────────────────────────────────────────────

// ── Profile Edit (settings-profile) ─────────────────────────────────────────
// Ported from profile_edit_test.dart: seeds an in-memory ProfileRepository
// through a screen-wide SettingsCubit read at initState.

/// In-memory [ProfileRepository] (zero-network double).
class _InMemoryProfileRepository implements ProfileRepository {
  _InMemoryProfileRepository([this._profile]);
  UserProfile? _profile;

  @override
  Future<UserProfile?> load() async => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> clear() async {
    _profile = null;
  }
}

/// No-network [AccountService] the cubit needs but this surface never invokes.
class _FakeAccountService implements AccountService {
  const _FakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async =>
      AccountActionOutcome.success;

  @override
  Future<AccountActionOutcome> signOut() async => AccountActionOutcome.success;
}

/// Builds a SettingsCubit over an in-memory profile and kicks off its load
/// (fire-and-forget — the live preview settles once the bloc emits).
SettingsCubit _profileCubit({UserProfile? seed}) {
  final cubit = SettingsCubit(
    profileRepository: _InMemoryProfileRepository(seed),
    accountService: const _FakeAccountService(),
    fallbackPhoneE164: '+96170100200',
  );
  unawaited(cubit.load());
  return cubit;
}

Widget _profileScreen({UserProfile? seed}) => BlocProvider<SettingsCubit>(
      create: (_) => _profileCubit(seed: seed),
      child: const ProfileEditScreen(),
    );

// ── Saved Locations (settings-addresses) ─────────────────────────────────────
// Ported from saved_locations_test.dart. The screen self-provides its cubit from
// the `repository` seam and wraps its body in a RootAwareBackScope, so it needs
// the Router the dev preview host supplies.

/// Scriptable saved-locations repo — only `fetchSavedLocations` is exercised;
/// mutations throw (never reached without interaction).
class _FakeSavedLocationRepo implements SavedLocationRepository {
  const _FakeSavedLocationRepo(this.list);
  final List<SavedLocation> list;

  @override
  Future<List<SavedLocation>> fetchSavedLocations() async => list;

  @override
  Future<SavedLocation> saveLocation({
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      throw UnimplementedError();

  @override
  Future<SavedLocation> updateLocation({
    required String id,
    required double latitude,
    required double longitude,
    required String label,
    required SavedLocationCategory category,
    String? address,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteLocation(String id) async {}
}

const _seededLocations = <SavedLocation>[
  SavedLocation(
    id: 'addr-client-001-home',
    label: 'Home',
    latitude: 33.8869,
    longitude: 35.5131,
    category: SavedLocationCategory.home,
    address: 'Sassine Square, Ashrafieh',
    isDefault: true,
  ),
  SavedLocation(
    id: 'addr-client-001-office',
    label: 'Office',
    latitude: 33.8938,
    longitude: 35.5018,
    category: SavedLocationCategory.work,
    address: 'Downtown Beirut',
  ),
];

Widget _savedLocationsScreen(List<SavedLocation> list) =>
    SavedLocationsScreen(repository: _FakeSavedLocationRepo(list));

// ── Address Detail (address-detail) ─────────────────────────────────────────
// Ported from address_detail_test.dart. Injecting `userId` skips the
// AuthTokenStore FutureBuilder and `repository` supplies the in-memory
// FakeAddressFormRepository, so the form mounts with no Dio/session.

const _existingAddress = SavedLocation(
  id: 'addr-client-001-home',
  label: 'Home',
  latitude: 33.8869,
  longitude: 35.5131,
  category: SavedLocationCategory.home,
  address: 'Sassine Square, Ashrafieh',
  isDefault: true,
  building: 'Cedar Tower',
  floorApt: '4th floor, Apt 7',
  deliveryNotes: 'Ring the bell twice',
  codPhone: '+96170100200',
);

Widget _addAddressScreen() => const AddressDetailFormScreen(
      userId: 'user-test',
      repository: FakeAddressFormRepository(),
    );

Widget _editAddressScreen() => const AddressDetailFormScreen(
      userId: 'user-test',
      addressId: 'addr-client-001-home',
      existing: _existingAddress,
      repository: FakeAddressFormRepository(),
    );

// ── Notification Preferences (settings-notifications) ────────────────────────
// Ported from notification_preferences_test.dart: provide a NotificationPrefsCubit
// backed by an in-memory repo and pump the presentation screen directly.

/// In-memory prefs repo serving the default snapshot.
class _FakePrefsRepo implements NotificationPrefsRepository {
  const _FakePrefsRepo();

  @override
  Future<NotificationPrefs> fetch() async => const NotificationPrefs();

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      NotificationPrefs(categories: categories);
}

Widget _notificationPrefsScreen() => BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(repository: const _FakePrefsRepo()),
      child: const NotificationPrefsScreen(),
    );

// ── Diagnostics (settings-diagnostics) ───────────────────────────────────────
// Ported from diagnostics_test.dart. The test forces the enabled body via the
// test-only `Diag.enabledOverride`; the dev tool runs as a debug build where
// `Diag.enabled` is already true (`kDebugMode`), so no override is needed. Every
// side-effecting seam (share, clipboard) is a no-op.

final _diagSessions = <DiagSessionFileInfo>[
  DiagSessionFileInfo(
    path: '/data/user/0/app.jeeb.mobile.dev/files/diag/'
        '2026-07-03T10-30-15-123Z-client.jsonl',
    name: '2026-07-03T10-30-15-123Z-client.jsonl',
    sizeBytes: 12 * 1024 + 410,
    modified: DateTime(2026, 7, 3, 12, 30),
    isCurrent: true,
  ),
  DiagSessionFileInfo(
    path: '/data/user/0/app.jeeb.mobile.dev/files/diag/'
        '2026-07-02T08-00-00-000Z-jeeber.jsonl',
    name: '2026-07-02T08-00-00-000Z-jeeber.jsonl',
    sizeBytes: 532,
    modified: DateTime(2026, 7, 2, 9, 0),
  ),
];

DiagnosticsScreen _diagnosticsScreen(List<DiagSessionFileInfo> sessions) =>
    DiagnosticsScreen(
      sessionsLoader: () async => sessions,
      shareLauncher: (_) async {},
      clipboardWriter: (_) async {},
    );

// ── Language Settings (language-settings) ────────────────────────────────────
// Ported from language_settings_test.dart. The screen reads a LocaleCubit for
// the active-row check mark. We build one over real SharedPreferences (available
// under the running dev flavor) with a fixed device-locale provider.

class _LanguageSettingsPreview extends StatefulWidget {
  const _LanguageSettingsPreview({required this.deviceLocale});
  final Locale deviceLocale;

  @override
  State<_LanguageSettingsPreview> createState() =>
      _LanguageSettingsPreviewState();
}

class _LanguageSettingsPreviewState extends State<_LanguageSettingsPreview> {
  LocaleCubit? _cubit;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _cubit = LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => widget.deviceLocale,
        );
      });
    });
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
    return BlocProvider<LocaleCubit>.value(
      value: cubit,
      child: const LanguageSettingsScreen(),
    );
  }
}

// ── Notifications (notifications) ────────────────────────────────────────────
// Ported from notifications_list_test.dart: fake repository seam.

class _FakeNotifRepo implements NotificationsRepository {
  const _FakeNotifRepo(this._items);
  final List<NotificationItem> _items;

  @override
  Future<List<NotificationItem>> fetchNotifications() async => _items;

  @override
  Future<void> markRead(String id) async {}
}

const _notifInbox = <NotificationItem>[
  NotificationItem(
    id: 'n1',
    kind: NotificationKind.offerAccepted,
    title: 'Offer accepted',
    body: 'Your offer on request JB-1001 was accepted.',
    timestamp: '2026-07-04T20:00:00Z',
    read: false,
    ref: 'req-client-001-accepted',
  ),
  NotificationItem(
    id: 'n2',
    kind: NotificationKind.status,
    title: 'Your delivery is on the way',
    body: 'Package #JB-1001 is out for delivery.',
    timestamp: '2026-07-04T18:30:00Z',
    read: false,
  ),
  NotificationItem(
    id: 'n3',
    kind: NotificationKind.topup,
    title: 'Wallet topped up',
    body: '\$250.00 was added to your wallet.',
    timestamp: '2026-07-03T09:15:00Z',
    read: true,
  ),
  NotificationItem(
    id: 'n4',
    kind: NotificationKind.kycApproved,
    title: 'Identity verified',
    body: 'Your KYC has been approved.',
    timestamp: '2026-07-02T12:00:00Z',
    read: true,
  ),
];

// ── Dispute Status (dispute-status) ──────────────────────────────────────────
// Ported from dispute_status_test.dart: fake repository seam returning
// open / resolved snapshots.

class _FakeDisputeRepo implements DisputeStatusRepository {
  const _FakeDisputeRepo(this._status);
  final DisputeStatus _status;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => _status;
}

const _disputeOpen = DisputeStatus(
  id: 'dispute-client-001-open',
  state: DisputeState.open,
  orderRef: 'JB-1001',
  conversationRef: 'conv-journey-accepted',
  createdAt: '2026-07-01T10:00:00Z',
  evidence: DisputeEvidenceSummary(
    reason: 'Item arrived damaged',
    comment: 'The box was crushed on delivery.',
    photoCount: 2,
    hasVoice: true,
    hasChatSnapshot: true,
    chatMessageCount: 6,
    timelineCount: 3,
  ),
);

const _disputeResolved = DisputeStatus(
  id: 'dispute-client-001-open',
  state: DisputeState.resolved,
  outcome: DisputeOutcome.refund,
  resolution: 'refund_issued',
  note: 'Full refund issued to your wallet.',
  refundAmount: 25.0,
  currency: 'USD',
  orderRef: 'JB-1001',
  createdAt: '2026-07-01T10:00:00Z',
  resolvedAt: '2026-07-03T14:00:00Z',
);

Widget _disputeScreen(DisputeStatus status) => DisputeStatusScreen(
      disputeId: 'dispute-client-001-open',
      repository: _FakeDisputeRepo(status),
    );

// ─────────────────────────────────────────────────────────────────────────────
// The group. Entries sorted alphabetically by title.
// ─────────────────────────────────────────────────────────────────────────────
final List<DevScreenEntry> settingsSharedScreens = <DevScreenEntry>[
  // Address Detail ───────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'address-detail',
    title: 'Address Detail',
    group: 'Settings & Shared',
    keywords: const <String>[
      'address',
      'location',
      'form',
      'add address',
      'edit address',
      'delivery',
      'JM-050',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'add-en',
        label: 'Add mode, empty form (EN)',
        locale: const Locale('en'),
        builder: (_) => _addAddressScreen(),
      ),
      DevScreenState(
        id: 'edit-en',
        label: 'Edit mode, pre-filled (EN)',
        locale: const Locale('en'),
        builder: (_) => _editAddressScreen(),
      ),
      DevScreenState(
        id: 'add-ar',
        label: 'Add mode (AR)',
        locale: const Locale('ar'),
        builder: (_) => _addAddressScreen(),
      ),
    ],
  ),

  // Diagnostics ────────────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'settings-diagnostics',
    title: 'Diagnostics',
    group: 'Settings & Shared',
    keywords: const <String>[
      'diagnostics',
      'logs',
      'debug',
      'sessions',
      'jsonl',
      'export',
      'dev tools',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Persisted sessions (EN)',
        locale: const Locale('en'),
        builder: (_) => _diagnosticsScreen(_diagSessions),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'Empty session list (EN)',
        locale: const Locale('en'),
        builder: (_) => _diagnosticsScreen(const <DiagSessionFileInfo>[]),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Persisted sessions (AR)',
        locale: const Locale('ar'),
        builder: (_) => _diagnosticsScreen(_diagSessions),
      ),
    ],
  ),

  // Dispute Status ─────────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'dispute-status',
    title: 'Dispute Status',
    group: 'Settings & Shared',
    keywords: const <String>[
      'dispute',
      'refund',
      'resolution',
      'complaint',
      'order issue',
      'evidence',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'open-en',
        label: 'Open dispute (EN)',
        locale: const Locale('en'),
        builder: (_) => _disputeScreen(_disputeOpen),
      ),
      DevScreenState(
        id: 'resolved-refund-ar',
        label: 'Resolved refund (AR)',
        locale: const Locale('ar'),
        builder: (_) => _disputeScreen(_disputeResolved),
      ),
    ],
  ),

  // Language Settings ──────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'language-settings',
    title: 'Language Settings',
    group: 'Settings & Shared',
    keywords: const <String>[
      'language',
      'locale',
      'english',
      'arabic',
      'translation',
      'rtl',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'english-en',
        label: 'English selected (EN)',
        locale: const Locale('en'),
        builder: (_) =>
            const _LanguageSettingsPreview(deviceLocale: Locale('en')),
      ),
      DevScreenState(
        id: 'arabic-ar',
        label: 'Arabic selected (AR)',
        locale: const Locale('ar'),
        builder: (_) =>
            const _LanguageSettingsPreview(deviceLocale: Locale('ar')),
      ),
    ],
  ),

  // Live Settings ──────────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'settings',
    title: 'Live Settings',
    group: 'Settings & Shared',
    keywords: const <String>[
      'settings',
      'account',
      'profile',
      'preferences',
      'network error',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'network-error-en',
        label: 'Network-error fallback (EN)',
        locale: const Locale('en'),
        builder: (_) => const LiveSettingsScreen(),
      ),
      DevScreenState(
        id: 'network-error-ar',
        label: 'Network-error fallback (AR)',
        locale: const Locale('ar'),
        builder: (_) => const LiveSettingsScreen(),
      ),
    ],
  ),

  // Notification Preferences ───────────────────────────────────────────────────
  DevScreenEntry(
    id: 'settings-notifications',
    title: 'Notification Preferences',
    group: 'Settings & Shared',
    keywords: const <String>[
      'notifications',
      'preferences',
      'toggles',
      'push',
      'categories',
      'JM-058',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Category toggles loaded (EN)',
        locale: const Locale('en'),
        builder: (_) => _notificationPrefsScreen(),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Category toggles loaded (AR)',
        locale: const Locale('ar'),
        builder: (_) => _notificationPrefsScreen(),
      ),
    ],
  ),

  // Notifications ──────────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'notifications',
    title: 'Notifications',
    group: 'Settings & Shared',
    keywords: const <String>[
      'notifications',
      'inbox',
      'alerts',
      'messages',
      'activity',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Populated inbox (EN)',
        locale: const Locale('en'),
        builder: (_) => const NotificationsListScreen(
          repository: _FakeNotifRepo(_notifInbox),
        ),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'Empty inbox (EN)',
        locale: const Locale('en'),
        builder: (_) => const NotificationsListScreen(
          repository: _FakeNotifRepo(<NotificationItem>[]),
        ),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Populated inbox (AR)',
        locale: const Locale('ar'),
        builder: (_) => const NotificationsListScreen(
          repository: _FakeNotifRepo(_notifInbox),
        ),
      ),
    ],
  ),

  // Password Security ──────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'password-security',
    title: 'Password Security',
    group: 'Settings & Shared',
    keywords: const <String>[
      'password',
      'security',
      'change password',
      'social login',
      'account',
      'JM-061',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Change-password form (EN)',
        locale: const Locale('en'),
        builder: (_) => const PasswordSecurityScreen(),
      ),
      DevScreenState(
        id: 'social-only-en',
        label: 'Social-only, form hidden (EN)',
        locale: const Locale('en'),
        builder: (_) => const PasswordSecurityScreen(hasPassword: false),
      ),
      DevScreenState(
        id: 'idle-ar',
        label: 'Change-password form (AR)',
        locale: const Locale('ar'),
        builder: (_) => const PasswordSecurityScreen(),
      ),
    ],
  ),

  // Profile Edit ───────────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'settings-profile',
    title: 'Profile Edit',
    group: 'Settings & Shared',
    keywords: const <String>[
      'profile',
      'name',
      'phone',
      'avatar',
      'account',
      'edit',
      'T-mobile-031',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'idle-en',
        label: 'Seeded name + read-only phone (EN)',
        locale: const Locale('en'),
        builder: (_) => _profileScreen(
          seed: const UserProfile(phoneE164: '+96170100200', name: 'Sami'),
        ),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'No name, placeholder avatar (EN)',
        locale: const Locale('en'),
        builder: (_) => _profileScreen(),
      ),
      DevScreenState(
        id: 'seeded-ar',
        label: 'Seeded name (AR)',
        locale: const Locale('ar'),
        builder: (_) => _profileScreen(
          seed: const UserProfile(phoneE164: '+96170100200', name: 'سامي'),
        ),
      ),
    ],
  ),

  // Saved Locations ────────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'settings-addresses',
    title: 'Saved Locations',
    group: 'Settings & Shared',
    keywords: const <String>[
      'addresses',
      'saved locations',
      'home',
      'work',
      'places',
      'JM-049',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'populated-en',
        label: 'Seeded list + default badge (EN)',
        locale: const Locale('en'),
        builder: (_) => _savedLocationsScreen(_seededLocations),
      ),
      DevScreenState(
        id: 'empty-en',
        label: 'Empty state (EN)',
        locale: const Locale('en'),
        builder: (_) => _savedLocationsScreen(const <SavedLocation>[]),
      ),
      DevScreenState(
        id: 'populated-ar',
        label: 'Seeded list (AR)',
        locale: const Locale('ar'),
        builder: (_) => _savedLocationsScreen(_seededLocations),
      ),
    ],
  ),

  // Support Ticket ─────────────────────────────────────────────────────────────
  DevScreenEntry(
    id: 'support-ticket',
    title: 'Support Ticket',
    group: 'Settings & Shared',
    keywords: const <String>[
      'support',
      'help',
      'ticket',
      'contact',
      'feedback',
      'customer service',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'form-en',
        label: 'Form (EN)',
        locale: const Locale('en'),
        builder: (_) => const SupportTicketScreen(),
      ),
      DevScreenState(
        id: 'form-ar',
        label: 'Form (AR)',
        locale: const Locale('ar'),
        builder: (_) => const SupportTicketScreen(),
      ),
    ],
  ),
];
