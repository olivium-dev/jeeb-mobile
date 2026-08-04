// Shared dev-only fixtures for `SettingsScreen`.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/notification_preferences.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';

/// In-memory [ProfileRepository] — `load()` resolves to [profile] on the next
/// microtask, `save()` replaces it. No SharedPreferences, no Dio, no GetIt.
class SettingsScreenFakeProfileRepository implements ProfileRepository {
  SettingsScreenFakeProfileRepository([this._profile]);

  UserProfile? _profile;

  @override
  Future<UserProfile?> load() async => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> clear() async {
    _profile = const UserProfile.empty();
  }
}

/// A profile read that never lands, holding [SettingsCubit] on
/// `isLoading: true` for as long as the surface is open.
/// `load()` emits the loading flag and only leaves it when the future
class SettingsScreenPendingProfileRepository implements ProfileRepository {
  const SettingsScreenPendingProfileRepository();

  @override
  Future<UserProfile?> load() => Completer<UserProfile?>().future;

  @override
  Future<void> save(UserProfile profile) => Completer<void>().future;

  @override
  Future<void> clear() => Completer<void>().future;
}

/// Always-succeeds [AccountService]. Nothing in the previewed surface calls it
/// (see the file header), but [SettingsCubit] requires one.
class SettingsScreenFakeAccountService implements AccountService {
  const SettingsScreenFakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async =>
      AccountActionOutcome.success;

  @override
  Future<AccountActionOutcome> signOut() async => AccountActionOutcome.success;
}

/// A [SettingsCubit] parked in one exact [SettingsState].
/// Three of the states this screen renders — the latched `deletionPending`
/// row, `isDeletingAccount`, `isSigningOut` — are produced by cubit methods
class SettingsScreenSeededCubit extends SettingsCubit {
  SettingsScreenSeededCubit(SettingsState seed)
      : super(
          profileRepository: SettingsScreenFakeProfileRepository(),
          accountService: const SettingsScreenFakeAccountService(),
        ) {
    emit(seed);
  }
}

/// An in-memory stand-in for [SharedPreferences].
/// [LocaleCubit] REQUIRES a `SharedPreferences`, and the real one is async
/// (`getInstance()`) and platform-channel backed — neither of which a
class SettingsScreenInMemoryPrefs implements SharedPreferences {
  SettingsScreenInMemoryPrefs([Map<String, Object>? seed])
      : _store = <String, Object>{...?seed};

  final Map<String, Object> _store;

  @override
  Object? get(String key) => _store[key];

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  double? getDouble(String key) => _store[key] as double?;

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  String? getString(String key) => _store[key] as String?;

  @override
  List<String>? getStringList(String key) =>
      (_store[key] as List<String>?)?.toList();

  @override
  Set<String> getKeys() => _store.keys.toSet();

  @override
  bool containsKey(String key) => _store.containsKey(key);

  @override
  Future<bool> setBool(String key, bool value) => _put(key, value);

  @override
  Future<bool> setDouble(String key, double value) => _put(key, value);

  @override
  Future<bool> setInt(String key, int value) => _put(key, value);

  @override
  Future<bool> setString(String key, String value) => _put(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _put(key, value);

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _store.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}

  Future<bool> _put(String key, Object value) async {
    _store[key] = value;
    return true;
  }
}

/// Seats a previewed [SettingsScreen] the way the app seats it, minus the app.
/// Supplies the ambient [LocaleCubit] the screen's language section watches
/// unconditionally, owns the [SettingsCubit] lifecycle (both surfaces rebuild
class SettingsScreenPreviewHost extends StatefulWidget {
  const SettingsScreenPreviewHost({
    super.key,
    required this.create,
    required this.builder,
    this.width,
  });

  /// Builds the cubit under review. Called once per [State], and again only
  /// when the fixture itself changes (see `didUpdateWidget`) — never per frame.
  final SettingsCubit Function() create;

  /// Builds the screen from that cubit.
  final Widget Function(SettingsCubit cubit) builder;

  /// Device width to pin, or `null` to take whatever the host offers (the
  /// Screen Catalog runs full-bleed inside the device it is already on).
  final double? width;

  @override
  State<SettingsScreenPreviewHost> createState() =>
      _SettingsScreenPreviewHostState();
}

class _SettingsScreenPreviewHostState extends State<SettingsScreenPreviewHost> {
  late SettingsCubit _cubit = widget.create();
  final SharedPreferences _prefs = SettingsScreenInMemoryPrefs();

