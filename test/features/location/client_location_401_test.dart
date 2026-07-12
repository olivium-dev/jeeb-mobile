// JEBV4-108 — honest 401 handling at the create seam.
//
// On-device (C3/auto-filed blocker sig:2afb9ae6c5): POST /v1/requests returned
// 401 (invalid/seam session) and the client showed a generic "check your
// connection" snackbar and stayed put — a dead end, since retrying with the
// same session can never succeed. The client must (a) tell the user the
// session is invalid and (b) route to re-auth. Backend is correct; this is
// client-only (the ticket's residual defect).
//
// Also covers the P2-5 honesty split: a non-auth 4xx/5xx create failure gets
// the couldn't-create copy — connectivity is only blamed for real network
// failures.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_current_location_resolver.dart';
import '../../support/fake_request_submission_service.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arb);
  final String _arb;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _delegate;

String _locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ClientLocationScreen(
          userId: 'user-client-001',
          repository: FakeLocationSelectRepository(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('REGISTER'))),
      ),
      GoRoute(
        path: '/waiting/:id',
        name: 'waiting-no-coverage',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('WAITING'))),
      ),
    ],
  );
}

Widget _harness(GoRouter router) {
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

Future<void> _typeAndConfirm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('clientLocation.descriptionField')),
    '2 shawarma + cola from Barbar',
  );
  await tester.pump();
  await tester.ensureVisible(
    find.bySemanticsIdentifier('location_select_confirm_cta'),
  );
  await tester.tap(find.bySemanticsIdentifier('location_select_confirm_cta'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    _delegate = _SyncDelegate(File('lib/l10n/app_en.arb').readAsStringSync());
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    // JEBV4-176: the current-location option resolves a REAL device fix so the
    // Confirm CTA enables (the create-then-401 path under test depends on it).
    sl.registerLazySingleton<CurrentLocationResolver>(
      FakeCurrentLocationResolver.new,
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
      'JEBV4-108: 401 from POST /v1/requests tells the user the session '
      'expired and routes to re-auth (no connectivity misdirection)',
      (tester) async {
    final submission = FakeRequestSubmissionService(
      error: const RequestSubmissionException(
        RequestSubmissionFailure.unauthorized,
        'HTTP 401',
      ),
    );
    sl.registerLazySingleton<ComposeRequestController>(
      () => ComposeRequestController(submission),
    );
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await _typeAndConfirm(tester);

    // The create fired once (real seam), the honest session message showed,
    // and the user landed on the re-auth surface — NOT a generic dead end.
    expect(submission.submitCount, 1);
    expect(
      find.text('Your session has expired. '
          'Please log in again to send your request.'),
      findsOneWidget,
    );
    expect(_locationOf(router), '/register');
    expect(find.text('REGISTER'), findsOneWidget);
  });

  testWidgets(
      'P2-5: a non-auth 4xx failure shows the couldn\'t-create copy and '
      'stays on the create step (connectivity is never blamed)',
      (tester) async {
    final submission = FakeRequestSubmissionService(
      error: const RequestSubmissionException(
        RequestSubmissionFailure.invalidInput,
        'HTTP 400',
      ),
    );
    sl.registerLazySingleton<ComposeRequestController>(
      () => ComposeRequestController(submission),
    );
    final router = _buildRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await _typeAndConfirm(tester);

    expect(submission.submitCount, 1);
    expect(
      find.text('We could not create your request. Please try again.'),
      findsOneWidget,
    );
    // No misleading connectivity copy, no navigation.
    expect(
      find.textContaining('connection', findRichText: true),
      findsNothing,
    );
    expect(_locationOf(router), '/');
  });
}
