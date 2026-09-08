import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection_container.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/onboarding/onboarding_cubit.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../l10n/app_localizations.dart';
import '../gateway/dev_gateway_client.dart';

class RosterUser {
  const RosterUser({
    required this.userId,
    required this.name,
    required this.role,
    required this.roles,
  });

  factory RosterUser.fromDevUser(DevUser user) => RosterUser(
    userId: user.id,
    name: user.username,
    role: user.role ?? '',
    roles: user.roles,
  );

  final String userId;
  final String name;
  final String role;
  final List<String> roles;

  bool get isJeeber => <String>[role, ...roles].any((candidate) {
    final normalized = candidate.trim().toLowerCase();
    return normalized == 'jeeber' || normalized == 'driver';
  });

  UserRole get activeRole => isJeeber ? UserRole.jeeber : UserRole.client;
}

/// Resolves the role Super Login should hand to the product app.
///
/// The all-users roster is sourced from user-management, whose registration
/// projection can still describe a dev-seeded Jeeber as customer-only. The
/// authenticated `/v1/users/me` capability view is the authority used by the
/// product shell, so prefer its complete role set and retain the roster only as
/// a fail-soft fallback.
UserRole resolveSuperLoginActiveRole(
  RosterUser user,
  Map<String, dynamic>? profile, {
  Iterable<String> tokenRoles = const <String>[],
}) {
  final rawRoles = profile?['availableRoles'] ?? profile?['available_roles'];
  final roles = <String>[
    ...tokenRoles,
    if (rawRoles is List) ...rawRoles.whereType<String>(),
  ];
  if (roles.any((role) {
    final normalized = role.trim().toLowerCase();
    return normalized == 'jeeber' || normalized == 'driver';
  })) {
    return UserRole.jeeber;
  }
  return user.activeRole;
}

/// Extracts only role claims from a JWT minted by the development gateway.
/// Malformed or opaque access tokens simply return no roles and fall back to
/// the authenticated profile/roster path.
List<String> superLoginRolesFromAccessToken(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return const <String>[];
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return const <String>[];
    final raw = payload['roles'];
    if (raw is String && raw.trim().isNotEmpty) return <String>[raw.trim()];
    if (raw is! List) return const <String>[];
    return raw
        .whereType<String>()
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toList(growable: false);
  } on FormatException {
    return const <String>[];
  }
}

class FullRosterLoginPage extends StatefulWidget {
  const FullRosterLoginPage({super.key, this.client});

  final DevGatewayClient? client;

  @override
  State<FullRosterLoginPage> createState() => _FullRosterLoginPageState();
}

class _FullRosterLoginPageState extends State<FullRosterLoginPage> {
  final Dio _dio = sl<Dio>();
  final AuthTokenStore _tokenStore = sl<AuthTokenStore>();
  final TextEditingController _search = TextEditingController();
  late final DevGatewayClient _client;

  late Future<List<RosterUser>> _roster = _fetchRoster();
  String _query = '';
  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? DevGatewayClient();
  }

  Future<List<RosterUser>> _fetchRoster() async {
    final users = await _client.fetchSuperLoginRoster();
    return users
        .map(RosterUser.fromDevUser)
        .where((u) => u.userId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _loginAs(RosterUser user) async {
    setState(() => _busyUserId = user.userId);
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/tokens',
        // Resolve roles from the gateway's durable user projection. The public
        // roster can lag that projection and advertise a freshly seeded Jeeber
        // as customer-only; forwarding those stale roles mints the wrong
        // session even though the gateway already knows the correct roles.
        data: <String, dynamic>{'userId': user.userId},
      );
      final access = res.data?['accessToken'] as String?;
      final refresh = res.data?['refreshToken'] as String?;
      if (access == null || access.isEmpty) {
        throw const FormatException('mint returned no accessToken');
      }
      await _tokenStore.save(
        accessToken: access,
        refreshToken: refresh ?? access,
        userId: user.userId,
      );
      final tokenRoles = superLoginRolesFromAccessToken(access);
      var activeRole = resolveSuperLoginActiveRole(
        user,
        null,
        tokenRoles: tokenRoles,
      );
      try {
        final profile = await _dio.get<Map<String, dynamic>>(
          '/v1/users/me',
          options: Options(
            headers: <String, String>{'Authorization': 'Bearer $access'},
          ),
        );
        activeRole = resolveSuperLoginActiveRole(
          user,
          profile.data,
          tokenRoles: tokenRoles,
        );
      } on DioException {
        // The roster remains a useful fallback for normal accounts. The
        // product app will retry its own capability sync after launch.
      }
      final preferences = sl<SharedPreferences>();
      await preferences.setBool(OnboardingCubit.completedKey, true);
      // The Dev Tool is an account switcher, so its handoff must update both
      // the credentials and the active role. Leaving a prior client's role in
      // SharedPreferences makes Jeeber child routes render owner/client UI
      // even when the newly selected account has the driver capability.
      await preferences.setString(RoleCubit.rolePrefKey, activeRole.storageKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged in as ${user.name} (${activeRole.storageKey}). Open the Jeeb app icon '
            '— it now shares this session.',
          ),
        ),
      );
      Navigator.of(context).maybePop();
    } on DioException catch (e) {
      _error('Login failed: ${e.response?.statusCode ?? e.message}');
    } catch (e) {
      _error('Login failed: $e');
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Login Plus — all users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name or role',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<RosterUser>>(
              future: _roster,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  final described = _describeRosterError(context, snap.error!);
                  return _RosterError(
                    message: described.message,
                    detail: described.detail,
                    onRetry: () => setState(() => _roster = _fetchRoster()),
                  );
                }
                final all = snap.data ?? const <RosterUser>[];
                final users = _query.isEmpty
                    ? all
                    : all
                          .where(
                            (u) =>
                                u.name.toLowerCase().contains(_query) ||
                                u.role.toLowerCase().contains(_query),
                          )
                          .toList(growable: false);
                if (users.isEmpty) {
                  return const Center(child: Text('No users'));
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final busy = _busyUserId == u.userId;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text(u.name.isEmpty ? u.userId : u.name),
                      subtitle: Text(u.role),
                      trailing: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      onTap: _busyUserId == null ? () => _loginAs(u) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

({String message, String? detail}) _describeRosterError(
  BuildContext context,
  Object error,
) {
  final l10n = AppLocalizations.of(context);
  if (error is DevGatewayException) {
    final status = error.statusCode;
    switch (status) {
      case null:
        return (
          message: l10n.internalDevToolRosterErrorUnreachable,
          detail: error.message,
        );
      case 404:
        return (
          message: l10n.internalDevToolRosterErrorDisabled,
          detail: error.message,
        );
      case 401:
      case 403:
        return (
          message: l10n.internalDevToolRosterErrorRejected,
          detail: error.message,
        );
      case 502:
      case 503:
        return (
          message: l10n.internalDevToolRosterErrorUpstream,
          detail: error.message,
        );
      default:
        return (
          message: l10n.internalDevToolRosterErrorGeneric(status),
          detail: error.message,
        );
    }
  }
  return (message: l10n.internalDevToolRosterErrorUnknown, detail: '$error');
}

class _RosterError extends StatelessWidget {
  const _RosterError({
    required this.message,
    required this.onRetry,
    this.detail,
  });

  final String message;
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(message, textAlign: TextAlign.center),
          ),
          if (detail != null && detail!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
