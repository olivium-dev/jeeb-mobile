import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/tabs/dashboard_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// JEEBER-LOOP F3 — Jeeber home must expose the active-delivery feed.
///
/// Before the fix, [DashboardTab._JeeberHomeHost] mounted [JeeberHomeScreen]
/// with NO `requestFeedCubit`, so the screen was pinned to State 2 (the
/// availability toggle only): the Jeeber had no in-app entry to an active
/// delivery and could only reach one via a deep link. This test pumps the REAL
/// [DashboardTab] under a router with DI registered and asserts that:
///
///   1. a [RequestFeedCubit] is STRUCTURALLY resolvable from inside the
///      [JeeberHomeScreen] subtree (the host now provides it), and
///   2. with the Jeeber online and a seeded feed, the feed entry
///      ([JeeberFeedTabView], State 3) actually renders.
///
/// On the pre-fix source assertion 1 throws `ProviderNotFound<RequestFeedCubit>`
/// (the screen's `BlocProvider.value` is never built because the cubit is null)
/// and assertion 2 never renders the feed — it stays on the no-requests view.
class _OnlineAvailabilityGateway extends InMemoryAvailabilityGateway {
  _OnlineAvailabilityGateway()
      : super(
          initial: AvailabilityStatus.initial.copyWith(
            state: AvailabilityState.online,
          ),
        );
}

LocalizationsDelegate<AppLocalizations> _loadSyncDelegate() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  return _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: DashboardTab()),
      ),
      GoRoute(
        path: '/jeeber/onboarding',
        name: 'jeeber-onboarding',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/jeeber/requests/:id',
        name: 'jeeber-request-detail',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
}

Widget _app(LocalizationsDelegate<AppLocalizations> delegate) {
  return MaterialApp.router(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: _router(),
  );
}

void main() {
  late LocalizationsDelegate<AppLocalizations> delegate;

  setUpAll(() {
    delegate = _loadSyncDelegate();
  });

  setUp(() {
    // The two DI registrations the production DashboardTab resolves.
    sl.registerLazySingleton<AvailabilityGateway>(_OnlineAvailabilityGateway.new);
    // A seeded feed so State 3 (the feed entry) actually renders — the whole
    // point of F3.
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(DevJeeberFeedFixtures.incoming()),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
      'DashboardTab provides a RequestFeedCubit above JeeberHomeScreen and '
      'renders the active-delivery feed entry (F3)', (tester) async {
    await tester.pumpWidget(_app(delegate));
    await tester.pumpAndSettle();

    // No crash bringing the Jeeber surface up.
    expect(tester.takeException(), isNull);

    // The registered Jeeber home rendered.
    expect(find.byType(JeeberHomeScreen), findsOneWidget);

    // 1. The RequestFeedCubit is STRUCTURALLY resolvable from inside
    //    JeeberHomeScreen's subtree (read<T>() throws if absent), proving the
    //    host wired it — not merely "no error". This is the fail-without anchor:
    //    pre-fix the host passed no requestFeedCubit, so the screen's
    //    BlocProvider.value was never built and this read throws.
    final BuildContext screenCtx =
        tester.element(find.byType(JeeberHomeScreen));
    final feedCubit = screenCtx.read<RequestFeedCubit>();
    expect(feedCubit, isA<RequestFeedCubit>());

    // 2. With the Jeeber online + seeded requests, the feed entry (State 3)
    //    renders. Pre-fix this never appeared (State 2 toggle-only).
    expect(
      find.byType(JeeberFeedTabView),
      findsOneWidget,
      reason: 'F3: the active-delivery feed must render so the Jeeber has an '
          'in-app entry point to an active delivery.',
    );
  });
}
