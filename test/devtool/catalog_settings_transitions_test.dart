import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/settings_screen_fixtures.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_cubit.dart';
import 'package:jeeb_mobile/features/notification_prefs/application/notification_prefs_state.dart';
import 'package:jeeb_mobile/features/notification_prefs/presentation/notification_prefs_screen.dart';
import 'package:jeeb_mobile/features/settings/application/settings_state.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../support/load_test_fonts.dart';
import '../support/midnight_test_harness.dart';

Widget _state(String feature, String screen, String label) => Builder(
  builder: kScreenCatalog
      .singleWhere((e) => e.feature == feature && e.screen == screen)
      .states
      .singleWhere((s) => s.label == label)
      .builder,
);

void main() {
  setUpAll(loadCatalogCaptureFonts);
  for (final locale in kFailureLocales) {
    for (final scenario in <String>['deletion', 'profile', 'notification']) {
      testWidgets(
        'settings catalog $scenario transition: ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          final label = switch (scenario) {
            'deletion' => 'Loaded — Deletion Pending',
            'profile' => 'Save failed — the optimistic name rolls back (LR-15)',
            _ => 'Notification write failed (F11)',
          };
          await tester.pumpWidget(
            wrapMidnight(
              _state('settings', 'SettingsScreen', label),
              locale: locale,
              scrollable: false,
            ),
          );
          await pumpPastFakeLatency(tester);
          expect(tester.takeException(), isNull);
          final screen = find.byType(SettingsScreen);
          final cubit = tester.widget<SettingsScreen>(screen).cubit!;
          final copy = AppLocalizations.of(tester.element(screen));
          expect(cubit.state.status, SettingsStatus.loaded);
          if (scenario == 'deletion') {
            expect(cubit.state.deletionPending, isTrue);
            expect(
              cubit.state.profile.name,
              SettingsScreenPreviewFixtures.pendingName,
            );
            expect(find.text(copy.accountDeletePending), findsOneWidget);
            final delete = tester.widget<TextButton>(
              find.byKey(const Key('settings-row-delete-account')),
            );
            expect(delete.onPressed, isNull);
          } else {
            expect(cubit.state.error, isA<AppFailure>());
            expect(find.byType(SnackBar), findsOneWidget);
            expect(
              find.text(
                scenario == 'profile'
                    ? copy.settingsProfileSaveFailed
                    : copy.settingsNotificationsSaveFailed,
              ),
              findsOneWidget,
            );
            if (scenario == 'profile') {
              expect(cubit.state.profile.name, isNot('Rejected edit'));
              expect(find.text('Rejected edit'), findsNothing);
              expect(cubit.state.error, const NetworkFailure(offline: true));
            } else {
              expect(cubit.state.notifications.offers, isTrue);
              expect(cubit.state.error, const ServerFailure(status: 500));
            }
          }
        },
      );
    }

    for (final feature in <String>['settings', 'notification_prefs']) {
      testWidgets(
        'notification catalog $feature truly rejects a save: ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          await tester.pumpWidget(
            wrapMidnight(
              _state(
                feature,
                feature == 'settings'
                    ? 'NotificationPreferencesScreen'
                    : 'NotificationPrefsScreen',
                feature == 'settings'
                    ? 'Save failed — retry'
                    : 'Save failed — the toggle reverts, snack carries Retry',
              ),
              locale: locale,
              scrollable: false,
            ),
          );
          await pumpPastFakeLatency(tester);
          expect(tester.takeException(), isNull);
          final context = tester.element(find.byType(NotificationPrefsScreen));
          final cubit = context.read<NotificationPrefsCubit>();
          final state = cubit.state as NotificationPrefsLoaded;
          expect(
            state.prefs.categories.offers,
            isTrue,
            reason: 'the rejected optimistic false toggle must revert',
          );
          expect(state.isSaving, isFalse);
          expect(find.byType(SnackBar), findsOneWidget);
          final copy = AppLocalizations.of(context);
          expect(find.text(copy.actionRetry), findsOneWidget);
          await tester.tap(find.text(copy.actionRetry));
          await tester.pumpAndSettle();
          expect(
            (cubit.state as NotificationPrefsLoaded).prefs.categories.offers,
            isTrue,
          );
          expect(find.byType(SnackBar), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
