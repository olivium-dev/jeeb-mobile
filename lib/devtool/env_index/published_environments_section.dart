import 'package:flutter/material.dart';

import 'env_index_client.dart';

/// Server URL page section listing environments from the published index.
/// Tapping an entry fills the override field; saving stays with the page.
class PublishedEnvironmentsSection extends StatefulWidget {
  const PublishedEnvironmentsSection({
    required this.onPick,
    this.fetcher,
    super.key,
  });

  final ValueChanged<String> onPick;

  /// Test seam; defaults to [EnvIndexClient.fetch].
  final Future<List<EnvIndexEntry>> Function()? fetcher;

  @override
  State<PublishedEnvironmentsSection> createState() =>
      _PublishedEnvironmentsSectionState();
}

class _PublishedEnvironmentsSectionState
    extends State<PublishedEnvironmentsSection> {
  late Future<List<EnvIndexEntry>> _future = _load();

  Future<List<EnvIndexEntry>> _load() =>
      (widget.fetcher ?? EnvIndexClient().fetch)();

  void _retry() => setState(() {
    _future = _load();
  });

  String _caveat(EnvIndexEntry env) => [
    if (env.reachability == 'lan') 'LAN only',
    if (env.cleartext) 'cleartext — dev flavor only',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Published environments',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refetch environment index',
              onPressed: _retry,
            ),
          ],
        ),
        FutureBuilder<List<EnvIndexEntry>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Could not load the environment index: ${snapshot.error}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              );
            }
            final environments = snapshot.data ?? const [];
            if (environments.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('The environment index is empty.'),
              );
            }
            return Column(
              children: [
                for (final env in environments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(env.label),
                    subtitle: Text(
                      [
                        env.gatewayBaseUrl,
                        if (_caveat(env).isNotEmpty) _caveat(env),
                        if (env.notes != null) env.notes!,
                      ].join('\n'),
                    ),
                    trailing: env.cleartext || env.reachability == 'lan'
                        ? const Icon(Icons.warning_amber_outlined)
                        : null,
                    onTap: () => widget.onPick(env.gatewayBaseUrl),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
