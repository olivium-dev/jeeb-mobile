import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/dev_base_url.dart';
import '../core/di/injection_container.dart';
import '../core/network/auth_token_store.dart';
import '../core/network/mock_gateway_client.dart';

const String kMsiGatewayBaseUrl = kDevelopmentGatewayBaseUrl;

const List<String> kDevServerUrlPresets = <String>[
  kMsiGatewayBaseUrl,
  kStagingGatewayBaseUrl,
  'http://10.0.2.2:4010',
];

class ServerUrlPage extends StatefulWidget {
  const ServerUrlPage({super.key});

  @override
  State<ServerUrlPage> createState() => _ServerUrlPageState();
}

class _ServerUrlPageState extends State<ServerUrlPage> {
  final SharedPreferences _prefs = sl<SharedPreferences>();
  late final TextEditingController _controller = TextEditingController(
    text: DevBaseUrl.read(sl<SharedPreferences>()) ?? '',
  );
  late final String _runningBaseUrl = sl.isRegistered<Dio>()
      ? sl<Dio>().options.baseUrl
      : MockGatewayClient.mockBaseUrl;
  bool _applying = false;

  String get _effective =>
      DevBaseUrl.read(_prefs) ?? MockGatewayClient.mockBaseUrl;

  DevBackendEnvironment? get _selectedEnvironment =>
      DevBackendEnvironment.fromBaseUrl(_effective);

  Future<void> _selectEnvironment(DevBackendEnvironment environment) async {
    await _apply(environment.baseUrl, environment: environment);
  }

  Future<void> _saveCustom() => _apply(_controller.text);

  Future<void> _apply(
    String rawUrl, {
    DevBackendEnvironment? environment,
  }) async {
    final url = DevBaseUrl.canonicalOrigin(rawUrl);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter an HTTP(S) origin without a path or credentials.',
          ),
        ),
      );
      return;
    }

    final previous = _effective;
    final appliedUrl = environment?.baseUrl ?? url;
    final changed =
        DevBaseUrl.normalize(previous) != DevBaseUrl.normalize(appliedUrl);
    setState(() => _applying = true);
    try {
      if (changed && sl.isRegistered<AuthTokenStore>()) {
        // Clear before publishing a new endpoint. If keychain deletion fails,
        // the switch aborts and the old endpoint remains selected.
        await sl<AuthTokenStore>().clear();
      }

      if (environment == null) {
        await DevBaseUrl.write(_prefs, url);
      } else {
        await DevBaseUrl.selectEnvironment(_prefs, environment);
      }

      if (!mounted) return;
      _controller.text = appliedUrl;
      setState(() {});
      final label = environment?.label ?? 'Custom gateway';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? '$label selected. Restart the app to apply it; the previous '
                      'session was cleared.'
                : '$label is already selected.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Environment switch failed; the current selection was kept.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _reset() async {
    if (_applying) return;
    final previous = _effective;
    final defaultUrl = MockGatewayClient.mockBaseUrl;
    final changed =
        DevBaseUrl.normalize(previous) != DevBaseUrl.normalize(defaultUrl);
    setState(() => _applying = true);
    try {
      if (changed && sl.isRegistered<AuthTokenStore>()) {
        await sl<AuthTokenStore>().clear();
      }
      await DevBaseUrl.write(_prefs, null);
      if (!mounted) return;
      _controller.clear();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed
                ? 'Build default selected. Restart the app to apply it; the '
                      'previous session was cleared.'
                : 'Build default is already selected.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset failed; the current selection was kept.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Environment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Selected environment',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final environment in DevBackendEnvironment.values) ...[
            Card(
              child: ListTile(
                key: ValueKey('devtool.environment.${environment.id}'),
                enabled: !_applying,
                selected: _selectedEnvironment == environment,
                leading: Icon(
                  environment == DevBackendEnvironment.development
                      ? Icons.developer_mode
                      : Icons.cloud_outlined,
                ),
                title: Text(environment.label),
                subtitle: Text(
                  '${environment.description}\n${environment.baseUrl}',
                ),
                isThreeLine: true,
                trailing: _selectedEnvironment == environment
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.chevron_right),
                onTap: () => _selectEnvironment(environment),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Text(
            'Selected for next launch:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          SelectableText(
            _effective,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Running now: $_runningBaseUrl',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (DevBaseUrl.normalize(_effective) !=
              DevBaseUrl.normalize(_runningBaseUrl)) ...[
            const SizedBox(height: 8),
            const Card(
              child: ListTile(
                leading: Icon(Icons.restart_alt),
                title: Text('Restart required'),
                subtitle: Text(
                  'Restart the app before using the selected environment.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Advanced', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('devtool.environment.customUrl'),
            controller: _controller,
            enabled: !_applying,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Custom gateway URL',
              hintText: 'https://gateway.example.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in kDevServerUrlPresets)
                ActionChip(
                  label: Text(preset),
                  onPressed: _applying
                      ? null
                      : () => setState(() => _controller.text = preset),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('devtool.environment.applyCustom'),
            onPressed: _applying ? null : _saveCustom,
            child: Text(_applying ? 'Applying…' : 'Apply custom URL'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _applying ? null : _reset,
            child: const Text('Reset to build default'),
          ),
        ],
      ),
    );
  }
}

Future<void> showClearLocalDataDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Clear local data?'),
      content: const Text(
        'Wipes auth tokens and all app preferences on this device, returning '
        'the app to a first-run state. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await const FlutterSecureStorage().deleteAll();
  await sl<SharedPreferences>().clear();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Local data cleared. Restart the app for a clean first run.',
      ),
    ),
  );
}
