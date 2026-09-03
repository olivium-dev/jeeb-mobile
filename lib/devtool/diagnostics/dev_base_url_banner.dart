import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/base_url_source.dart';
import '../../core/config/dev_base_url.dart';
import '../../core/di/injection_container.dart';

/// `dev.base_url_override` outranks every dart-define and survives
/// `adb install -r`. Shown when it diverges; deliberately does NOT auto-clear.
class DevBaseUrlBanner extends StatelessWidget {
  const DevBaseUrlBanner({super.key, this.preferences});

  final SharedPreferences? preferences;

  @override
  Widget build(BuildContext context) {
    final prefs = preferences ?? sl<SharedPreferences>();
    final resolved = resolveBaseUrlForBuild(override: DevBaseUrl.read(prefs));
    if (!resolved.overrideDivergesFromBuild) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('devtool.baseUrlOverrideBanner'),
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Server URL override active',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 2),
          Text(
            '${resolved.value}  (build default: ${resolved.buildValue}). '
            'Survives reinstall — clear it in Chat & Push diagnostics or '
            'Server URL.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
