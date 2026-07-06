import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../notification_prefs/application/notification_prefs_cubit.dart';
import '../../../notification_prefs/domain/notification_prefs_repository.dart';
import '../../../notification_prefs/presentation/notification_prefs_screen.dart';

/// Wrapper that creates the [NotificationPrefsCubit] with the DI-registered
/// [NotificationPrefsRepository] and provides it to [NotificationPrefsScreen].
///
/// T-MOB-026: cubit is now server-first (GET on mount, debounced PATCH on
/// toggle) rather than SharedPreferences-only.
class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key, this.repository});

  /// DT-04 catalog / test seam: overrides the DI-registered repository.
  /// Production callers leave this null and get the unchanged
  /// `sl<NotificationPrefsRepository>()` resolution.
  final NotificationPrefsRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(
        repository: repository ?? sl<NotificationPrefsRepository>(),
      ),
      child: const NotificationPrefsScreen(),
    );
  }
}
