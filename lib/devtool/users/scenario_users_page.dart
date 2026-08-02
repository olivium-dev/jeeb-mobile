import 'package:flutter/material.dart';

import '../gateway/dev_gateway_client.dart';

class ScenarioUsersPage extends StatefulWidget {
  const ScenarioUsersPage({super.key});

  @override
  State<ScenarioUsersPage> createState() => _ScenarioUsersPageState();
}

class _UserScenario {
  const _UserScenario(this.label, this.role, this.scenario);

  final String label;
  final String role;
  final String scenario;
}

const List<_UserScenario> _scenarios = [
  _UserScenario('Regular customer', 'client', 'regular'),
  _UserScenario('Jeeber', 'jeeber', 'regular'),
  _UserScenario('Suspended', 'client', 'suspended'),
  _UserScenario('KYC pending', 'client', 'kyc-pending'),
  _UserScenario('Funded wallet', 'client', 'funded-wallet'),
  _UserScenario('Admin', 'admin', 'regular'),
];

class _ScenarioUsersPageState extends State<ScenarioUsersPage> {
  final DevGatewayClient _client = DevGatewayClient();

  _UserScenario _selectedScenario = _scenarios.first;
  bool _seeding = false;
  DevUser? _lastSeeded;

  Future<List<DevUser>>? _rosterFuture;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  void _loadRoster() {
    setState(() {
      _rosterFuture = _client.listUsers();
    });
  }

  Future<void> _createUser() async {
    setState(() => _seeding = true);
    try {
      final user = await _client.seedUser(
        role: _selectedScenario.role,
        scenario: _selectedScenario.scenario,
      );
      if (!mounted) return;
      setState(() => _lastSeeded = user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${_selectedScenario.label}: ${user.username} '
            '(${user.id})',
          ),
        ),
      );
      _loadRoster();
    } on DevGatewayException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scenario Users')),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadRoster();
          await _rosterFuture;
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Create user', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<_UserScenario>(
              initialValue: _selectedScenario,
              decoration: const InputDecoration(
                labelText: 'Scenario',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final scenario in _scenarios)
                  DropdownMenuItem(
                    value: scenario,
                    child: Text(scenario.label),
                  ),
              ],
              onChanged: _seeding
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _selectedScenario = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _seeding ? null : _createUser,
              icon: _seeding
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add),
              label: const Text('Create user'),
            ),
            if (_lastSeeded != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Last created',
                          style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 4),
                      SelectableText('id: ${_lastSeeded!.id}'),
                      SelectableText('username: ${_lastSeeded!.username}'),
                      if (_lastSeeded!.role != null)
                        SelectableText('role: ${_lastSeeded!.role}'),
                      SelectableText('status: ${_lastSeeded!.status}'),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text('Roster', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            _buildRoster(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoster() {
    return FutureBuilder<List<DevUser>>(
      future: _rosterFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          final message =
              error is DevGatewayException ? error.message : error.toString();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _loadRoster,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final users = snapshot.data ?? const <DevUser>[];
        if (users.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No users seeded yet.'),
          );
        }
        return Column(
          children: [
            for (final user in users)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(user.username.isEmpty ? user.id : user.username),
                  subtitle: Text(
                    'id: ${user.id}'
                    '${user.role != null ? ' • role: ${user.role}' : ''}'
                    ' • status: ${user.status}',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
