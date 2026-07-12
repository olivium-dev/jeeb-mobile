import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/role/user_role.dart';
import '../../../../core/session/profile_refresh_signals.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile_name/data/dio_display_name_repository.dart';
import '../../application/settings_cubit.dart';
import '../../data/dio_account_service.dart';
import '../../domain/profile_repository.dart';
import '../../domain/user_profile.dart';
import 'settings_screen.dart';

/// Live-backed settings entry used by the app route.
///
/// The generic [SettingsScreen] remains a testable presentation surface with
/// injectable seams. This host supplies those seams from the real gateway:
/// `GET /v1/users/me` for profile metadata.
///
/// JEBV4-204 (E9): the in-app role SWITCH was removed (the additive 5-tab shell
/// + auto-activation supersede it), so this host no longer wires a role toggle.
// ORPHAN (JEBV4-227, verified 2026-07-12): legacy settings hub, no forward-nav entry point (customer-profile is the live surface) — see docs/project-understanding/reconciliation/orphans.md
class LiveSettingsScreen extends StatefulWidget {
  const LiveSettingsScreen({super.key});

  @override
  State<LiveSettingsScreen> createState() => _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<LiveSettingsScreen> {
  late Future<_SettingsAccountSnapshot> _snapshot = _loadSnapshot();

  Future<_SettingsAccountSnapshot> _loadSnapshot() async {
    final response = await sl<Dio>().get<Map<String, dynamic>>('/v1/users/me');
    return _SettingsAccountSnapshot.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  void _retry() {
    setState(() => _snapshot = _loadSnapshot());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<_SettingsAccountSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return _LoadedLiveSettings(snapshot: snapshot.requireData);
        }
        if (snapshot.hasError) {
          return _LiveSettingsError(onRetry: _retry);
        }
        return Scaffold(
          appBar: OMDSAppBar(title: l10n.settingsTitle),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
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
    // Real Dio-backed account service (the test-only `FakeAccountService`
    // lives under `test/support/` and must never be referenced from `lib/`).
    // Shares the same DI gateway Dio as the profile read above so destructive
    // settings actions hit the live jeeb-gateway, not an always-success stub.
    accountService: DioAccountService(sl<Dio>(), AuthTokenStore()),
    // Profile-name lane: a saved name is ALSO mirrored to the gateway via
    // `PUT /api/User/profile` (`username`) so getMe / receipts / chat headers
    // carry the real name, and live greetings re-pull on the signal.
    displayNameRepository: DioDisplayNameRepository(sl<Dio>()),
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

class _LiveSettingsError extends StatelessWidget {
  const _LiveSettingsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.settingsTitle),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: Sizes.sixXLarge,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: Spacing.medium),
              Text(
                l10n.settingsNetworkError,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: Spacing.large),
              FilledButton(onPressed: onRetry, child: Text(l10n.kycRetry)),
            ],
          ),
        ),
      ),
    );
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
