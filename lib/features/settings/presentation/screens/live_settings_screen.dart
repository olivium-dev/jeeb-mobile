import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/role/user_role.dart';
import '../../../../core/session/profile_refresh_signals.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile_name/data/dio_display_name_repository.dart';
import '../../application/settings_cubit.dart';
import '../../data/dio_account_service.dart';
import '../../domain/avatar_cache_evictor.dart';
import '../../domain/avatar_repository.dart';
import '../../domain/profile_repository.dart';
import '../../domain/user_profile.dart';
import 'settings_screen.dart';

/// The live `/settings` host (MIDNIGHT M3-37, ORPHAN ruling KEEP+restyle).
///
/// It reads `GET /v1/users/me`, then hands the result to [SettingsScreen] —
/// which is R22 and already Midnight, so the loaded body is NOT restyled here.
/// What this screen owns is the two frames before that: the cold read and the
/// failed read. Both now wear R22's own chrome (`content` field, orange glow
/// top-end, in-body [JeebTopBar]) so the header and the field do not jump when
/// the future lands.
///
/// The illustration is `radar` for the same reason M3-22 picked it on
/// `account_status`: this is an account listening for a signal, not a request,
/// and its three identity discs are dropped because there is no second party
/// to name here.
class LiveSettingsScreen extends StatefulWidget {
  const LiveSettingsScreen({super.key, this.snapshotLoader});

  /// Test/catalog seam for the `GET /v1/users/me` read. Production omits it
  /// and the screen resolves Dio from DI; the catalog needs it because the
  /// loading and error frames are otherwise unreachable without a live gateway.
  final Future<Map<String, dynamic>> Function()? snapshotLoader;

  /// Frozen identifiers.
  static const String loadingIdentifier = 'live_settings_loading';
  static const String errorIdentifier = 'live_settings_error';
  static const String retryIdentifier = 'live_settings_retry_cta';

  @override
  State<LiveSettingsScreen> createState() => _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<LiveSettingsScreen> {
  late Future<_SettingsAccountSnapshot> _snapshot = _loadSnapshot();

  Future<_SettingsAccountSnapshot> _loadSnapshot() async {
    final loader = widget.snapshotLoader;
    if (loader != null) {
      return _SettingsAccountSnapshot.fromJson(await loader());
    }
    final response = await sl<Dio>().get<Map<String, dynamic>>('/v1/users/me');
    return _SettingsAccountSnapshot.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  void _retry() {
    // Block body, not an arrow: `() => _snapshot = _loadSnapshot()` returns the
    // Future, which trips setState's "callback returned a Future" assert — so
    // every Retry tap threw in debug builds.
    setState(() {
      _snapshot = _loadSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SettingsAccountSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        // Connection state first, not `hasError` first: `FutureBuilder` carries
        // the stale error across a future swap, so Retry used to leave the
        // failed frame on screen until the second read landed.
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LiveSettingsChrome(child: _LiveSettingsLoading());
        }
        if (snapshot.hasError) {
          return _LiveSettingsChrome(child: _LiveSettingsError(onRetry: _retry));
        }
        return _LoadedLiveSettings(snapshot: snapshot.requireData);
      },
    );
  }
}

/// R22's own shell around whichever pre-load frame is showing: the `content`
/// field with the tile's single top-end glow, a transparent scaffold and the
/// in-body back bar carrying `settings_back`.
class _LiveSettingsChrome extends StatelessWidget {
  const _LiveSettingsChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      glowPlacement: JeebFieldGlowPlacement.topEnd,
      // R22 is board-still: nothing on this screen animates.
      animateDecor: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              JeebTopBar.back(
                title: l10n.settingsTitle,
                identifier: 'settings_back',
                // Same guard the loaded body uses: `/settings` has no forward
                // entry point, so never pop the last page (black surface).
                onLeadingPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
              ),
              Expanded(child: Center(child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The cold read of `GET /v1/users/me`.
class _LiveSettingsLoading extends StatelessWidget {
  const _LiveSettingsLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      variant: JeebEmptyStateVariant.radar,
      status: JeebEmptyStateStatus.loading,
      medallions: const <JeebEmptyMedallion>[],
      identifier: LiveSettingsScreen.loadingIdentifier,
      headline: l10n.liveSettingsLoadingHeadline,
    );
  }
}

/// The failed read. Same illustration, danger-tinted centre (kit ruling 1), and
/// the retry is the glass pill — never an orange act R22 does not draw.
class _LiveSettingsError extends StatelessWidget {
  const _LiveSettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      variant: JeebEmptyStateVariant.radar,
      status: JeebEmptyStateStatus.error,
      medallions: const <JeebEmptyMedallion>[],
      identifier: LiveSettingsScreen.errorIdentifier,
      headline: l10n.settingsNetworkError,
      action: Semantics(
        identifier: LiveSettingsScreen.retryIdentifier,
        button: true,
        container: true,
        child: JeebCtaButton.outline(
          label: l10n.kycRetry,
          expand: false,
          onTap: onRetry,
        ),
      ),
    );
  }
}

