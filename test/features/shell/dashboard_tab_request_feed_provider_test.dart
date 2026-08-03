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

/// JEEBER-LOOP F3 — Jeeber home must expose the active-delivery
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
    sl.registerLazySingleton<AvailabilityGateway>(_OnlineAvailabilityGateway.new);
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

    expect(tester.takeException(), isNull);

    expect(find.byType(JeeberHomeScreen), findsOneWidget);

    final BuildContext screenCtx =
        tester.element(find.byType(JeeberHomeScreen));
    final feedCubit = screenCtx.read<RequestFeedCubit>();
    expect(feedCubit, isA<RequestFeedCubit>());

    expect(
      find.byType(JeeberFeedTabView),
      findsOneWidget,
      reason: 'F3: the active-delivery feed must render so the Jeeber has an '
          'in-app entry point to an active delivery.',
    );
  });
}
