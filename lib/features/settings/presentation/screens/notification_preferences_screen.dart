import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../notification_prefs/application/notification_prefs_cubit.dart';
import '../../../notification_prefs/domain/notification_prefs_repository.dart';
import '../../../notification_prefs/presentation/notification_prefs_screen.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key, this.repository});

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
