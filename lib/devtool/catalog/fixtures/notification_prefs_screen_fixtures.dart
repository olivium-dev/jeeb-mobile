/// Fixtures for NotificationPrefsScreen (JM-058, D64).
/// Re-exports fixtures from notification_preferences_screen_fixtures.dart.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/notification_prefs/application/notification_prefs_cubit.dart';
import '../../../features/notification_prefs/domain/notification_prefs_model.dart';
import '../../../features/notification_prefs/domain/notification_prefs_repository.dart';

export 'notification_preferences_screen_fixtures.dart';

/// Catalog Loaded state: offers & order status ON, wallet & marketing OFF.
const NotificationPrefs notificationPrefsScreenCatalogPrefs = NotificationPrefs(
  categories: NotificationCategoryPrefs(
    offers: true,
    orderStatus: true,
    wallet: false,
    marketing: false,
  ),
);

/// Mounts NotificationPrefsScreen over NotificationPrefsCubit (initState seam).
Widget notificationPrefsScreenSeeded({
  required NotificationPrefsRepository repository,
  required Widget child,
}) {
  return BlocProvider<NotificationPrefsCubit>(
    create: (_) => NotificationPrefsCubit(repository: repository),
    child: child,
  );
}
