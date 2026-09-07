import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/entries/batch_06_entries.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/client_location_screen_fixtures.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_current_location_resolver.dart';
import '../../support/fake_request_submission_service.dart';
import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const _field = Key('clientLocation.descriptionField');
const _inline = 'compose_description_error';

class _PendingSubmission implements RequestSubmissionService {
  final result = Completer<String>();
  @override
  Future<String> submit(RequestDraft draft) => result.future;
}

Future<void> _mount(
  WidgetTester tester,
  Locale locale,
  RequestSubmissionService service,
) async {
  useReduceMotion(tester);
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  sl.registerSingleton(ComposeRequestController(service));
  final router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => ClientLocationScreen(
          userId: 'test-user',
          repository: const FakeLocationSelectRepository(),
          currentLocationResolver: FakeCurrentLocationResolver(),
        ),
      ),
      GoRoute(
        path: '/waiting/:id',
        name: 'waiting-no-coverage',
        builder: (_, _) => const Scaffold(body: Text('created')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(_field), 'Milk 2L');
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.bySemanticsIdentifier('location_select_confirm_cta'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  tearDown(sl.reset);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    for (final label in <String>[
      'description_too_short',
      'moderation_blocked',
    ]) {
      testWidgets(
        'seeded catalog $label renders without compose DI · ${locale.languageCode}',
        (tester) async {
          useReduceMotion(tester);
          tester.view.physicalSize = const Size(1080, 2600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final entry = batch06Entries.singleWhere(
            (entry) => entry.screen == 'Location Select (create flow)',
          );
          expect(entry.states.take(3).map((state) => state.label), <String>[
            'Current location + saved addresses',
            'Saved-addresses load error',
            'Cold load — saved addresses in flight (M4 loading)',
          ]);
          final state = entry.states.singleWhere(
            (state) => state.label == label,
          );
          final router = GoRouter(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, _) => state.builder(context),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(
              routerConfig: router,
              locale: locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                SyncAppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          );
          await tester.pumpAndSettle();
          final l10n = AppLocalizations.of(tester.element(find.byKey(_field)));
          expect(find.bySemanticsIdentifier(_inline), findsOneWidget);
          expect(
            find.text(
              label == 'description_too_short'
                  ? l10n.composeDescriptionTooShort
                  : l10n.composeDescriptionProhibited('Firearms'),
            ),
            findsOneWidget,
          );
          expect(sl.isRegistered<ComposeRequestController>(), isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final code in <String>[
      'too-short',
      'too-long',
      'unrecognized-server-code',
    ]) {
      testWidgets(
        'description $code binds inline and clears on edit · ${locale.languageCode}',
        (tester) async {
          final service = FakeRequestSubmissionService(
            error: RequestSubmissionException.classified(
              RequestSubmissionFailure.invalidInput,
              appFailure: ValidationFailure(
                field: 'description',
                fieldErrors: <String, List<String>>{
                  'description': <String>[code],
                },
              ),
            ),
          );
          await _mount(tester, locale, service);
          final l10n = AppLocalizations.of(tester.element(find.byKey(_field)));
          await _submit(tester);
          final expected = switch (code) {
            'too-short' => l10n.composeDescriptionTooShort,
            'too-long' => l10n.composeDescriptionTooLong,
            _ => l10n.errorValidationBody,
          };
          expect(service.submitCount, 1);
          expect(find.bySemanticsIdentifier(_inline), findsOneWidget);
          expect(find.text(expected), findsOneWidget);
          expect(
            find.bySemanticsIdentifier('client_location_submit_error'),
            findsNothing,
          );
          expect(find.text(code), findsNothing);
          await tester.enterText(find.byKey(_field), 'Bread 2L');
          await tester.pump();
          expect(find.bySemanticsIdentifier(_inline), findsNothing);
        },
      );
    }

    testWidgets(
      'blocked moderation remains inline after snack timeout · ${locale.languageCode}',
      (tester) async {
        await _mount(
          tester,
          locale,
          const ClientLocationScreenModerationSubmissionService(
            blocked: true,
            matches: <String>['Firearms'],
          ),
        );
        await _submit(tester);
        final l10n = AppLocalizations.of(tester.element(find.byKey(_field)));
        expect(
          find.text(l10n.composeDescriptionProhibited('Firearms')),
          findsOneWidget,
        );
        expect(find.bySemanticsIdentifier(_inline), findsOneWidget);
        expect(
          find.bySemanticsIdentifier('client_location_moderation_blocked'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsIdentifier('client_location_moderation_blocked'),
          findsNothing,
        );
        expect(find.bySemanticsIdentifier(_inline), findsOneWidget);
        expect(find.text('created'), findsNothing);
      },
    );

    testWidgets(
      'network failure remains a snack, not a field error · ${locale.languageCode}',
      (tester) async {
        await _mount(
          tester,
          locale,
          FakeRequestSubmissionService(
            error: const RequestSubmissionException.classified(
              RequestSubmissionFailure.network,
              appFailure: NetworkFailure(offline: true),
            ),
          ),
        );
        await _submit(tester);
        expect(
          find.bySemanticsIdentifier('client_location_submit_error'),
          findsOneWidget,
        );
        expect(find.bySemanticsIdentifier(_inline), findsNothing);
      },
    );
  }

  testWidgets('late validation does not blame a description edited in flight', (
    tester,
  ) async {
    final service = _PendingSubmission();
    await _mount(tester, const Locale('en'), service);
    await tester.tap(find.bySemanticsIdentifier('location_select_confirm_cta'));
    await tester.pump();
    await tester.enterText(find.byKey(_field), 'Edited order');
    service.result.completeError(
      ClientLocationScreenFixtures.validationTooShort,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier(_inline), findsNothing);
    // The server outcome is never swallowed: the snack carries it instead.
    expect(
      find.bySemanticsIdentifier('client_location_submit_error'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'blocked moderation still surfaces a snack when edited in flight',
    (tester) async {
      final service = _PendingSubmission();
      await _mount(tester, const Locale('en'), service);
      await tester.tap(
        find.bySemanticsIdentifier('location_select_confirm_cta'),
      );
      await tester.pump();
      await tester.enterText(find.byKey(_field), 'Edited order');
      service.result.completeError(ClientLocationScreenFixtures.moderationBlocked);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('client_location_moderation_blocked'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier(_inline), findsNothing);
      expect(find.text('created'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
