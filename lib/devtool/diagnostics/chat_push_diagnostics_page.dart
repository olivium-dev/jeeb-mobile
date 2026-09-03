import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/base_url_source.dart';
import '../../core/config/dev_base_url.dart';
import '../../core/di/injection_container.dart';
import '../../core/diagnostics/chat_diagnostics.dart';
import '../../core/firebase/jeeb_firestore.dart';
import '../../core/realtime/realtime_socket_policy.dart';

/// Read-only snapshot of everything that decides whether chat and push can
/// work on this install. Every value here has silently disagreed with its
/// neighbour in a real outage at least once.
class ChatPushDiagnosticsPage extends StatefulWidget {
  const ChatPushDiagnosticsPage({super.key, this.seamChannel});

  /// Android channel that reads `/data/local/tmp/jeeb-dev-seam.json`.
  final MethodChannel? seamChannel;

  @override
  State<ChatPushDiagnosticsPage> createState() =>
      _ChatPushDiagnosticsPageState();
}

class _ChatPushDiagnosticsPageState extends State<ChatPushDiagnosticsPage> {
  static const MethodChannel _defaultSeamChannel = MethodChannel(
    'com.olivium.jeeb/dev_seam',
  );

  SharedPreferences get _prefs => sl<SharedPreferences>();

  String? _fcmToken;
  String _fcmStatus = 'reading…';
  String _seamStatus = 'reading…';

  @override
  void initState() {
    super.initState();
    _loadFcmToken();
    _loadSeamPresence();
  }

  Future<void> _loadFcmToken() async {
    String? token;
    var status = 'no token';
    try {
      token = await FirebaseMessaging.instance.getToken();
      status = token == null || token.isEmpty ? 'no token' : 'obtained';
    } catch (error) {
      status = 'failed: ${error.runtimeType}';
    }
    if (!mounted) return;
    setState(() {
      _fcmToken = token;
      _fcmStatus = status;
    });
  }

  Future<void> _loadSeamPresence() async {
    final channel = widget.seamChannel ?? _defaultSeamChannel;
    var status = 'absent';
    try {
      final raw = await channel.invokeMethod<String>('readSeamFile');
      status = raw == null || raw.trim().isEmpty
          ? 'absent'
          : 'PRESENT (${raw.length} bytes) — survives uninstall, can force a '
                'stale token into every debug boot';
    } on MissingPluginException {
      status = 'not available on this platform';
    } catch (error) {
      status = 'unreadable: ${error.runtimeType}';
    }
    if (!mounted) return;
    setState(() => _seamStatus = status);
  }

