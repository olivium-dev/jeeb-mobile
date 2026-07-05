// Isolated native UI test — NotificationPrefsScreen (settings-notifications,
// JM-058). The settings-route wrapper (NotificationPreferencesScreen) resolves
// its repository from GetIt (`sl<>()`), which is unconfigured under the harness;
// so we mirror the widget test instead — provide a NotificationPrefsCubit backed
// by an in-memory repo and pump the presentation screen directly. The cubit
// loads in initState, landing on the four category toggles + the locked
// transactional row. Covers English and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_model.dart';
import 'package:jeeb_mobile/features/notification_prefs/domain/notification_prefs_repository.dart';
import 'package:jeeb_mobile/features/notification_prefs/presentation/notification_prefs_screen.dart';

import '../support/screen_harness.dart';

/// In-memory prefs repo serving the default snapshot (mirrors the widget test).
class _FakePrefsRepo implements NotificationPrefsRepository {
  @override
  Future<NotificationPrefs> fetch() async => const NotificationPrefs();

  @override
  Future<NotificationPrefs> save(NotificationCategoryPrefs categories) async =>
      NotificationPrefs(categories: categories);
}

Widget _screen() => BlocProvider<NotificationPrefsCubit>(
      create: (_) => NotificationPrefsCubit(repository: _FakePrefsRepo()),
      child: const NotificationPrefsScreen(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('settings-notifications: category toggles loaded (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'settings-notifications__idle',
    );
  });

  testWidgets('settings-notifications: category toggles loaded (ar)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'settings-notifications__ar',
      locale: const Locale('ar'),
    );
  });
}