  /// Swapping the fixture must swap the STATE on screen.
  /// Both surfaces move between states in place — the catalog's state picker
  @override
  void didUpdateWidget(covariant SettingsScreenPreviewHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.create != oldWidget.create) {
      _cubit.close();
      _cubit = widget.create();
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The ambient locale decides which language row carries the check, so the
    final Locale ambient =
        Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final Widget seated = BlocProvider<LocaleCubit>(
      // Keyed on the ambient locale: `create` runs once per element, so
      key: ValueKey<Locale>(ambient),
      create: (_) => LocaleCubit(
        prefs: _prefs,
        deviceLocaleProvider: () => ambient,
      ),
      child: widget.builder(_cubit),
    );
    final double? width = widget.width;
    if (width == null) return seated;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: width, child: seated),
    );
  }
}

/// The designed states both dev surfaces render.
/// **Every state has its own account holder.** Four of them differ from the
abstract final class SettingsScreenPreviewFixtures {
  /// The catalog's reference customer, and the string its "Loaded — Profile"
  /// state is recognised by.
  static const String sampleName = 'Maya Haddad';
  static const String samplePhone = '+96170123456';

  /// A different real number for the phone-only state, so "signed in with no
  /// name yet" cannot be mistaken for the reference customer.
  static const String phoneOnlyPhone = '+96171445599';

  /// The account scheduled for deletion.
  static const String pendingName = 'Nour Bakri';
  static const String pendingPhone = '+96171889200';

  /// The account whose destructive actions are in flight.
  static const String inFlightName = 'Karim Assaf';
  static const String inFlightPhone = '+96176220900';

  /// Layout ceiling: a full Lebanese name with two family particles, which is
  /// ordinary here and roughly triples the reference title.
  static const String longestName =
      'Abdulrahman Al-Muhandis Al-Trabulsi Al-Beiruti';
  static const String longestPhone = '+96181004477';

  /// The reference profile: a name and a phone on file.
  static UserProfile sampleProfile() => const UserProfile(
        phoneE164: samplePhone,
        name: sampleName,
      );

  /// Hydrated through the REAL `load()` path over an in-memory repository —
  /// the same two emissions production makes, just without the gateway.
  static SettingsCubit loadedProfile() => _hydrated(sampleProfile());

  /// Signed in, never opened profile-edit: no name, only the registration
  /// phone. The row falls back to the "Add your name" placeholder.
  static SettingsCubit phoneOnly() =>
      _hydrated(const UserProfile(phoneE164: phoneOnlyPhone));

  /// The cold read still in flight (`isLoading: true`, profile still empty).
  static SettingsCubit coldLoad() {
    final cubit = SettingsCubit(
      profileRepository: const SettingsScreenPendingProfileRepository(),
      accountService: const SettingsScreenFakeAccountService(),
    );
    unawaited(cubit.load());
    return cubit;
  }

  /// E20 (JEBV4-215): the delete request has been accepted and the row has
  /// latched to the scheduled-purge copy.
  static SettingsCubit deletionPending() => SettingsScreenSeededCubit(
        const SettingsState(
          profile: UserProfile(phoneE164: pendingPhone, name: pendingName),
          deletionPending: true,
        ),
      );

  /// Both destructive requests in flight at once — the only rendering in which
  /// the Account rows are disabled without being latched.
  static SettingsCubit destructiveInFlight() => SettingsScreenSeededCubit(
        const SettingsState(
          profile: UserProfile(phoneE164: inFlightPhone, name: inFlightName),
          isDeletingAccount: true,
          isSigningOut: true,
        ),
      );

  /// The ceiling reading: the longest name on file with every optional
  /// notification opted OUT, so the switch rows are reviewable in their off
  static SettingsCubit longestContent() => SettingsScreenSeededCubit(
        const SettingsState(
          profile: UserProfile(phoneE164: longestPhone, name: longestName),
          notifications: NotificationPreferences(
            offers: false,
            chat: false,
            status: false,
            ratingReminders: false,
          ),
        ),
      );

  static SettingsCubit _hydrated(UserProfile profile) {
    final cubit = SettingsCubit(
      profileRepository: SettingsScreenFakeProfileRepository(profile),
      accountService: const SettingsScreenFakeAccountService(),
    );
    unawaited(cubit.load());
    return cubit;
  }
}