  Future<void> _clearOverride() async {
    await DevBaseUrl.write(_prefs, null);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Override cleared. Restart the app to apply.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveBaseUrlForBuild(
      override: DevBaseUrl.read(_prefs),
    );
    final socketUri = const RealtimeSocketPolicy().configuredUri();
    final restHost = Uri.tryParse(resolved.value)?.host ?? '';
    final socketHost = socketUri?.host ?? '';
    final hostsAgree =
        restHost.isNotEmpty && socketHost.isNotEmpty && restHost == socketHost;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat & Push diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (resolved.isOverridden)
            _OverrideBanner(
              resolved: resolved,
              onClear: _clearOverride,
            ),
          _Section(
            title: 'REST base URL',
            rows: <_Row>[
              _Row('Effective', resolved.value),
              _Row('Source', resolved.source.label),
              _Row('Build default', resolved.buildValue),
            ],
          ),
          _Section(
            title: 'Realtime socket (compile-time only)',
            warning: hostsAgree
                ? null
                : 'Socket host "$socketHost" does not match REST host '
                      '"$restHost". JEEB_REALTIME_SOCKET_URL is fixed at build '
                      'time, so a Server URL switch never moves it — chat and '
                      'live tracking keep dialling the old backend, silently.',
            rows: <_Row>[
              _Row('JEEB_REALTIME_SOCKET_URL', socketUri?.toString() ?? 'unset'),
              _Row('Matches REST host', hostsAgree ? 'yes' : 'NO'),
            ],
          ),
          _Section(
            title: 'Firebase',
            rows: <_Row>[
              _Row('Apps initialised', '${Firebase.apps.length}'),
              _Row('Project id', _firebaseValue((o) => o.projectId)),
              _Row('Package / bundle', _firebaseValue(_packageOf)),
              _Row('App id', _firebaseValue((o) => o.appId)),
              _Row('Sender id', _firebaseValue((o) => o.messagingSenderId)),
            ],
          ),
          _Section(
            title: 'Firestore',
            rows: <_Row>[
              const _Row('Database id', JeebFirestore.databaseId),
              _Row(
                'Uses contract default',
                JeebFirestore.usesDefaultDatabase ? 'yes' : 'NO',
              ),
              _Row('Resolved app', _firestoreApp()),
            ],
          ),
          _Section(
            title: 'Push registration',
            rows: <_Row>[
              _Row('FCM token', _maskToken(_fcmToken)),
              _Row('Token status', _fcmStatus),
              ..._registrationRows(),
            ],
          ),
          _Section(
            title: 'Dev seam file',
            rows: <_Row>[
              _Row('/data/local/tmp/jeeb-dev-seam.json', _seamStatus),
            ],
          ),
          const SizedBox(height: 8),
          const _ChatDegradationList(),
        ],
      ),
    );
  }

  List<_Row> _registrationRows() {
    final last = PushRegistrationDiagnostics.last;
    if (last == null) {
      return const <_Row>[_Row('Last registration', 'none this session')];
    }
    return <_Row>[
      _Row('Last registration', last.succeeded ? 'OK' : 'FAILED'),
      _Row('Status', last.status?.toString() ?? last.error ?? 'unknown'),
      _Row('Reason', last.reason),
      _Row('At', last.at.toIso8601String()),
    ];
  }

  String _firestoreApp() {
    try {
      return JeebFirestore.instance().app.name;
    } catch (error) {
      return 'unavailable (${error.runtimeType})';
    }
  }

  static String _firebaseValue(String? Function(FirebaseOptions) read) {
    if (Firebase.apps.isEmpty) return 'no Firebase app';
    try {
      return read(Firebase.app().options) ?? 'unset';
    } catch (error) {
      return 'unavailable (${error.runtimeType})';
    }
  }

  static String? _packageOf(FirebaseOptions options) =>
      options.androidClientId ?? options.iosBundleId;

  static String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'none';
    if (token.length <= 12) return '••••';
    return '${token.substring(0, 6)}…${token.substring(token.length - 6)}';
  }
}

class _OverrideBanner extends StatelessWidget {
  const _OverrideBanner({required this.resolved, required this.onClear});

  final ResolvedBaseUrl resolved;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Server URL override is ACTIVE',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This app is talking to ${resolved.value}, not the build default '
              '${resolved.buildValue}. The override lives in SharedPreferences '
              '(${DevBaseUrl.prefsKey}) and survives a reinstall.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const ValueKey('devtool.diagnostics.clearOverride'),
              onPressed: onClear,
              child: const Text('Clear override'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatDegradationList extends StatelessWidget {
  const _ChatDegradationList();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ChatDiagnosticEvent>>(
      valueListenable: ChatDiagnostics.listenable,
      builder: (context, events, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chat degradations (${events.length})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                TextButton(
                  onPressed: events.isEmpty ? null : ChatDiagnostics.clear,
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'None recorded. Open a chat thread to exercise the chain.',
                ),
              )
            else
              for (final event in events.reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(
                    '${event.at.toIso8601String()}  ${event.line}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows, this.warning});

  final String title;
  final List<_Row> rows;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      row.label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      row.value,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (warning != null) ...[
            const SizedBox(height: 6),
            Text(
              warning!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
