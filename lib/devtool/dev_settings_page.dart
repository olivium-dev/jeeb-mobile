import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/dev_base_url.dart';
import '../core/di/injection_container.dart';
import '../core/network/mock_gateway_client.dart';
import 'env_index/env_index_client.dart';
import 'env_index/published_environments_section.dart';

const String kConfiguredDevGatewayBaseUrl = String.fromEnvironment(
  'JEEB_DEV_GATEWAY_BASE_URL',
  defaultValue: 'https://gateway.dev.invalid',
);
const String kConfiguredDevMockBaseUrl = String.fromEnvironment(
  'JEEB_DEV_MOCK_BASE_URL',
  defaultValue: 'https://mock.dev.invalid',
);

const List<String> kDevServerUrlPresets = <String>[
  kConfiguredDevGatewayBaseUrl,
  kConfiguredDevMockBaseUrl,
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

  String get _effective =>
      DevBaseUrl.read(_prefs) ?? MockGatewayClient.mockBaseUrl;

  Future<void> _save() async {
    await DevBaseUrl.write(_prefs, _controller.text);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved. Restart the app to apply.')),
    );
  }

  Future<void> _reset() async {
    await DevBaseUrl.write(_prefs, null);
    if (!mounted) return;
    _controller.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset to build default. Restart to apply.'),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server URL')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Currently pointing at:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          SelectableText(
            _effective,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Override base URL',
              hintText: 'https://gateway.example',
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
                  onPressed: () => _controller.text = preset,
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (EnvIndexClient.isConfigured)
            PublishedEnvironmentsSection(
              onPick: (url) => setState(() => _controller.text = url),
            )
          else
            Text(
              'Published environment index disabled '
              '(JEEB_ENV_INDEX_KEY not set).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _reset,
            child: const Text('Reset to default'),
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
