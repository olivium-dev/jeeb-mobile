import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../notification_prefs/application/notification_prefs_cubit.dart';
import '../../../notification_prefs/data/notification_prefs_store.dart';
import '../../../notification_prefs/presentation/notification_prefs_screen.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(
        store: sl<NotificationPrefsStore>(),
      ),
      child: const NotificationPrefsScreen(),
    );
  }
}
