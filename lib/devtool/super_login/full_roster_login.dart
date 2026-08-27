import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/di/injection_container.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/onboarding/onboarding_cubit.dart';
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
        data: <String, dynamic>{
          'userId': user.userId,
          if (user.roles.isNotEmpty) 'roles': user.roles,
        },
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
      await sl<SharedPreferences>().setBool(OnboardingCubit.completedKey, true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged in as ${user.name} (${user.role}). Open the Jeeb app icon '
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
                        .where((u) =>
                            u.name.toLowerCase().contains(_query) ||
                            u.role.toLowerCase().contains(_query))
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