class _LoadedLiveSettings extends StatefulWidget {
  const _LoadedLiveSettings({required this.snapshot});

  final _SettingsAccountSnapshot snapshot;

  @override
  State<_LoadedLiveSettings> createState() => _LoadedLiveSettingsState();
}

class _LoadedLiveSettingsState extends State<_LoadedLiveSettings> {
  late final SettingsCubit _settingsCubit = SettingsCubit(
    profileRepository: _SnapshotProfileRepository(widget.snapshot.profile),
    accountService: DioAccountService(sl<Dio>(), AuthTokenStore()),
    displayNameRepository: DioDisplayNameRepository(sl<Dio>()),
    // F5: no `remoteProfileRepository` here — this screen's own `_snapshot`
    // FutureBuilder already re-fetches `/v1/users/me` fresh on every mount
    // (`_loadSnapshot`), so `load()`'s own cross-device sync would just be a
    // redundant second round trip. Still wire the write path so this
    // cubit's `changeAvatar`/`removePhoto` are correct if ever invoked from
    // this list (today's only avatar affordance lives on `/settings/profile`).
    avatarRepository: sl.isRegistered<AvatarRepository>()
        ? sl<AvatarRepository>()
        : null,
    avatarCacheEvictor: sl.isRegistered<AvatarCacheEvictor>()
        ? sl<AvatarCacheEvictor>()
        : null,
    refreshSignals: sl.isRegistered<ProfileRefreshSignals>()
        ? sl<ProfileRefreshSignals>()
        : null,
  )..load();

  @override
  void dispose() {
    _settingsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsScreen(cubit: _settingsCubit);
  }
}

class _SnapshotProfileRepository implements ProfileRepository {
  _SnapshotProfileRepository(this._profile);

  UserProfile _profile;

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

class _SettingsAccountSnapshot {
  const _SettingsAccountSnapshot({
    required this.profile,
    required this.availableRoles,
    required this.activeRole,
  });

  final UserProfile profile;
  final List<String> availableRoles;
  final String? activeRole;

  static _SettingsAccountSnapshot fromJson(Map<String, dynamic> json) {
    final roles = _roles(json['availableRoles'] ?? json['available_roles']);
    final activeRole = _role(json['activeRole'] ?? json['active_role']);
    final availableRoles = <String>{...roles};
    if (activeRole != null) {
      availableRoles.add(activeRole);
    }
    return _SettingsAccountSnapshot(
      profile: UserProfile(
        phoneE164:
            _str(json['phoneE164'] ?? json['phone'] ?? json['phoneNumber']) ??
            '',
        name: _str(json['name'] ?? json['fullName'] ?? json['displayName']),
        photoUrl: _str(
          json['avatarUrl'] ?? json['avatar_url'] ?? json['photoUrl'],
        ),
      ),
      availableRoles: availableRoles.toList(growable: false),
      activeRole: activeRole,
    );
  }

  static List<String> _roles(Object? value) {
    if (value is! List) return const <String>[];
    final normalized = value.map(_role).whereType<String>().toSet();
    return normalized.toList(growable: false);
  }

  static String? _role(Object? value) {
    final raw = _str(value)?.toLowerCase();
    return switch (raw) {
      'client' || 'customer' || 'user' => UserRole.client.storageKey,
      'jeeber' ||
      'driver' ||
      'delivery' ||
      'deliveryman' ||
      'delivery_man' => UserRole.jeeber.storageKey,
      _ => null,
    };
  }

  static String? _str(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
