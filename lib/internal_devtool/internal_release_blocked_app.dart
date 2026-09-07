import 'package:flutter/material.dart';
import '../core/widgets/jeeb/jeeb_empty_state.dart';

import '../core/theme/app_theme.dart';

/// Fail-closed surface for an invalid internal-release policy combination.
///
/// This is intentionally not a QA tool. The valid staging launcher is routed
/// into the original full Jeeber Dev Tool by `main_android_internal.dart`.
class InternalReleaseBlockedApp extends StatelessWidget {
  const InternalReleaseBlockedApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.midnight(),
    darkTheme: AppTheme.midnight(),
    themeMode: ThemeMode.dark,
    home: const Scaffold(
      body: SafeArea(
        child: JeebEmptyState(
          identifier: 'internal_release_blocked_error',
          status: JeebEmptyStateStatus.error,
          reason: JeebEmptyStateReason.failed,
          variant: JeebEmptyStateVariant.parcel,
          headline: 'Internal build blocked',
          body:
              "This build's signed internal-release policy does not match "
              'the staging contract.',
        ),
      ),
    ),
  );
}
