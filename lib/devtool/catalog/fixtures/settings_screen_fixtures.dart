// Shared dev-only fixtures for `SettingsScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_10_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/settings/presentation/screens/settings_screen.dart`.
//
// The catalog owned a private `_settingsCubit()` factory over the neighbouring
// profile-edit fakes, plus a `_SettingsPreview` host that resolved a REAL
// `SharedPreferences` through the platform channel. Copying either into the
// preview section would have given the two surfaces two different "Maya
// Haddad", free to drift — and on a settings list the designed state IS the
// copy in the rows. Both surfaces now import this file. The fakes are declared
// here rather than borrowed from `profile_edit_screen_fixtures.dart` so this
// screen's designed states cannot move when that screen's do; they are three
// methods each.
//
// Three deliberate changes came with the extraction:
//
//  * **The prefs are in-memory.** [LocaleCubit] is a hard requirement of this
//    screen (`_LanguageSection` calls `context.watch<LocaleCubit>()`
//    unconditionally) and it REQUIRES a `SharedPreferences`. The real one is
//    async and platform-channel backed, which a synchronous
//    `Widget Function()` preview cannot have, so the catalog had to render a
//    `SizedBox.shrink()` until `getInstance()` resolved. [SettingsScreenInMemoryPrefs]
//    answers from a map, so both surfaces build synchronously — and tapping a
//    language row in a dev tool no longer writes to the real user's prefs.
//  * **`deletionPending` is SEEDED, not driven.** The catalog reached that
//    state by chaining `requestAccountDeletion()` onto the load future, which
//    also sets `SettingsBanner.accountDeletionRequested` and therefore pops a
//    SnackBar over the surface for four seconds. [SettingsScreenSeededCubit]
//    puts the cubit straight into the designed state, so the card shows the
//    row and nothing else. Same pixels, minus the transient.
//  * **Each state has its own account holder** — see
//    [SettingsScreenPreviewFixtures]. Only the reference state keeps "Maya
//    Haddad"; the deletion-pending card, which used to be a byte-identical
//    twin of it apart from one row at the bottom of a scrolling list, now
//    names itself in its first row.
//
// Everything here is a LOCAL fake over the screen's own seams: `SettingsScreen`
// takes `cubit:`, and [SettingsCubit] takes `profileRepository:` /
// `accountService:`, so neither surface ever resolves `sl<ProfileRepository>()`
// / `sl<AccountService>()`. Network-free by construction, not merely by the
// guard the hosts install.
//
// NOT covered by any fixture here, because the screen cannot reach it: the
// destructive rows open [LogoutDeleteConfirmSheet], which terminates the
// session through its own `AccountSessionTerminator` and never calls
// `SettingsCubit.requestAccountDeletion()` / `signOut()`. Every state below
// that those methods would produce is therefore a state only a fixture can
// build. See the preview section for what that implies.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

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
///
/// `load()` emits the loading flag and only leaves it when the future
/// completes, so this is the only way to inspect the cold-start rendering
/// without a real slow connection.
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
///
/// Three of the states this screen renders — the latched `deletionPending`
/// row, `isDeletingAccount`, `isSigningOut` — are produced by cubit methods
/// the screen never calls, so there is no gesture and no fake that reaches
/// them. Seeding is not a shortcut here; it is the only route.
///
/// Inert by construction: no repository call is ever made, so nothing async is
/// in flight and the state cannot move.
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
///
/// [LocaleCubit] REQUIRES a `SharedPreferences`, and the real one is async
/// (`getInstance()`) and platform-channel backed — neither of which a
/// synchronous `Widget Function()` preview can have. This answers from a plain
/// map, so construction is synchronous and a write in the canvas or the
/// catalog is simply a map write.
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
///
/// Supplies the ambient [LocaleCubit] the screen's language section watches
/// unconditionally, owns the [SettingsCubit] lifecycle (both surfaces rebuild
/// their state builders, so the cubit has to be created and closed by
/// something with a `State`), and optionally pins a device width — a settings
/// list is all row copy, and row copy breaks at a width, not at a size.
///
/// [builder] receives the cubit so the CALLER constructs the screen. That is
/// deliberate: `tool/preview_coverage.dart` counts a screen as covered only
/// when its own preview section literally constructs it, and it is also what
/// keeps this host reusable for `LiveSettingsScreen`-shaped hosts later.
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
  ///
  /// Both surfaces move between states in place — the catalog's state picker
  /// and a render test that pumps two previews in a row both replace this
  /// widget with another of the same type and no key, which Flutter treats as
  /// an update rather than a remount. Without this the [State] survives and
  /// keeps the first fixture's cubit, so the surface goes on showing the
  /// previous designed state under the new state's name. `create` is a static
  /// tear-off at both call sites, so the comparison is stable.
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
    // AR rendering of a matrix card checks "العربية" — as it does in the app,
    // where one cubit drives both the check and `MaterialApp.locale`. Read it
    // HERE, in a build: a `Localizations.maybeLocaleOf` inside the provider's
    // `create` would register an inherited dependency in a callback that never
    // runs again, which `provider` rejects outright.
    final Locale ambient =
        Localizations.maybeLocaleOf(context) ?? const Locale('en');
    final Widget seated = BlocProvider<LocaleCubit>(
      // Keyed on the ambient locale: `create` runs once per element, so
      // without this a card re-rendered in the other locale would keep the
      // cubit seeded from the first one and tick the wrong language row.
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
///
/// **Every state has its own account holder.** Four of them differ from the
/// reference only in the Account section at the BOTTOM of a scrolling list —
/// a latched row, two greyed rows — which is both hard to tell apart when
/// scrolling the catalog and, in a render test on anything shorter than the
/// whole list, not built at all. A distinct name in the FIRST row makes each
/// card self-identifying at a glance and gives the render tests a discriminator
/// they can actually reach. The reference customer stays with `loadedProfile`.
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
  /// state in the one card that already stresses the row layout.
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
