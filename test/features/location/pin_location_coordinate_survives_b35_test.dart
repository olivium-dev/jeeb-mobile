// B-35 — the map-pinned coordinate must survive back to client-location.
//
// The capture-location route used to pop WITHOUT the picked LocationPoint (and
// the router even overrode the screen's own result-consuming handler with a
// fire-and-forget push), so a confirmed pin was silently discarded and every
// pinned pickup collapsed to the Beirut fallback. This test drives the real
// screen flow through a GoRouter whose capture-location leg pops a picked point,
// and asserts that exact coordinate reaches the create draft (G1 payload).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart'
    show LocationPoint;
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arb);
  final Map<String, String> _arb;
  @override
  bool isSupported(Locale locale) => _arb.containsKey(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb[locale.languageCode]!);
  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _delegate;

// The point the customer "drops" on the capture map.
const _pickedPoint = LocationPoint(latitude: 33.9012, longitude: 35.6033);

Widget _app(FakeRequestSubmissionService submission) {
  final router = GoRouter(
    initialLocation: '/client-location',
    routes: <RouteBase>[
      GoRoute(
        path: '/client-location',
        name: 'client-location',
        builder: (_, _) => const ClientLocationScreen(
          userId: 'user-client-001',
          repository: FakeLocationSelectRepository(),
        ),
      ),
      GoRoute(
        path: '/capture-location',
        name: 'capture-location',
        // Simulates the confirmed pin returning the picked coordinate — the
        // exact contract app_router now honours (was `context.pop()` value-less).
        builder: (context, _) => CaptureLocationScreen(
          onPinned: () {
            if (context.canPop()) context.pop(_pickedPoint);
          },
        ),
      ),
      GoRoute(
        path: '/waiting/:id',
        name: 'waiting-no-coverage',
        builder: (_, state) => Scaffold(
          body: Text('waiting-${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    theme: AppTheme.light(),
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: <LocalizationsDelegate<dynamic>>[
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  setUpAll(() {
    _delegate = _SyncDelegate({
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  tearDown(() async => sl.reset());

  testWidgets(
      'a coordinate picked on capture-location survives back into the create '
      'draft (B-35)', (tester) async {
    final submission = FakeRequestSubmissionService(requestId: 'req-b35');
    sl.registerLazySingleton<ComposeRequestController>(
      () => ComposeRequestController(submission),
    );

    await tester.pumpWidget(_app(submission));
    await tester.pumpAndSettle();

    // Open the map picker via the screen's OWN handler (router no longer
    // overrides it) and confirm the pin.
    await tester.tap(
      find.bySemanticsIdentifier('location_select_new_location_cta'),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('capture_location_pin_cta'),
        findsOneWidget);
    await tester.tap(find.bySemanticsIdentifier('capture_location_pin_cta'));
    await tester.pumpAndSettle();

    // Back on client-location: supply the G1 description, then confirm/create.
    await tester.enterText(
      find.byKey(const Key('clientLocation.descriptionField')),
      'A cake from Sea Sweet',
    );
    await tester.pump();
    await tester.tap(
      find.bySemanticsIdentifier('location_select_confirm_cta'),
    );
    await tester.pumpAndSettle();

    // The picked coordinate reached the POST /requests draft verbatim — NOT the
    // Beirut fallback (33.8886, 35.4955).
    final draft = submission.lastDraft;
    expect(draft, isNotNull);
    expect(draft!.pickupLat, 33.9012);
    expect(draft.pickupLng, 35.6033);
    expect(draft.dropoffLat, 33.9012);
    expect(draft.dropoffLng, 35.6033);
  });
}
