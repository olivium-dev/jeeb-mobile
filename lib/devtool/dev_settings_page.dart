import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/dev_base_url.dart';
import '../core/di/injection_container.dart';
import '../core/network/mock_gateway_client.dart';

/// The MSI dev/staging gateway. Origin-only (scheme + host + port, no `/v1`) —
/// the anti-drift contract in `AppConfig.gatewayBaseUrl` is that every request
/// path carries exactly one `/v1`, so a `/v1` here would double to `/v1/v1`.
const String kMsiGatewayBaseUrl = 'http://192.168.2.39:10090';

/// Owner ruling, 2026-07-31 (`OWNER-DECISIONS.md`, DEVICE-E2E rulings #2):
/// **add MSI as a preset.** Neither shipped preset is the dev backend —
/// `10.0.2.2:4010` is the emulator loopback to the Express mock and
/// `api.jeeb.app` is NXDOMAIN and out of scope — so the only URL that actually
/// works had to be hand-typed at the start of every device session. A stale
/// `http://127.0.0.1:9000` left over from a dead `adb reverse` tunnel then
/// **silently broke every backend call** and cost an entire device window,
/// presenting as product bugs: empty profiles, empty lists,
/// `[push][register] FAILED`.
///
/// MSI is FIRST so it is the leftmost chip — the one a tired operator taps.
///
/// **The ruling's second half — "make it the dev default" — is deliberately NOT
/// implemented here, and this is the reason.** The build default is
/// `MockGatewayClient.mockBaseUrl`, i.e. `--dart-define=JEEB_MOCK_BASE_URL`,
/// and MB1's own device round sets that to `http://127.0.0.1:9000` ON PURPOSE:
/// that is the `adb reverse` hop into the api-recorder, which then proxies to
/// MSI. Hard-defaulting the app to MSI would route around the recorder and
/// silently void every capture-class gate row in the batch. Changing the
/// default belongs in the DevTool batch that owns `dev_base_url.dart`, with the
/// recorder path considered; it is out of MB1's member list.
const List<String> kDevServerUrlPresets = <String>[
  kMsiGatewayBaseUrl,
  'http://10.0.2.2:4010',
  'https://api.jeeb.app/v1',
];

/// DT-08 / F4 — change the gateway base URL at runtime. Writes a persisted
/// override (see [DevBaseUrl]) that the DI graph reads when building `Dio`;
/// applies on the next app start.
class ServerUrlPage extends StatefulWidget {
  const ServerUrlPage({super.key});

  @override
  State<ServerUrlPage> createState() => _ServerUrlPageState();
}

class _ServerUrlPageState extends State<ServerUrlPage> {
  final SharedPreferences _prefs = sl<SharedPreferences>();
  late final TextEditingController _controller =
      TextEditingController(text: DevBaseUrl.read(sl<SharedPreferences>()) ?? '');

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
      const SnackBar(content: Text('Reset to build default. Restart to apply.')),
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
          Text('Currently pointing at:',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(_effective,
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Override base URL',
              hintText: 'https://staging.jeeb.app/v1',
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
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(height: 8),
          OutlinedButton(
              onPressed: _reset, child: const Text('Reset to default')),
        ],
      ),
    );
  }
}

/// DT-08 / F5 — clear ALL local data on the phone (factory reset): wipes secure
/// storage (auth tokens) and SharedPreferences (onboarding flags, base-URL
/// override, dev-seam). Shows a confirm dialog first.
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
      content: Text('Local data cleared. Restart the app for a clean first run.'),
    ),
  );
}
